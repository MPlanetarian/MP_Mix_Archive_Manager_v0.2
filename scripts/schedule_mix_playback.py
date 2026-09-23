#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - DJ Mix Scheduler
Menu: "Schedule DJ Mix or Multiple DJ Mixes to Play Loudly (Uses Default Audio Player)"

Features:
  - Select single mix or multiple mixes to be played at an exact date and time in the future.
  - Option to pick from the last 10 recorded mixes (strictly limited to 10).
  - Option to provide a full file path to an audio file (WAV, MP3, FLAC).
  - Option to provide a playlist (.m3u8, .m3u, .xspf, .pls) for multiple mixes.
  - "Plays Loudly": Unmutes master audio and raises volume to high level (95-100%) on Linux & macOS.
  - Dispatches playback via configured Default Audio Player (Strawberry, cliamp, VLC, mpv, etc.).
  - Lightweight background daemon tracks schedules and triggers playback accurately.
"""

import os
import sys
import time
import datetime
import json
import re
import shutil
import subprocess
import signal
from pathlib import Path

# --- ANSI Colors ---
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[1;37m"
NC = "\033[0m"

CONFIG_DIR = Path.home() / ".config" / "mix-manager"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)
QUEUE_FILE = CONFIG_DIR / "scheduled_mixes.json"
PID_FILE = CONFIG_DIR / "scheduler_daemon.pid"
LOG_FILE = CONFIG_DIR / "scheduler_daemon.log"
SCHEDULED_PLAYLISTS_DIR = CONFIG_DIR / "playlists"
SCHEDULED_PLAYLISTS_DIR.mkdir(parents=True, exist_ok=True)

AUDIO_EXTS = ('.flac', '.wav', '.mp3', '.m4a', '.aif', '.aiff', '.ogg')
PLAYLIST_EXTS = ('.m3u8', '.m3u', '.xspf', '.pls')


def get_base_dir():
    # Return repo/scripts root directory
    script_p = Path(__file__).resolve()
    if script_p.parent.name == "scripts":
        return script_p.parent.parent
    return script_p.parent


def get_default_player():
    # 1. Environment variable
    env_player = os.environ.get("DEFAULT_AUDIO_PLAYER")
    if env_player:
        return env_player.strip().lower()

    # 2. Check config.env in base dir or ~/.config/mix-manager/config.env
    cfg_candidates = [
        get_base_dir() / "config.env",
        CONFIG_DIR / "config.env",
        Path.home() / ".config" / "mix-manager" / "config.env"
    ]
    for cfg in cfg_candidates:
        if cfg.is_file():
            try:
                with open(cfg, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("DEFAULT_AUDIO_PLAYER="):
                            val = line.split("=", 1)[1].strip().strip('"').strip("'")
                            if val:
                                return val.lower()
            except Exception:
                pass
    return "strawberry"


def list_recent_mixes(limit=10):
    """Scan mix archive directories and return the last 10 mixes recorded by modification time."""
    base_dir = get_base_dir()
    scan_paths = [
        base_dir / "FLAC_CONVERTED_OUTPUTS",
        Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"),
        Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"),
        Path("/Volumes/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"),
        Path("/Volumes/WD BLACK B/MIX_ARCHIVE"),
        base_dir / "CONVERTED_WAV_FILES",
        Path.home() / "Documents" / "BASH_SCRIPTS" / "FLAC_CONVERTED_OUTPUTS",
        Path.home() / "Documents" / "mplanetarian" / "M_PRODUCTION" / "RELEASS",
        Path.home() / "Music",
        base_dir
    ]

    seen = set()
    mixes = []

    for sdir in scan_paths:
        if not sdir.is_dir():
            continue
        try:
            for entry in os.scandir(str(sdir)):
                if entry.is_file():
                    lower = entry.name.lower()
                    if any(lower.endswith(ext) for ext in ('.flac', '.wav', '.mp3')):
                        real_p = os.path.realpath(entry.path)
                        if real_p not in seen:
                            seen.add(real_p)
                            try:
                                st = entry.stat()
                                # Only mix audio files (ignore short snippets < 5MB unless keyword match)
                                if st.st_size >= 5 * 1024 * 1024 or 'mix' in lower or 'stream_of_frequency' in lower:
                                    mixes.append({
                                        'path': real_p,
                                        'filename': entry.name,
                                        'mtime': st.st_mtime,
                                        'size': st.st_size
                                    })
                            except Exception:
                                pass
        except Exception:
            pass

    # Sort strictly descending by modification time (newest recorded first)
    mixes.sort(key=lambda x: x['mtime'], reverse=True)
    return mixes[:limit]


def parse_target_datetime(input_str):
    """
    Parse a user entered date/time into a future datetime object.
    Supports:
      - YYYY-MM-DD HH:MM or YYYY-MM-DD HH:MM:SS
      - DD-MM-YYYY HH:MM or YYYY/MM/DD HH:MM
      - HH:MM (infers today if future, tomorrow if time already passed today)
      - Relative offsets: +30m, 30m, +2h, 2h, +1d, 1d
      - 'tomorrow 14:30', 'today 21:00'
    """
    s = input_str.strip()
    if not s:
        return None
    now = datetime.datetime.now()

    # Relative offset: +30m, 30m, +2h, +1d
    m = re.match(r'^\+?(\d+)\s*(m|min|mins|minutes?)$', s, re.IGNORECASE)
    if m:
        return now + datetime.timedelta(minutes=int(m.group(1)))
    m = re.match(r'^\+?(\d+)\s*(h|hr|hrs|hours?)$', s, re.IGNORECASE)
    if m:
        return now + datetime.timedelta(hours=int(m.group(1)))
    m = re.match(r'^\+?(\d+)\s*(d|days?)$', s, re.IGNORECASE)
    if m:
        return now + datetime.timedelta(days=int(m.group(1)))

    # 'tomorrow HH:MM' or 'tomorrow at HH:MM'
    m = re.match(r'^tomorrow(?:\s+at)?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$', s, re.IGNORECASE)
    if m:
        tmrw = now + datetime.timedelta(days=1)
        h, mn, sec = int(m.group(1)), int(m.group(2)), int(m.group(3) or 0)
        return tmrw.replace(hour=h, minute=mn, second=sec, microsecond=0)

    # 'today HH:MM' or 'today at HH:MM'
    m = re.match(r'^today(?:\s+at)?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$', s, re.IGNORECASE)
    if m:
        h, mn, sec = int(m.group(1)), int(m.group(2)), int(m.group(3) or 0)
        return now.replace(hour=h, minute=mn, second=sec, microsecond=0)

    # HH:MM or HH:MM:SS (time only)
    m = re.match(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$', s)
    if m:
        h, mn, sec = int(m.group(1)), int(m.group(2)), int(m.group(3) or 0)
        target = now.replace(hour=h, minute=mn, second=sec, microsecond=0)
        if target <= now:
            target += datetime.timedelta(days=1)
        return target

    # Full date + time formats
    formats = [
        '%Y-%m-%d %H:%M:%S',
        '%Y-%m-%d %H:%M',
        '%Y/%m/%d %H:%M:%S',
        '%Y/%m/%d %H:%M',
        '%d-%m-%Y %H:%M:%S',
        '%d-%m-%Y %H:%M',
        '%d/%m/%Y %H:%M:%S',
        '%d/%m/%Y %H:%M',
    ]
    for fmt in formats:
        try:
            return datetime.datetime.strptime(s, fmt)
        except ValueError:
            pass

    return None


def parse_selection(input_str, max_val):
    """Parse comma/space separated numbers and ranges (e.g. '1, 3, 5-7' or 'all')."""
    s = input_str.strip().lower()
    if s == 'all':
        return list(range(1, max_val + 1))
    parts = re.split(r'[, \t]+', s)
    selected = set()
    for p in parts:
        if not p:
            continue
        if '-' in p:
            sub = p.split('-')
            if len(sub) == 2 and sub[0].isdigit() and sub[1].isdigit():
                start, end = int(sub[0]), int(sub[1])
                for x in range(min(start, end), max(start, end) + 1):
                    if 1 <= x <= max_val:
                        selected.add(x)
        elif p.isdigit():
            val = int(p)
            if 1 <= val <= max_val:
                selected.add(val)
    return sorted(list(selected))


def load_queue():
    if not QUEUE_FILE.is_file():
        return []
    try:
        with open(QUEUE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
    except Exception:
        pass
    return []


def save_queue(queue):
    tmp_file = QUEUE_FILE.with_suffix(".tmp")
    with open(tmp_file, "w", encoding="utf-8") as f:
        json.dump(queue, f, indent=2)
    tmp_file.replace(QUEUE_FILE)


def set_loud_audio_volume(volume_percent=95):
    """Unmutes audio and raises volume to a loud level (95-100%) on Linux and macOS."""
    success = False

    # 1. PipeWire wpctl
    wpctl = shutil.which("wpctl")
    if wpctl:
        try:
            subprocess.run([wpctl, "set-mute", "@DEFAULT_AUDIO_SINK@", "0"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            vol_float = f"{min(volume_percent, 100) / 100.0:.2f}"
            subprocess.run([wpctl, "set-volume", "@DEFAULT_AUDIO_SINK@", vol_float],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            success = True
        except Exception:
            pass

    # 2. PulseAudio pactl
    pactl = shutil.which("pactl")
    if pactl:
        try:
            subprocess.run([pactl, "set-sink-mute", "@DEFAULT_SINK@", "0"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([pactl, "set-sink-volume", "@DEFAULT_SINK@", f"{volume_percent}%"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            success = True
        except Exception:
            pass

    # 3. ALSA amixer
    amixer = shutil.which("amixer")
    if amixer:
        try:
            subprocess.run([amixer, "set", "Master", "unmute"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([amixer, "set", "Master", f"{volume_percent}%"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            success = True
        except Exception:
            pass

    # 4. macOS osascript
    if sys.platform == "darwin":
        try:
            subprocess.run([
                "osascript",
                "-e", "set volume output muted false",
                "-e", f"set volume output volume {volume_percent}"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            success = True
        except Exception:
            pass

    return success


def dispatch_audio_playback(player, files, playlist_path=None):
    """Launch playback using the requested Default Audio Player."""
    player = (player or "strawberry").lower()
    target_to_play = playlist_path if playlist_path else (files[0] if files else None)
    if not target_to_play and not files:
        return False

    # Send loud volume instruction to Strawberry directly if Strawberry is chosen
    if player == "strawberry":
        try:
            subprocess.run(["strawberry", "-v", "100"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    if player == "strawberry":
        cmd = None
        if shutil.which("strawberry"):
            if playlist_path:
                cmd = ["strawberry", "-l", playlist_path]
            elif len(files) == 1:
                cmd = ["strawberry", files[0]]
            else:
                cmd = ["strawberry", "-l"] + files
        elif sys.platform == "darwin":
            cmd = ["open", "-a", "Strawberry", target_to_play]
        else:
            # Flatpak check
            res = subprocess.run(["flatpak", "list"], capture_output=True, text=True)
            if "org.strawberrymusicplayer.strawberry" in res.stdout:
                if playlist_path:
                    cmd = ["flatpak", "run", "org.strawberrymusicplayer.strawberry", "-l", playlist_path]
                else:
                    cmd = ["flatpak", "run", "org.strawberrymusicplayer.strawberry"] + files

        if cmd:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            time.sleep(0.5)
            # Ensure playing
            subprocess.run(["strawberry", "-p"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True

    elif player == "cliamp":
        cliamp_bin = shutil.which("cliamp") or (get_base_dir() / "bin" / "cliamp")
        if not cliamp_bin or not Path(cliamp_bin).is_file():
            cliamp_bin = Path.home() / ".local" / "bin" / "cliamp"
        if Path(cliamp_bin).is_file():
            targets = [playlist_path] if playlist_path else files
            subprocess.run([str(cliamp_bin), "queue"] + targets, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.3)
            subprocess.Popen([str(cliamp_bin), "play"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True

    elif player == "vlc":
        vlc_bin = shutil.which("vlc")
        if vlc_bin:
            targets = [playlist_path] if playlist_path else files
            subprocess.Popen([vlc_bin] + targets, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
        elif sys.platform == "darwin":
            subprocess.Popen(["open", "-a", "VLC", target_to_play], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True

    elif player == "mpv":
        mpv_bin = shutil.which("mpv")
        if mpv_bin:
            cmd = [mpv_bin, "--volume=100"]
            if playlist_path:
                cmd.append(f"--playlist={playlist_path}")
            else:
                cmd.extend(files)
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True

    # Fallback to system default audio opener
    if sys.platform == "darwin":
        subprocess.Popen(["open", target_to_play], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    elif shutil.which("xdg-open"):
        subprocess.Popen(["xdg-open", target_to_play], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True

    return False


def send_notification(title, message):
    """Desktop notification for the scheduled playback alarm."""
    if shutil.which("notify-send"):
        try:
            subprocess.run([
                "notify-send", "-u", "critical",
                "-i", "audio-speakers",
                title, message
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
    elif sys.platform == "darwin":
        try:
            osa = f'display notification "{message}" with title "{title}"'
            subprocess.run(["osascript", "-e", osa], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass


def execute_job(job):
    """Executes a scheduled mix job: unmute, set loud volume, launch default player."""
    title = job.get("title", "DJ Mix")
    player = job.get("player", get_default_player())
    files = job.get("files", [])
    playlist_path = job.get("playlist_path")
    vol = job.get("volume_percent", 95)

    # 1. Unmute and crank volume
    set_loud_audio_volume(vol)

    # 2. Desktop notification
    send_notification("DJ Mix Scheduler", f"Playing Loudly ({vol}%):\n{title}")

    # 3. Launch audio player
    dispatch_audio_playback(player, files, playlist_path)


def is_daemon_running():
    """Checks if the background scheduler daemon is running."""
    if not PID_FILE.is_file():
        return False, None
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)
        return True, pid
    except (OSError, ValueError):
        PID_FILE.unlink(missing_ok=True)
        return False, None


def ensure_daemon():
    """Starts the background daemon process if it is not already running."""
    running, pid = is_daemon_running()
    if running:
        return pid

    script_path = Path(__file__).resolve()
    with open(LOG_FILE, "a", encoding="utf-8") as out:
        proc = subprocess.Popen(
            [sys.executable, str(script_path), "--daemon"],
            stdout=out,
            stderr=out,
            start_new_session=True
        )
    PID_FILE.write_text(str(proc.pid))
    return proc.pid


def daemon_loop():
    """Background daemon loop that wakes every 10 seconds and executes pending jobs."""
    PID_FILE.write_text(str(os.getpid()))
    try:
        while True:
            queue = load_queue()
            now_epoch = time.time()
            changed = False

            for job in queue:
                if job.get("status") == "pending":
                    sched_epoch = job.get("scheduled_epoch", 0)
                    if now_epoch >= sched_epoch:
                        try:
                            execute_job(job)
                            job["status"] = "completed"
                            job["executed_at"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        except Exception as e:
                            job["status"] = "error"
                            job["error"] = str(e)
                        changed = True

            if changed:
                save_queue(queue)

            time.sleep(10)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        PID_FILE.unlink(missing_ok=True)


def create_scheduled_job(files, playlist_path, title, target_dt, player=None, volume=95):
    """Add a new scheduled playback job and ensure the background daemon is running."""
    player = player or get_default_player()
    sched_epoch = target_dt.timestamp()
    job_id = f"mix_job_{int(time.time())}_{target_dt.strftime('%H%M%S')}"

    # If multiple files are provided without an existing playlist, generate an .m3u8
    if len(files) > 1 and not playlist_path:
        pl_name = f"Scheduled_{target_dt.strftime('%Y%m%d_%H%M%S')}.m3u8"
        gen_playlist = SCHEDULED_PLAYLISTS_DIR / pl_name
        with open(gen_playlist, "w", encoding="utf-8") as f:
            f.write("#EXTM3U\n")
            for fpath in files:
                f.write(f"#EXTINF:-1,{Path(fpath).name}\n")
                f.write(f"{fpath}\n")
        playlist_path = str(gen_playlist)

    job = {
        "id": job_id,
        "title": title,
        "files": files,
        "playlist_path": playlist_path,
        "player": player,
        "volume_percent": volume,
        "scheduled_time": target_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "scheduled_epoch": sched_epoch,
        "created_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "status": "pending"
    }

    queue = load_queue()
    queue.append(job)
    save_queue(queue)

    daemon_pid = ensure_daemon()
    return job, daemon_pid


def view_pending_jobs(interactive=True):
    queue = load_queue()
    pending = [j for j in queue if j.get("status") == "pending"]
    running, pid = is_daemon_running()

    print(f"\n{BOLD}{BLUE}================================================================================{NC}")
    print(f"  {BOLD}{WHITE}ACTIVE & PENDING SCHEDULED DJ MIXES{NC}")
    print(f"{BOLD}{BLUE}================================================================================{NC}")
    if running:
        print(f"  Background Daemon : {BOLD}{GREEN}Active (PID: {pid}){NC}")
    else:
        print(f"  Background Daemon : {YELLOW}Idle / Not running{NC}")
    print(f"  Pending Schedules : {BOLD}{CYAN}{len(pending)}{NC}\n")

    if not pending:
        print(f"  {DIM}No scheduled mixes currently pending in the queue.{NC}\n")
    else:
        now_epoch = time.time()
        for idx, job in enumerate(pending, 1):
            sched_epoch = job.get("scheduled_epoch", 0)
            diff = max(0, int(sched_epoch - now_epoch))
            hours = diff // 3600
            mins = (diff % 3600) // 60
            secs = diff % 60
            countdown = f"{hours}h {mins}m {secs}s" if hours > 0 else f"{mins}m {secs}s"

            print(f"  {BOLD}{CYAN}{idx}){NC} {BOLD}{WHITE}{job.get('title')}{NC}")
            print(f"     • Scheduled Date/Time : {BOLD}{YELLOW}{job.get('scheduled_time')}{NC} (in {GREEN}{countdown}{NC})")
            print(f"     • Audio Player        : {job.get('player')} ({GREEN}{job.get('volume_percent')}% Volume Loud{NC})")
            print(f"     • Job ID              : {DIM}{job.get('id')}{NC}")
            if job.get("playlist_path"):
                print(f"     • Playlist            : {job.get('playlist_path')}")
            print("")

    if interactive:
        input(f"Press {BOLD}[Enter]{NC} to return to menu...")


def cancel_job_dialog():
    queue = load_queue()
    pending = [j for j in queue if j.get("status") == "pending"]

    print(f"\n{BOLD}{RED}=== CANCEL A SCHEDULED DJ MIX ===${NC}\n")
    if not pending:
        print(f"  {YELLOW}No pending scheduled mixes to cancel.{NC}\n")
        input(f"Press {BOLD}[Enter]{NC} to return to menu...")
        return

    for idx, job in enumerate(pending, 1):
        print(f"  {BOLD}{CYAN}{idx}){NC} {job.get('title')} ({YELLOW}{job.get('scheduled_time')}{NC})")

    print(f"\n  {BOLD}0){NC} Back")
    try:
        choice = input(f"\nEnter number to cancel [1-{len(pending)}, 0 to exit]: ").strip()
    except (KeyboardInterrupt, EOFError):
        return

    if not choice or choice == "0":
        return

    if choice.isdigit() and 1 <= int(choice) <= len(pending):
        selected = pending[int(choice) - 1]
        selected["status"] = "cancelled"
        save_queue(queue)
        print(f"\n{GREEN}✓ Job '{selected.get('title')}' successfully cancelled!{NC}\n")
        time.sleep(1.2)


def prompt_for_datetime():
    """Prompt user for target date and time with clear formatting hints."""
    now = datetime.datetime.now()
    today_str = now.strftime("%Y-%m-%d")
    print(f"\n{BOLD}{BLUE}─── [ SCHEDULE PLAYBACK DATE & TIME ] ───────────────────────────{NC}")
    print(f"  Current System Time: {BOLD}{CYAN}{now.strftime('%Y-%m-%d %H:%M:%S')}{NC}")
    print(f"  {WHITE}Enter date and time when the mix should start playing loudly:{NC}")
    print(f"    • Exact Date & Time : {BOLD}{GREEN}{today_str} 18:30{NC} (or YYYY-MM-DD HH:MM)")
    print(f"    • Time Today/Tmrw   : {BOLD}{GREEN}20:00{NC} (or tomorrow 14:00)")
    print(f"    • Relative Timer    : {BOLD}{GREEN}+15m{NC}, {BOLD}{GREEN}+45m{NC}, {BOLD}{GREEN}+2h{NC}, {BOLD}{GREEN}+1d{NC}")
    print(f"    • (Type '0' or 'q' to cancel)")
    print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────{NC}")

    while True:
        try:
            user_input = input(f"\n{BOLD}Scheduled Time: {NC}").strip()
        except (KeyboardInterrupt, EOFError):
            return None

        if not user_input or user_input.lower() in ('0', 'q', 'back', 'cancel'):
            return None

        target_dt = parse_target_datetime(user_input)
        if not target_dt:
            print(f"  {RED}Error: Unable to parse date/time format. Please try again (e.g. {today_str} 18:30 or +30m).{NC}")
            continue

        if target_dt <= datetime.datetime.now():
            print(f"  {RED}Error: Scheduled time ({target_dt.strftime('%Y-%m-%d %H:%M:%S')}) is in the past! Please enter a future time.{NC}")
            continue

        return target_dt


def schedule_from_last_10_mixes(default_player):
    """Presents the last 10 recorded mixes and allows single or multi-mix scheduling."""
    print(f"\n{BOLD}{CYAN}Scanning mix archive for the last 10 recorded mixes...{NC}")
    recent = list_recent_mixes(limit=10)

    if not recent:
        print(f"\n{RED}Error: No recent audio mixes found in the mix archive directories!{NC}")
        input(f"Press {BOLD}[Enter]{NC} to return to menu...")
        return

    print(f"\n{BOLD}{BLUE}================================================================================{NC}")
    print(f"  {BOLD}{WHITE}LAST 10 RECORDED DJ MIXES (CHOOSE ONE OR MULTIPLE){NC}")
    print(f"{BOLD}{BLUE}================================================================================{NC}")

    for idx, m in enumerate(recent, 1):
        mtime_str = datetime.datetime.fromtimestamp(m['mtime']).strftime('%Y-%m-%d %H:%M')
        size_mb = m['size'] / (1024 * 1024)
        print(f"  {BOLD}{CYAN}{idx:2d}){NC} {BOLD}{WHITE}{m['filename']}{NC}")
        print(f"       {DIM}Size: {size_mb:.1f} MB  |  Recorded: {mtime_str}{NC}")

    print(f"{BOLD}{BLUE}--------------------------------------------------------------------------------{NC}")
    print(f"  Selection examples: {BOLD}{GREEN}1{NC} (single), {BOLD}{GREEN}1, 3, 5{NC} (multiple), {BOLD}{GREEN}1-3{NC} (range), {BOLD}{GREEN}all{NC}, or {BOLD}{YELLOW}0{NC} to cancel")

    while True:
        try:
            sel_str = input(f"\n{BOLD}Select mix number(s): {NC}").strip()
        except (KeyboardInterrupt, EOFError):
            return

        if not sel_str or sel_str == '0' or sel_str.lower() == 'q':
            return

        selected_indices = parse_selection(sel_str, len(recent))
        if not selected_indices:
            print(f"  {RED}Invalid selection. Please choose numbers between 1 and {len(recent)}.{NC}")
            continue
        break

    chosen_mixes = [recent[i - 1] for i in selected_indices]
    print(f"\n{BOLD}{GREEN}Selected {len(chosen_mixes)} Mix(es):{NC}")
    for idx, m in enumerate(chosen_mixes, 1):
        print(f"  {idx}. {m['filename']}")

    # Prompt for date and time
    target_dt = prompt_for_datetime()
    if not target_dt:
        print(f"\n{YELLOW}Scheduling cancelled.{NC}")
        time.sleep(1)
        return

    files = [m['path'] for m in chosen_mixes]
    if len(chosen_mixes) == 1:
        title = chosen_mixes[0]['filename']
    else:
        title = f"{len(chosen_mixes)} DJ Mixes ({chosen_mixes[0]['filename']} + {len(chosen_mixes)-1} more)"

    job, pid = create_scheduled_job(files, None, title, target_dt, player=default_player)

    diff = int(target_dt.timestamp() - time.time())
    hours = diff // 3600
    mins = (diff % 3600) // 60
    secs = diff % 60
    countdown = f"{hours}h {mins}m {secs}s" if hours > 0 else f"{mins}m {secs}s"

    print(f"\n{BOLD}{GREEN}================================================================================{NC}")
    print(f"  {BOLD}✓ MIX PLAYBACK SUCCESSFULLY SCHEDULED!{NC}")
    print(f"{BOLD}{GREEN}================================================================================{NC}")
    print(f"  • Mix Title(s)      : {BOLD}{WHITE}{title}{NC}")
    print(f"  • Scheduled Time    : {BOLD}{YELLOW}{job['scheduled_time']}{NC} (in {GREEN}{countdown}{NC})")
    print(f"  • Default Player    : {BOLD}{CYAN}{default_player}{NC}")
    print(f"  • Volume Output     : {BOLD}{RED}95% (Loud Master Output Unmuted){NC}")
    print(f"  • Background Daemon : Active (PID: {pid})")
    print(f"{BOLD}{GREEN}================================================================================{NC}\n")

    input(f"Press {BOLD}[Enter]{NC} to return to menu...")


def schedule_from_single_file(default_player):
    """Prompts for a full audio file path (WAV/MP3/FLAC) and schedules playback."""
    print(f"\n{BOLD}{BLUE}=== SCHEDULE SINGLE AUDIO MIX BY FILE PATH ==={NC}\n")
    print(f"  Enter the full absolute path to the audio file (WAV, MP3, FLAC).")
    print(f"  (Tab completion and path expansion '~' are supported, or type '0' to cancel)\n")

    while True:
        try:
            path_str = input(f"{BOLD}File Path: {NC}").strip().strip('"').strip("'")
        except (KeyboardInterrupt, EOFError):
            return

        if not path_str or path_str == '0' or path_str.lower() == 'q':
            return

        resolved = Path(path_str).expanduser().resolve()
        if not resolved.is_file():
            print(f"  {RED}Error: File '{path_str}' does not exist! Please check the path.{NC}")
            continue

        lower = resolved.name.lower()
        if not any(lower.endswith(ext) for ext in AUDIO_EXTS):
            print(f"  {RED}Error: File must be an audio file ({', '.join(AUDIO_EXTS)}).{NC}")
            continue

        target_file = str(resolved)
        break

    # Prompt for date and time
    target_dt = prompt_for_datetime()
    if not target_dt:
        print(f"\n{YELLOW}Scheduling cancelled.{NC}")
        time.sleep(1)
        return

    title = Path(target_file).name
    job, pid = create_scheduled_job([target_file], None, title, target_dt, player=default_player)

    diff = int(target_dt.timestamp() - time.time())
    hours = diff // 3600
    mins = (diff % 3600) // 60
    secs = diff % 60
    countdown = f"{hours}h {mins}m {secs}s" if hours > 0 else f"{mins}m {secs}s"

    print(f"\n{BOLD}{GREEN}================================================================================{NC}")
    print(f"  {BOLD}✓ MIX PLAYBACK SUCCESSFULLY SCHEDULED!{NC}")
    print(f"{BOLD}{GREEN}================================================================================{NC}")
    print(f"  • Mix Title         : {BOLD}{WHITE}{title}{NC}")
    print(f"  • Scheduled Time    : {BOLD}{YELLOW}{job['scheduled_time']}{NC} (in {GREEN}{countdown}{NC})")
    print(f"  • Default Player    : {BOLD}{CYAN}{default_player}{NC}")
    print(f"  • Volume Output     : {BOLD}{RED}95% (Loud Master Output Unmuted){NC}")
    print(f"  • Background Daemon : Active (PID: {pid})")
    print(f"{BOLD}{GREEN}================================================================================{NC}\n")

    input(f"Press {BOLD}[Enter]{NC} to return to menu...")


def schedule_from_playlist(default_player):
    """Allows choosing an existing playlist or providing a playlist path (.m3u8, .xspf)."""
    base_dir = get_base_dir()
    playlist_dirs = [
        base_dir / "playlists",
        SCHEDULED_PLAYLISTS_DIR,
        Path.home() / "Music" / "Playlists"
    ]

    found_playlists = []
    seen = set()
    for pdir in playlist_dirs:
        if pdir.is_dir():
            for p in pdir.glob("*"):
                if p.is_file() and p.suffix.lower() in PLAYLIST_EXTS:
                    if p.name not in seen:
                        seen.add(p.name)
                        found_playlists.append(p)

    print(f"\n{BOLD}{BLUE}=== SCHEDULE MULTIPLE MIXES VIA PLAYLIST ==={NC}\n")

    selected_playlist = None
    if found_playlists:
        print(f"  {WHITE}Available Playlists Found:{NC}")
        for idx, pl in enumerate(found_playlists, 1):
            print(f"  {BOLD}{CYAN}{idx}){NC} {pl.name} {DIM}({pl.parent}){NC}")
        print(f"  {BOLD}{CYAN}C){NC} Enter Custom Playlist Path")
        print(f"  {BOLD}0){NC} Cancel\n")

        try:
            choice = input(f"Select option [1-{len(found_playlists)}, C, 0]: ").strip()
        except (KeyboardInterrupt, EOFError):
            return

        if not choice or choice == "0":
            return
        elif choice.isdigit() and 1 <= int(choice) <= len(found_playlists):
            selected_playlist = str(found_playlists[int(choice) - 1].resolve())

    if not selected_playlist:
        while True:
            try:
                p_in = input(f"\n{BOLD}Enter Playlist File Path (.m3u8 / .m3u / .xspf / .pls): {NC}").strip().strip('"').strip("'")
            except (KeyboardInterrupt, EOFError):
                return
            if not p_in or p_in == "0":
                return
            res = Path(p_in).expanduser().resolve()
            if not res.is_file():
                print(f"  {RED}Error: Playlist file '{p_in}' not found!{NC}")
                continue
            if res.suffix.lower() not in PLAYLIST_EXTS:
                print(f"  {RED}Error: File must be a playlist ({', '.join(PLAYLIST_EXTS)}).{NC}")
                continue
            selected_playlist = str(res)
            break

    # Prompt for date and time
    target_dt = prompt_for_datetime()
    if not target_dt:
        print(f"\n{YELLOW}Scheduling cancelled.{NC}")
        time.sleep(1)
        return

    title = f"Playlist: {Path(selected_playlist).name}"
    job, pid = create_scheduled_job([], selected_playlist, title, target_dt, player=default_player)

    diff = int(target_dt.timestamp() - time.time())
    hours = diff // 3600
    mins = (diff % 3600) // 60
    secs = diff % 60
    countdown = f"{hours}h {mins}m {secs}s" if hours > 0 else f"{mins}m {secs}s"

    print(f"\n{BOLD}{GREEN}================================================================================{NC}")
    print(f"  {BOLD}✓ PLAYLIST PLAYBACK SUCCESSFULLY SCHEDULED!{NC}")
    print(f"{BOLD}{GREEN}================================================================================{NC}")
    print(f"  • Playlist Name     : {BOLD}{WHITE}{title}{NC}")
    print(f"  • Scheduled Time    : {BOLD}{YELLOW}{job['scheduled_time']}{NC} (in {GREEN}{countdown}{NC})")
    print(f"  • Default Player    : {BOLD}{CYAN}{default_player}{NC}")
    print(f"  • Volume Output     : {BOLD}{RED}95% (Loud Master Output Unmuted){NC}")
    print(f"  • Background Daemon : Active (PID: {pid})")
    print(f"{BOLD}{GREEN}================================================================================{NC}\n")

    input(f"Press {BOLD}[Enter]{NC} to return to menu...")


def instant_test_run(default_player):
    """Instantly test unmute, loud volume, and dispatching to default player with a recent mix."""
    print(f"\n{BOLD}{YELLOW}Testing Loud Audio Playback Right Now...{NC}\n")
    recent = list_recent_mixes(limit=1)
    if not recent:
        print(f"{RED}No mix found to test playback.{NC}")
        input(f"Press {BOLD}[Enter]{NC} to continue...")
        return

    test_file = recent[0]['path']
    print(f"  • Target Test File : {BOLD}{WHITE}{recent[0]['filename']}{NC}")
    print(f"  • Player           : {BOLD}{CYAN}{default_player}{NC}")
    print(f"  • Unmuting & Setting Volume to 95%...")
    set_loud_audio_volume(95)
    print(f"  • Launching {default_player}...")
    dispatch_audio_playback(default_player, [test_file])
    print(f"\n{GREEN}✓ Audio test triggered successfully!{NC}\n")
    time.sleep(1.5)


def main_interactive_menu(player_override=None):
    """Main terminal UI for the Mix Scheduler."""
    default_player = player_override or get_default_player()
    ensure_daemon()

    while True:
        running, pid = is_daemon_running()
        queue = load_queue()
        pending = [j for j in queue if j.get("status") == "pending"]

        # Clear screen for fresh menu
        os.system("clear" if os.name != "nt" else "cls")

        print(f"{BOLD}{BLUE}================================================================================{NC}")
        print(f"  {BOLD}{WHITE}DJ MIX SCHEDULER (PLAYS LOUDLY VIA DEFAULT AUDIO PLAYER){NC}")
        print(f"{BOLD}{BLUE}================================================================================{NC}")
        print(f"  Default Audio Player : {BOLD}{CYAN}{default_player}{NC}")
        print(f"  Volume Output Mode   : {BOLD}{RED}High Output (95-100% Unmuted){NC}")
        daemon_str = f"{GREEN}Active (PID: {pid}){NC}" if running else f"{YELLOW}Idle / Starting...{NC}"
        print(f"  Background Daemon    : {daemon_str}")
        print(f"  Pending Schedules    : {BOLD}{YELLOW}{len(pending)} active{NC}")
        print(f"{BOLD}{BLUE}--------------------------------------------------------------------------------{NC}")
        print(f"  {BOLD}{CYAN}1){NC} Schedule Mix(es) from Last 10 Recorded Mixes {GREEN}(Fast Selection){NC}")
        print(f"  {BOLD}{CYAN}2){NC} Schedule a Single Audio Mix by Full File Path {GREEN}(WAV / MP3 / FLAC){NC}")
        print(f"  {BOLD}{CYAN}3){NC} Schedule Multiple Mixes via Playlist {GREEN}(.m3u8 / .m3u / .xspf / .pls){NC}")
        print(f"  {BOLD}{CYAN}4){NC} View Pending Scheduled Mixes & Alarms {DIM}({len(pending)} pending){NC}")
        print(f"  {BOLD}{CYAN}5){NC} Cancel a Scheduled Mix Job")
        print(f"  {BOLD}{CYAN}6){NC} Test Audio Player & Loud Playback Right Now {YELLOW}(Instant Test){NC}")
        print(f"{BOLD}{BLUE}--------------------------------------------------------------------------------{NC}")
        print(f"  {BOLD}0){NC} Return to Mix Manager Main Menu {DIM}(or q){NC}")
        print("")

        try:
            choice = input(f"Enter choice [0-6]: ").strip()
        except (KeyboardInterrupt, EOFError):
            break

        if choice in ('0', 'q', 'exit'):
            break
        elif choice == '1':
            schedule_from_last_10_mixes(default_player)
        elif choice == '2':
            schedule_from_single_file(default_player)
        elif choice == '3':
            schedule_from_playlist(default_player)
        elif choice == '4':
            view_pending_jobs(interactive=True)
        elif choice == '5':
            cancel_job_dialog()
        elif choice == '6':
            instant_test_run(default_player)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="DJ Mix Scheduler (Plays Loudly via Default Player)")
    parser.add_argument("--daemon", action="store_true", help="Run background scheduler daemon worker")
    parser.add_argument("--ensure-daemon", action="store_true", help="Ensure background scheduler daemon is running")
    parser.add_argument("--list", action="store_true", help="List all pending scheduled mix jobs")
    parser.add_argument("--cancel", type=str, help="Cancel scheduled mix job by ID")
    parser.add_argument("--player", type=str, help="Specify audio player (e.g. strawberry, cliamp, vlc)")
    parser.add_argument("--test", action="store_true", help="Test loud playback right now")

    args = parser.parse_args()

    if args.daemon:
        daemon_loop()
    elif args.ensure_daemon:
        pid = ensure_daemon()
        print(f"Daemon running with PID {pid}")
    elif args.list:
        view_pending_jobs(interactive=False)
    elif args.cancel:
        queue = load_queue()
        for j in queue:
            if j.get("id") == args.cancel:
                j["status"] = "cancelled"
                save_queue(queue)
                print(f"Cancelled job {args.cancel}")
                sys.exit(0)
        print(f"Job {args.cancel} not found.")
    elif args.test:
        instant_test_run(args.player or get_default_player())
    else:
        main_interactive_menu(player_override=args.player)
