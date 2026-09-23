#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - Custom Playlists Creator & Multi-Player Launcher
Allows users to:
  - Create and edit custom playlists (.m3u, .m3u8, .xspf) from mixes in the archive
  - Search, filter, and add audio mixes by title, episode number, or date
  - Re-order or remove tracks within playlists
  - Launch any installed audio player (cliamp, Strawberry, VLC, MPV, foobar2000, Kodi)
    directly loaded with the custom playlist!
"""

import os
import sys
import subprocess
import shutil
import re
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

AUDIO_EXTS = ['.flac', '.wav', '.mp3', '.m4a', '.aif', '.ogg']

def get_base_dir():
    return Path(__file__).resolve().parent

def get_playlists_dir():
    p_dir = get_base_dir() / "playlists"
    p_dir.mkdir(parents=True, exist_ok=True)
    return p_dir

def list_archive_mixes():
    base_dir = get_base_dir()
    env_dir = os.environ.get("MIX_ARCHIVE_DIR")
    arch_dir = Path(env_dir) if env_dir and Path(env_dir).is_dir() else (base_dir / "MIX_ARCHIVE")
    scan_paths = [
        arch_dir / "FLAC_CONVERTED_OUTPUTS",
        arch_dir,
        base_dir / "MIX_ARCHIVE" / "FLAC_CONVERTED_OUTPUTS",
        base_dir / "FLAC_CONVERTED_OUTPUTS",
        base_dir / "CONVERTED_WAV_FILES",
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
                    if any(lower.endswith(ext) for ext in AUDIO_EXTS):
                        if entry.name not in seen and entry.stat().st_size >= 20 * 1024 * 1024:
                            seen.add(entry.name)
                            mixes.append({
                                "filename": entry.name,
                                "path": entry.path,
                                "size": entry.stat().st_size
                            })
        except Exception:
            pass
    mixes.sort(key=lambda x: x["filename"].lower())
    return mixes

def list_playlists():
    p_dir = get_playlists_dir()
    playlists = []
    for f in sorted(p_dir.iterdir()):
        if f.is_file() and f.suffix.lower() in ('.m3u', '.m3u8', '.xspf'):
            playlists.append(f)
    return playlists

def parse_m3u(file_path):
    tracks = []
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    tracks.append(line)
    except Exception:
        pass
    return tracks

def write_m3u(file_path, track_paths):
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("#EXTM3U\n")
        for t in track_paths:
            title = Path(t).stem
            f.write(f"#EXTINF:-1,{title}\n")
            f.write(f"{t}\n")

def launch_playlist_in_player(playlist_path, player="cliamp"):
    playlist_path = Path(playlist_path).resolve()
    print(f"\n{BOLD}{GREEN}Launching {player} with playlist: {playlist_path.name}...{NC}")
    
    if player == "cliamp":
        # Launch cliamp with playlist
        cliamp_bin = shutil.which("cliamp") or (get_base_dir() / "bin" / "cliamp")
        if os.name == 'posix' and shutil.which("konsole"):
            subprocess.Popen(["konsole", "--hold", "-e", str(cliamp_bin), str(playlist_path)])
        elif os.name == 'posix' and shutil.which("ptyxis"):
            subprocess.Popen(["ptyxis", "--", str(cliamp_bin), str(playlist_path)])
        else:
            subprocess.Popen([str(cliamp_bin), str(playlist_path)])
    elif player == "strawberry":
        subprocess.Popen(["strawberry", str(playlist_path)])
    elif player == "vlc":
        if shutil.which("vlc"):
            subprocess.Popen(["vlc", str(playlist_path)])
        elif shutil.which("flatpak"):
            subprocess.Popen(["flatpak", "run", "org.videolan.VLC", str(playlist_path)])
    elif player == "mpv":
        if shutil.which("mpv"):
            subprocess.Popen(["mpv", f"--playlist={playlist_path}"])
    elif player == "kodi":
        if shutil.which("kodi"):
            subprocess.Popen(["kodi", str(playlist_path)])
        elif shutil.which("flatpak"):
            subprocess.Popen(["flatpak", "run", "tv.kodi.Kodi", str(playlist_path)])
    else:
        # Fallback to system default
        if sys.platform == "darwin":
            subprocess.Popen(["open", str(playlist_path)])
        elif sys.platform == "win32":
            subprocess.Popen(["cmd.exe", "/c", "start", "", str(playlist_path)])
        else:
            subprocess.Popen(["xdg-open", str(playlist_path)])

def interactive_ui():
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        playlists = list_playlists()
        
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}        Custom Playlists Creator & Audio Player Launcher              {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"  Playlist Directory: {CYAN}{get_playlists_dir()}{NC}")
        print(f"  Saved Playlists:    {WHITE}{len(playlists)}{NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        if playlists:
            print(f"{BOLD}Existing Playlists:{NC}")
            for idx, p in enumerate(playlists, start=1):
                tracks = parse_m3u(p)
                print(f"  {BOLD}{CYAN}{idx:2d}){NC} {p.name:<36} {DIM}({len(tracks)} mix tracks){NC}")
            print("")
        else:
            print(f"  {DIM}No playlists created yet.{NC}\n")
            
        print(f"{BOLD}Playlist Operations:{NC}")
        print(f"  {BOLD}{CYAN} C){NC} Create New Custom Playlist (.m3u8)")
        print(f"  {BOLD}{CYAN} L){NC} Launch a Playlist in Audio Player (cliamp, Strawberry, VLC, etc.)")
        print(f"  {BOLD}{CYAN} E){NC} Edit / Re-order Tracks in Existing Playlist")
        print(f"  {BOLD}{CYAN} D){NC} Delete a Playlist")
        if sys.platform == "darwin":
            print(f"  {BOLD}{CYAN} T){NC} Generate Traktor Playlist from History Files (macOS)")
        print(f"\n  {BOLD}{CYAN} 0){NC} Return to Main Menu {DIM}(or 'q'){NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        cmd = input(f"{BOLD}Enter choice: {NC}").strip()
        if cmd in ('0', 'q', 'exit', 'quit'):
            break
            
        if cmd.lower() == 'c':
            create_playlist_wizard()
        elif cmd.lower() == 't' and sys.platform == "darwin":
            traktor_script = get_base_dir() / "generate_traktor_playlist_from_history.py"
            if traktor_script.is_file():
                subprocess.run([sys.executable, str(traktor_script)])
            else:
                print(f"{RED}Error: generate_traktor_playlist_from_history.py not found!{NC}")
                time.sleep(1)
        elif cmd.lower() == 'l':
            if not playlists:
                print(f"{YELLOW}No playlists available.{NC}")
                time.sleep(1)
                continue
            sel = input(f"Select playlist to launch [1-{len(playlists)}]: ").strip()
            if sel.isdigit() and 1 <= int(sel) <= len(playlists):
                p_file = playlists[int(sel) - 1]
                print(f"\nSelect Audio Player:")
                print(f"  1) cliamp (Terminal Player)")
                print(f"  2) Strawberry Music Player")
                print(f"  3) VLC Media Player")
                print(f"  4) MPV Player")
                print(f"  5) Kodi Media Center")
                p_sel = input("Select player [1-5, default 1]: ").strip() or "1"
                p_map = {"1": "cliamp", "2": "strawberry", "3": "vlc", "4": "mpv", "5": "kodi"}
                player_name = p_map.get(p_sel, "cliamp")
                launch_playlist_in_player(p_file, player_name)
                time.sleep(1)
        elif cmd.lower() == 'e':
            if not playlists:
                continue
            sel = input(f"Select playlist to edit [1-{len(playlists)}]: ").strip()
            if sel.isdigit() and 1 <= int(sel) <= len(playlists):
                edit_playlist_wizard(playlists[int(sel) - 1])
        elif cmd.lower() == 'd':
            if not playlists:
                continue
            sel = input(f"Select playlist to delete [1-{len(playlists)}]: ").strip()
            if sel.isdigit() and 1 <= int(sel) <= len(playlists):
                to_del = playlists[int(sel) - 1]
                conf = input(f"Delete {to_del.name}? [y/N]: ").strip().lower()
                if conf in ('y', 'yes'):
                    to_del.unlink()
                    print(f"{RED}✓ Playlist deleted.{NC}")
                    time.sleep(0.8)

def create_playlist_wizard():
    print(f"\n{BOLD}{MAGENTA}--- Create New Custom Playlist ---{NC}")
    name = input("Enter Playlist Name (e.g. Best_Of_SOF): ").strip()
    if not name:
        return
    if not name.lower().endswith(('.m3u', '.m3u8')):
        name += ".m3u8"
        
    p_file = get_playlists_dir() / name
    all_mixes = list_archive_mixes()
    selected_paths = []
    
    filter_q = ""
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        filtered = [m for m in all_mixes if not filter_q or filter_q.lower() in m["filename"].lower()]
        
        print(f"{BOLD}{MAGENTA}Creating Playlist: {name}{NC}")
        print(f"Selected Tracks: {GREEN}{len(selected_paths)}{NC} mixes in playlist")
        if filter_q:
            print(f"Active Filter: {CYAN}{filter_q}{NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        for idx, m in enumerate(filtered[:25], start=1):
            fname = m["filename"]
            if len(fname) > 55:
                fname = fname[:52] + "..."
            in_list = f"{GREEN}★ ADDED{NC}" if m["path"] in selected_paths else ""
            print(f"  {idx:2d}) {fname:<55} {in_list}")
            
        print(f"{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        print("Options: Enter numbers (e.g. 1,3,5), '/<query>' to filter, 'save' to finish, 'cancel' to exit")
        cmd = input(f"{BOLD}Select: {NC}").strip()
        
        if cmd.lower() == 'cancel':
            return
        elif cmd.lower() == 'save':
            if selected_paths:
                write_m3u(p_file, selected_paths)
                print(f"\n{GREEN}✓ Playlist successfully created with {len(selected_paths)} tracks:{NC} {p_file}")
                input("Press Enter to continue...")
            return
        elif cmd.startswith('/'):
            filter_q = cmd[1:].strip()
        else:
            try:
                for part in cmd.split(','):
                    part = part.strip()
                    if part.isdigit():
                        i = int(part)
                        if 1 <= i <= len(filtered):
                            p = filtered[i - 1]["path"]
                            if p not in selected_paths:
                                selected_paths.append(p)
                            else:
                                selected_paths.remove(p)
            except Exception:
                pass

def edit_playlist_wizard(p_file):
    tracks = parse_m3u(p_file)
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"{BOLD}{MAGENTA}Editing Playlist: {p_file.name}{NC}")
        print(f"Total Tracks: {len(tracks)}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        for idx, t in enumerate(tracks, start=1):
            print(f"  {idx:2d}) {Path(t).name}")
        print(f"{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        print("Options: 'r <index>' to remove track, 'add' to append tracks, 'save' to finish, '0' to cancel")
        cmd = input(f"{BOLD}Select: {NC}").strip()
        if cmd in ('0', 'cancel'):
            return
        elif cmd == 'save':
            write_m3u(p_file, tracks)
            print(f"{GREEN}✓ Playlist updated.{NC}")
            time.sleep(1)
            return
        elif cmd.startswith('r '):
            idx_str = cmd[2:].strip()
            if idx_str.isdigit() and 1 <= int(idx_str) <= len(tracks):
                tracks.pop(int(idx_str) - 1)
        elif cmd == 'add':
            mixes = list_archive_mixes()
            print("\nSelect mix to append:")
            for i, m in enumerate(mixes[:15], start=1):
                print(f"  {i:2d}) {m['filename']}")
            asel = input(f"Select [1-{min(15, len(mixes))}]: ").strip()
            if asel.isdigit() and 1 <= int(asel) <= min(15, len(mixes)):
                tracks.append(mixes[int(asel) - 1]["path"])

def main():
    parser = argparse.ArgumentParser(description="Custom Playlists Creator & Launcher")
    parser.add_argument("--list", action="store_true", help="List all playlists")
    parser.add_argument("--launch", help="Playlist path or name to launch")
    parser.add_argument("--player", default="cliamp", help="Audio player to launch")
    args = parser.parse_args()
    
    if args.list:
        for p in list_playlists():
            print(f"{p.name} ({len(parse_m3u(p))} tracks)")
    elif args.launch:
        launch_playlist_in_player(args.launch, args.player)
    else:
        interactive_ui()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("")
        sys.exit(0)
