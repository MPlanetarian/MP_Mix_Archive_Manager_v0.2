#!/usr/bin/env python3
"""
scripts/inspect_playing_audio.py - Advanced Audio Specification & Stream Inspector
Inspects the currently playing audio file (or specified mix) and displays deep technical
audio specifications: Format, Bit Depth, Sample Rate, Codec, Duration, File Size, File Path,
Title, Artist, Compression Ratio, Active Interface, Latency, and Associated Assets.
"""

import sys
import os
import re
import json
import time
import shutil
import platform
import subprocess
from datetime import datetime

# ANSI Color codes
BOLD = '\033[1m'
CYAN = '\033[0;36m'
GREEN = '\033[0;32m'
YELLOW = '\033[0;33m'
MAGENTA = '\033[0;35m'
BLUE = '\033[0;34m'
RED = '\033[0;31m'
WHITE = '\033[1;37m'
DIM = '\033[2m'
NC = '\033[0m'

SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_config():
    cfg = {}
    cfg_file = os.path.join(SCRIPT_DIR, "config.env")
    if not os.path.isfile(cfg_file):
        cfg_file = os.path.expanduser("~/.config/mix-manager/config.env")
    if os.path.isfile(cfg_file):
        try:
            with open(cfg_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        cfg[k.strip()] = v.strip().strip('"').strip("'")
        except Exception:
            pass
    return cfg

def format_seconds(seconds):
    try:
        sec = float(seconds)
        hrs = int(sec // 3600)
        mins = int((sec % 3600) // 60)
        secs = int(sec % 60)
        ms = int((sec - int(sec)) * 100)
        if hrs > 0:
            return f"{hrs:02d}:{mins:02d}:{secs:02d}.{ms:02d}"
        return f"{mins:02d}:{secs:02d}.{ms:02d}"
    except Exception:
        return str(seconds)

def format_bytes(num_bytes):
    try:
        b = float(num_bytes)
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if abs(b) < 1024.0:
                return f"{b:3.2f} {unit}"
            b /= 1024.0
        return f"{b:.2f} PB"
    except Exception:
        return f"{num_bytes} bytes"

def detect_playing_audio_file():
    # 1. Check cliamp track status file or proc
    cliamp_path = "/tmp/cliamp_current_track.txt"
    if os.path.isfile(cliamp_path):
        try:
            with open(cliamp_path, "r", encoding="utf-8", errors="ignore") as f:
                lines = [l.strip() for l in f if l.strip()]
            for l in lines:
                if l.startswith("FILE:") or l.startswith("PATH:"):
                    p = l.split(":", 1)[1].strip()
                    if os.path.isfile(p):
                        return p, "cliamp"
                elif os.path.isfile(l):
                    return l, "cliamp"
        except Exception:
            pass

    # 2. Check playerctl (MPRIS)
    if shutil.which("playerctl"):
        try:
            p = subprocess.run(["playerctl", "metadata", "xesam:url"], capture_output=True, text=True, timeout=0.4)
            if p.returncode == 0 and p.stdout.strip():
                url = p.stdout.strip().splitlines()[0]
                if url.startswith("file://"):
                    import urllib.parse
                    fpath = urllib.parse.unquote(url[7:])
                    if os.path.isfile(fpath):
                        # Get player name
                        p_name = "MPRIS Player"
                        pn = subprocess.run(["playerctl", "status"], capture_output=True, text=True, timeout=0.3)
                        return fpath, p_name
        except Exception:
            pass

    # 3. Check open file descriptors of running audio players in /proc
    try:
        target_procs = ["cliamp", "strawberry", "vlc", "mpv", "audacity"]
        for tp in target_procs:
            pid_cmd = ["pgrep", "-f", tp]
            pids_res = subprocess.run(pid_cmd, capture_output=True, text=True, timeout=0.3)
            for pid in pids_res.stdout.split():
                fd_dir = f"/proc/{pid}/fd"
                if os.path.isdir(fd_dir):
                    try:
                        for fd in os.listdir(fd_dir):
                            full_fd = os.path.join(fd_dir, fd)
                            if os.path.islink(full_fd):
                                tgt = os.readlink(full_fd)
                                if tgt.lower().endswith(('.flac', '.wav', '.mp3', '.m4a', '.ogg', '.aac', '.alac')):
                                    if os.path.isfile(tgt):
                                        return tgt, tp
                    except Exception:
                        pass
    except Exception:
        pass

    return None, None

def get_live_player_stats():
    stats = {
        "status": "STOPPED",
        "position_sec": 0,
        "duration_sec": 0,
        "position_str": "00:00",
        "duration_str": "00:00",
        "progress_pct": 0.0,
        "player": "None"
    }

    # 1. Check cliamp status
    st_file = "/tmp/cliamp_status.txt"
    if os.path.isfile(st_file):
        try:
            with open(st_file, "r", encoding="utf-8", errors="ignore") as f:
                c = f.read()
            m_pos = re.search(r'POSITION:\s*(\d+(?:\.\d+)?)', c)
            m_dur = re.search(r'DURATION:\s*(\d+(?:\.\d+)?)', c)
            m_st = re.search(r'STATUS:\s*(\w+)', c)
            if m_pos: stats["position_sec"] = float(m_pos.group(1))
            if m_dur: stats["duration_sec"] = float(m_dur.group(1))
            if m_st: stats["status"] = m_st.group(1).upper()
            if stats["duration_sec"] > 0:
                stats["progress_pct"] = (stats["position_sec"] / stats["duration_sec"]) * 100.0
                stats["position_str"] = format_seconds(stats["position_sec"]).split('.')[0]
                stats["duration_str"] = format_seconds(stats["duration_sec"]).split('.')[0]
            stats["player"] = "cliamp"
            return stats
        except Exception:
            pass

    # 2. Check playerctl
    if shutil.which("playerctl"):
        try:
            st = subprocess.run(["playerctl", "status"], capture_output=True, text=True, timeout=0.3)
            if st.returncode == 0:
                stats["status"] = st.stdout.strip().upper()
                pos = subprocess.run(["playerctl", "position"], capture_output=True, text=True, timeout=0.3)
                if pos.returncode == 0:
                    stats["position_sec"] = float(pos.stdout.strip())
                stats["player"] = "MPRIS"
        except Exception:
            pass

    return stats

def probe_audio_file(file_path):
    spec = {
        "file_path": file_path,
        "file_name": os.path.basename(file_path),
        "file_size": 0,
        "file_size_fmt": "0 B",
        "file_size_mb": 0.0,
        "extension": "",
        "format_name": "",
        "format_long_name": "",
        "codec_name": "",
        "codec_long_name": "",
        "bit_depth": "Unknown",
        "sample_format": "",
        "sample_rate": 0,
        "sample_rate_str": "",
        "channels": 0,
        "channel_layout": "",
        "bitrate_bps": 0,
        "bitrate_kbps": 0.0,
        "duration_sec": 0.0,
        "duration_fmt": "00:00:00",
        "total_samples": 0,
        "title": "",
        "artist": "",
        "album": "",
        "genre": "",
        "date": "",
        "encoder": "",
        "compression_ratio": None,
        "compression_savings": None,
        "embedded_art": False,
        "embedded_art_info": "",
        "mtime_str": "",
        "drive_info": "",
        "drive_free": ""
    }

    if not os.path.isfile(file_path):
        return spec

    # File attributes
    st = os.stat(file_path)
    spec["file_size"] = st.st_size
    spec["file_size_fmt"] = format_bytes(st.st_size)
    spec["file_size_mb"] = round(st.st_size / (1024 * 1024), 2)
    spec["mtime_str"] = datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")

    stem, ext = os.path.splitext(spec["file_name"])
    spec["extension"] = ext.lstrip(".").upper()

    # Disk / mount info
    try:
        p = subprocess.run(["df", "-h", file_path], capture_output=True, text=True, timeout=0.4)
        if p.returncode == 0:
            lines = p.stdout.strip().splitlines()
            if len(lines) >= 2:
                parts = lines[1].split()
                if len(parts) >= 6:
                    spec["drive_info"] = f"{parts[0]} mounted on {parts[5]}"
                    spec["drive_free"] = f"{parts[3]} free ({parts[4]} used)"
    except Exception:
        pass

    # ffprobe probe
    if shutil.which("ffprobe"):
        try:
            cmd = ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", file_path]
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=3.0)
            if p.returncode == 0 and p.stdout:
                data = json.loads(p.stdout)
                fmt = data.get("format", {})
                streams = data.get("streams", [])

                spec["format_name"] = fmt.get("format_name", "").upper()
                spec["format_long_name"] = fmt.get("format_long_name", "")
                
                try:
                    spec["duration_sec"] = float(fmt.get("duration", 0))
                    spec["duration_fmt"] = format_seconds(spec["duration_sec"])
                except Exception:
                    pass

                try:
                    spec["bitrate_bps"] = int(fmt.get("bit_rate", 0))
                    spec["bitrate_kbps"] = round(spec["bitrate_bps"] / 1000.0, 1)
                except Exception:
                    pass

                tags = fmt.get("tags", {})
                spec["title"] = tags.get("title", tags.get("TITLE", ""))
                spec["artist"] = tags.get("artist", tags.get("ARTIST", ""))
                spec["album"] = tags.get("album", tags.get("ALBUM", ""))
                spec["genre"] = tags.get("genre", tags.get("GENRE", ""))
                spec["date"] = tags.get("date", tags.get("DATE", ""))
                spec["encoder"] = tags.get("encoder", tags.get("ENCODER", ""))

                # Search audio stream
                for s in streams:
                    ctype = s.get("codec_type")
                    if ctype == "audio":
                        spec["codec_name"] = s.get("codec_name", "")
                        spec["codec_long_name"] = s.get("codec_long_name", "")
                        spec["sample_format"] = s.get("sample_fmt", "")
                        
                        try:
                            spec["sample_rate"] = int(s.get("sample_rate", 0))
                            if spec["sample_rate"] > 0:
                                khz = spec["sample_rate"] / 1000.0
                                spec["sample_rate_str"] = f"{spec['sample_rate']:,} Hz ({khz:.1f} kHz)"
                        except Exception:
                            pass

                        try:
                            spec["channels"] = int(s.get("channels", 0))
                            spec["channel_layout"] = s.get("channel_layout", "stereo" if spec["channels"] == 2 else "mono")
                        except Exception:
                            pass

                        # Determine bit depth
                        raw_bits = s.get("bits_per_raw_sample")
                        bps = s.get("bits_per_sample")
                        if raw_bits and str(raw_bits) != "0":
                            spec["bit_depth"] = f"{raw_bits}-Bit"
                        elif bps and str(bps) != "0":
                            spec["bit_depth"] = f"{bps}-Bit"
                        elif "s32" in spec["sample_format"] or "32" in spec["codec_name"]:
                            spec["bit_depth"] = "32-Bit"
                        elif "s24" in spec["sample_format"] or "24" in spec["codec_name"]:
                            spec["bit_depth"] = "24-Bit"
                        elif "s16" in spec["sample_format"] or "16" in spec["codec_name"]:
                            spec["bit_depth"] = "16-Bit"
                        elif "flt" in spec["sample_format"]:
                            spec["bit_depth"] = "32-Bit Float"

                        if spec["duration_sec"] > 0 and spec["sample_rate"] > 0:
                            spec["total_samples"] = int(spec["duration_sec"] * spec["sample_rate"])

                    elif ctype == "video" and s.get("disposition", {}).get("attached_pic"):
                        spec["embedded_art"] = True
                        spec["embedded_art_info"] = f"{s.get('codec_name', '').upper()} {s.get('width')}x{s.get('height')}"

        except Exception:
            pass

    # Fallback to Python wave module for uncompressed WAV if needed
    if spec["extension"] == "WAV" and spec["sample_rate"] == 0:
        try:
            import wave
            with wave.open(file_path, "rb") as wf:
                spec["channels"] = wf.getnchannels()
                spec["sample_rate"] = wf.getframerate()
                spec["sample_rate_str"] = f"{spec['sample_rate']:,} Hz ({spec['sample_rate']/1000:.1f} kHz)"
                sampwidth = wf.getsampwidth()
                spec["bit_depth"] = f"{sampwidth * 8}-Bit"
                spec["codec_name"] = f"pcm_s{sampwidth*8}le"
                spec["codec_long_name"] = f"PCM signed {sampwidth*8}-bit little-endian"
                nframes = wf.getnframes()
                if spec["sample_rate"] > 0:
                    spec["duration_sec"] = nframes / float(spec["sample_rate"])
                    spec["duration_fmt"] = format_seconds(spec["duration_sec"])
                    spec["bitrate_bps"] = spec["sample_rate"] * spec["channels"] * sampwidth * 8
                    spec["bitrate_kbps"] = round(spec["bitrate_bps"] / 1000.0, 1)
        except Exception:
            pass

    # Title fallback: derive clean title from filename if tag missing
    if not spec["title"]:
        clean_title = stem.replace("_", " ").replace("-", " ")
        clean_title = re.sub(r"\s+", " ", clean_title).strip()
        spec["title"] = clean_title

    # Compression calculation for FLAC / ALAC
    if spec["extension"] in ["FLAC", "ALAC", "M4A"] and spec["duration_sec"] > 0 and spec["sample_rate"] > 0:
        bit_val = 16
        if "24" in spec["bit_depth"]: bit_val = 24
        elif "32" in spec["bit_depth"]: bit_val = 32
        ch_val = spec["channels"] if spec["channels"] > 0 else 2
        raw_pcm_bytes = spec["duration_sec"] * spec["sample_rate"] * ch_val * (bit_val / 8.0)
        if raw_pcm_bytes > 0 and spec["file_size"] > 0:
            ratio = (spec["file_size"] / raw_pcm_bytes) * 100.0
            savings_bytes = raw_pcm_bytes - spec["file_size"]
            spec["compression_ratio"] = f"{ratio:.1f}% of uncompressed raw PCM"
            spec["compression_savings"] = f"{format_bytes(savings_bytes)} saved ({100.0 - ratio:.1f}% reduction)"

    return spec

def find_associated_assets(file_path):
    assets = {
        "tracklist": None,
        "tracklist_tracks": 0,
        "cover": None,
        "spectrogram": None,
        "video": None
    }
    if not file_path:
        return assets

    stem, _ = os.path.splitext(file_path)
    parent = os.path.dirname(file_path)

    # 1. Matching Tracklist (.txt)
    tl_candidates = [
        f"{stem}.txt",
        os.path.join(parent, f"{os.path.basename(stem)}.txt"),
        os.path.join(SCRIPT_DIR, "FLAC_CONVERTED_OUTPUTS", f"{os.path.basename(stem)}.txt")
    ]
    for c in tl_candidates:
        if os.path.isfile(c):
            assets["tracklist"] = c
            try:
                with open(c, "r", encoding="utf-8", errors="ignore") as f:
                    cnt = sum(1 for line in f if re.match(r'^\s*\d{1,3}[\.\:\-]', line))
                assets["tracklist_tracks"] = cnt
            except Exception:
                pass
            break

    # 2. Matching Cover (.png, .jpg)
    cov_candidates = [
        f"{stem}.png", f"{stem}.jpg", f"{stem}.jpeg",
        os.path.join(parent, "Cover.png"), os.path.join(parent, "cover.jpg"),
        os.path.join(SCRIPT_DIR, "assets", "Cover.png")
    ]
    for c in cov_candidates:
        if os.path.isfile(c):
            assets["cover"] = c
            break

    # 3. Matching Spectrogram
    spek_candidates = [
        f"{stem}_spek.png", f"{stem}.spek.png",
        os.path.join(SCRIPT_DIR, "SPEK_OUTPUTS", f"{os.path.basename(stem)}.png"),
        os.path.join(parent, f"{os.path.basename(stem)}_spek.png")
    ]
    for c in spek_candidates:
        if os.path.isfile(c):
            assets["spectrogram"] = c
            break

    # 4. Matching Video (.mp4, .mkv)
    vid_candidates = [
        f"{stem}.mp4", f"{stem}.mkv",
        os.path.join(SCRIPT_DIR, f"{os.path.basename(stem)}.mp4"),
        os.path.join("/run/media/mplanetarian/DATA/NFT_VIDEOS", f"{os.path.basename(stem)}.mp4")
    ]
    for c in vid_candidates:
        if os.path.isfile(c):
            assets["video"] = c
            break

    return assets

def get_audio_interface_details():
    ai_script = os.path.join(SCRIPT_DIR, "scripts", "get_audio_interface.py")
    if os.path.isfile(ai_script):
        try:
            p = subprocess.run([sys.executable, ai_script, "--json"], capture_output=True, text=True, timeout=0.5)
            if p.returncode == 0:
                return json.loads(p.stdout)
        except Exception:
            pass
    return {
        "interface": "Default Audio Output",
        "latency_str": "N/A",
        "sound_system": "PipeWire"
    }

def render_specification_screen(spec, assets, audio_hw, live_stats):
    os.system('clear' if os.name != 'nt' else 'cls')

    print(f"{BOLD}{MAGENTA}==================================================================================={NC}")
    print(f"{BOLD}{MAGENTA}            🎧 ADVANCED AUDIO FILE SPECIFICATION & STREAM INSPECTOR 🎧             {NC}")
    print(f"{BOLD}{MAGENTA}==================================================================================={NC}\n")

    # 1. Identity & Metadata
    title_disp = spec["title"] or spec["file_name"]
    print(f"  {BOLD}{WHITE}Mix Title:{NC}         {BOLD}{CYAN}{title_disp}{NC}")
    if spec["artist"]:
        print(f"  {BOLD}{WHITE}Artist / DJ:{NC}       {WHITE}{spec['artist']}{NC}")
    if spec["album"]:
        print(f"  {BOLD}{WHITE}Album / Series:{NC}    {WHITE}{spec['album']}{NC}")
    if spec["genre"]:
        print(f"  {BOLD}{WHITE}Genre & Date:{NC}      {WHITE}{spec['genre']}{NC}  {DIM}({spec['date'] or 'N/A'}){NC}")

    print(f"\n  {BOLD}{BLUE}─── [ ENCODED AUDIO SPECIFICATIONS ] ───────────────────────────────────────────{NC}")
    
    # 2. Audio Format & Codec Specs
    fmt_badge = f"{GREEN}{spec['extension']}{NC}"
    print(f"  • {BOLD}Container Format:{NC}  {fmt_badge}  {DIM}({spec['format_long_name'] or spec['format_name']}){NC}")
    print(f"  • {BOLD}Audio Codec:{NC}       {BOLD}{WHITE}{spec['codec_name']}{NC}  {DIM}[{spec['codec_long_name']}]{NC}")
    print(f"  • {BOLD}Bit Depth / Res:{NC}   {BOLD}{GREEN}{spec['bit_depth']}{NC}  {DIM}(Sample Format: {spec['sample_format'] or 'pcm'}){NC}")
    print(f"  • {BOLD}Sampling Rate:{NC}     {BOLD}{CYAN}{spec['sample_rate_str'] or str(spec['sample_rate']) + ' Hz'}{NC}")
    ch_str = "Stereo (2 Channels)" if spec['channels'] == 2 else f"{spec['channels']} Channels"
    print(f"  • {BOLD}Channels & Layout:{NC} {WHITE}{ch_str}{NC}  {DIM}[{spec['channel_layout']}]{NC}")
    
    br_str = f"{spec['bitrate_kbps']:,.0f} kbps" if spec['bitrate_kbps'] > 0 else "Uncompressed PCM"
    print(f"  • {BOLD}Stream Bitrate:{NC}    {BOLD}{YELLOW}{br_str}{NC}")
    print(f"  • {BOLD}Exact Duration:{NC}    {BOLD}{WHITE}{spec['duration_fmt']}{NC}  {DIM}({spec['duration_sec']:,.2f}s • {spec['total_samples']:,} samples){NC}")

    if spec["compression_ratio"]:
        print(f"  • {BOLD}Lossless Ratio:{NC}    {GREEN}{spec['compression_ratio']}{NC}  {DIM}({spec['compression_savings']}){NC}")

    print(f"\n  {BOLD}{BLUE}─── [ STORAGE, DRIVE & FILESYSTEM ] ────────────────────────────────────────────{NC}")
    print(f"  • {BOLD}File Size:{NC}         {BOLD}{GREEN}{spec['file_size_fmt']}{NC}  {DIM}({spec['file_size']:,} bytes • {spec['file_size_mb']:,} MB){NC}")
    print(f"  • {BOLD}File Name:{NC}         {WHITE}{spec['file_name']}{NC}")
    print(f"  • {BOLD}Full File Path:{NC}    {DIM}{spec['file_path']}{NC}")
    if spec["drive_info"]:
        print(f"  • {BOLD}Storage Volume:{NC}    {WHITE}{spec['drive_info']}{NC}  {DIM}({spec['drive_free']}){NC}")
    print(f"  • {BOLD}Last Modified:{NC}     {WHITE}{spec['mtime_str']}{NC}")

    print(f"\n  {BOLD}{BLUE}─── [ LIVE HARDWARE INTERFACE & STREAM LATENCY ] ───────────────────────────────{NC}")
    print(f"  • {BOLD}Audio Interface:{NC}   {BOLD}{CYAN}{audio_hw.get('interface', 'Default Audio Output')}{NC}")
    print(f"  • {BOLD}Buffer Latency:{NC}    {BOLD}{YELLOW}{audio_hw.get('latency_str', 'N/A')}{NC}  {DIM}(System: {audio_hw.get('sound_system', 'Audio')}){NC}")
    
    # Live playback progress
    if live_stats.get("status") in ["PLAYING", "PAUSED"]:
        p_badge = f"{GREEN}▶ PLAYING{NC}" if live_stats["status"] == "PLAYING" else f"{YELLOW}⏸ PAUSED{NC}"
        pct = live_stats["progress_pct"]
        bar_len = 30
        filled = int(bar_len * (pct / 100.0))
        prog_bar = f"{GREEN}{'━' * filled}{NC}{DIM}{'━' * (bar_len - filled)}{NC}"
        print(f"  • {BOLD}Playback State:{NC}    {p_badge} via {BOLD}{live_stats.get('player', 'cliamp')}{NC}")
        print(f"  • {BOLD}Track Progress:{NC}    [{prog_bar}] {BOLD}{pct:.1f}%{NC}  {DIM}({live_stats.get('position_str', '00:00')} / {spec['duration_fmt']}){NC}")

    print(f"\n  {BOLD}{BLUE}─── [ COMPANION ASSETS & ARTWORK ] ─────────────────────────────────────────────{NC}")
    if spec["embedded_art"]:
        print(f"  • {BOLD}Embedded Artwork:{NC}  {GREEN}YES{NC} {DIM}({spec['embedded_art_info']}){NC}")
    else:
        print(f"  • {BOLD}Embedded Artwork:{NC}  {DIM}None{NC}")

    if assets["tracklist"]:
        print(f"  • {BOLD}Tracklist File:{NC}    {GREEN}Found{NC} ({assets['tracklist_tracks']} timestamped tracks)  {DIM}{os.path.basename(assets['tracklist'])}{NC}")
    else:
        print(f"  • {BOLD}Tracklist File:{NC}    {YELLOW}Missing / None found{NC}")

    if assets["spectrogram"]:
        print(f"  • {BOLD}Spectrogram PNG:{NC}   {GREEN}Available{NC}  {DIM}{os.path.basename(assets['spectrogram'])}{NC}")

    if assets["video"]:
        print(f"  • {BOLD}Companion Video:{NC}   {GREEN}Available{NC}  {DIM}{os.path.basename(assets['video'])}{NC}")

    print(f"\n{BOLD}{MAGENTA}-----------------------------------------------------------------------------------{NC}")
    print(f"{BOLD}Quick Actions:{NC}")
    print(f"  {BOLD}{CYAN}[T]{NC} Open Tracklist Console   {BOLD}{CYAN}[C]{NC} Open Cover Art Viewer   {BOLD}{CYAN}[S]{NC} View Spectrogram (Spek)")
    print(f"  {BOLD}{CYAN}[Y]{NC} Copy Path to Clipboard   {BOLD}{CYAN}[D]{NC} Open Mix in DAW         {BOLD}{CYAN}[F]{NC} Reveal in Dolphin / Finder")
    print(f"  {BOLD}{CYAN}[R]{NC} Refresh Playback Stats   {BOLD}{CYAN}[Q]{NC} Return to Main Menu")
    print(f"{BOLD}{MAGENTA}-----------------------------------------------------------------------------------{NC}")

def interactive_loop(file_path):
    spec = probe_audio_file(file_path)
    assets = find_associated_assets(file_path)

    while True:
        audio_hw = get_audio_interface_details()
        live_stats = get_live_player_stats()
        render_specification_screen(spec, assets, audio_hw, live_stats)

        sys.stdout.write(f"\n{BOLD}Enter action [T/C/S/Y/D/F/R or Q to exit]: {NC}")
        sys.stdout.flush()

        try:
            choice = input().strip().lower()
        except (EOFError, KeyboardInterrupt):
            break

        if choice in ['q', '0', 'exit']:
            break
        elif choice == 'r':
            continue
        elif choice == 't':
            if assets["tracklist"]:
                v_script = os.path.join(SCRIPT_DIR, "scripts", "view_tracklist_console.sh")
                if os.path.isfile(v_script):
                    subprocess.run(["bash", v_script, assets["tracklist"]])
                else:
                    subprocess.run(["less", assets["tracklist"]])
            else:
                print(f"\n{YELLOW}No tracklist file available to display.{NC}")
                time.sleep(1)
        elif choice == 'c':
            if assets["cover"]:
                subprocess.Popen(["xdg-open", assets["cover"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                print(f"\n{YELLOW}No cover art file found.{NC}")
                time.sleep(1)
        elif choice == 's':
            if assets["spectrogram"]:
                subprocess.Popen(["xdg-open", assets["spectrogram"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                spek_sh = os.path.join(SCRIPT_DIR, "scripts", "generate_spek.sh")
                if os.path.isfile(spek_sh):
                    subprocess.run(["bash", spek_sh, file_path])
                else:
                    print(f"\n{YELLOW}Spectrogram not generated yet.{NC}")
                    time.sleep(1)
        elif choice == 'y':
            # Copy to clipboard
            copied = False
            if shutil.which("wl-copy"):
                subprocess.run(["wl-copy", file_path], check=False)
                copied = True
            elif shutil.which("xclip"):
                subprocess.run(["xclip", "-selection", "clipboard"], input=file_path.encode(), check=False)
                copied = True
            elif shutil.which("pbcopy"):
                subprocess.run(["pbcopy"], input=file_path.encode(), check=False)
                copied = True
            if copied:
                print(f"\n{GREEN}✓ Copied file path to clipboard!{NC}")
            else:
                print(f"\n{YELLOW}Clipboard utility not found.{NC}")
            time.sleep(1)
        elif choice == 'd':
            # Open in DAW
            cfg = load_config()
            daw = cfg.get("DEFAULT_DAW", "reaper")
            if shutil.which(daw):
                subprocess.Popen([daw, file_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print(f"\n{GREEN}✓ Launched {daw} with mix audio file!{NC}")
            elif shutil.which("audacity"):
                subprocess.Popen(["audacity", file_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print(f"\n{GREEN}✓ Launched Audacity with mix audio file!{NC}")
            else:
                print(f"\n{YELLOW}No DAW installed.{NC}")
            time.sleep(1)
        elif choice == 'f':
            parent_dir = os.path.dirname(file_path)
            subprocess.Popen(["xdg-open", parent_dir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"\n{GREEN}✓ Opened folder: {parent_dir}{NC}")
            time.sleep(1)

def main():
    target_file = None

    for arg in sys.argv[1:]:
        if not arg.startswith("--") and os.path.isfile(arg):
            target_file = arg
            break

    if not target_file:
        target_file, _ = detect_playing_audio_file()

    # One-line summary mode
    if "--summary" in sys.argv:
        if not target_file or not os.path.isfile(target_file):
            print("No audio file currently playing")
            sys.exit(1)
        spec = probe_audio_file(target_file)
        ch = "Stereo" if spec['channels'] == 2 else f"{spec['channels']}ch"
        br = f"{spec['bitrate_kbps']:.0f} kbps" if spec['bitrate_kbps'] > 0 else ""
        summary_parts = [spec['extension'], spec['bit_depth'], spec['sample_rate_str'].split('(')[-1].rstrip(')'), ch, br, spec['duration_fmt'], spec['file_size_fmt']]
        summary_str = " • ".join([p for p in summary_parts if p])
        print(summary_str)
        return

    # JSON export mode
    if "--json" in sys.argv:
        if not target_file or not os.path.isfile(target_file):
            print(json.dumps({"error": "No audio file playing or found"}))
            sys.exit(1)
        spec = probe_audio_file(target_file)
        assets = find_associated_assets(target_file)
        audio_hw = get_audio_interface_details()
        live = get_live_player_stats()
        out = {
            "spec": spec,
            "assets": assets,
            "audio_hardware": audio_hw,
            "playback": live
        }
        print(json.dumps(out, indent=2))
        return

    # Path mode
    if "--path" in sys.argv:
        if target_file:
            print(target_file)
        return

    # If no audio is currently playing, prompt user or show search/selection
    if not target_file or not os.path.isfile(target_file):
        os.system('clear' if os.name != 'nt' else 'cls')
        print(f"{BOLD}{MAGENTA}==================================================================================={NC}")
        print(f"{BOLD}{MAGENTA}            🎧 ADVANCED AUDIO FILE SPECIFICATION & STREAM INSPECTOR 🎧             {NC}")
        print(f"{BOLD}{MAGENTA}==================================================================================={NC}\n")
        print(f"  {YELLOW}Notice: No active audio stream or playing mix was automatically detected.{NC}\n")
        print(f"  {BOLD}Options:{NC}")
        print(f"  {BOLD}{CYAN}1){NC} Select from recently converted FLAC mixes")
        print(f"  {BOLD}{CYAN}2){NC} Select from unconverted / archive WAV mixes")
        print(f"  {BOLD}{CYAN}3){NC} Enter custom audio file path manually")
        print(f"  {BOLD}{CYAN}0){NC} Return to main menu\n")
        
        try:
            c = input(f"{BOLD}Enter choice [0-3]: {NC}").strip()
        except Exception:
            return

        cfg = load_config()
        if c == '1':
            flac_dir = os.path.join(SCRIPT_DIR, "FLAC_CONVERTED_OUTPUTS")
            if not os.path.isdir(flac_dir):
                flac_dir = os.path.join(cfg.get("MIX_ARCHIVE_DIR", ""), "FLAC_CONVERTED_OUTPUTS")
            files = [os.path.join(flac_dir, f) for f in os.listdir(flac_dir) if f.lower().endswith(".flac")] if os.path.isdir(flac_dir) else []
            files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
            if files:
                target_file = files[0]
            else:
                print(f"{RED}No FLAC mixes found in archive.{NC}")
                time.sleep(1.2)
                return
        elif c == '2':
            wav_dir = os.path.join(cfg.get("MIX_ARCHIVE_DIR", ""), "CONVERTED_WAV_FILES")
            files = [os.path.join(wav_dir, f) for f in os.listdir(wav_dir) if f.lower().endswith((".wav", ".flac"))] if os.path.isdir(wav_dir) else []
            files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
            if files:
                target_file = files[0]
            else:
                print(f"{RED}No WAV mixes found in archive.{NC}")
                time.sleep(1.2)
                return
        elif c == '3':
            p = input(f"\n{BOLD}Enter audio file path: {NC}").strip().strip('"').strip("'")
            if os.path.isfile(p):
                target_file = p
            else:
                print(f"{RED}File not found: {p}{NC}")
                time.sleep(1.2)
                return
        else:
            return

    interactive_loop(target_file)

if __name__ == "__main__":
    main()
