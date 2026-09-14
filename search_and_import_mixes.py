#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.2 - Universal Mix Search & Importer
Search and ingest mixes from local drives, removable media (USB/SSD), and SMB network shares.
Features:
  - Auto-discovery of local mounted volumes, external drives, and common music directories
  - Built-in & custom SMB share support (via rclone and direct CIFS mounts)
  - Intelligent filtering by audio extension and minimum file size (default: >= 100 MB for full mixes)
  - Duplicate detection against active Mix Archive, Converted WAVs, and FLAC outputs
  - Live progress display with transfer speed and ETA
  - Detailed audit logging in IMPORT_LOGS/
  - Optional automatic trigger of FLAC conversion post-import
"""

import os
import sys
import shutil
import datetime
import subprocess
import re
import argparse
import time
from pathlib import Path

# --- ANSI Terminal Colors ---
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

# Audio extensions to look for
DEFAULT_AUDIO_EXTS = ['.wav', '.flac', '.aif', '.aiff', '.m4a', '.mp3']

# Known SMB Sources (from existing environment)
DEFAULT_SMB_SOURCES = [
    {
        "name": "STREAM_OF_FREQUENCY_RECORDINGS_TRAKTOR_2026",
        "url": "smb://192.168.1.138/mplanetarian/.../STREAM_OF_FREQUENCY_RECORDINGS_TRAKTOR_2026/",
        "rclone_path": ':smb,host="192.168.1.138",user="mplanetarian",pass="Bl5Ejf6SBQivAUu_JvImDn__AKLASZcq":mplanetarian/Documents/MPlanetarian/M_PRODUCTION/STREAM_OF_FREQUENCY_RECORDINGS_TRAKTOR_2026/'
    },
    {
        "name": "STREAM_OF_FREQUENCY_MIX_ARCHIVE",
        "url": "smb://192.168.1.138/DATAMAC1/M_PRODUCTION/MIX_ARCHIVE/STREAM_OF_FREQUENCY_MIX_ARCHIVE/",
        "rclone_path": ':smb,host="192.168.1.138",user="mplanetarian",pass="Bl5Ejf6SBQivAUu_JvImDn__AKLASZcq":DATAMAC1/M_PRODUCTION/MIX_ARCHIVE/STREAM_OF_FREQUENCY_MIX_ARCHIVE/'
    }
]

def load_config_env():
    """Load settings from config.env if present."""
    script_dir = Path(__file__).resolve().parent
    config_file = script_dir / "config.env"
    env_vars = {}
    if config_file.is_file():
        try:
            with open(config_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    key, val = line.split("=", 1)
                    key = key.strip()
                    val = val.strip().strip('"').strip("'")
                    env_vars[key] = val
        except Exception:
            pass
    return env_vars

def get_destination_dir(env_vars):
    """Determine target mix archive directory."""
    if "MIX_ARCHIVE_DIR" in env_vars and os.path.isdir(env_vars["MIX_ARCHIVE_DIR"]):
        return env_vars["MIX_ARCHIVE_DIR"]
    if os.environ.get("MIX_ARCHIVE_DIR") and os.path.isdir(os.environ["MIX_ARCHIVE_DIR"]):
        return os.environ["MIX_ARCHIVE_DIR"]
    
    # Common default paths
    user = os.environ.get("USER", "mplanetarian")
    candidates = [
        f"/run/media/{user}/WD BLACK B/MIX_ARCHIVE",
        f"/run/media/{user}/DATA/MIX_ARCHIVE",
        f"/Volumes/WD BLACK B/MIX_ARCHIVE",
        str(Path.home() / "Music" / "MIX_ARCHIVE"),
        str(Path(__file__).resolve().parent)
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c
    return str(Path(__file__).resolve().parent)

def human_size(bytes_val):
    """Convert bytes to human-readable string."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(bytes_val) < 1024.0:
            return f"{bytes_val:3.1f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.1f} PB"

def normalize_mix_key(name):
    """Extract comparable key from mix filename (ignoring extension, timestamps, case)."""
    clean = name.lower()
    for ext in DEFAULT_AUDIO_EXTS:
        if clean.endswith(ext):
            clean = clean[:-len(ext)]
            break
    # Remove common Traktor date/time suffixes like _2026-09-08_12h16m09 or _03h02m02
    clean = re.sub(r'_\d{4}-\d{2}-\d{2}_\d{1,2}h\d{2}m\d{2}(?:_\d{1,2}h\d{2}m\d{2})*', '', clean)
    clean = re.sub(r'_\d{1,2}h\d{2}m\d{2}', '', clean)
    clean = re.sub(r'[\s_\-]+', ' ', clean).strip()
    return clean

def get_existing_archive_keys(dest_dir):
    """Index existing mixes in archive destination and subdirectories."""
    existing_bases = set()
    existing_keys = set()
    
    subdirs_to_check = [
        dest_dir,
        os.path.join(dest_dir, "CONVERTED_WAV_FILES"),
        os.path.join(dest_dir, "FLAC_CONVERTED_OUTPUTS"),
        "/run/media/mplanetarian/VROC/M_PRODUCTION/STREAM_OF_FREQUENCY/CONVERTED_WAV_FILES_MOVED"
    ]
    
    for sdir in subdirs_to_check:
        if not os.path.isdir(sdir):
            continue
        try:
            for entry in os.scandir(sdir):
                if entry.is_file():
                    lower = entry.name.lower()
                    if any(lower.endswith(ext) for ext in DEFAULT_AUDIO_EXTS):
                        base = os.path.splitext(entry.name)[0].lower()
                        existing_bases.add(base)
                        norm_key = normalize_mix_key(entry.name)
                        if norm_key:
                            existing_keys.add(norm_key)
        except Exception:
            pass
            
    return existing_bases, existing_keys

def detect_local_drives():
    """Discover mounted drives and common music directories on the system."""
    drives = []
    user = os.environ.get("USER", "mplanetarian")
    
    scan_bases = [
        f"/run/media/{user}",
        "/run/media/system",
        f"/media/{user}",
        "/media",
        "/mnt",
        "/Volumes"
    ]
    
    seen_paths = set()
    
    # 1. Scan filesystem mounts
    for base in scan_bases:
        if os.path.isdir(base):
            try:
                for entry in os.scandir(base):
                    if entry.is_dir() and not entry.name.startswith('.'):
                        real_path = str(Path(entry.path).resolve())
                        if real_path not in seen_paths:
                            seen_paths.add(real_path)
                            try:
                                usage = shutil.disk_usage(real_path)
                                drives.append({
                                    "type": "drive",
                                    "label": entry.name,
                                    "path": real_path,
                                    "total": usage.total,
                                    "free": usage.free
                                })
                            except Exception:
                                pass
            except Exception:
                pass
                
    # 2. Add user home media folders if they exist
    home = Path.home()
    user_folders = [
        ("User Music Library", home / "Music"),
        ("Downloads Folder", home / "Downloads"),
        ("Desktop Folder", home / "Desktop"),
        ("Documents Audio", home / "Documents" / "MPlanetarian" / "M_PRODUCTION")
    ]
    for label, folder in user_folders:
        if folder.is_dir():
            real_path = str(folder.resolve())
            if real_path not in seen_paths:
                seen_paths.add(real_path)
                try:
                    usage = shutil.disk_usage(real_path)
                    drives.append({
                        "type": "folder",
                        "label": label,
                        "path": real_path,
                        "total": usage.total,
                        "free": usage.free
                    })
                except Exception:
                    pass
                    
    return drives

def scan_local_path(target_path, min_size_mb, exts, existing_bases, existing_keys, max_depth=5):
    """Recursively scan a local path for audio files meeting criteria."""
    candidates = []
    target_path = Path(target_path)
    min_bytes = min_size_mb * 1024 * 1024
    
    print(f"{CYAN}Scanning directory: {target_path} (Min size: {min_size_mb} MB)...{NC}")
    
    for root, dirs, files in os.walk(str(target_path)):
        # Calculate current depth relative to target_path
        rel = os.path.relpath(root, str(target_path))
        depth = 0 if rel == '.' else len(Path(rel).parts)
        if depth >= max_depth:
            dirs.clear()  # Do not recurse further
            continue
            
        # Skip hidden and system directories
        dirs[:] = [d for d in dirs if not d.startswith('.') and not d.startswith('$') and d not in ('System Volume Information', 'node_modules', '__pycache__')]
        
        for f in files:
            if f.startswith('.'):
                continue
            lower_name = f.lower()
            if any(lower_name.endswith(ext) for ext in exts):
                full_path = os.path.join(root, f)
                try:
                    stat = os.stat(full_path)
                    size = stat.st_size
                    if size >= min_bytes:
                        base = os.path.splitext(f)[0].lower()
                        norm = normalize_mix_key(f)
                        
                        is_existing = (base in existing_bases) or (norm in existing_keys)
                        
                        candidates.append({
                            "source_type": "local",
                            "filename": f,
                            "path": full_path,
                            "size": size,
                            "mtime": stat.st_mtime,
                            "is_existing": is_existing,
                            "display_source": os.path.basename(root)
                        })
                except Exception:
                    continue
                    
    return candidates

def scan_smb_rclone(smb_source, min_size_mb, exts, existing_bases, existing_keys):
    """Scan an SMB source using rclone lsf."""
    candidates = []
    min_bytes = min_size_mb * 1024 * 1024
    rpath = smb_source["rclone_path"]
    
    print(f"{CYAN}Scanning SMB share: {smb_source['name']}...{NC}")
    
    cmd = [
        "rclone", "lsf", "--csv", "--files-only", "--recursive",
        "--format", "sp", rpath
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except Exception as e:
        print(f"{RED}Error communicating with SMB share: {e}{NC}")
        return []
        
    if res.returncode != 0:
        print(f"{RED}rclone error on {smb_source['name']}: {res.stderr.strip()}{NC}")
        return []
        
    lines = res.stdout.strip().split("\n")
    for line in lines:
        if not line or "," not in line:
            continue
        parts = line.split(",", 1)
        try:
            size = int(parts[0])
            rel_path = parts[1]
        except ValueError:
            continue
            
        fname = os.path.basename(rel_path)
        lower_name = fname.lower()
        if any(lower_name.endswith(ext) for ext in exts) and size >= min_bytes:
            base = os.path.splitext(fname)[0].lower()
            norm = normalize_mix_key(fname)
            is_existing = (base in existing_bases) or (norm in existing_keys)
            
            candidates.append({
                "source_type": "smb",
                "filename": fname,
                "path": rel_path,
                "rclone_remote": rpath,
                "smb_source_name": smb_source["name"],
                "size": size,
                "mtime": time.time(),
                "is_existing": is_existing,
                "display_source": f"SMB: {smb_source['name']}"
            })
            
    return candidates

def print_progress_bar(transferred, total, speed, eta_seconds):
    """Render a clean ANSI in-place progress bar."""
    width = 30
    if total > 0:
        pct = min(100.0, (transferred / total) * 100.0)
        filled = int(round(width * (transferred / float(total))))
    else:
        pct = 0.0
        filled = 0
    bar = '=' * filled + '-' * (width - filled)
    
    eta_str = f"{int(eta_seconds // 60):02d}:{int(eta_seconds % 60):02d}" if eta_seconds >= 0 else "--:--"
    speed_str = f"{human_size(speed)}/s"
    
    sys.stdout.write(f"\r  {CYAN}[{bar}]{NC} {pct:5.1f}% ({human_size(transferred)} / {human_size(total)}) @ {speed_str} [ETA: {eta_str}]")
    sys.stdout.flush()

def copy_local_file_with_progress(src, dst):
    """Copy a local file with real-time speed, bytes, and ETA display."""
    total_size = os.path.getsize(src)
    chunk_size = 1024 * 1024  # 1MB
    transferred = 0
    start_time = time.time()
    
    with open(src, 'rb') as fsrc, open(dst, 'wb') as fdst:
        while True:
            chunk = fsrc.read(chunk_size)
            if not chunk:
                break
            fdst.write(chunk)
            transferred += len(chunk)
            elapsed = time.time() - start_time
            speed = transferred / elapsed if elapsed > 0.05 else 0
            remaining = (total_size - transferred) / speed if speed > 0 else 0
            print_progress_bar(transferred, total_size, speed, remaining)
            
    print_progress_bar(total_size, total_size, total_size / max(0.01, time.time() - start_time), 0)
    print("")
    # Preserve metadata and timestamp
    shutil.copystat(src, dst)

def log_import_job(log_file, lines):
    """Append structured lines to log file."""
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n\n")

def run_flac_conversion_if_requested(dest_dir):
    """Prompt or automatically trigger Make_SOF_FLAC_CONVERSION.sh."""
    script_dir = Path(__file__).resolve().parent
    conv_script = script_dir / "Make_SOF_FLAC_CONVERSION.sh"
    if not conv_script.is_file():
        conv_script = script_dir / "scripts" / "Make_SOF_FLAC_CONVERSION.sh"
        
    if conv_script.is_file():
        print(f"\n{BOLD}{YELLOW}Launching FLAC Conversion Process ({conv_script.name})...{NC}\n")
        subprocess.run(["bash", str(conv_script)], cwd=str(dest_dir))
    else:
        print(f"{YELLOW}FLAC Conversion script not found at expected path.{NC}")

def interactive_ui():
    """Main interactive terminal wizard for searching and importing mixes."""
    env_vars = load_config_env()
    dest_dir = get_destination_dir(env_vars)
    
    min_size_mb = 100
    selected_exts = DEFAULT_AUDIO_EXTS
    
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}       Universal Mix Search & Importer (Local Drives & SMB)           {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        
        # Display Destination Archive Info
        dest_free = shutil.disk_usage(dest_dir).free if os.path.isdir(dest_dir) else 0
        print(f"  Destination Archive: {GREEN}{dest_dir}{NC}")
        print(f"  Archive Free Space:  {YELLOW}{human_size(dest_free)}{NC}")
        print(f"  Min File Size:       {CYAN}{min_size_mb} MB{NC} (Filters full mixes vs short tracks)")
        print(f"  Audio Formats:       {CYAN}{', '.join(selected_exts)}{NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        # Discover Local Drives
        local_drives = detect_local_drives()
        print(f"{BOLD}Detected Local & Removable Storage:{NC}")
        for idx, drive in enumerate(local_drives, start=1):
            free_str = human_size(drive['free'])
            total_str = human_size(drive['total'])
            print(f"  {BOLD}{CYAN}{idx:2d}){NC} [{drive['label']}] {DIM}{drive['path']}{NC} ({free_str} free / {total_str})")
            
        print(f"\n{BOLD}Configured SMB Network Shares:{NC}")
        smb_start = len(local_drives) + 1
        for sidx, src in enumerate(DEFAULT_SMB_SOURCES):
            num = smb_start + sidx
            print(f"  {BOLD}{CYAN}{num:2d}){NC} [SMB Share] {WHITE}{src['name']}{NC} {DIM}({src['url']}){NC}")
            
        print(f"\n{BOLD}Additional Search Options:{NC}")
        all_drives_opt = smb_start + len(DEFAULT_SMB_SOURCES)
        custom_dir_opt = all_drives_opt + 1
        custom_smb_opt = custom_dir_opt + 1
        filter_size_opt = custom_smb_opt + 1
        
        print(f"  {BOLD}{CYAN}{all_drives_opt:2d}){NC} Scan ALL Detected Local Drives & Media at once")
        print(f"  {BOLD}{CYAN}{custom_dir_opt:2d}){NC} Scan a Custom Local Directory Path...")
        print(f"  {BOLD}{CYAN}{custom_smb_opt:2d}){NC} Connect & Scan a Custom SMB Network Share (Host/Share/Path)...")
        print(f"  {BOLD}{CYAN}{filter_size_opt:2d}){NC} Change Min File Size Filter (Current: {min_size_mb} MB)")
        print(f"\n  {BOLD}{CYAN} 0){NC} Return to Main Menu (or 'q')")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        choice = input(f"{BOLD}Select source to search [1-{filter_size_opt}, 0 to return]: {NC}").strip().lower()
        if choice in ('0', 'q', 'exit', 'quit'):
            break
            
        # Change size filter
        if choice == str(filter_size_opt):
            new_size = input(f"Enter new minimum file size in MB (0 for all audio files) [{min_size_mb}]: ").strip()
            if new_size.isdigit():
                min_size_mb = int(new_size)
            continue
            
        targets_to_scan = []
        
        try:
            choice_num = int(choice)
        except ValueError:
            print(f"{RED}Invalid input!{NC}")
            time.sleep(1)
            continue
            
        if 1 <= choice_num <= len(local_drives):
            drv = local_drives[choice_num - 1]
            targets_to_scan.append({"type": "local", "path": drv["path"], "name": drv["label"]})
        elif smb_start <= choice_num < smb_start + len(DEFAULT_SMB_SOURCES):
            src = DEFAULT_SMB_SOURCES[choice_num - smb_start]
            targets_to_scan.append({"type": "smb", "smb_source": src})
        elif choice_num == all_drives_opt:
            for drv in local_drives:
                targets_to_scan.append({"type": "local", "path": drv["path"], "name": drv["label"]})
        elif choice_num == custom_dir_opt:
            cpath = input("Enter full local path to scan: ").strip()
            if os.path.isdir(cpath):
                targets_to_scan.append({"type": "local", "path": cpath, "name": os.path.basename(cpath) or cpath})
            else:
                print(f"{RED}Directory not found: {cpath}{NC}")
                time.sleep(1.5)
                continue
        elif choice_num == custom_smb_opt:
            smb_host = input("Enter SMB Host/IP (e.g. 192.168.1.138): ").strip()
            if not smb_host:
                continue
            smb_share = input("Enter Share or Export Name (e.g. Music or Documents): ").strip()
            smb_user = input("Enter Username (leave blank for guest): ").strip()
            smb_pass = ""
            if smb_user:
                import getpass
                smb_pass = getpass.getpass("Enter Password (optional): ")
            smb_sub = input("Enter Subfolder path (optional, leave blank for root): ").strip()
            
            # Construct rclone smb path
            auth_parts = [f'host="{smb_host}"']
            if smb_user:
                auth_parts.append(f'user="{smb_user}"')
            if smb_pass:
                # Obscure password via rclone obscure if available
                try:
                    p_res = subprocess.run(["rclone", "obscure", smb_pass], capture_output=True, text=True)
                    if p_res.returncode == 0:
                        obs_pass = p_res.stdout.strip()
                        auth_parts.append(f'pass="{obs_pass}"')
                except Exception:
                    pass
            r_prefix = f':smb,{",".join(auth_parts)}:'
            full_rclone = f"{r_prefix}{smb_share}/{smb_sub}".rstrip('/') + '/'
            custom_src = {
                "name": f"Custom SMB ({smb_host}/{smb_share})",
                "url": f"smb://{smb_host}/{smb_share}/{smb_sub}",
                "rclone_path": full_rclone
            }
            targets_to_scan.append({"type": "smb", "smb_source": custom_src})
        else:
            print(f"{RED}Option out of range!{NC}")
            time.sleep(1)
            continue
            
        # Index existing archive to determine duplicate status
        print(f"\n{BOLD}Indexing existing archive to identify duplicate mixes...{NC}")
        existing_bases, existing_keys = get_existing_archive_keys(dest_dir)
        print(f" -> Found {len(existing_bases)} unique mix base names in archive.\n")
        
        found_candidates = []
        for tgt in targets_to_scan:
            if tgt["type"] == "local":
                c = scan_local_path(tgt["path"], min_size_mb, selected_exts, existing_bases, existing_keys)
                found_candidates.extend(c)
            elif tgt["type"] == "smb":
                c = scan_smb_rclone(tgt["smb_source"], min_size_mb, selected_exts, existing_bases, existing_keys)
                found_candidates.extend(c)
                
        if not found_candidates:
            print(f"\n{YELLOW}No audio mixes matching the criteria (>= {min_size_mb} MB) were found.{NC}")
            input("Press Enter to continue...")
            continue
            
        # Deduplicate candidates in case same file was found via multiple scan targets
        seen_cand = set()
        dedup_candidates = []
        for cand in found_candidates:
            key = (cand["source_type"], cand["path"])
            if key not in seen_cand:
                seen_cand.add(key)
                dedup_candidates.append(cand)
        found_candidates = dedup_candidates
        
        # Candidate Review and Selection Loop
        filter_query = ""
        while True:
            os.system('clear' if os.name == 'posix' else 'cls')
            displayed = []
            for cand in found_candidates:
                if filter_query and filter_query.lower() not in cand["filename"].lower():
                    continue
                displayed.append(cand)
                
            new_count = sum(1 for c in displayed if not c["is_existing"])
            exist_count = len(displayed) - new_count
            
            print(f"{BOLD}{MAGENTA}======================================================================{NC}")
            print(f"{BOLD}{MAGENTA}                    Candidate Mix Search Results                      {NC}")
            print(f"{BOLD}{MAGENTA}======================================================================{NC}")
            print(f"  Found: {BOLD}{WHITE}{len(displayed)}{NC} mixes | {GREEN}{new_count} NEW{NC} | {YELLOW}{exist_count} In Archive{NC}")
            if filter_query:
                print(f"  Active Keyword Filter: {CYAN}{filter_query}{NC} (Type '/clear' to reset)")
            print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
            print(f"{BOLD}{' #':3} | {'Status':12} | {'File Name':<38} | {'Size':>9} | {'Source'}{NC}")
            print(f"{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
            
            # Show top 40 if list is very large
            max_show = 35
            for idx, item in enumerate(displayed[:max_show], start=1):
                st = f"{GREEN}[NEW]{NC}        " if not item["is_existing"] else f"{YELLOW}[ARCHIVED]{NC}   "
                fname = item["filename"]
                if len(fname) > 38:
                    fname = fname[:35] + "..."
                src_disp = item["display_source"]
                if len(src_disp) > 20:
                    src_disp = src_disp[:17] + "..."
                print(f" {idx:2d} | {st} | {fname:<38} | {human_size(item['size']):>9} | {DIM}{src_disp}{NC}")
                
            if len(displayed) > max_show:
                print(f" {DIM}... and {len(displayed) - max_show} more mixes (use filter to narrow down){NC}")
                
            print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
            print(f"Selection Options:")
            print(f"  - {BOLD}a{NC} / {BOLD}all{NC}: Import ALL {GREEN}{new_count} NEW{NC} mixes")
            print(f"  - {BOLD}1,3,5-8{NC}: Select specific mix numbers")
            print(f"  - {BOLD}/<query>{NC}: Filter list by text (e.g. '/131' or '/frequency')")
            print(f"  - {BOLD}b{NC} / {BOLD}q{NC}: Back to search sources")
            print(f"{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
            
            sel = input(f"{BOLD}Enter selection: {NC}").strip()
            if not sel or sel.lower() in ('b', 'q', 'back'):
                break
                
            if sel.startswith('/'):
                subcmd = sel[1:].strip()
                if subcmd == 'clear':
                    filter_query = ""
                else:
                    filter_query = subcmd
                continue
                
            selected_items = []
            if sel.lower() in ('a', 'all'):
                selected_items = [c for c in displayed if not c["is_existing"]]
                if not selected_items:
                    print(f"{YELLOW}No NEW mixes found in the current view! Use numbers to force import archived mixes.{NC}")
                    time.sleep(1.5)
                    continue
            elif sel == '*':
                selected_items = list(displayed)
            else:
                # Parse indices
                try:
                    for part in sel.split(','):
                        part = part.strip()
                        if '-' in part:
                            start_str, end_str = part.split('-', 1)
                            for i in range(int(start_str), int(end_str) + 1):
                                if 1 <= i <= len(displayed):
                                    selected_items.append(displayed[i - 1])
                        else:
                            i = int(part)
                            if 1 <= i <= len(displayed):
                                selected_items.append(displayed[i - 1])
                except ValueError:
                    print(f"{RED}Invalid selection format!{NC}")
                    time.sleep(1.2)
                    continue
                    
            if not selected_items:
                print(f"{YELLOW}No items selected.{NC}")
                time.sleep(1)
                continue
                
            # Pre-flight disk space calculation
            total_import_bytes = sum(c["size"] for c in selected_items)
            free_archive_space = shutil.disk_usage(dest_dir).free
            
            print(f"\n{BOLD}Import Plan Summary:{NC}")
            print(f"  Mixes to Import:     {BOLD}{len(selected_items)}{NC}")
            print(f"  Total Data Size:     {CYAN}{human_size(total_import_bytes)}{NC}")
            print(f"  Destination Free:    {GREEN}{human_size(free_archive_space)}{NC}")
            
            if total_import_bytes > free_archive_space:
                print(f"\n{BOLD}{RED}ERROR: Insufficient disk space on destination archive drive!{NC}")
                print(f"Required: {human_size(total_import_bytes)}, Available: {human_size(free_archive_space)}")
                input("Press Enter to return...")
                continue
                
            confirm = input(f"\nProceed with importing {len(selected_items)} mix(es)? [Y/n]: ").strip().lower()
            if confirm and confirm not in ('y', 'yes'):
                continue
                
            # Perform Import
            print(f"\n{BOLD}{GREEN}Starting Import Process...{NC}\n")
            today_str = datetime.date.today().strftime('%Y-%m-%d')
            log_dir = os.path.join(dest_dir, "IMPORT_LOGS")
            log_file = os.path.join(log_dir, f"import_search_{today_str}.log")
            
            start_time = time.time()
            success_count = 0
            fail_count = 0
            bytes_transferred = 0
            log_entries = [
                "==================================================",
                f"UNIVERSAL MIX IMPORT AUDIT LOG - {datetime.datetime.now()}",
                "=================================================="
            ]
            
            # Group items by type
            local_items = [c for c in selected_items if c["source_type"] == "local"]
            smb_items = [c for c in selected_items if c["source_type"] == "smb"]
            
            # 1. Process Local Files
            for idx, item in enumerate(local_items, start=1):
                src_path = item["path"]
                dst_path = os.path.join(dest_dir, item["filename"])
                print(f"[{idx}/{len(selected_items)}] Copying: {WHITE}{item['filename']}{NC}")
                try:
                    copy_local_file_with_progress(src_path, dst_path)
                    success_count += 1
                    bytes_transferred += item["size"]
                    log_entries.append(f"SUCCESS (LOCAL): {src_path} -> {dst_path} ({human_size(item['size'])})")
                except Exception as e:
                    fail_count += 1
                    print(f"{RED}Error copying file: {e}{NC}")
                    log_entries.append(f"FAILED (LOCAL): {src_path} - Error: {e}")
                    
            # 2. Process SMB Files (batch via rclone)
            if smb_items:
                # Group by rclone remote
                by_remote = {}
                for s_item in smb_items:
                    rem = s_item["rclone_remote"]
                    by_remote.setdefault(rem, []).append(s_item)
                    
                for rem, items in by_remote.items():
                    print(f"\nImporting {len(items)} file(s) from SMB share via rclone...")
                    import tempfile
                    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as tf:
                        temp_list_path = tf.name
                        for it in items:
                            tf.write(f"{it['path']}\n")
                            
                    cmd = [
                        "rclone", "copy", rem, dest_dir,
                        "--files-from-raw", temp_list_path,
                        "--progress",
                        "--log-file", log_file,
                        "--log-level", "INFO"
                    ]
                    try:
                        res = subprocess.run(cmd)
                        if res.returncode == 0:
                            success_count += len(items)
                            bytes_transferred += sum(it["size"] for it in items)
                            for it in items:
                                log_entries.append(f"SUCCESS (SMB): {rem}{it['path']} -> {dest_dir} ({human_size(it['size'])})")
                        else:
                            fail_count += len(items)
                            log_entries.append(f"FAILED (SMB BATCH): rclone exit code {res.returncode}")
                    except Exception as e:
                        fail_count += len(items)
                        log_entries.append(f"FAILED (SMB BATCH): {e}")
                    finally:
                        if os.path.exists(temp_list_path):
                            os.remove(temp_list_path)
                            
            elapsed = max(1, int(time.time() - start_time))
            mins = elapsed // 60
            secs = elapsed % 60
            
            summary = [
                "",
                "==================================================",
                "IMPORT EXECUTION REPORT",
                "==================================================",
                f"Status:            {'SUCCESS' if fail_count == 0 else 'COMPLETED WITH WARNINGS'}",
                f"Total Imported:    {success_count} file(s)",
                f"Failed:            {fail_count} file(s)",
                f"Data Volume:       {human_size(bytes_transferred)}",
                f"Duration:          {mins}m {secs}s",
                f"Destination:       {dest_dir}",
                f"Audit Log:         {log_file}",
                "=================================================="
            ]
            log_entries.extend(summary)
            log_import_job(log_file, log_entries)
            
            print(f"\n{BOLD}{GREEN}Import Complete!{NC}")
            print("\n".join(summary))
            
            # Check if any WAV was imported and prompt for conversion
            has_wav = any(c["filename"].lower().endswith(".wav") for c in selected_items)
            if has_wav and success_count > 0:
                print(f"\n{BOLD}{YELLOW}New WAV mixes have been imported into the archive.{NC}")
                do_conv = input("Would you like to run the FLAC conversion pipeline now? [Y/n]: ").strip().lower()
                if not do_conv or do_conv in ('y', 'yes'):
                    run_flac_conversion_if_requested(dest_dir)
                    
            input("\nPress Enter to return to main search...")
            break

def main():
    parser = argparse.ArgumentParser(description="Universal Mix Search & Importer (Local Drives & SMB)")
    parser.add_argument("--source", help="Specific directory or SMB URL to scan")
    parser.add_argument("--dest", help="Destination archive directory")
    parser.add_argument("--min-size", type=int, default=100, help="Minimum file size in MB (default: 100)")
    parser.add_argument("--batch", action="store_true", help="Batch import all new mixes without prompting")
    parser.add_argument("--auto-convert", action="store_true", help="Automatically trigger FLAC conversion post-import")
    
    args = parser.parse_args()
    
    if not args.source and not args.batch:
        interactive_ui()
    else:
        env_vars = load_config_env()
        dest_dir = args.dest or get_destination_dir(env_vars)
        existing_bases, existing_keys = get_existing_archive_keys(dest_dir)
        print(f"Scanning source: {args.source} for mixes >= {args.min_size} MB...")
        candidates = scan_local_path(args.source, args.min_size, DEFAULT_AUDIO_EXTS, existing_bases, existing_keys)
        new_items = [c for c in candidates if not c["is_existing"]]
        print(f"Found {len(candidates)} total mixes, {len(new_items)} new.")
        if args.batch:
            for item in new_items:
                dst = os.path.join(dest_dir, item["filename"])
                print(f"Importing: {item['filename']}")
                copy_local_file_with_progress(item["path"], dst)
            if args.auto_convert and any(i["filename"].lower().endswith(".wav") for i in new_items):
                run_flac_conversion_if_requested(dest_dir)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{YELLOW}Operation interrupted by user.{NC}")
        sys.exit(0)
