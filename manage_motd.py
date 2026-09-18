#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - System MOTD (Message Of The Day) Generator & Manager
Generates a dynamic terminal MOTD showcasing the last 3 mixes created by the manager,
including creation date & time, file size, format, and full file name.
"""

import os
import sys
import datetime
import subprocess
import argparse
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

AUDIO_EXTS = ['.flac', '.wav', '.mp3', '.m4a', '.aif', '.aiff']

def human_size(bytes_val):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(bytes_val) < 1024.0:
            return f"{bytes_val:3.1f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.1f} PB"

def get_base_dir():
    p = Path(__file__).resolve().parent
    if p.name == "scripts":
        return p.parent
    return p

def find_recent_mixes(limit=3):
    """Discover the last N created/converted mixes across archive directories."""
    base_dir = get_base_dir()
    scan_paths = [
        base_dir / "FLAC_CONVERTED_OUTPUTS",
        Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"),
        base_dir / "CONVERTED_WAV_FILES",
        Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES"),
        base_dir
    ]
    mix_archive_env = os.environ.get("MIX_ARCHIVE_DIR")
    if mix_archive_env:
        p = Path(mix_archive_env)
        scan_paths.insert(0, p / "FLAC_CONVERTED_OUTPUTS")
        scan_paths.insert(2, p / "CONVERTED_WAV_FILES")
    
    seen_bases = set()
    mix_candidates = []
    
    for sdir in scan_paths:
        if not sdir.is_dir():
            continue
        try:
            for entry in os.scandir(str(sdir)):
                if entry.is_file():
                    lower = entry.name.lower()
                    if any(lower.endswith(ext) for ext in AUDIO_EXTS):
                        base = Path(entry.name).stem.lower()
                        if base not in seen_bases:
                            seen_bases.add(base)
                            stat = entry.stat()
                            # Require at least 50MB to qualify as full mix
                            if stat.st_size >= 50 * 1024 * 1024:
                                mix_candidates.append({
                                    "filename": entry.name,
                                    "path": entry.path,
                                    "size": stat.st_size,
                                    "mtime": stat.st_mtime,
                                    "format": Path(entry.name).suffix.lstrip('.').upper()
                                })
        except Exception:
            pass
            
    mix_candidates.sort(key=lambda x: x["mtime"], reverse=True)
    return mix_candidates[:limit]

# Backward compatibility alias
find_last_5_mixes = find_recent_mixes

def format_motd_text(mixes, ansi=True):
    b = BOLD if ansi else ""
    m = MAGENTA if ansi else ""
    c = CYAN if ansi else ""
    g = GREEN if ansi else ""
    y = YELLOW if ansi else ""
    d = DIM if ansi else ""
    bl = BLUE if ansi else ""
    w = WHITE if ansi else ""
    nc = NC if ansi else ""
    
    hostname = os.uname().nodename
    now_str = datetime.datetime.now().strftime("%a %b %d %Y, %H:%M:%S")
    
    col_name = "Full File Name"
    max_name_len = max([len(item["filename"]) for item in mixes] + [len(col_name)]) if mixes else len(col_name)
    banner_width = max(78, 49 + max_name_len)
    
    border_main = "=" * banner_width
    border_div = "─" * banner_width
    border_sub = "  " + "─" * (banner_width - 2)
    title_text = "STREAM OF FREQUENCY - RECENT ARCHIVE RELEASES"
    
    hdr_num = "#"
    hdr_dt = "Creation Date & Time"
    hdr_sz = "Size"
    hdr_fmt = "Fmt"
    
    lines = [
        f"{b}{m}{border_main}{nc}",
        f"{b}{m}{title_text.center(banner_width)}{nc}",
        f"{b}{m}{border_main}{nc}",
        f"  Host: {w}{hostname}{nc}  |  Generated: {d}{now_str}{nc}",
        f"{b}{bl}{border_div}{nc}",
        f"  {b}{hdr_num:2} | {hdr_dt:<20} | {hdr_sz:>9} | {hdr_fmt:4} | {col_name}{nc}",
        f"{bl}{border_sub}{nc}"
    ]
    
    if not mixes:
        lines.append(f"  {d}No archived mix recordings detected.{nc}")
    else:
        for idx, item in enumerate(mixes, start=1):
            dt_str = datetime.datetime.fromtimestamp(item["mtime"]).strftime("%Y-%m-%d %H:%M")
            filename = item["filename"]
            size_str = human_size(item["size"])
            fmt_str = item["format"]
            lines.append(f"  {c}{idx:2d}{nc} | {dt_str:<20} | {y}{size_str:>9}{nc} | {g}{fmt_str:4}{nc} | {w}{filename}{nc}")
            
    lines.extend([
        f"{b}{bl}{border_div}{nc}",
        f"  {d}Launch Studio Manager:{nc} {b}{g}manager{nc}  or  {b}{g}~/manager.sh{nc}",
        f"{b}{m}{border_main}{nc}\n"
    ])
    return "\n".join(lines)

def apply_motd(limit=3):
    mixes = find_recent_mixes(limit=limit)
    motd_ansi = format_motd_text(mixes, ansi=True)
    motd_plain = format_motd_text(mixes, ansi=False)
    
    # 1. User config MOTD
    user_motd_dir = Path.home() / ".config" / "mix-manager"
    user_motd_dir.mkdir(parents=True, exist_ok=True)
    user_motd_file = user_motd_dir / "motd"
    with open(user_motd_file, "w", encoding="utf-8") as f:
        f.write(motd_ansi)
        
    # 2. Add / update hook in ~/.bashrc.d or ~/.bashrc if desired
    bashrc = Path.home() / ".bashrc"
    hook_tag = "# >>> Mix Archive Manager Dynamic MOTD >>>"
    hook_end = "# <<< Mix Archive Manager Dynamic MOTD <<<"
    hook_code = f"""{hook_tag}
if [ -f "$HOME/.config/mix-manager/motd" ] && [ -t 1 ]; then
    cat "$HOME/.config/mix-manager/motd"
fi
{hook_end}"""
    
    if bashrc.is_file():
        try:
            with open(bashrc, "r", encoding="utf-8") as f:
                content = f.read()
            if hook_tag not in content:
                with open(bashrc, "a", encoding="utf-8") as f:
                    f.write(f"\n{hook_code}\n")
        except Exception:
            pass
            
    # 3. Attempt /etc/motd write if writable
    etc_motd = Path("/etc/motd")
    try:
        if os.access(etc_motd, os.W_OK):
            with open(etc_motd, "w", encoding="utf-8") as f:
                f.write(motd_plain)
    except Exception:
        pass
        
    return user_motd_file

def interactive_ui():
    mixes = find_recent_mixes(limit=3)
    os.system('clear' if os.name == 'posix' else 'cls')
    print(format_motd_text(mixes, ansi=True))
    print(f"{BOLD}MOTD Management Options:{NC}")
    print(f"  {BOLD}{CYAN} 1){NC} Apply & Update MOTD Now (~/.config/mix-manager/motd & ~/.bashrc)")
    print(f"  {BOLD}{CYAN} 2){NC} Try Writing System /etc/motd (requires sudo)")
    print(f"\n  {BOLD}{CYAN} 0){NC} Return to Main Menu {DIM}(or 'q'){NC}")
    choice = input(f"\n{BOLD}Select option: {NC}").strip()
    if choice == '1':
        out_f = apply_motd(limit=3)
        print(f"\n{GREEN}✓ MOTD successfully updated at {out_f}!{NC}")
        print(f"{CYAN}✓ Automatically enabled in interactive terminal logins (~/.bashrc).{NC}")
        input("Press Enter to continue...")
    elif choice == '2':
        motd_plain = format_motd_text(mixes, ansi=False)
        tmp_motd = "/tmp/mix_motd_plain.txt"
        with open(tmp_motd, "w") as f:
            f.write(motd_plain)
        cmd = ["sudo", "cp", tmp_motd, "/etc/motd"]
        res = subprocess.run(cmd)
        if res.returncode == 0:
            print(f"\n{GREEN}✓ System /etc/motd updated successfully!{NC}")
        else:
            print(f"\n{YELLOW}Could not update /etc/motd (insufficient permissions).{NC}")
        input("Press Enter to continue...")

def main():
    parser = argparse.ArgumentParser(description="System MOTD Generator with Recent Mixes")
    parser.add_argument("--print", action="store_true", help="Print MOTD to stdout")
    parser.add_argument("--apply", action="store_true", help="Generate and apply MOTD")
    parser.add_argument("--limit", type=int, default=3, help="Number of mixes to display (default: 3)")
    args = parser.parse_args()
    
    if args.print:
        mixes = find_recent_mixes(limit=args.limit)
        print(format_motd_text(mixes, ansi=True))
    elif args.apply:
        out_f = apply_motd(limit=args.limit)
        print(f"MOTD updated at {out_f}")
    else:
        interactive_ui()

if __name__ == "__main__":
    main()
