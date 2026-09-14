#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - System MOTD (Message Of The Day) Generator & Manager
Generates a dynamic terminal MOTD showcasing the last 5 mixes created by the manager,
including creation date & time, file size, format, and episode title.
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
    return Path(__file__).resolve().parent

def find_last_5_mixes():
    """Discover the last 5 created/converted mixes across archive directories."""
    base_dir = get_base_dir()
    scan_paths = [
        base_dir / "FLAC_CONVERTED_OUTPUTS",
        Path("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"),
        base_dir / "CONVERTED_WAV_FILES",
        base_dir
    ]
    
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
    return mix_candidates[:5]

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
    
    lines = [
        f"{b}{m}=============================================================================={nc}",
        f"{b}{m}              STREAM OF FREQUENCY - RECENT ARCHIVE RELEASES                   {nc}",
        f"{b}{m}=============================================================================={nc}",
        f"  Host: {w}{hostname}{nc}  |  Generated: {d}{now_str}{nc}",
        f"{b}{bl}──────────────────────────────────────────────────────────────────────────────{nc}",
        f"  {b}{'#':2} | {'Creation Date & Time':<20} | {'Size':>9} | {'Fmt':4} | {'Mix Title / Episode'}{nc}",
        f"  {bl}────────────────────────────────────────────────────────────────────────────{nc}"
    ]
    
    if not mixes:
        lines.append(f"  {d}No archived mix recordings detected.{nc}")
    else:
        for idx, item in enumerate(mixes, start=1):
            dt_str = datetime.datetime.fromtimestamp(item["mtime"]).strftime("%Y-%m-%d %H:%M")
            title = Path(item["filename"]).stem
            if len(title) > 38:
                title = title[:35] + "..."
            size_str = human_size(item["size"])
            fmt_str = item["format"]
            lines.append(f"  {c}{idx:2d}{nc} | {dt_str:<20} | {y}{size_str:>9}{nc} | {g}{fmt_str:4}{nc} | {w}{title}{nc}")
            
    lines.extend([
        f"{b}{bl}──────────────────────────────────────────────────────────────────────────────{nc}",
        f"  {d}Launch Studio Manager:{nc} {b}{g}manager{nc}  or  {b}{g}~/manager.sh{nc}",
        f"{b}{m}=============================================================================={nc}\n"
    ])
    return "\n".join(lines)

def apply_motd():
    mixes = find_last_5_mixes()
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
    mixes = find_last_5_mixes()
    os.system('clear' if os.name == 'posix' else 'cls')
    print(format_motd_text(mixes, ansi=True))
    print(f"{BOLD}MOTD Management Options:{NC}")
    print(f"  ${BOLD}${CYAN} 1)${NC} Apply & Update MOTD Now (~/.config/mix-manager/motd & ~/.bashrc)")
    print(f"  ${BOLD}${CYAN} 2)${NC} Try Writing System /etc/motd (requires sudo)")
    print(f"\n  ${BOLD}${CYAN} 0)${NC} Return to Main Menu ${DIM}(or 'q')${NC}")
    choice = input(f"\n{BOLD}Select option: {NC}").strip()
    if choice == '1':
        out_f = apply_motd()
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
    parser = argparse.ArgumentParser(description="System MOTD Generator with Last 5 Mixes")
    parser.add_argument("--print", action="store_true", help="Print MOTD to stdout")
    parser.add_argument("--apply", action="store_true", help="Generate and apply MOTD")
    args = parser.parse_args()
    
    if args.print:
        mixes = find_last_5_mixes()
        print(format_motd_text(mixes, ansi=True))
    elif args.apply:
        out_f = apply_motd()
        print(f"MOTD updated at {out_f}")
    else:
        interactive_ui()

if __name__ == "__main__":
    main()
