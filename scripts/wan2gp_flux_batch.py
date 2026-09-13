#!/usr/bin/env bash
"true" '''\'
# Self-executing Python wrapper using the WAN2GP virtual environment
APP_DIR="/var/home/mplanetarian/pinokio/api/wan.git/app"
VENV_PYTHON="$APP_DIR/venv/bin/python"

if [ ! -x "$VENV_PYTHON" ]; then
    echo -e "\033[0;31m[-] Error: WAN2GP Python virtualenv not found at: $VENV_PYTHON\033[0m" >&2
    exit 1
fi

SITE_PKGS=$("$VENV_PYTHON" -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
export LD_LIBRARY_PATH="$SITE_PKGS/nvidia/cudnn/lib:$SITE_PKGS/nvidia/cublas/lib:$SITE_PKGS/nvidia/cuda_runtime/lib:${LD_LIBRARY_PATH:-}"
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
export CUDA_VISIBLE_DEVICES="0"

exec "$VENV_PYTHON" "$0" "$@"
'''

import argparse
import gc
import math
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any
from PIL import Image

# Styling colors
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
CYAN = "\033[0;36m"
RED = "\033[0;31m"
BOLD = "\033[1m"
RESET = "\033[0m"

# Default directories
DATA_DIR = Path("/run/media/mplanetarian/DATA")
BATCH_DIR = DATA_DIR / "WAN2GP_FLUX_BATCH"
CTRL_IMAGE_DIR = BATCH_DIR / "CTRL_IMAGE"
PROCESSED_DIR = BATCH_DIR / "PROCESSED"
OUTPUT_DIR = Path("/home/mplanetarian/Documents/WAN2GP_OUTPUTS")

# WAN2GP constants
WAN_APP_ROOT = Path("/var/home/mplanetarian/pinokio/api/wan.git/app")
MODEL_TYPE = "flux2_klein_9b"
BFS_LORA = "bfs_head_v1_flux-klein_9b_step3750_rank64.safetensors"
INFERENCE_STEPS = 4
SAFE_PROFILE = "4.5"
ATTENTION_MODE = "sage"

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}


def format_duration(seconds: float | None) -> str:
    """Format seconds into readable mm:ss or hh:mm:ss format."""
    if seconds is None or seconds < 0 or not math.isfinite(seconds):
        return "--:--"
    m, s = divmod(int(round(seconds)), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}h {m:02d}m {s:02d}s"
    return f"{m:02d}:{s:02d}"


class BatchProgressTracker:
    """Real-time progress callback and animated terminal display for WAN2GP generation."""

    def __init__(
        self,
        batch_index: int,
        total_batch: int,
        image_name: str,
        model_name: str,
        completed_durations: list[float],
        inference_steps: int = 4,
    ):
        self.batch_index = batch_index
        self.total_batch = total_batch
        self.image_name = image_name
        self.model_name = model_name
        self.completed_durations = completed_durations
        self.expected_steps = inference_steps

        self.start_time = time.time()
        self.current_step: int | None = None
        self.total_steps: int | None = inference_steps
        self.percent: int = 0
        self.phase: str = "Preparing"
        self.status_detail: str = ""
        self.active: bool = True

        self._lock = threading.Lock()
        self._spinner_frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        self._spinner_idx = 0

        self._thread = threading.Thread(target=self._ticker_loop, daemon=True, name="batch-progress-ticker")
        self._thread.start()

    def on_progress(self, progress: Any) -> None:
        with self._lock:
            if hasattr(progress, "current_step") and progress.current_step is not None:
                self.current_step = progress.current_step
            if hasattr(progress, "total_steps") and progress.total_steps is not None and progress.total_steps > 0:
                self.total_steps = progress.total_steps
            if hasattr(progress, "progress") and progress.progress is not None:
                self.percent = max(self.percent, int(progress.progress))
            if hasattr(progress, "phase") and progress.phase:
                raw_p = str(progress.phase).replace("_", " ").title()
                if "Inference" in raw_p or "Denoising" in raw_p:
                    self.phase = "Denoising"
                elif "Decoding" in raw_p or "Vae" in raw_p:
                    self.phase = "VAE Decoding"
                elif "Encoding" in raw_p or "Text" in raw_p:
                    self.phase = "Encoding Prompt"
                elif "Loading" in raw_p:
                    self.phase = "Loading Model"
                else:
                    self.phase = raw_p
            if hasattr(progress, "status") and progress.status:
                self.status_detail = str(progress.status)

    def on_status(self, status: Any) -> None:
        with self._lock:
            if status:
                s_str = str(status)
                self.status_detail = s_str
                s_lower = s_str.lower()
                if "denois" in s_lower:
                    self.phase = "Denoising"
                elif "vae" in s_lower or "decod" in s_lower:
                    self.phase = "VAE Decoding"
                elif "prompt" in s_lower or "encod" in s_lower:
                    self.phase = "Encoding Prompt"

    def on_info(self, info: Any) -> None:
        with self._lock:
            if info:
                self.status_detail = str(info)

    def on_error(self, error: Any) -> None:
        with self._lock:
            self.phase = "Error"
            if hasattr(error, "message"):
                self.status_detail = str(error.message)

    def stop(self) -> None:
        with self._lock:
            self.active = False
        if self._thread.is_alive():
            self._thread.join(timeout=0.3)
        sys.__stdout__.write("\r\033[K")
        sys.__stdout__.flush()

    def _ticker_loop(self) -> None:
        while self.active:
            with self._lock:
                now = time.time()
                elapsed = now - self.start_time
                self._spinner_idx = (self._spinner_idx + 1) % len(self._spinner_frames)
                spinner = self._spinner_frames[self._spinner_idx]

                curr_s = self.current_step
                tot_s = self.total_steps or self.expected_steps
                pct = self.percent

                if curr_s is not None and tot_s is not None and tot_s > 0:
                    step_pct = int((curr_s / tot_s) * 80) + 10
                    pct = max(pct, min(90, step_pct))
                    if curr_s >= tot_s:
                        pct = max(pct, 92)

                task_eta = None
                if curr_s is not None and curr_s > 0 and tot_s is not None and tot_s > 0:
                    time_per_step = elapsed / curr_s
                    rem_steps = max(0, tot_s - curr_s)
                    vae_buffer = 3.0 if "denois" in self.phase.lower() or curr_s < tot_s else 1.0
                    task_eta = (rem_steps * time_per_step) + vae_buffer
                elif pct > 10:
                    task_eta = max(0.0, (elapsed / (pct / 100.0)) - elapsed)

                batch_eta = None
                if self.total_batch > 0:
                    remaining_items = max(0, self.total_batch - self.batch_index)
                    if self.completed_durations:
                        avg_item_time = sum(self.completed_durations) / len(self.completed_durations)
                        curr_rem = task_eta if task_eta is not None else max(0.0, avg_item_time - elapsed)
                        batch_eta = (remaining_items * avg_item_time) + curr_rem
                    elif task_eta is not None:
                        est_item_time = elapsed + task_eta
                        batch_eta = task_eta + (remaining_items * est_item_time)

                bar_len = 16
                pct_clamped = max(0, min(100, pct))
                filled = int(bar_len * (pct_clamped / 100.0))
                bar_str = "█" * filled + "░" * (bar_len - filled)

                batch_str = f"[{self.batch_index}/{self.total_batch}]" if self.total_batch > 0 else "[Watch]"
                step_str = f"Step {curr_s}/{tot_s} ({self.phase})" if (curr_s is not None and tot_s is not None and tot_s > 0) else self.phase
                elapsed_fmt = format_duration(elapsed)
                eta_fmt = format_duration(task_eta)
                batch_eta_fmt = f" | Batch Est: ~{format_duration(batch_eta)}" if (batch_eta is not None and self.total_batch > 1) else ""

                line = (
                    f"\r  {CYAN}{spinner}{RESET} {batch_str} "
                    f"[{GREEN}{bar_str}{RESET}] {BOLD}{pct_clamped:>3}%{RESET} | "
                    f"{YELLOW}{step_str}{RESET} | "
                    f"Time: {CYAN}{elapsed_fmt}{RESET} (ETA: {GREEN}{eta_fmt}{RESET}{batch_eta_fmt})"
                )

                sys.__stdout__.write(f"{line}\033[K")
                sys.__stdout__.flush()

            time.sleep(0.12)


def natural_sort_key(p: Path):
    """Sort filenames naturally (e.g. 1, 2, 10 instead of 1, 10, 2)."""
    return [int(text) if text.isdigit() else text.lower() for text in re.split(r'(\d+)', p.name)]


def get_control_images(ctrl_dir: Path) -> list[Path]:
    """Find all valid control image files inside CTRL_IMAGE_DIR, sorted naturally."""
    if not ctrl_dir.is_dir():
        return []
    images = [
        item for item in ctrl_dir.iterdir()
        if item.is_file() and item.suffix.lower() in SUPPORTED_EXTENSIONS and not item.name.startswith(".")
    ]
    images.sort(key=natural_sort_key)
    return images


def get_control_image(ctrl_dir: Path) -> Path | None:
    """Find the primary control image file inside CTRL_IMAGE_DIR."""
    images = get_control_images(ctrl_dir)
    return images[0] if images else None


def check_and_resolve_running_server():
    """Ensure no conflicting wgp.py server is running to prevent OOM/GPU lockup."""
    try:
        res = subprocess.run(["pgrep", "-f", "python.*wgp\\.py"], capture_output=True, text=True)
        pids = [p.strip() for p in res.stdout.strip().split("\n") if p.strip()]
        current_pid = str(os.getpid())
        pids = [p for p in pids if p != current_pid]

        if pids:
            print(f"{YELLOW}[!] WARNING: Active WAN2GP server process detected (PID: {', '.join(pids)}).{RESET}")
            print(f"{YELLOW}    Running concurrent instances will exceed GPU VRAM / System RAM and can cause system instability.{RESET}")
            ans = input(f"{BOLD}    Would you like to stop the WAN2GP server now to proceed safely? [Y/n]: {RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                print(f"{CYAN}[*] Stopping existing WAN2GP instance...{RESET}")
                stop_script = Path("/var/home/mplanetarian/wan2gp.sh")
                if stop_script.exists():
                    subprocess.run(["bash", str(stop_script), "stop"], check=False)
                else:
                    subprocess.run(["pkill", "-TERM", "-f", "python.*wgp\\.py"], check=False)
                time.sleep(2)
                # Verify stopped
                check_res = subprocess.run(["pgrep", "-f", "python.*wgp\\.py"], capture_output=True, text=True)
                check_pids = [p.strip() for p in check_res.stdout.strip().split("\n") if p.strip() and p.strip() != current_pid]
                if check_pids:
                    print(f"{YELLOW}[*] Forcefully terminating lingering server processes...{RESET}")
                    subprocess.run(["pkill", "-9", "-f", "python.*wgp\\.py"], check=False)
                    time.sleep(1)
                print(f"{GREEN}[✓] WAN2GP server stopped. GPU VRAM is now available.{RESET}")
            else:
                print(f"{RED}[-] Aborting batch run to avoid memory conflict.{RESET}")
                sys.exit(0)
    except Exception as e:
        print(f"{YELLOW}[!] Warning while checking server status: {e}{RESET}")


def get_user_prompt(initial_prompt: str | None = None, multi_ctrl: bool = False, num_ctrls: int = 1) -> str:
    """Prompt the user until a non-empty prompt is provided."""
    if initial_prompt and initial_prompt.strip():
        return initial_prompt.strip()

    if multi_ctrl and num_ctrls > 1:
        print(f"\n{YELLOW}[i] Picture 1 will cycle through all {num_ctrls} Control Images in CTRL_IMAGE dir.{RESET}")
    else:
        print(f"\n{YELLOW}[i] Picture 1 is the Control Image (loaded from CTRL_IMAGE dir).{RESET}")
    print(f"{YELLOW}[i] Picture 2 is the Batch Input Image (from WAN2GP_FLUX_BATCH dir).{RESET}")
    while True:
        try:
            prompt = input(f"\n{BOLD}{CYAN}Enter generation prompt for Flux 2 Klein 9B: {RESET}").strip()
            if prompt:
                return prompt
            print(f"{RED}[-] Prompt cannot be empty. Please enter a valid prompt.{RESET}")
        except (KeyboardInterrupt, EOFError):
            print(f"\n{YELLOW}[*] Canceled by user.{RESET}")
            sys.exit(0)


def calculate_720p_resolution(image_path: Path) -> str:
    """Determine 720p resolution matching the input image aspect ratio."""
    try:
        with Image.open(image_path) as img:
            w, h = img.size
            if w > h:
                return "1280x720"  # 16:9 Landscape 720p
            elif h > w:
                return "720x1280"  # 9:16 Portrait 720p
            else:
                return "720x720"   # 1:1 Square 720p
    except Exception:
        return "1280x720"


def find_pending_images(batch_dir: Path) -> list[Path]:
    """Find image files directly in BATCH_DIR (ignoring subdirectories)."""
    if not batch_dir.is_dir():
        return []

    images = []
    for item in sorted(batch_dir.iterdir()):
        if item.is_file() and item.suffix.lower() in SUPPORTED_EXTENSIONS and not item.name.startswith("."):
            images.append(item)
    return images


def rename_converted_outputs(source_image: Path, generated_files: list[str], ctrl_image: Path | None = None, total_ctrls: int = 1) -> list[Path]:
    """Rename generated output files to preserve the original image filename with '_2' appended.

    If multiple control images are being used (total_ctrls > 1), the control image identifier
    is included in the filename: [source_stem]_[ctrl_stem]_2.[ext]
    If single control image (total_ctrls == 1): [source_stem]_2.[ext]
    """
    renamed = []
    for idx, file_path_str in enumerate(generated_files):
        gen_file = Path(file_path_str)
        if not gen_file.exists():
            renamed.append(gen_file)
            continue

        out_ext = source_image.suffix if source_image.suffix.lower() in {".jpg", ".jpeg"} else (gen_file.suffix or source_image.suffix or ".jpg")
        
        if total_ctrls > 1 and ctrl_image:
            safe_ctrl_stem = re.sub(r'[^\w\-]', '_', ctrl_image.stem)[:32]
            ctrl_tag = f"_{safe_ctrl_stem}"
        else:
            ctrl_tag = ""

        suffix_tag = f"{ctrl_tag}_2" if idx == 0 else f"{ctrl_tag}_2_{idx+1}"
        target_name = f"{source_image.stem}{suffix_tag}{out_ext}"
        target_path = gen_file.parent / target_name

        if target_path.exists() and target_path != gen_file:
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            target_name = f"{source_image.stem}{suffix_tag}_{timestamp}{out_ext}"
            target_path = gen_file.parent / target_name
            counter = 1
            while target_path.exists() and target_path != gen_file:
                target_name = f"{source_image.stem}{suffix_tag}_{timestamp}_{counter}{out_ext}"
                target_path = gen_file.parent / target_name
                counter += 1

        shutil.move(str(gen_file), str(target_path))
        renamed.append(target_path)
    return renamed


def move_to_processed(source_path: Path, processed_dir: Path) -> Path:
    """Safely move the processed image to PROCESSED_DIR without overwriting."""
    processed_dir.mkdir(parents=True, exist_ok=True)
    target_path = processed_dir / source_path.name
    if target_path.exists():
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        target_path = processed_dir / f"{source_path.stem}_{timestamp}{source_path.suffix}"
    shutil.move(str(source_path), str(target_path))
    return target_path


def main():
    parser = argparse.ArgumentParser(description="WAN2GP Flux 2 Klein 9B Batch Image Processor")
    parser.add_argument("--prompt", "-p", type=str, default=None, help="Generation prompt")
    parser.add_argument("--watch", "-w", action="store_true", help="Run in continuous watch mode (check every 2 seconds)")
    parser.add_argument("--interval", "-i", type=float, default=2.0, help="Check interval in seconds for watch mode (default: 2.0)")
    parser.add_argument("--multi-control", "-m", action="store_true", help="Enable multi-control mode: process all control images in CTRL_IMAGE dir for each input image")
    parser.add_argument("--single-control", "-s", action="store_true", help="Force single-control mode: process only the first/primary control image")
    args = parser.parse_args()

    # 1. Verify DATA directory
    if not DATA_DIR.exists():
        print(f"{RED}[-] Error: DATA drive not mounted at {DATA_DIR}! Please mount it first.{RESET}")
        sys.exit(1)

    BATCH_DIR.mkdir(parents=True, exist_ok=True)
    CTRL_IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    all_ctrls = get_control_images(CTRL_IMAGE_DIR)

    # Determine control mode
    if args.multi_control:
        use_multi = True
    elif args.single_control:
        use_multi = False
    else:
        if len(all_ctrls) > 1:
            print(f"\n{YELLOW}[?] Detected multiple ({len(all_ctrls)}) control images in {CTRL_IMAGE_DIR}:{RESET}")
            for i, c in enumerate(all_ctrls, 1):
                print(f"    {i}) {c.name}")
            try:
                ans = input(f"\n{BOLD}{CYAN}Convert each batch image against ALL {len(all_ctrls)} control images? [Y/n]: {RESET}").strip().lower()
                use_multi = ans in ("", "y", "yes")
            except (KeyboardInterrupt, EOFError):
                print(f"\n{YELLOW}[*] Canceled by user.{RESET}")
                sys.exit(0)
        else:
            use_multi = False

    active_ctrls = all_ctrls if use_multi else (all_ctrls[:1] if all_ctrls else [])

    if all_ctrls:
        ctrl_names = [c.name for c in all_ctrls]
        if len(ctrl_names) <= 3:
            ctrl_display = ", ".join(ctrl_names)
        else:
            ctrl_display = f"{len(ctrl_names)} images ({ctrl_names[0]}, {ctrl_names[1]}, ...)"
    else:
        ctrl_display = "None found"

    mode_label = f"Multi-Control ({len(active_ctrls)} control images)" if use_multi else "Single Control"

    print(f"{BOLD}{CYAN}======================================================{RESET}")
    print(f"{BOLD}{CYAN}    WAN2GP FLUX 2 KLEIN 9B BATCH IMAGE PROCESSOR      {RESET}")
    print(f"{BOLD}{CYAN}======================================================{RESET}")
    print(f"  Model:            {GREEN}Flux 2 Klein 9B (Distilled, 4 Steps){RESET}")
    print(f"  LoRA:             {GREEN}BFS LoRA (bfs_head_v1_flux-klein_9b...){RESET}")
    print(f"  Quality:          {GREEN}720p Output Resolution{RESET}")
    print(f"  Reference Mode:   {GREEN}Picture 1 = Control Image, Picture 2 = Batch Image (KI){RESET}")
    print(f"  Naming Pattern:   {GREEN}[image]{'_[ctrl]' if use_multi else ''}_2.[ext]{RESET}")
    print(f"  Control Image(s): {YELLOW}{CTRL_IMAGE_DIR}{RESET} -> [{GREEN}{ctrl_display}{RESET}]")
    print(f"  Control Mode:     {BOLD}{CYAN}{mode_label}{RESET}")
    print(f"  Input Directory:  {YELLOW}{BATCH_DIR}{RESET}")
    print(f"  Output Directory: {GREEN}{OUTPUT_DIR}{RESET}")
    print(f"  Processed Dir:    {GREEN}{PROCESSED_DIR}{RESET}")
    print(f"  Safety Profile:   {CYAN}Profile {SAFE_PROFILE} (LowRAM_LowVRAM+ / Memory Safe){RESET}")
    print(f"{CYAN}------------------------------------------------------{RESET}")

    if active_ctrls:
        if use_multi:
            print(f"{GREEN}[✓] Multi-control enabled: Running separate conversions across {len(active_ctrls)} control images:{RESET}")
            for c_idx, c_path in enumerate(active_ctrls, 1):
                print(f"    {c_idx}. {BOLD}{c_path.name}{RESET}")
        else:
            print(f"{GREEN}[✓] Using primary control image (Picture 1): {BOLD}{active_ctrls[0].name}{RESET}")
    else:
        print(f"{YELLOW}[!] Notice: No control image currently found in {CTRL_IMAGE_DIR}.{RESET}")
        print(f"{YELLOW}    Please place one or more control images into {CTRL_IMAGE_DIR} before processing.{RESET}")

    # 2. Check for server conflict before allocating memory
    check_and_resolve_running_server()

    # 3. Always require prompt input before running
    prompt = get_user_prompt(args.prompt, multi_ctrl=use_multi, num_ctrls=len(active_ctrls))
    print(f"{GREEN}[✓] Active prompt: {BOLD}\"{prompt}\"{RESET}")

    # 4. Initialize WAN2GP Session in safe Profile 4.5
    sys.path.insert(0, str(WAN_APP_ROOT))
    import torch
    from shared.api import WanGPSession

    print(f"\n{CYAN}[*] Initializing WAN2GP runtime (Profile {SAFE_PROFILE}, Attention: {ATTENTION_MODE})...{RESET}")
    session = WanGPSession(
        root=WAN_APP_ROOT,
        cli_args=["--profile", SAFE_PROFILE, "--attention", ATTENTION_MODE],
        output_dir=OUTPUT_DIR,
        console_output=True,
    )
    session.ensure_ready()
    print(f"{GREEN}[✓] WAN2GP runtime loaded and ready.{RESET}\n")

    def cleanup_and_exit(signum=None, frame=None):
        print(f"\n{YELLOW}[*] Shutting down session and freeing GPU memory...{RESET}")
        try:
            session.close()
        except Exception:
            pass
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        print(f"{GREEN}[✓] Cleaned up successfully. Exiting.{RESET}")
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup_and_exit)
    signal.signal(signal.SIGTERM, cleanup_and_exit)

    completed_durations: list[float] = []

    def process_single_conversion(image_path: Path, ctrl_path: Path, ctrl_idx: int = 1, total_ctrls: int = 1, conv_idx: int = 1, total_convs: int = 1) -> bool:
        """Run a single conversion for an input image against a given control image."""
        res = calculate_720p_resolution(image_path)
        ctrl_badge = f" [Control {ctrl_idx}/{total_ctrls}]" if total_ctrls > 1 else ""
        conv_badge = f"[{conv_idx}/{total_convs}] " if total_convs > 1 else ""
        print(f"\n{BOLD}{CYAN}--------------------------------------------------{RESET}")
        print(f"{BOLD}[*] {conv_badge}Processing: {YELLOW}{image_path.name}{RESET}{ctrl_badge}")
        print(f"    Picture 1 (Control Image): {GREEN}{ctrl_path.name}{RESET}{ctrl_badge}")
        print(f"    Picture 2 (Batch Input):   {YELLOW}{image_path.name}{RESET}")
        print(f"    Target Resolution:         {CYAN}{res}{RESET}")
        print(f"    Reference Mode:            {CYAN}Picture 1 (Control) + Picture 2 (Input){RESET}")
        if completed_durations:
            avg_t = sum(completed_durations) / len(completed_durations)
            rem_convs = total_convs - conv_idx + 1
            est_rem = rem_convs * avg_t
            print(f"    Est. Batch Remaining:      {CYAN}~{format_duration(est_rem)} ({rem_convs} conversion(s) left @ ~{avg_t:.1f}s/ea){RESET}")
        print(f"{CYAN}--------------------------------------------------{RESET}")

        settings = session.get_default_settings(MODEL_TYPE)
        settings.update({
            "prompt": prompt,
            "resolution": res,
            "video_prompt_type": "KI",
            "image_guide": str(ctrl_path.resolve()),
            "image_refs": [str(ctrl_path.resolve()), str(image_path.resolve())],
            "activated_loras": [BFS_LORA],
            "loras_multipliers": "1.0",
            "num_inference_steps": INFERENCE_STEPS,
        })

        tracker = BatchProgressTracker(
            batch_index=conv_idx,
            total_batch=total_convs,
            image_name=image_path.name,
            model_name="Flux 2 Klein 9B",
            completed_durations=completed_durations,
            inference_steps=INFERENCE_STEPS,
        )

        try:
            start_t = time.time()
            result = session.run_task(settings, callbacks=tracker)
            elapsed = time.time() - start_t
            tracker.stop()

            if result.success:
                completed_durations.append(elapsed)
                renamed_outputs = rename_converted_outputs(image_path, result.generated_files, ctrl_image=ctrl_path, total_ctrls=total_ctrls)
                output_names = [p.name for p in renamed_outputs]
                print(f"{GREEN}[✓] Generated conversion {conv_idx}/{total_convs} in {elapsed:.1f}s! Saved output: {', '.join(output_names)}{RESET}")

                done_count = len(completed_durations)
                if total_convs > 1 and done_count < total_convs:
                    avg_t = sum(completed_durations) / done_count
                    rem_c = total_convs - done_count
                    rem_t = rem_c * avg_t
                    pct_done = (done_count / total_convs) * 100
                    print(f"{CYAN}[i] Batch Progress: {done_count}/{total_convs} conversions done ({pct_done:.0f}%) | "
                          f"Avg: {avg_t:.1f}s/ea | Est. Remaining: ~{format_duration(rem_t)}{RESET}")
                return True
            else:
                tracker.stop()
                err_msgs = [e.message for e in result.errors]
                print(f"{RED}[-] Generation failed for {image_path.name} with control {ctrl_path.name}: {', '.join(err_msgs)}{RESET}")
                return False
        except Exception as ex:
            tracker.stop()
            print(f"{RED}[-] Exception during generation for {image_path.name} with control {ctrl_path.name}: {ex}{RESET}")
            return False
        finally:
            tracker.stop()
            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    def process_input_image(image_path: Path, ctrl_list: list[Path], conv_start_idx: int = 1, total_convs: int = 1) -> tuple[bool, int]:
        """Process a single input image across all specified control images.
        Only moves the source file to PROCESSED_DIR when all control conversions succeed.
        Returns (success_bool, next_conv_idx).
        """
        if not ctrl_list:
            print(f"{RED}[-] Error: No control images provided for {image_path.name}!{RESET}")
            return False, conv_start_idx

        total_ctrls = len(ctrl_list)
        successes = 0
        curr_conv = conv_start_idx

        for idx, ctrl_path in enumerate(ctrl_list, 1):
            if process_single_conversion(image_path, ctrl_path, ctrl_idx=idx, total_ctrls=total_ctrls, conv_idx=curr_conv, total_convs=total_convs):
                successes += 1
            curr_conv += 1

        if successes == total_ctrls:
            dest = move_to_processed(image_path, PROCESSED_DIR)
            print(f"{GREEN}[✓] Completed all {total_ctrls} control conversion(s) for {image_path.name}! Moved input to: {dest.name}{RESET}")
            return True, curr_conv
        elif successes > 0:
            print(f"{YELLOW}[!] Partial success ({successes}/{total_ctrls}) for {image_path.name}. Keeping input in batch directory for inspection.{RESET}")
            return False, curr_conv
        else:
            print(f"{RED}[-] All conversions failed for {image_path.name}. Retaining input in batch directory.{RESET}")
            return False, curr_conv

    # 5. Execution mode: Watch Mode or Batch Run
    watch_mode = args.watch
    if not watch_mode:
        initial_images = find_pending_images(BATCH_DIR)
        if not initial_images:
            print(f"{YELLOW}[i] No pending images found in {BATCH_DIR}.{RESET}")
            print(f"{CYAN}Entering Watch Mode (checks for new images every {args.interval}s). Press Ctrl+C to stop.{RESET}")
            watch_mode = True
        else:
            print(f"{GREEN}[i] Found {len(initial_images)} pending image(s) to process.{RESET}")

    if watch_mode:
        ctrl_mode_desc = f"Multi-Control ({len(active_ctrls)} controls)" if use_multi else "Single-Control"
        print(f"\n{BOLD}{GREEN}[*] Watching {BATCH_DIR} for new images every {args.interval}s [{ctrl_mode_desc}]...{RESET}")
        print(f"{CYAN}(Drop images into {BATCH_DIR} to generate. Press Ctrl+C to exit.){RESET}\n")
        failed_attempts: dict[Path, int] = {}
        last_ctrl_names: list[str] = []
        try:
            while True:
                current_ctrls = get_control_images(CTRL_IMAGE_DIR)
                current_names = [c.name for c in current_ctrls]
                if current_names != last_ctrl_names:
                    if current_ctrls:
                        mode_str = f"Multi-Control ({len(current_ctrls)} images)" if use_multi else f"Single-Control (Active: {current_ctrls[0].name})"
                        print(f"{GREEN}[✓] Control images in {CTRL_IMAGE_DIR}: {', '.join(current_names)} [{mode_str}]{RESET}")
                    else:
                        print(f"{YELLOW}[!] All control images removed from {CTRL_IMAGE_DIR}. Waiting for control images...{RESET}")
                    last_ctrl_names = current_names

                if not current_ctrls:
                    time.sleep(args.interval)
                    continue

                step_ctrls = current_ctrls if use_multi else current_ctrls[:1]
                images = find_pending_images(BATCH_DIR)
                actionable_images = [img for img in images if failed_attempts.get(img, 0) < 2]

                if actionable_images:
                    total_conversions = len(actionable_images) * len(step_ctrls)
                    print(f"\n{BOLD}{GREEN}[+] Detected {len(actionable_images)} new image(s)! Starting batch ({total_conversions} conversions across {len(step_ctrls)} control(s))...{RESET}")
                    sub_start = time.time()
                    curr_conv_idx = 1
                    for img in actionable_images:
                        ok, curr_conv_idx = process_input_image(img, step_ctrls, conv_start_idx=curr_conv_idx, total_convs=total_conversions)
                        if ok:
                            failed_attempts.pop(img, None)
                        else:
                            failed_attempts[img] = failed_attempts.get(img, 0) + 1
                            if failed_attempts[img] >= 2:
                                print(f"{RED}[!] Image {img.name} failed twice. Skipping in watch mode until resolved.{RESET}")
                    sub_elapsed = time.time() - sub_start
                    print(f"\n{GREEN}[✓] Batch pass finished ({total_conversions} conversions in {format_duration(sub_elapsed)}). Resuming watch mode...{RESET}\n")
                time.sleep(args.interval)
        except KeyboardInterrupt:
            cleanup_and_exit()
    else:
        # Single-pass batch run
        images = find_pending_images(BATCH_DIR)
        if not active_ctrls:
            print(f"{RED}[-] Error: No control images found in {CTRL_IMAGE_DIR}! Please place at least one control image before running batch.{RESET}")
            cleanup_and_exit()

        if not images:
            print(f"{YELLOW}[i] No pending images found in {BATCH_DIR} to process.{RESET}")
            cleanup_and_exit()

        total_imgs = len(images)
        total_conversions = total_imgs * len(active_ctrls)
        print(f"\n{BOLD}{CYAN}Batch Plan:{RESET}")
        print(f"  Input images:       {total_imgs}")
        print(f"  Control images:     {len(active_ctrls)} ({', '.join(c.name for c in active_ctrls)})")
        print(f"  Total conversions:  {total_conversions}")
        print(f"{CYAN}------------------------------------------------------{RESET}")

        success_count = 0
        fail_count = 0
        batch_start_time = time.time()
        curr_conv_idx = 1

        for img_idx, img in enumerate(images, 1):
            print(f"\n{BOLD}{CYAN}=== [{img_idx}/{total_imgs}] {img.name} ==={RESET}")
            ok, curr_conv_idx = process_input_image(img, active_ctrls, conv_start_idx=curr_conv_idx, total_convs=total_conversions)
            if ok:
                success_count += 1
            else:
                fail_count += 1

        total_elapsed = time.time() - batch_start_time
        print(f"\n{BOLD}{GREEN}======================================================{RESET}")
        print(f"{BOLD}{GREEN}                 BATCH COMPLETED                      {RESET}")
        print(f"{BOLD}{GREEN}======================================================{RESET}")
        print(f"  Input Images Processed: {GREEN}{success_count}{RESET} / {total_imgs}")
        print(f"  Failed Images:          {RED if fail_count > 0 else GREEN}{fail_count}{RESET}")
        print(f"  Control Images Used:    {CYAN}{len(active_ctrls)}{RESET}")
        print(f"  Total Conversions:      {CYAN}{total_conversions}{RESET}")
        print(f"  Total Time:             {CYAN}{format_duration(total_elapsed)} ({total_elapsed:.1f}s){RESET}")
        if completed_durations:
            avg = sum(completed_durations) / len(completed_durations)
            print(f"  Average Time:           {CYAN}{avg:.1f}s per conversion{RESET}")
        print(f"  Outputs Saved In:       {CYAN}{OUTPUT_DIR}{RESET}")
        print(f"  Originals Moved To:     {CYAN}{PROCESSED_DIR}{RESET}")
        cleanup_and_exit()


if __name__ == "__main__":
    main()
