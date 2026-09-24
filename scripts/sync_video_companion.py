#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Synchronized Video Companion & Multi-Player Launcher
Features:
  1. Open a specified video in popular video players (VLC, Haruna, MPV, Kodi)
  2. Configure default video player
  3. Synchronized Video Companion Mode:
     - Automatically launches the companion video in the default player when mix audio starts playing
     - Actively monitors audio playback (cliamp, Strawberry, MPRIS, PipeWire)
     - Automatically terminates/closes the video player as soon as audio playback finishes or stops!
"""

import os
import sys
import time
import subprocess
import shutil
import signal
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

VIDEO_EXTS = ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.ts']

VIDEO_PLAYERS = {
    "vlc": {
        "name": "VLC Media Player",
        "bin": "vlc",
        "flatpak": "org.videolan.VLC",
        "cmd_args": ["--no-video-title-show", "--loop"]
    },
    "haruna": {
        "name": "Haruna Video Player",
        "bin": "haruna",
        "flatpak": "org.kde.haruna",
        "cmd_args": []
    },
    "mpv": {
        "name": "MPV Media Player",
        "bin": "mpv",
        "flatpak": "io.mpv.Mpv",
        "cmd_args": ["--loop=inf"]
    },
    "kodi": {
        "name": "Kodi Entertainment Center",
        "bin": "kodi",
        "flatpak": "tv.kodi.Kodi",
        "cmd_args": []
    }
}

def load_config():
    config_file = Path(__file__).resolve().parent / "config.env"
    cfg = {}
    if config_file.is_file():
        try:
            with open(config_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        cfg[k.strip()] = v.strip().strip('"').strip("'")
        except Exception:
            pass
    return cfg

def save_config_key(key, val):
    config_file = Path(__file__).resolve().parent / "config.env"
    if not config_file.is_file():
        return
    try:
        with open(config_file, "r", encoding="utf-8") as f:
            lines = f.readlines()
        found = False
        new_lines = []
        for line in lines:
            if line.strip().startswith(f"{key}="):
                new_lines.append(f'{key}="{val}"\n')
                found = True
            else:
                new_lines.append(line)
        if not found:
            new_lines.append(f'\n{key}="{val}"\n')
        with open(config_file, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
    except Exception:
        pass

def find_available_videos():
    cfg = load_config()
    scan_paths = []
    if cfg.get("NFT_VIDEOS_DIR") and os.path.isdir(cfg["NFT_VIDEOS_DIR"]):
        scan_paths.append(Path(cfg["NFT_VIDEOS_DIR"]))
    
    # Standard locations
    user = os.environ.get("USER", "mplanetarian")
    candidates = [
        Path(f"/run/media/{user}/DATA/NFT_VIDEOS"),
        Path(f"/run/media/{user}/VROC/VIDEO"),
        Path.home() / "Videos",
        Path(__file__).resolve().parent
    ]
    for c in candidates:
        if c.is_dir() and c not in scan_paths:
            scan_paths.append(c)
            
    videos = []
    for sdir in scan_paths:
        try:
            for entry in os.scandir(str(sdir)):
                if entry.is_file():
                    lower = entry.name.lower()
                    if any(lower.endswith(ext) for ext in VIDEO_EXTS):
                        videos.append({
                            "name": entry.name,
                            "path": entry.path,
                            "dir": sdir.name
                        })
        except Exception:
            pass
            
    return videos

def launch_video(video_path, player_key="vlc"):
    player = VIDEO_PLAYERS.get(player_key, VIDEO_PLAYERS["vlc"])
    cmd = []
    
    if shutil.which(player["bin"]):
        cmd = [player["bin"]] + player["cmd_args"] + [str(video_path)]
    elif shutil.which("flatpak") and player.get("flatpak"):
        cmd = ["flatpak", "run", player["flatpak"]] + player["cmd_args"] + [str(video_path)]
    else:
        # Fallback to xdg-open / open / start
        if sys.platform == "darwin":
            cmd = ["open", str(video_path)]
        elif sys.platform == "win32":
            cmd = ["cmd.exe", "/c", "start", "", str(video_path)]
        else:
            cmd = ["xdg-open", str(video_path)]
            
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return proc
    except Exception as e:
        print(f"{RED}Error launching video player: {e}{NC}")
        return None

def is_audio_playing():
    """Detect whether music or a mix is currently playing."""
    # 1. Check cliamp status
    now_playing_file = Path("/tmp/cliamp_now_playing.txt")
    if now_playing_file.is_file():
        try:
            mtime = now_playing_file.stat().st_mtime
            # If written in last 6 seconds, cliamp is actively playing
            if time.time() - mtime < 6:
                return True
        except Exception:
            pass
            
    # 2. Check Strawberry MPRIS
    if shutil.which("qdbus"):
        try:
            res = subprocess.run(
                ["qdbus", "org.mpris.MediaPlayer2.strawberry", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.PlaybackStatus"],
                capture_output=True, text=True, timeout=1
            )
            if res.returncode == 0 and res.stdout.strip() == "Playing":
                return True
        except Exception:
            pass
            
    # 3. Check VLC MPRIS
    if shutil.which("qdbus"):
        try:
            res = subprocess.run(
                ["qdbus", "org.mpris.MediaPlayer2.vlc", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.PlaybackStatus"],
                capture_output=True, text=True, timeout=1
            )
            if res.returncode == 0 and res.stdout.strip() == "Playing":
                return True
        except Exception:
            pass
            
    # 4. Check PipeWire active playback streams
    if shutil.which("wpctl"):
        try:
            res = subprocess.run(["wpctl", "status"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                lines = res.stdout.split("\n")
                for line in lines:
                    if "Streams:" in line and "running" in line:
                        return True
        except Exception:
            pass
            
    return False

def run_sync_companion_daemon(video_path, player_key="vlc"):
    """Monitors audio playback: opens video when mix plays, closes when mix stops."""
    print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}      Synchronized Mix-Video Companion Daemon Active                  {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"  Companion Video: {CYAN}{Path(video_path).name}{NC}")
    print(f"  Video Player:    {GREEN}{VIDEO_PLAYERS.get(player_key, {}).get('name', player_key)}{NC}")
    print(f"  Status:          Waiting for mix playback to start...")
    print(f"  {DIM}(Press Ctrl+C to stop companion mode){NC}\n")
    
    video_proc = None
    was_playing = False
    
    try:
        while True:
            playing = is_audio_playing()
            if playing and not was_playing:
                print(f"{BOLD}{GREEN}[ACTIVE]{NC} Mix playback detected! Launching companion video...")
                video_proc = launch_video(video_path, player_key)
                was_playing = True
            elif not playing and was_playing:
                print(f"{BOLD}{YELLOW}[STOPPED]{NC} Mix playback stopped. Automatically closing video player...")
                if video_proc:
                    try:
                        video_proc.terminate()
                        video_proc.wait(timeout=2)
                    except Exception:
                        try:
                            video_proc.kill()
                        except Exception:
                            pass
                    video_proc = None
                was_playing = False
                print("Waiting for next mix to start playing...")
            time.sleep(1.2)
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Stopping companion daemon...{NC}")
        if video_proc:
            try:
                video_proc.terminate()
            except Exception:
                pass

def interactive_ui():
    cfg = load_config()
    default_player = cfg.get("DEFAULT_VIDEO_PLAYER", "vlc")
    videos = find_available_videos()
    
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}        Synchronized Mix-Video Companion & Video Players Hub          {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"  Default Video Player: {GREEN}{VIDEO_PLAYERS.get(default_player, {}).get('name', default_player)}{NC}")
        print(f"  Available Videos:     {CYAN}{len(videos)} videos found in media directories{NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        print(f"Options:")
        print(f"  ${BOLD}${CYAN} 1)${NC} Start Synchronized Video Companion (Auto-open on play, auto-close on stop)")
        print(f"  ${BOLD}${CYAN} 2)${NC} Open Video File in VLC Media Player")
        print(f"  ${BOLD}${CYAN} 3)${NC} Open Video File in Haruna Media Player")
        print(f"  ${BOLD}${CYAN} 4)${NC} Open Video File in MPV Media Player")
        print(f"  ${BOLD}${CYAN} 5)${NC} Open Video File in Kodi Entertainment Center")
        print(f"  ${BOLD}${CYAN} 6)${NC} Set Default Video Player (Current: {default_player})")
        print(f"\n  ${BOLD}${CYAN} 0)${NC} Return to Main Menu ${DIM}(or 'q')${NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        choice = input(f"{BOLD}Enter choice [1-6, 0 to return]: {NC}").strip()
        if choice in ('0', 'q', 'exit', 'quit'):
            break
            
        if choice == '6':
            print(f"\nSelect default video player:")
            keys = list(VIDEO_PLAYERS.keys())
            for idx, k in enumerate(keys, start=1):
                print(f"  {idx}) {VIDEO_PLAYERS[k]['name']}")
            sel = input("Select [1-4]: ").strip()
            if sel.isdigit() and 1 <= int(sel) <= len(keys):
                default_player = keys[int(sel) - 1]
                save_config_key("DEFAULT_VIDEO_PLAYER", default_player)
                print(f"{GREEN}✓ Default video player updated to {VIDEO_PLAYERS[default_player]['name']}!{NC}")
                time.sleep(1)
            continue
            
        # Select video
        selected_vid = None
        if videos:
            print(f"\nSelect Video File:")
            for idx, v in enumerate(videos[:15], start=1):
                print(f"  {idx:2d}) {v['name']} {DIM}({v['dir']}){NC}")
            print(f"   C) Enter custom video path")
            vsel = input(f"Select video [1-{min(15, len(videos))} or C]: ").strip()
            if vsel.isdigit() and 1 <= int(vsel) <= min(15, len(videos)):
                selected_vid = videos[int(vsel) - 1]["path"]
            elif vsel.lower() == 'c':
                c_path = input("Enter full path to video: ").strip()
                if os.path.isfile(c_path):
                    selected_vid = c_path
        else:
            c_path = input("Enter full path to video file: ").strip()
            if os.path.isfile(c_path):
                selected_vid = c_path
                
        if not selected_vid:
            print(f"{RED}No valid video file selected.{NC}")
            time.sleep(1.2)
            continue
            
        if choice == '1':
            run_sync_companion_daemon(selected_vid, default_player)
            input("\nPress Enter to continue...")
        elif choice == '2':
            launch_video(selected_vid, "vlc")
        elif choice == '3':
            launch_video(selected_vid, "haruna")
        elif choice == '4':
            launch_video(selected_vid, "mpv")
        elif choice == '5':
            launch_video(selected_vid, "kodi")

def main():
    parser = argparse.ArgumentParser(description="Synchronized Video Companion & Multi-Player Launcher")
    parser.add_argument("--sync", action="store_true", help="Run synchronized video companion daemon")
    parser.add_argument("--video", help="Video path to play")
    parser.add_argument("--player", default="vlc", choices=["vlc", "haruna", "mpv", "kodi"], help="Video player")
    args = parser.parse_args()
    
    if args.sync and args.video:
        run_sync_companion_daemon(args.video, args.player)
    elif args.video:
        launch_video(args.video, args.player)
    else:
        interactive_ui()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("")
        sys.exit(0)
