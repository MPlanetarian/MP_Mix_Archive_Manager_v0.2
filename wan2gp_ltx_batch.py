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
BATCH_DIR = DATA_DIR / "WAN2GP_LTX_BATCH"
CTRL_VIDEO_DIR = BATCH_DIR / "CTRL_VIDEO"
PROCESSED_DIR = BATCH_DIR / "PROCESSED"
OUTPUT_DIR = Path("/home/mplanetarian/Documents/WAN2GP_OUTPUTS")

# WAN2GP constants
WAN_APP_ROOT = Path("/var/home/mplanetarian/pinokio/api/wan.git/app")
SAFE_PROFILE = "4.5"
ATTENTION_MODE = "sage"

# Supported model variants
AVAILABLE_MODELS = {
    "2b": {
        "id": "ltxv_2b_distilled",
        "name": "LTX Video 0.9.8 Distilled 2B",
        "label": "2B Distilled",
        "description": "Ultra fast, lightweight (Profile 4.5 or 2)",
        "steps": 8,
    },
    "13b": {
        "id": "ltxv_distilled",
        "name": "LTX Video 0.9.8 Distilled 13B",
        "label": "13B Distilled",
        "description": "High fidelity, superior motion quality (Profile 4.5)",
        "steps": 6,
    },
    "13b_dev": {
        "id": "ltxv_13B",
        "name": "LTX Video 0.9.8 13B (Dev)",
        "label": "13B Dev",
        "description": "Full 30-step development model (Profile 4.5)",
        "steps": 30,
    },
    "25_22b": {
        "id": "ltx2_25_22B_distilled",
        "name": "LTX-2 2.5 Distilled 22B",
        "label": "22B Distilled (LTX-2.5)",
        "description": "Latest Generation 22B video + audio model (Profile 4.5)",
        "steps": 8,
    },
    "25_22b_dev": {
        "id": "ltx2_25_22B",
        "name": "LTX-2 2.5 Dev 22B",
        "label": "22B Dev (LTX-2.5)",
        "description": "Latest Generation 22B video + audio Dev model (Profile 4.5)",
        "steps": 8,
    },
}

AVAILABLE_LORAS = {
    "none": {
        "id": "none",
        "name": "None (Clean Base)",
        "files": [],
        "multipliers": "",
    },
    "editanything_v2": {
        "id": "editanything_v2",
        "name": "EditAnything v2 (LTX-2.5)",
        "files": ["edit_anything_v2_ltx2.5.safetensors"],
        "multipliers": "1.0",
    },
    "editanything_v1": {
        "id": "editanything_v1",
        "name": "EditAnything v1.1",
        "files": ["edit_anything_v1.1_r256.safetensors"],
        "multipliers": "1.0",
    },
    "motion_transfer": {
        "id": "motion_transfer",
        "name": "EditAnything 30k Motion Transfer",
        "files": ["edit_anything_30k_v0.1_motion_transfer_r256.safetensors"],
        "multipliers": "1.0",
    },
    "bfs_head_swap": {
        "id": "bfs_head_swap",
        "name": "BFS Head Swap (LTX-2 Video)",
        "files": ["bfs_head_swap_v1_ltx2_ic_lora_12000_train_3.safetensors"],
        "multipliers": "1.0",
    },
    "msr": {
        "id": "msr",
        "name": "LTX-2.5 MSR (Multi-Subject Reference)",
        "files": ["LTX-2.5-Licon-MSR-V1_bf16.safetensors"],
        "multipliers": "1.0",
    },
    "deblur": {
        "id": "deblur",
        "name": "LTX-2.5 Deblur / Refocus",
        "files": ["ltx-2.5-22b-ic-lora-deblur-0.9.safetensors"],
        "multipliers": "1.0",
    },
    "decompression": {
        "id": "decompression",
        "name": "LTX-2.5 Decompression Cleanup",
        "files": ["ltx-2.5-22b-ic-lora-decompression-0.9.safetensors"],
        "multipliers": "1.0",
    },
    "ingredients": {
        "id": "ingredients",
        "name": "LTX-2.5 Ingredients Reference",
        "files": ["ltx-2.5-22b-ic-lora-ingredients-0.9.safetensors"],
        "multipliers": "1.0",
    },
}

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}
SUPPORTED_VIDEO_EXTENSIONS = {".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v"}


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
        inference_steps: int = 8,
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
        # Clear the live progress line
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
                    vae_buffer = 5.0 if "denois" in self.phase.lower() or curr_s < tot_s else 1.0
                    task_eta = (rem_steps * time_per_step) + vae_buffer
                elif pct > 10:
                    task_eta = max(0.0, (elapsed / (pct / 100.0)) - elapsed)

                batch_eta = None
                if self.total_batch > 0:
                    remaining_images = max(0, self.total_batch - self.batch_index)
                    if self.completed_durations:
                        avg_img_time = sum(self.completed_durations) / len(self.completed_durations)
                        curr_rem = task_eta if task_eta is not None else max(0.0, avg_img_time - elapsed)
                        batch_eta = (remaining_images * avg_img_time) + curr_rem
                    elif task_eta is not None:
                        est_img_time = elapsed + task_eta
                        batch_eta = task_eta + (remaining_images * est_img_time)

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


def get_control_videos(ctrl_dir: Path) -> list[Path]:
    """Find all valid control video files inside CTRL_VIDEO_DIR, sorted naturally."""
    if not ctrl_dir.is_dir():
        return []
    videos = [
        item for item in ctrl_dir.iterdir()
        if item.is_file() and item.suffix.lower() in SUPPORTED_VIDEO_EXTENSIONS and not item.name.startswith(".")
    ]
    videos.sort(key=natural_sort_key)
    return videos


def get_control_video(ctrl_dir: Path) -> Path | None:
    """Find the primary control video file inside CTRL_VIDEO_DIR."""
    videos = get_control_videos(ctrl_dir)
    return videos[0] if videos else None


def select_control_video(ctrl_dir: Path, requested_video: str | None = None, no_control: bool = False) -> Path | None:
    """Resolve and select a single control video from CTRL_VIDEO_DIR or user argument."""
    if no_control:
        return None

    ctrl_dir.mkdir(parents=True, exist_ok=True)

    # 1. If explicitly specified via CLI argument
    if requested_video:
        req_path = Path(requested_video).expanduser()
        if not req_path.is_absolute() and not req_path.is_file():
            in_ctrl = ctrl_dir / requested_video
            if in_ctrl.is_file():
                req_path = in_ctrl
        if not req_path.is_file():
            print(f"{RED}[-] Error: Specified control video not found at: {req_path}{RESET}")
            sys.exit(1)
        if req_path.suffix.lower() not in SUPPORTED_VIDEO_EXTENSIONS:
            print(f"{YELLOW}[!] Warning: Control video '{req_path.name}' does not have a standard video extension.{RESET}")
        return req_path

    # 2. Look for control videos in CTRL_VIDEO_DIR
    videos = get_control_videos(ctrl_dir)
    if not videos:
        return None

    if len(videos) == 1:
        single_vid = videos[0]
        print(f"\n{YELLOW}[?] Detected control video in {ctrl_dir.name}:{RESET} {BOLD}{GREEN}{single_vid.name}{RESET}")
        try:
            ans = input(f"{BOLD}{CYAN}Use this control video for batch generation? [Y/n]: {RESET}").strip().lower()
            if ans in ("", "y", "yes"):
                return single_vid
            else:
                print(f"{YELLOW}[i] Control video skipped. Running pure Image-to-Video.{RESET}")
                return None
        except (KeyboardInterrupt, EOFError):
            print(f"\n{YELLOW}[*] Canceled by user.{RESET}")
            sys.exit(0)

    # Multiple videos detected in CTRL_VIDEO_DIR: prompt user to pick one
    print(f"\n{YELLOW}[?] Detected multiple ({len(videos)}) control videos in {ctrl_dir}:{RESET}")
    for idx, vid in enumerate(videos, 1):
        print(f"  {BOLD}{idx}){RESET} {vid.name}")
    print(f"  {BOLD}0){RESET} None (Pure Image-to-Video without control video)")

    while True:
        try:
            choice = input(f"\n{BOLD}{CYAN}Select a single control video [1-{len(videos)}, or 0=None, Enter=1]: {RESET}").strip().lower()
            if choice in ("", "1"):
                return videos[0]
            elif choice in ("0", "n", "no", "none"):
                print(f"{YELLOW}[i] Running pure Image-to-Video without control video.{RESET}")
                return None
            elif choice.isdigit() and 1 <= int(choice) <= len(videos):
                return videos[int(choice) - 1]
            print(f"{RED}[-] Invalid selection. Please enter a number between 0 and {len(videos)}.{RESET}")
        except (KeyboardInterrupt, EOFError):
            print(f"\n{YELLOW}[*] Canceled by user.{RESET}")
            sys.exit(0)

# Video duration presets (at 30 FPS)
# Short: 81 frames (standard default single window, ~2.7s)
# Medium: 409 frames (halfway between default 81 and max 737, ~13.6s)
# Long: 737 frames (slider dragged to right all the way, ~24.5s)
LENGTH_OPTIONS = {
    "short": {
        "label": "Short (Default)",
        "frames": 81,
        "seconds": 2.7,
        "description": "81 frames (~2.7s) - Single window, fastest generation",
    },
    "medium": {
        "label": "Medium (Halfway)",
        "frames": 409,
        "seconds": 13.6,
        "description": "409 frames (~13.6s) - Halfway between default and max",
    },
    "long": {
        "label": "Long (Max Slider)",
        "frames": 737,
        "seconds": 24.5,
        "description": "737 frames (~24.5s) - Full slider dragged to right",
    },
}


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


def get_user_prompt(initial_prompt: str | None = None, ctrl_video: Path | None = None, model_name: str = "LTX Video") -> str:
    """Prompt the user until a non-empty prompt is provided."""
    if initial_prompt and initial_prompt.strip():
        return initial_prompt.strip()

    if ctrl_video:
        print(f"\n{YELLOW}[i] Start Frame:   Batch image (from WAN2GP_LTX_BATCH dir){RESET}")
        print(f"{YELLOW}[i] Control Video: {ctrl_video.name} (from CTRL_VIDEO dir){RESET}")
    else:
        print(f"\n{YELLOW}[i] Mode:          Pure Image-to-Video (Start Frame Injection){RESET}")

    while True:
        try:
            prompt = input(f"\n{BOLD}{CYAN}Enter video generation prompt for {model_name}: {RESET}").strip()
            if prompt:
                return prompt
            print(f"{RED}[-] Prompt cannot be empty. Please enter a valid prompt.{RESET}")
        except (KeyboardInterrupt, EOFError):
            print(f"\n{YELLOW}[*] Canceled by user.{RESET}")
            sys.exit(0)


def get_video_duration(initial_length: str | None = None) -> tuple[str, int]:
    """Ask user for video length option: short, medium, or long."""
    if initial_length:
        key = initial_length.strip().lower()
        if key in ("1", "s", "short", "default"):
            return "short", LENGTH_OPTIONS["short"]["frames"]
        elif key in ("2", "m", "med", "medium"):
            return "medium", LENGTH_OPTIONS["medium"]["frames"]
        elif key in ("3", "l", "long", "max"):
            return "long", LENGTH_OPTIONS["long"]["frames"]
        elif key.isdigit():
            val = int(key)
            return "custom", val

    print(f"\n{BOLD}{CYAN}Select Video Duration:{RESET}")
    print(f"  {BOLD}1) Short  [Default]{RESET} - {GREEN}81 frames  (~2.7s){RESET}  [Standard single window, fastest]")
    print(f"  {BOLD}2) Medium [Halfway]{RESET} - {YELLOW}409 frames (~13.6s){RESET}  [Halfway between default and max]")
    print(f"  {BOLD}3) Long   [Maximum]{RESET} - {CYAN}737 frames (~24.5s){RESET}  [Full slider dragged to maximum]")

    while True:
        try:
            choice = input(f"\n{BOLD}{CYAN}Choose length [1=Short(Default), 2=Medium, 3=Long]: {RESET}").strip().lower()
            if choice in ("", "1", "s", "short", "default"):
                return "short", LENGTH_OPTIONS["short"]["frames"]
            elif choice in ("2", "m", "med", "medium"):
                return "medium", LENGTH_OPTIONS["medium"]["frames"]
            elif choice in ("3", "l", "long", "max"):
                return "long", LENGTH_OPTIONS["long"]["frames"]
            print(f"{RED}[-] Invalid option. Please enter 1 (short), 2 (medium), or 3 (long).{RESET}")
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


def rename_converted_outputs(source_image: Path, generated_files: list[str]) -> list[Path]:
    """Rename generated output files to preserve the original image filename directly.

    Keeps the exact original image filename (e.g. <name>.mp4 for <name>.png/jpg)
    to marry the original image name with the new video.
    """
    renamed = []
    for idx, file_path_str in enumerate(generated_files):
        gen_file = Path(file_path_str)
        if not gen_file.exists():
            renamed.append(gen_file)
            continue

        out_ext = gen_file.suffix or ".mp4"
        suffix_tag = "" if idx == 0 else f"_{idx+1}"
        target_name = f"{source_image.stem}{suffix_tag}{out_ext}"
        target_path = gen_file.parent / target_name

        if target_path.exists() and target_path.resolve() != gen_file.resolve():
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            target_name = f"{source_image.stem}{suffix_tag}_{timestamp}{out_ext}"
            target_path = gen_file.parent / target_name
            counter = 1
            while target_path.exists() and target_path.resolve() != gen_file.resolve():
                target_name = f"{source_image.stem}{suffix_tag}_{timestamp}_{counter}{out_ext}"
                target_path = gen_file.parent / target_name
                counter += 1

        if gen_file.resolve() != target_path.resolve():
            shutil.move(str(gen_file), str(target_path))
            gen_json = gen_file.with_suffix(".json")
            if gen_json.exists():
                target_json = target_path.with_suffix(".json")
                shutil.move(str(gen_json), str(target_json))

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
    script_basename = Path(sys.argv[0]).name.lower()
    default_model_key = "13b" if "13b" in script_basename else "2b"

    parser = argparse.ArgumentParser(description="WAN2GP LTX Video Batch Image-to-Video Processor (2B, 13B & 22B)")
    parser.add_argument("--model", "-m", type=str, default=default_model_key, choices=list(AVAILABLE_MODELS.keys()), help=f"LTX Video model variant to use ({', '.join(AVAILABLE_MODELS.keys())}; default: {default_model_key})")
    parser.add_argument("--lora", type=str, default="none", choices=list(AVAILABLE_LORAS.keys()), help=f"LoRA enhancement to apply ({', '.join(AVAILABLE_LORAS.keys())}; default: none)")
    parser.add_argument("--prompt", "-p", type=str, default=None, help="Generation prompt")
    parser.add_argument("--length", "-l", type=str, default=None, choices=["short", "medium", "long"], help="Video duration preset (short, medium, long)")
    parser.add_argument("--control-video", "-c", type=str, default=None, help="Path to single control video (or filename in CTRL_VIDEO)")
    parser.add_argument("--no-control", action="store_true", help="Disable control video (force pure Image-to-Video)")
    parser.add_argument("--watch", "-w", action="store_true", help="Run in continuous watch mode (check every 2 seconds)")
    parser.add_argument("--interval", "-i", type=float, default=2.0, help="Check interval in seconds for watch mode (default: 2.0)")
    args = parser.parse_args()

    model_key = args.model.lower()
    model_info = AVAILABLE_MODELS.get(model_key, AVAILABLE_MODELS["2b"])
    model_type = model_info["id"]
    model_name = model_info["name"]

    lora_key = (args.lora or "none").lower()
    lora_info = AVAILABLE_LORAS.get(lora_key, AVAILABLE_LORAS["none"])

    # 1. Verify DATA directory
    if not DATA_DIR.exists():
        print(f"{RED}[-] Error: DATA drive not mounted at {DATA_DIR}! Please mount it first.{RESET}")
        sys.exit(1)

    BATCH_DIR.mkdir(parents=True, exist_ok=True)
    CTRL_VIDEO_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    # 2. Select Control Video (if available or specified)
    active_ctrl_video = select_control_video(CTRL_VIDEO_DIR, requested_video=args.control_video, no_control=args.no_control)

    ctrl_display = active_ctrl_video.name if active_ctrl_video else "None (Pure Image-to-Video)"
    mode_display = "Image-to-Video + Control Video Guide" if active_ctrl_video else "Image-to-Video (Start Frame Injection)"

    print(f"{BOLD}{CYAN}======================================================{RESET}")
    print(f"{BOLD}{CYAN}      WAN2GP LTX VIDEO BATCH VIDEO PROCESSOR          {RESET}")
    print(f"{BOLD}{CYAN}======================================================{RESET}")
    print(f"  Model:            {GREEN}{model_name}{RESET}")
    print(f"  Mode:             {GREEN}{mode_display}{RESET}")
    print(f"  LoRAs:            {GREEN}{lora_info['name']}{RESET}")
    print(f"  Control Video:    {YELLOW if active_ctrl_video else GREEN}{ctrl_display}{RESET}")
    print(f"  Control Dir:      {YELLOW}{CTRL_VIDEO_DIR}{RESET}")
    print(f"  Quality:          {GREEN}720p Output Resolution{RESET}")
    print(f"  Naming Pattern:   {GREEN}[original_name].[ext]{RESET}")
    print(f"  Input Directory:  {YELLOW}{BATCH_DIR}{RESET}")
    print(f"  Output Directory: {GREEN}{OUTPUT_DIR}{RESET}")
    print(f"  Processed Dir:    {GREEN}{PROCESSED_DIR}{RESET}")
    print(f"  Safety Profile:   {CYAN}Profile {SAFE_PROFILE} (LowRAM_LowVRAM+ / Memory Safe){RESET}")
    print(f"{CYAN}------------------------------------------------------{RESET}")

    if active_ctrl_video:
        print(f"{GREEN}[✓] Active control video: {BOLD}{active_ctrl_video.name}{RESET}")
    else:
        print(f"{CYAN}[i] Control video: None (standard start frame injection){RESET}")

    # 3. Check for server conflict before allocating memory
    check_and_resolve_running_server()

    # 4. Prompt user for generation prompt
    prompt = get_user_prompt(args.prompt, ctrl_video=active_ctrl_video, model_name=model_name)
    print(f"{GREEN}[✓] Active prompt: {BOLD}\"{prompt}\"{RESET}")

    # 5. Prompt user for video length option (short, medium, long)
    length_key, video_frames = get_video_duration(args.length)
    length_meta = LENGTH_OPTIONS.get(length_key, {"label": "Custom", "seconds": video_frames / 30.0})
    print(f"{GREEN}[✓] Active duration: {BOLD}{length_meta['label']}{RESET} -> {GREEN}{video_frames} frames (~{length_meta['seconds']:.1f}s at 30 FPS){RESET}")

    # 6. Initialize WAN2GP Session in safe Profile 4.5
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

    expected_steps = model_info.get("steps", 8)
    completed_durations: list[float] = []

    def process_image(image_path: Path, batch_idx: int = 1, total_batch: int = 1) -> bool:
        res = calculate_720p_resolution(image_path)
        batch_pct = ((batch_idx - 1) / total_batch) * 100 if total_batch > 0 else 0
        print(f"\n{BOLD}{CYAN}=================================================={RESET}")
        print(f"{BOLD}[*] [{batch_idx}/{total_batch}] ({batch_pct:.0f}% of batch) Processing image: {YELLOW}{image_path.name}{RESET}")
        print(f"    Target Resolution: {CYAN}{res} (720p){RESET}")
        print(f"    Duration:          {CYAN}{video_frames} frames (~{video_frames / 30.0:.1f}s){RESET}")
        print(f"    Model:             {GREEN}{model_name}{RESET} ({expected_steps} steps)")
        print(f"    Start Frame:       {GREEN}{image_path.name}{RESET}")
        if active_ctrl_video:
            print(f"    Control Video:     {GREEN}{active_ctrl_video.name}{RESET}")
        if completed_durations:
            avg_time = sum(completed_durations) / len(completed_durations)
            rem_imgs = total_batch - batch_idx + 1
            est_rem = rem_imgs * avg_time
            print(f"    Est. Batch Time:   {CYAN}~{format_duration(est_rem)} remaining ({rem_imgs} images left @ ~{avg_time:.1f}s/ea){RESET}")
        print(f"{CYAN}--------------------------------------------------{RESET}")

        safe_output_name = image_path.stem.replace("{", "[").replace("}", "]")
        settings = session.get_default_settings(model_type)
        settings.update({
            "output_filename": safe_output_name,
            "prompt": prompt,
            "resolution": res,
            "image_prompt_type": "S",
            "image_start": [str(image_path.resolve())],
            "video_length": video_frames,
            "activated_loras": lora_info["files"],
            "loras_multipliers": lora_info["multipliers"],
            "image_refs": None,
            "video_guide": str(active_ctrl_video.resolve()) if active_ctrl_video else None,
            "video_prompt_type": "V" if active_ctrl_video else "",
            "image_guide": None,
        })

        tracker = BatchProgressTracker(
            batch_index=batch_idx,
            total_batch=total_batch,
            image_name=image_path.name,
            model_name=model_name,
            completed_durations=completed_durations,
            inference_steps=expected_steps,
        )

        try:
            start_t = time.time()
            result = session.run_task(settings, callbacks=tracker)
            elapsed = time.time() - start_t
            tracker.stop()

            if result.success:
                completed_durations.append(elapsed)
                gen_files = list(result.generated_files) if result.generated_files else []
                # Fallback: if result.generated_files is empty or files don't exist, check OUTPUT_DIR for newest file
                if not gen_files or not any(Path(p).exists() for p in gen_files):
                    candidates = [
                        p for p in OUTPUT_DIR.iterdir()
                        if p.is_file() and p.suffix.lower() in SUPPORTED_VIDEO_EXTENSIONS and p.stat().st_mtime >= start_t - 2
                    ]
                    if candidates:
                        candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
                        gen_files = [str(candidates[0])]

                renamed_outputs = rename_converted_outputs(image_path, gen_files)
                output_names = [p.name for p in renamed_outputs]
                print(f"{GREEN}[✓] Generated image {batch_idx}/{total_batch} in {elapsed:.1f}s! Saved output: {', '.join(output_names)}{RESET}")
                dest = move_to_processed(image_path, PROCESSED_DIR)
                print(f"{GREEN}[✓] Moved input image to: {dest.name}{RESET}")

                done_count = len(completed_durations)
                if total_batch > 1 and done_count < total_batch:
                    avg_t = sum(completed_durations) / done_count
                    rem_count = total_batch - done_count
                    rem_t = rem_count * avg_t
                    pct_done = (done_count / total_batch) * 100
                    print(f"{CYAN}[i] Batch Progress: {done_count}/{total_batch} completed ({pct_done:.0f}%) | "
                          f"Avg: {avg_t:.1f}s/img | Est. remaining: ~{format_duration(rem_t)}{RESET}")
                return True
            else:
                tracker.stop()
                err_msgs = [e.message for e in result.errors]
                print(f"{RED}[-] Generation failed for {image_path.name}: {', '.join(err_msgs)}{RESET}")
                return False
        except Exception as ex:
            tracker.stop()
            print(f"{RED}[-] Exception during generation for {image_path.name}: {ex}{RESET}")
            return False
        finally:
            tracker.stop()
            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

    # 6. Execution mode: Watch Mode or Batch Run
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
        print(f"\n{BOLD}{GREEN}[*] Watching {BATCH_DIR} for new images every {args.interval}s...{RESET}")
        print(f"{CYAN}(Drop images into {BATCH_DIR} to generate videos. Press Ctrl+C to exit.){RESET}\n")
        try:
            while True:
                images = find_pending_images(BATCH_DIR)
                if images:
                    sub_total = len(images)
                    sub_start = time.time()
                    print(f"\n{BOLD}{GREEN}[+] Detected {sub_total} new image(s)! Starting batch...{RESET}")
                    for idx, img in enumerate(images, 1):
                        process_image(img, batch_idx=idx, total_batch=sub_total)
                    sub_elapsed = time.time() - sub_start
                    print(f"\n{GREEN}[✓] Batch finished ({sub_total} image(s) in {format_duration(sub_elapsed)}). Resuming watch mode...{RESET}\n")
                time.sleep(args.interval)
        except KeyboardInterrupt:
            cleanup_and_exit()
    else:
        # Single-pass batch run
        images = find_pending_images(BATCH_DIR)
        total_images = len(images)
        success_count = 0
        fail_count = 0
        batch_start_time = time.time()

        for idx, img in enumerate(images, 1):
            if process_image(img, batch_idx=idx, total_batch=total_images):
                success_count += 1
            else:
                fail_count += 1

        total_elapsed = time.time() - batch_start_time
        print(f"\n{BOLD}{GREEN}======================================================{RESET}")
        print(f"{BOLD}{GREEN}                 BATCH COMPLETED                      {RESET}")
        print(f"{BOLD}{GREEN}======================================================{RESET}")
        print(f"  Total Processed: {GREEN}{total_images}{RESET}")
        print(f"  Successful:      {GREEN}{success_count}{RESET}")
        print(f"  Failed:          {RED if fail_count > 0 else GREEN}{fail_count}{RESET}")
        print(f"  Total Time:      {CYAN}{format_duration(total_elapsed)} ({total_elapsed:.1f}s){RESET}")
        if completed_durations:
            avg = sum(completed_durations) / len(completed_durations)
            print(f"  Average Time:    {CYAN}{avg:.1f}s per video{RESET}")
        print(f"  Outputs in:      {CYAN}{OUTPUT_DIR}{RESET}")
        print(f"  Processed:       {CYAN}{PROCESSED_DIR}{RESET}")
        cleanup_and_exit()


if __name__ == "__main__":
    main()
