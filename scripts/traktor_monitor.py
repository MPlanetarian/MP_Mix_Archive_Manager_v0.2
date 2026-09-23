#!/usr/bin/env python3
"""
scripts/traktor_monitor.py - Cross-Platform Traktor Live Monitor & Audio Recorder Control
Works across macOS, Windows 10 & 11, and Linux (Bazzite / SteamOS / Fedora / Ubuntu).

Shows:
  • Traktor CPU % and memory footprint (RSS)
  • Tracks currently loaded / playing in decks (open audio files / session history)
  • Active recording file (open for write + real-time file size growth)
  • Audio interface from Traktor Settings + system audio defaults

Recording control:
  • macOS: System Events AppleScript menu click
  • Windows 10 & 11: PowerShell UI Automation / AppActivate hotkey dispatch
  • Live keys: s start · x stop · t toggle · r refresh · q quit
  • CLI: --start-recording / --stop-recording / --toggle-recording / --once / --list-menus
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
import platform
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional

IS_MACOS = platform.system() == "Darwin"
IS_WINDOWS = platform.system() == "Windows" or os.name == "nt" or "microsoft" in platform.release().lower()
IS_LINUX = platform.system() == "Linux"

# Enable VT100 / ANSI escape processing on Windows 10 & 11 console
if IS_WINDOWS:
    try:
        os.system("")
    except Exception:
        pass

TRAKTOR_PROC = "Traktor"
TRAKTOR_BUNDLE_ID = "com.native-instruments.Traktor"

SETTINGS_CANDIDATES = [
    Path.home() / "Documents/Native Instruments/Traktor 3.11.1/Traktor Settings.tsi",
    Path.home() / "Documents/Native Instruments/Traktor 3/Traktor Settings.tsi",
    Path.home() / "Documents/Native Instruments/Traktor Pro 3/Traktor Settings.tsi",
    Path.home() / "Documents/Native Instruments/Traktor Pro 4/Traktor Settings.tsi",
    Path.home() / "Documents/Native Instruments/Traktor 3.10.0/Traktor Settings.tsi",
    Path.home() / "Documents/Native Instruments/Traktor 2/Traktor Settings.tsi",
]

RECORDING_DIRS = [
    Path.home() / "Documents/MPlanetarian/M_PRODUCTION/STREAM_OF_FREQUENCY_RECORDINGS_TRAKTOR_2026",
    Path.home() / "Music/Traktor/Recordings",
    Path.home() / "Documents/Native Instruments/Traktor 3.11.1/Recordings",
    Path.home() / "Documents/Native Instruments/Traktor 3/Recordings",
    Path.home() / "Documents/Native Instruments/Traktor Pro 3/Recordings",
    Path.home() / "Documents/Native Instruments/Traktor Pro 4/Recordings",
    Path.home() / "Documents/Native Instruments/Traktor 3.11.1",
    Path("D:/MIX_ARCHIVE/CONVERTED_WAV_FILES"),
    Path("D:/MIX_ARCHIVE"),
    Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES"),
    Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"),
]
if os.environ.get("MIX_ARCHIVE_DIR"):
    _env_arch = Path(os.environ["MIX_ARCHIVE_DIR"])
    RECORDING_DIRS.extend([_env_arch / "CONVERTED_WAV_FILES", _env_arch])

AUDIO_EXTS = (".mp3", ".flac", ".aiff", ".aif", ".wav", ".m4a", ".stem.mp4", ".ogg", ".aac")

RECORD_START_MENU_CANDIDATES: list[tuple[str, str]] = [
    ("File", "Start Recording"),
    ("File", "Start Audio Recording"),
    ("File", "Record"),
    ("Deck", "Start Recording"),
    ("View", "Start Recording"),
    ("Traktor", "Start Recording"),
    ("File", "Audio Recorder On"),
    ("Deck", "Audio Recorder On"),
    ("View", "Audio Recorder On"),
]

RECORD_STOP_MENU_CANDIDATES: list[tuple[str, str]] = [
    ("File", "Stop Recording"),
    ("File", "Stop Audio Recording"),
    ("Deck", "Stop Recording"),
    ("View", "Stop Recording"),
    ("Traktor", "Stop Recording"),
    ("File", "Audio Recorder On"),
    ("Deck", "Audio Recorder On"),
    ("View", "Audio Recorder On"),
]


@dataclass
class RecordingItem:
    path: str
    name: str
    size: int = 0
    mtime: float = 0.0
    is_active: bool = False
    is_growing: bool = False


@dataclass
class Snapshot:
    ts: datetime
    running: bool = False
    pid: Optional[int] = None
    cpu: float = 0.0
    mem_pct: float = 0.0
    rss_mb: float = 0.0
    threads: int = 0
    cpu_time: str = ""
    loaded_tracks: list[str] = field(default_factory=list)
    recording: Optional[str] = None
    recording_size: Optional[int] = None
    recording_growing: Optional[bool] = None
    recording_active: bool = False
    recording_prefix: str = ""
    recent_recordings: list[RecordingItem] = field(default_factory=list)
    device_traktor: str = ""
    sample_rate: str = ""
    latency: str = ""
    driver: str = ""
    system_in: str = ""
    system_out: str = ""
    notes: list[str] = field(default_factory=list)
    last_action: str = ""



def run(cmd: list[str], timeout: float = 3.0) -> str:
    try:
        r = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return r.stdout or ""
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return ""


def run_osascript(script: str, timeout: float = 12.0) -> tuple[bool, str]:
    """Run AppleScript on macOS; return (ok, stdout_or_stderr)."""
    if not IS_MACOS:
        return False, "osascript only available on macOS"
    try:
        r = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        return False, str(e)
    out = (r.stdout or "").strip()
    err = (r.stderr or "").strip()
    if r.returncode != 0:
        return False, err or out or f"osascript exit {r.returncode}"
    return True, out


def find_traktor_pid() -> Optional[int]:
    """Find Traktor process ID across macOS, Linux, and Windows."""
    # 1. macOS detection
    if IS_MACOS:
        out = run(["pgrep", "-f", "Traktor.app/Contents/MacOS/Traktor$"])
        for line in out.splitlines():
            line = line.strip()
            if line.isdigit():
                return int(line)
        out = run(["pgrep", "-i", "-f", "Traktor"])
        for line in out.splitlines():
            line = line.strip()
            if line.isdigit():
                return int(line)
        return None

    # 2. Windows 10 & 11 detection
    if IS_WINDOWS:
        try:
            # Fast tasklist query
            out = subprocess.run(
                ["tasklist", "/fi", "imagename eq Traktor.exe", "/fo", "csv", "/nh"],
                capture_output=True,
                text=True,
                timeout=2.0,
                check=False,
            ).stdout or ""
            for line in out.splitlines():
                parts = [p.strip('"') for p in line.split('","')]
                if len(parts) >= 2 and "traktor" in parts[0].lower() and parts[1].isdigit():
                    return int(parts[1])
        except Exception:
            pass

        # Check Traktor Pro variations
        for img in ("Traktor Pro 3.exe", "Traktor Pro 4.exe", "Traktor Pro.exe"):
            try:
                out = subprocess.run(
                    ["tasklist", "/fi", f"imagename eq {img}", "/fo", "csv", "/nh"],
                    capture_output=True,
                    text=True,
                    timeout=1.5,
                    check=False,
                ).stdout or ""
                for line in out.splitlines():
                    parts = [p.strip('"') for p in line.split('","')]
                    if len(parts) >= 2 and parts[1].isdigit():
                        return int(parts[1])
            except Exception:
                pass

        # PowerShell fallback
        try:
            cmd = ["powershell.exe", "-NoProfile", "-Command",
                   "(Get-Process -Name Traktor* -ErrorAction SilentlyContinue | Select-Object -First 1).Id"]
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=2.5, check=False).stdout.strip()
            if out.isdigit():
                return int(out)
        except Exception:
            pass
        return None

    # 3. Linux (Native or Wine / Bottles / Proton)
    out = run(["pgrep", "-i", "-f", "Traktor"])
    for line in out.splitlines():
        line = line.strip()
        if line.isdigit():
            return int(line)
    return None


def open_traktor() -> bool:
    """Attempt to launch Native Instruments Traktor Pro on the host system."""
    if IS_MACOS:
        app_paths = [
            Path("/Applications/Native Instruments/Traktor Pro 3/Traktor.app"),
            Path("/Applications/Native Instruments/Traktor Pro 4/Traktor.app"),
            Path("/Applications/Native Instruments/Traktor 3/Traktor.app"),
            Path("/Applications/Traktor Pro 4.app"),
            Path("/Applications/Traktor Pro 3.app"),
            Path("/Applications/Traktor.app"),
        ]
        for p in app_paths:
            if p.exists():
                try:
                    subprocess.Popen(["open", str(p)])
                    return True
                except Exception:
                    pass

        try:
            r = subprocess.run(["open", "-b", TRAKTOR_BUNDLE_ID], capture_output=True, timeout=3.0)
            if r.returncode == 0:
                return True
        except Exception:
            pass

        for name in ("Traktor Pro 3", "Traktor Pro 4", "Traktor"):
            try:
                r = subprocess.run(["open", "-a", name], capture_output=True, timeout=3.0)
                if r.returncode == 0:
                    return True
            except Exception:
                pass
        return False

    if IS_WINDOWS:
        win_candidates = [
            r"C:\Program Files\Native Instruments\Traktor Pro 4\Traktor.exe",
            r"C:\Program Files\Native Instruments\Traktor Pro 3\Traktor.exe",
            r"C:\Program Files\Native Instruments\Traktor 2\Traktor.exe",
            r"C:\Program Files (x86)\Native Instruments\Traktor Pro 3\Traktor.exe",
        ]
        for p in win_candidates:
            if os.path.isfile(p):
                try:
                    os.startfile(p)
                    return True
                except Exception:
                    try:
                        subprocess.Popen([p])
                        return True
                    except Exception:
                        pass
        try:
            subprocess.Popen(["cmd.exe", "/c", "start", "", "Traktor.exe"])
            return True
        except Exception:
            pass
        return False

    if IS_LINUX:
        for cmd in ("traktor", "Traktor"):
            if shutil.which(cmd):
                try:
                    subprocess.Popen([cmd])
                    return True
                except Exception:
                    pass
    return False


def ensure_traktor_running(timeout: float = 12.0) -> Optional[int]:
    """If Traktor is not running already, open it and wait until its process is detected."""
    pid = find_traktor_pid()
    if pid:
        return pid

    print("\n🎛️  Traktor Pro is not currently running.")
    print("🚀 Launching Native Instruments Traktor Pro...")
    opened = open_traktor()
    if not opened:
        print("⚠️  Could not automatically launch Traktor. Waiting for manual start...\n")

    start_t = time.time()
    while time.time() - start_t < timeout:
        time.sleep(1.0)
        pid = find_traktor_pid()
        if pid:
            print(f"✓ Traktor Pro detected (PID: {pid}). Initializing live monitoring...")
            time.sleep(1.5)
            return pid
        elapsed = int(time.time() - start_t)
        print(f"⏳ Waiting for Traktor Pro to initialize ({elapsed}s)...", end="\r", flush=True)

    print("")
    return find_traktor_pid()


def process_stats(pid: int) -> dict:
    """Collect CPU %, memory (RSS MB), threads, and elapsed time."""
    # 1. macOS & Linux via ps
    if not IS_WINDOWS:
        out = run(["ps", "-p", str(pid), "-o", "%cpu=,%mem=,rss=,time="])
        parts = out.split()
        if len(parts) >= 4:
            try:
                cpu = float(parts[0])
                mem = float(parts[1])
                rss_kb = float(parts[2])
                t = parts[3]
                nthr = 0
                if IS_MACOS:
                    thr = run(["ps", "-M", "-p", str(pid)])
                    nthr = max(0, len([ln for ln in thr.splitlines() if ln.strip()]) - 1)
                elif os.path.isdir(f"/proc/{pid}/task"):
                    nthr = len(os.listdir(f"/proc/{pid}/task"))
                return {
                    "cpu": cpu,
                    "mem": mem,
                    "rss_mb": rss_kb / 1024.0,
                    "time": t,
                    "threads": nthr,
                }
            except Exception:
                pass

    # 2. Windows via PowerShell
    if IS_WINDOWS:
        try:
            ps_cmd = (
                f"$p = Get-Process -Id {pid} -ErrorAction SilentlyContinue; "
                "if ($p) { "
                "  $cpu = [math]::Round($p.CPU, 1); "
                "  $mem = [math]::Round($p.WorkingSet64 / 1MB, 1); "
                "  $thr = $p.Threads.Count; "
                "  $time = '{0:N1}s' -f $cpu; "
                "  Write-Output \"$cpu|$mem|$thr|$time\" "
                "}"
            )
            out = subprocess.run(
                ["powershell.exe", "-NoProfile", "-Command", ps_cmd],
                capture_output=True,
                text=True,
                timeout=2.5,
                check=False,
            ).stdout.strip()
            if "|" in out:
                c, m, th, tm = out.split("|", 3)
                return {
                    "cpu": float(c or 0.0),
                    "mem": 0.0,
                    "rss_mb": float(m or 0.0),
                    "time": tm,
                    "threads": int(th or 0),
                }
        except Exception:
            pass

    return {"cpu": 0.0, "mem": 0.0, "rss_mb": 0.0, "time": "?", "threads": 0}


def find_settings() -> Optional[Path]:
    """Find Traktor Settings.tsi across macOS, Windows, and Linux."""
    for p in SETTINGS_CANDIDATES:
        if p.is_file():
            return p

    # Standard Documents search
    docs_dirs = [
        Path.home() / "Documents/Native Instruments",
        Path.home() / "Documents",
    ]
    if IS_WINDOWS:
        user_prof = os.environ.get("USERPROFILE")
        if user_prof:
            docs_dirs.append(Path(user_prof) / "Documents/Native Instruments")
    elif IS_LINUX:
        # Check Wine prefixes
        wine_dirs = [
            Path.home() / ".wine/drive_c/users",
            Path.home() / ".var/app/com.usebottles.bottles/data/bottles/bottles",
        ]
        for wd in wine_dirs:
            if wd.is_dir():
                for p in wd.glob("**/Native Instruments/**/Traktor Settings.tsi"):
                    if p.is_file():
                        return p

    for base in docs_dirs:
        if base.is_dir():
            try:
                for p in base.rglob("Traktor Settings.tsi"):
                    if p.is_file():
                        return p
            except Exception:
                pass
    return None


def parse_settings(path: Path) -> dict:
    """Extract audio device, sample rate, latency, driver, and recording folder."""
    info = {
        "device": "?",
        "sample_rate": "?",
        "latency": "?",
        "driver": "?",
        "recording_prefix": "",
        "recording_dir": "",
    }
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return info

    def grab(name: str) -> Optional[str]:
        m = re.search(
            rf'Name="{re.escape(name)}"[^>]*Value="([^"]*)"',
            text,
        )
        return m.group(1) if m else None

    # Multi-platform audio device names
    info["device"] = (
        grab("Audio.DeviceName.Win")
        or grab("Audio.DeviceName.Mac")
        or grab("Audio.DeviceName.ASIO")
        or grab("Audio.DeviceName.WASAPI")
        or grab("Audio.DeviceName.DirectSound")
        or grab("Audio.DeviceName")
        or "?"
    )
    info["sample_rate"] = grab("Audio.SampleRate") or grab("Audio.FS.SampleRate") or "?"
    info["latency"] = grab("Audio.Latency") or grab("Audio.FS.Latency") or "?"
    info["driver"] = grab("Audio.DriverName") or "?"
    info["recording_prefix"] = grab("Recording.Prefix") or ""
    rec_dir = grab("Recording.Directory") or grab("Recording.Path") or ""
    if rec_dir:
        info["recording_dir"] = rec_dir
        p = Path(rec_dir)
        if p not in RECORDING_DIRS:
            RECORDING_DIRS.insert(0, p)
    return info


def system_audio_defaults() -> tuple[str, str]:
    """Retrieve system default audio input and output across OSes."""
    # 1. macOS: system_profiler
    if IS_MACOS:
        out = run(["system_profiler", "SPAudioDataType"], timeout=6.0)
        default_in = default_out = "?"
        current_name = None
        for line in out.splitlines():
            stripped = line.strip()
            if stripped.endswith(":") and not stripped.startswith("Manufacturer") and not stripped.startswith(
                "Output"
            ) and not stripped.startswith("Input") and not stripped.startswith("Current") and not stripped.startswith(
                "Transport"
            ) and not stripped.startswith("Default"):
                name = stripped[:-1].strip()
                if name and name not in ("Audio", "Devices"):
                    current_name = name
            if "Default Input Device: Yes" in line and current_name:
                default_in = current_name
            if "Default Output Device: Yes" in line and current_name:
                default_out = current_name
        return default_in, default_out

    # 2. Windows 10 & 11: PowerShell CoreAudio / Win32_SoundDevice
    if IS_WINDOWS:
        try:
            cmd = [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                "$d = Get-CimInstance Win32_SoundDevice | Select-Object -First 1 -ExpandProperty Name; if ($d) { $d } else { 'Default Audio Device' }",
            ]
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=2.0, check=False).stdout.strip()
            dev_name = out if out else "Windows Audio Endpoint"
            return dev_name, dev_name
        except Exception:
            return "Windows Audio Input", "Windows Audio Output"

    # 3. Linux: PipeWire / wpctl
    try:
        p = subprocess.run(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=0.5, check=False)
        if p.returncode == 0 and p.stdout:
            for line in p.stdout.splitlines():
                if "node.description =" in line:
                    m = re.search(r'node\.description\s*=\s*"([^"]+)"', line)
                    if m:
                        return "PipeWire Input", m.group(1).strip()
    except Exception:
        pass

    return "System Default In", "System Default Out"


def get_latest_traktor_history_tracks() -> list[str]:
    """Parse newest Traktor History XML session file (history_*.nml) for loaded tracks."""
    history_dirs = [
        Path.home() / "Documents/Native Instruments/Traktor 3.11.1/History",
        Path.home() / "Documents/Native Instruments/Traktor 3/History",
        Path.home() / "Documents/Native Instruments/Traktor Pro 3/History",
        Path.home() / "Documents/Native Instruments/Traktor Pro 4/History",
    ]
    if IS_WINDOWS and os.environ.get("USERPROFILE"):
        history_dirs.append(Path(os.environ["USERPROFILE"]) / "Documents/Native Instruments/Traktor 3.11.1/History")

    history_files: list[Path] = []
    for hd in history_dirs:
        if hd.is_dir():
            try:
                for f in hd.glob("history_*.nml"):
                    history_files.append(f)
            except Exception:
                pass

    if not history_files:
        return []

    # Pick the most recently modified history file
    history_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    latest_nml = history_files[0]

    # Only consider it active if modified within the last 4 hours
    if time.time() - latest_nml.stat().st_mtime > 14400:
        return []

    tracks: list[str] = []
    try:
        tree = ET.parse(latest_nml)
        root = tree.getroot()
        collection = root.find("COLLECTION")
        if collection is not None:
            entries = collection.findall("ENTRY")
            for entry in entries[-4:]:  # Last 4 loaded tracks (Decks A, B, C, D)
                title = entry.get("TITLE", "").strip()
                artist = entry.get("ARTIST", "").strip()
                loc = entry.find("LOCATION")
                fname = loc.get("FILE", "") if loc is not None else ""
                if title and artist:
                    tracks.append(f"{artist} - {title}")
                elif title:
                    tracks.append(title)
                elif fname:
                    tracks.append(fname)
    except Exception:
        pass
    return tracks


def lsof_tracks_and_recording(pid: int) -> tuple[list[str], Optional[str], Optional[int]]:
    """Inspect process file descriptors for loaded decks and active recordings."""
    loaded: list[str] = []
    recording: Optional[str] = None
    rec_size: Optional[int] = None

    # 1. macOS & Linux: lsof
    if not IS_WINDOWS and shutil.which("lsof"):
        out = run(["lsof", "-p", str(pid), "-F", "n"], timeout=5.0)
        paths = [line[1:] for line in out.splitlines() if line.startswith("n")]

        for p in paths:
            low = p.lower()
            if "/Library/" in p and "Native Instruments" not in p and "STREAM" not in p:
                if not any(low.endswith(ext) for ext in AUDIO_EXTS):
                    continue
            if any(low.endswith(ext) for ext in AUDIO_EXTS) or low.endswith(".wav"):
                if "STREAM_OF_FREQUENCY" in p or "/Recordings/" in p or "recording" in low:
                    recording = p
                    try:
                        rec_size = os.path.getsize(p)
                    except OSError:
                        rec_size = None
                elif any(low.endswith(ext) for ext in AUDIO_EXTS):
                    if p not in loaded:
                        loaded.append(p)

        # Refine write-mode detection with full lsof
        out2 = run(["lsof", "-p", str(pid)], timeout=5.0)
        for line in out2.splitlines():
            parts = line.split()
            if len(parts) >= 9:
                fd = parts[3]
                path = parts[-1]
                if "w" in fd and (path.endswith(".wav") or path.endswith(".aiff") or "STREAM_OF_FREQUENCY" in path):
                    recording = path
                    try:
                        rec_size = os.path.getsize(path)
                    except OSError:
                        pass

        nice = [Path(p).name for p in loaded]
        return nice, recording, rec_size

    # 2. Linux /proc/$pid/fd inspection (fast & lightweight fallback)
    if IS_LINUX and os.path.isdir(f"/proc/{pid}/fd"):
        try:
            for fd_name in os.listdir(f"/proc/{pid}/fd"):
                fd_path = os.path.join(f"/proc/{pid}/fd", fd_name)
                try:
                    target = os.readlink(fd_path)
                    low = target.lower()
                    if any(low.endswith(ext) for ext in AUDIO_EXTS):
                        if "stream_of_frequency" in low or "recording" in low:
                            recording = target
                            try:
                                rec_size = os.path.getsize(target)
                            except OSError:
                                pass
                        elif Path(target).name not in loaded:
                            loaded.append(Path(target).name)
                except OSError:
                    continue
        except Exception:
            pass

    # 3. Windows (or fallback): NML History & File Growth
    if not loaded:
        loaded = get_latest_traktor_history_tracks()

    return loaded, recording, rec_size


def detect_recording_by_growth(
    prefix: str, prev_size: Optional[int]
) -> tuple[Optional[str], Optional[int], Optional[bool]]:
    """Detect the newest recording file and check if it is actively growing."""
    candidates: list[Path] = []
    now = time.time()
    for d in RECORDING_DIRS:
        if not d.is_dir():
            continue
        try:
            for f in d.iterdir():
                if not f.is_file():
                    continue
                if f.suffix.lower() not in (".wav", ".aiff", ".aif", ".mp3"):
                    continue
                if prefix and prefix not in f.name and not f.name.startswith("MPlanetarian"):
                    pass
                candidates.append(f)
        except OSError:
            continue

    if not candidates:
        return None, None, None

    newest = max(candidates, key=lambda p: p.stat().st_mtime)
    try:
        st = newest.stat()
        size = st.st_size
        mtime = st.st_mtime
    except OSError:
        return str(newest), None, None

    # Growing if size grew since last tick, or modified in the last 4 seconds
    growing = False
    if prev_size is not None and size > prev_size:
        growing = True
    elif (now - mtime) < 4.0 and size > 0:
        growing = True

    return str(newest), size, growing


def get_recent_recordings(
    limit: int = 3,
    active_path: Optional[str] = None,
    active_size: Optional[int] = None,
    active_growing: Optional[bool] = None,
    is_active: bool = False,
) -> list[RecordingItem]:
    """Return the last `limit` recordings across recording directories, ordered by newest first."""
    seen: dict[str, Path] = {}
    dirs_to_check: list[Path] = list(RECORDING_DIRS)
    if active_path:
        act_p = Path(active_path)
        try:
            if act_p.parent.is_dir() and act_p.parent not in dirs_to_check:
                dirs_to_check.insert(0, act_p.parent)
        except OSError:
            pass

    for d in dirs_to_check:
        if not d.is_dir():
            continue
        try:
            for f in d.iterdir():
                if f.name.startswith("."):
                    continue
                if not f.is_file():
                    continue
                if f.suffix.lower() not in (".wav", ".aiff", ".aif", ".mp3", ".flac", ".m4a", ".ogg"):
                    continue
                try:
                    seen[str(f.resolve())] = f
                except OSError:
                    pass
        except OSError:
            continue

    if active_path:
        act_p = Path(active_path)
        try:
            if act_p.is_file():
                seen[str(act_p.resolve())] = act_p
        except OSError:
            pass

    items: list[RecordingItem] = []
    now = time.time()
    act_resolved = None
    if active_path:
        try:
            act_resolved = str(Path(active_path).resolve())
        except OSError:
            act_resolved = str(active_path)

    for f in seen.values():
        try:
            st = f.stat()
            f_size = st.st_size
            f_mtime = st.st_mtime
            resolved = str(f.resolve())
            this_is_active = False
            this_is_growing = False

            if act_resolved and (resolved == act_resolved or str(f) == active_path):
                this_is_active = is_active
                this_is_growing = bool(active_growing)
                if active_size is not None:
                    f_size = active_size
                if is_active:
                    f_mtime = max(f_mtime, now)

            items.append(
                RecordingItem(
                    path=str(f),
                    name=f.name,
                    size=f_size,
                    mtime=f_mtime,
                    is_active=this_is_active,
                    is_growing=this_is_growing,
                )
            )
        except OSError:
            continue

    items.sort(key=lambda x: x.mtime, reverse=True)
    return items[:limit]


def is_recording_active(pid: Optional[int] = None) -> bool:
    """Best-effort check if Traktor is currently writing an audio file."""
    if pid is None:
        pid = find_traktor_pid()

    # macOS / Linux lsof check
    if pid and not IS_WINDOWS and shutil.which("lsof"):
        out = run(["lsof", "-p", str(pid)], timeout=3.0)
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 9:
                fd = parts[3]
                path = parts[-1]
                if "w" in fd and (
                    path.endswith(".wav")
                    or path.endswith(".aiff")
                    or path.endswith(".aif")
                    or "STREAM_OF_FREQUENCY" in path
                    or "/Recordings/" in path
                ):
                    return True

    # Growth / modification check in recording directories
    now = time.time()
    for d in RECORDING_DIRS:
        if not d.is_dir():
            continue
        try:
            for f in d.iterdir():
                if not f.is_file():
                    continue
                if f.suffix.lower() not in (".wav", ".aiff", ".aif", ".mp3"):
                    continue
                try:
                    st = f.stat()
                    if now - st.st_mtime < 4.0 and st.st_size > 0:
                        return True
                except OSError:
                    continue
        except OSError:
            continue
    return False


def click_traktor_menu_item(menu_name: str, item_name: str) -> tuple[bool, str]:
    """macOS: Activate Traktor and click menu bar item via System Events."""
    if not IS_MACOS:
        return False, "Menu clicking is currently supported natively on macOS via System Events"
    menu_a = menu_name.replace("\\", "\\\\").replace('"', '\\"')
    item_a = item_name.replace("\\", "\\\\").replace('"', '\\"')
    script = f'''
tell application "System Events"
  set procs to every process whose bundle identifier is "{TRAKTOR_BUNDLE_ID}"
  if (count of procs) is 0 then
    set procs to every process whose name is "{TRAKTOR_PROC}"
  end if
  if (count of procs) is 0 then
    return "ERROR: Traktor is not running"
  end if
  set proc to item 1 of procs
  set frontmost of proc to true
  delay 0.25
  tell proc
    try
      click menu item "{item_a}" of menu "{menu_a}" of menu bar 1
      return "OK: clicked {menu_a} > {item_a}"
    on error errMsg number errNum
      return "ERROR: (" & errNum & ") " & errMsg
    end try
  end tell
end tell
'''
    ok, msg = run_osascript(script, timeout=12.0)
    if not ok or msg.startswith("ERROR:"):
        return False, msg
    return True, msg


def click_traktor_menu_item_fuzzy(want_start: bool) -> tuple[bool, str]:
    """macOS: Fuzzy scan Traktor menu bar items for recording controls."""
    if not IS_MACOS:
        return False, "Menu scanning is supported on macOS via Accessibility"
    script = f'''
tell application "System Events"
  set procs to every process whose bundle identifier is "{TRAKTOR_BUNDLE_ID}"
  if (count of procs) is 0 then
    set procs to every process whose name is "{TRAKTOR_PROC}"
  end if
  if (count of procs) is 0 then return "ERROR: Traktor is not running"
  set proc to item 1 of procs
  set frontmost of proc to true
  delay 0.25
  set wantStart to {"true" if want_start else "false"}
  tell proc
    set startHit to ""
    set stopHit to ""
    set toggleHit to ""
    try
      set menuNames to name of every menu bar item of menu bar 1
    on error errMsg
      return "ERROR: cannot read menu bar: " & errMsg
    end try
    repeat with mName in menuNames
      set mNameText to mName as text
      try
        set itemNames to name of every menu item of menu mNameText of menu bar 1
        repeat with iName in itemNames
          set iText to iName as text
          if iText is not "missing value" and iText is not "" then
            set lowerI to my toLower(iText)
            if lowerI contains "record" then
              if lowerI contains "stop" then
                if stopHit is "" then set stopHit to mNameText & "||" & iText
              else if lowerI contains "start" then
                if startHit is "" then set startHit to mNameText & "||" & iText
              else if lowerI contains "audio recorder on" or lowerI is "record" then
                if toggleHit is "" then set toggleHit to mNameText & "||" & iText
              end if
            end if
          end if
        end repeat
      end try
    end repeat
    set target to ""
    if wantStart then
      if startHit is not "" then set target to startHit
      else if toggleHit is not "" then set target to toggleHit
    else
      if stopHit is not "" then set target to stopHit
      else if toggleHit is not "" then set target to toggleHit
    end if
    if target is "" then
      return "ERROR: no recording menu item found in Traktor."
    end if
    set AppleScript's text item delimiters to "||"
    set parts to text items of target
    set AppleScript's text item delimiters to ""
    set menuName to item 1 of parts
    set itemName to item 2 of parts
    try
      click menu item itemName of menu menuName of menu bar 1
      return "OK: clicked " & menuName & " > " & itemName
    on error errMsg number errNum
      return "ERROR: (" & errNum & ") " & errMsg
    end try
  end tell
end tell

on toLower(t)
  set low to do shell script "printf %s " & quoted form of t & " | tr '[:upper:]' '[:lower:]'"
  return low
end toLower
'''
    ok, msg = run_osascript(script, timeout=18.0)
    if not ok or msg.startswith("ERROR:"):
        return False, msg
    return True, msg


def control_recording_windows(action: str) -> tuple[bool, str]:
    """Windows 10 & 11: Activate Traktor and send Audio Recorder key / UI Automation."""
    ps_script = f'''
$wshell = New-Object -ComObject WScript.Shell
$proc = Get-Process -Name Traktor* -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) {{
    Write-Output "ERROR: Traktor is not running"
    exit 1
}}
if ($wshell.AppActivate($proc.Id)) {{
    Start-Sleep -Milliseconds 250
    # Send mapped Audio Recorder key or standard shortcut
    $wshell.SendKeys("^(r)")
    Write-Output "OK: Sent Audio Recorder toggle signal to Traktor (PID $($proc.Id))"
    exit 0
}} else {{
    Write-Output "ERROR: Could not activate Traktor window"
    exit 1
}}
'''
    try:
        res = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command", ps_script],
            capture_output=True,
            text=True,
            timeout=5.0,
            check=False,
        )
        out = res.stdout.strip()
        if res.returncode == 0 and out.startswith("OK:"):
            return True, f"Windows {action} signal dispatched: {out}"
        return False, out or res.stderr.strip()
    except Exception as e:
        return False, f"Windows recording dispatch failed: {e}"


def menu_control_recording(action: str) -> tuple[bool, str]:
    """Start, stop, or toggle Traktor recording across macOS, Windows, and Linux."""
    action = action.lower().strip()
    if action not in ("start", "stop", "toggle"):
        return False, f"Unknown action {action!r}; use start|stop|toggle"

    pid = find_traktor_pid()
    if not pid:
        return False, "Traktor is not running"

    active = is_recording_active(pid)
    if action == "toggle":
        want_start = not active
    elif action == "start":
        if active:
            return True, "Already recording (active file write / growth detected)"
        want_start = True
    else:  # stop
        want_start = False

    # 1. macOS Menu Automation
    if IS_MACOS:
        candidates = RECORD_START_MENU_CANDIDATES if want_start else RECORD_STOP_MENU_CANDIDATES
        errors: list[str] = []
        for menu_name, item_name in candidates:
            ok, msg = click_traktor_menu_item(menu_name, item_name)
            if ok:
                verb = "Started" if want_start else "Stopped"
                return True, f"{verb} via menu: {msg}"
            errors.append(f"{menu_name} > {item_name}: {msg}")

        ok, msg = click_traktor_menu_item_fuzzy(want_start=want_start)
        if ok:
            verb = "Started" if want_start else "Stopped"
            return True, f"{verb} via menu scan: {msg}"

        hint = (
            "Could not find a recording menu item. "
            "Grant Accessibility to this terminal, and/or in Traktor: "
            "Preferences → Controller Manager → add a Keyboard device → "
            "map a key to 'Audio Recorder On', then re-run."
        )
        return False, hint

    # 2. Windows 10 & 11 Automation
    if IS_WINDOWS:
        return control_recording_windows(action)

    # 3. Linux / generic
    return False, f"Direct menu dispatch not supported on this platform. Map a keyboard shortcut in Traktor Controller Manager."


def human_size(n: Optional[int]) -> str:
    if n is None:
        return "?"
    val = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if val < 1024.0:
            return f"{val:.1f} {unit}" if unit != "B" else f"{int(val)} B"
        val /= 1024.0
    return f"{val:.2f} PB"


def cpu_bar(pct: float, width: int = 20) -> str:
    fill = int(min(pct, 100.0) / 100.0 * width)
    return "[" + ("#" * fill) + ("-" * (width - fill)) + "]"


def clear_screen() -> None:
    if IS_WINDOWS:
        os.system("cls")
    else:
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()


def format_recent_recordings(
    recordings: list[RecordingItem],
    box_w: int,
    term_h: int = 30,
) -> list[str]:
    lines = []
    lines.append("-" * box_w)
    lines.append("  LAST 3 RECORDINGS (Newest at Top)")
    lines.append("-" * box_w)
    if not recordings:
        lines.append("  (No audio recordings found in recording directories)")
        return lines

    first_dir = str(Path(recordings[0].path).parent)
    show_all_paths = term_h >= 40

    for idx, r in enumerate(recordings, 1):
        status_badge = ""
        if r.is_active:
            if r.is_growing:
                status_badge = "  [● LIVE: Growing]"
            else:
                status_badge = "  [● LIVE: Active Write]"

        date_str = (
            datetime.fromtimestamp(r.mtime).strftime("%Y-%m-%d %H:%M:%S")
            if r.mtime
            else ""
        )
        lines.append(f"  [{idx}] {r.name}{status_badge}")
        lines.append(f"      Size: {human_size(r.size):<10}  │  Modified: {date_str}")
        if show_all_paths or idx == 1 or str(Path(r.path).parent) != first_dir:
            lines.append(f"      Path: {r.path}")

    return lines


def render(s: Snapshot) -> str:
    lines = []
    w, h = shutil.get_terminal_size((100, 30))
    box_w = min(w, 82)
    term_h = h

    title = "🎛️  TRAKTOR PRO LIVE MONITOR & RECORDER  🎛️"
    lines.append("=" * box_w)
    lines.append(title.center(box_w))
    lines.append(s.ts.strftime("%A, %B %d, %Y • %H:%M:%S").center(box_w))
    lines.append("=" * box_w)
    lines.append("")

    if not s.running:
        lines.append("  STATUS     Traktor is NOT running")
        lines.append("")
        lines.append("  Start Traktor Pro (macOS, Windows, or Linux) to begin live monitoring.")
        lines.append("")
        lines.extend(format_recent_recordings(s.recent_recordings, box_w, term_h))
    else:
        lines.append(f"  STATUS     ● RUNNING   PID: {s.pid}   Threads: ≈{s.threads}")
        lines.append(
            f"  CPU        {s.cpu:5.1f}%  {cpu_bar(s.cpu)}   "
            f"RAM: {s.rss_mb:6.1f} MB RSS   CPU Time: {s.cpu_time}"
        )
        lines.append("")
        lines.append("-" * box_w)
        lines.append("  AUDIO INTERFACE & HARDWARE")
        lines.append("-" * box_w)
        lines.append(f"  Traktor Device      {s.device_traktor or '?'}")
        lines.append(
            f"  Driver / Clock      {s.driver or '?'}  │  Rate: {s.sample_rate} Hz  │  Buffer/Latency: {s.latency}"
        )
        lines.append(f"  System Default IN   {s.system_in}")
        lines.append(f"  System Default OUT  {s.system_out}")
        lines.append("")
        lines.append("-" * box_w)
        lines.append("  LOADED / ACTIVE TRACKS (Decks with Media Open)")
        lines.append("-" * box_w)
        if s.loaded_tracks:
            for i, t in enumerate(s.loaded_tracks, 1):
                lines.append(f"  [Deck {chr(64+i) if i<=4 else str(i)}] {t}")
        else:
            lines.append("  (No audio tracks actively open or loaded on decks)")
        lines.append("")
        lines.append("-" * box_w)
        lines.append("  AUDIO RECORDER STATUS")
        lines.append("-" * box_w)
        rec_badge = "● RECORDING (Active File Write)" if s.recording_active else "○ IDLE (Not Recording)"
        lines.append(f"  State    {rec_badge}")
        if s.recording_prefix:
            lines.append(f"  Prefix   {s.recording_prefix}")
        lines.append("  Control  [s] Start Rec  │  [x] Stop Rec  │  [t] Toggle Rec")
        lines.append("")
        lines.extend(format_recent_recordings(s.recent_recordings, box_w, term_h))

    if s.last_action:
        lines.append("")
        lines.append("-" * box_w)
        lines.append("  LAST RECORDER ACTION")
        lines.append("-" * box_w)
        lines.append(f"  {s.last_action}")

    if s.notes:
        lines.append("")
        lines.append("-" * box_w)
        lines.append("  SYSTEM NOTES")
        lines.append("-" * box_w)
        for n in s.notes:
            lines.append(f"  • {n}")

    lines.append("")
    lines.append("-" * box_w)
    lines.append("  HOTKEYS:  [Q] Quit  │  [R] Refresh  │  [S] Start Rec  │  [X] Stop Rec  │  [T] Toggle Rec")
    lines.append("=" * box_w)
    return "\n".join(lines)


def take_snapshot(prev_rec_size: Optional[int]) -> Snapshot:
    s = Snapshot(ts=datetime.now())
    settings_path = find_settings()
    if settings_path:
        conf = parse_settings(settings_path)
        s.device_traktor = conf["device"]
        s.sample_rate = conf["sample_rate"]
        s.latency = conf["latency"]
        s.driver = conf["driver"]
        s.recording_prefix = conf["recording_prefix"]
    else:
        s.notes.append("Traktor Settings.tsi not found (using system defaults)")

    try:
        s.system_in, s.system_out = system_audio_defaults()
    except Exception as e:
        s.notes.append(f"Audio device query notice: {e}")

    pid = find_traktor_pid()
    if not pid:
        s.running = False
        path, size, growing = detect_recording_by_growth(s.recording_prefix, prev_rec_size)
        s.recording, s.recording_size, s.recording_growing = path, size, growing
        s.recent_recordings = get_recent_recordings(
            limit=3,
            active_path=s.recording,
            active_size=s.recording_size,
            active_growing=s.recording_growing,
            is_active=False,
        )
        if not s.recording and s.recent_recordings:
            s.recording = s.recent_recordings[0].path
            s.recording_size = s.recent_recordings[0].size
        return s

    s.running = True
    s.pid = pid
    st = process_stats(pid)
    s.cpu = st["cpu"]
    s.mem_pct = st["mem"]
    s.rss_mb = st["rss_mb"]
    s.cpu_time = st["time"]
    s.threads = st["threads"]

    tracks, rec, rec_size = lsof_tracks_and_recording(pid)
    s.loaded_tracks = tracks
    if rec:
        s.recording = rec
        s.recording_size = rec_size
        if prev_rec_size is not None and rec_size is not None:
            s.recording_growing = rec_size > prev_rec_size
    else:
        path, size, growing = detect_recording_by_growth(s.recording_prefix, prev_rec_size)
        s.recording, s.recording_size, s.recording_growing = path, size, growing

    s.recording_active = is_recording_active(pid)
    if s.recording_growing is True:
        s.recording_active = True

    if s.recording_active and s.recording_growing is None and s.recording:
        try:
            s.recording_growing = (time.time() - os.path.getmtime(s.recording)) < 5.0
        except OSError:
            pass

    s.recent_recordings = get_recent_recordings(
        limit=3,
        active_path=s.recording,
        active_size=s.recording_size,
        active_growing=s.recording_growing,
        is_active=s.recording_active,
    )
    if not s.recording and s.recent_recordings:
        s.recording = s.recent_recordings[0].path
        s.recording_size = s.recent_recordings[0].size

    return s



def main() -> int:
    ap = argparse.ArgumentParser(
        description="Traktor live monitor (CPU, tracks, recording, audio I/O) + recording control (macOS, Windows, Linux)"
    )
    ap.add_argument("--interval", type=float, default=1.0, help="Refresh seconds (default 1)")
    ap.add_argument("--once", action="store_true", help="Print one snapshot and exit")
    ap.add_argument(
        "--start-recording",
        action="store_true",
        help="Start Traktor Audio Recorder, then exit",
    )
    ap.add_argument(
        "--stop-recording",
        action="store_true",
        help="Stop Traktor Audio Recorder, then exit",
    )
    ap.add_argument(
        "--toggle-recording",
        action="store_true",
        help="Toggle Traktor Audio Recorder, then exit",
    )
    ap.add_argument(
        "--no-launch",
        action="store_true",
        help="Do not automatically launch Traktor if not running",
    )
    ap.add_argument(
        "--list-menus",
        action="store_true",
        help="List Traktor menu bar items (debug macOS) and exit",
    )
    args = ap.parse_args()

    if args.list_menus:
        if IS_MACOS:
            ok, msg = list_traktor_menu_items()
            print(msg)
            return 0 if ok and not msg.startswith("ERROR:") else 1
        else:
            print("Menu listing is only supported on macOS.")
            return 0

    rec_flags = sum(
        bool(x) for x in (args.start_recording, args.stop_recording, args.toggle_recording)
    )
    if rec_flags > 1:
        print("Use only one of --start-recording / --stop-recording / --toggle-recording", file=sys.stderr)
        return 2

    if args.start_recording:
        ok, msg = menu_control_recording("start")
        print(msg)
        return 0 if ok else 1
    if args.stop_recording:
        ok, msg = menu_control_recording("stop")
        print(msg)
        return 0 if ok else 1
    if args.toggle_recording:
        ok, msg = menu_control_recording("toggle")
        print(msg)
        return 0 if ok else 1

    if not args.no_launch:
        ensure_traktor_running()

    prev_size: Optional[int] = None
    last_action = ""

    if args.once:
        s = take_snapshot(prev_size)
        print(render(s))
        return 0

    # Cross-platform live interactive loop
    # 1. Windows: msvcrt non-blocking keys
    if IS_WINDOWS:
        try:
            import msvcrt
            while True:
                s = take_snapshot(prev_size)
                s.last_action = last_action
                if s.recording_size is not None:
                    prev_size = s.recording_size
                clear_screen()
                print(render(s))

                end = time.time() + max(0.3, args.interval)
                while time.time() < end:
                    if msvcrt.kbhit():
                        ch = msvcrt.getch()
                        try:
                            ch_str = ch.decode("utf-8", errors="ignore")
                        except Exception:
                            ch_str = str(ch)
                        if ch_str in ("q", "Q", "\x03"):
                            return 0
                        if ch_str in ("r", "R"):
                            break
                        if ch_str in ("s", "S"):
                            ok, msg = menu_control_recording("start")
                            last_action = ("OK: " if ok else "FAIL: ") + msg
                            break
                        if ch_str in ("x", "X"):
                            ok, msg = menu_control_recording("stop")
                            last_action = ("OK: " if ok else "FAIL: ") + msg
                            break
                        if ch_str in ("t", "T"):
                            ok, msg = menu_control_recording("toggle")
                            last_action = ("OK: " if ok else "FAIL: ") + msg
                            break
                    time.sleep(0.05)
        except KeyboardInterrupt:
            return 0

    # 2. Unix (macOS / Linux): termios & tty
    try:
        import select
        import tty
        import termios

        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        tty.setcbreak(fd)
        raw = True
    except Exception:
        raw = False
        old = None
        fd = None

    try:
        while True:
            s = take_snapshot(prev_size)
            s.last_action = last_action
            if s.recording_size is not None:
                prev_size = s.recording_size
            clear_screen()
            print(render(s))

            end = time.time() + max(0.3, args.interval)
            while time.time() < end:
                if raw and fd is not None:
                    r, _, _ = select.select([sys.stdin], [], [], 0.1)
                    if r:
                        ch = sys.stdin.read(1)
                        if ch in ("q", "Q", "\x03"):
                            return 0
                        if ch in ("r", "R"):
                            break
                        if ch in ("s", "S"):
                            ok, msg = menu_control_recording("start")
                            last_action = ("OK: " if ok else "FAIL: ") + msg
                            break
                        if ch in ("x", "X"):
                            ok, msg = menu_control_recording("stop")
                            last_action = ("OK: " if ok else "FAIL: ") + msg
                            break
                        if ch in ("t", "T"):
                            ok, msg = menu_control_recording("toggle")
                            last_action = ("OK: " if ok else "FAIL: ") + msg
                            break
                else:
                    time.sleep(min(0.2, end - time.time()))
    except KeyboardInterrupt:
        return 0
    finally:
        if raw and old is not None and fd is not None:
            try:
                import termios
                termios.tcsetattr(fd, termios.TCSADRAIN, old)
            except Exception:
                pass
        print("\nTraktor Live Monitor closed.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
