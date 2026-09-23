#!/usr/bin/env python3
"""
scripts/generate_traktor_playlist_from_history.py - Traktor Playlist Generator from History Files
Exclusively supported on macOS.
- Scans Traktor Pro 3 History files (.nml)
- Displays available history sessions
- Allows viewing history tracklist in console before committing
- Arranges tracks in Key Field Ascending order
- Injects playlist into Traktor's collection.nml under root Playlists folder ($ROOT)
- Optionally launches Traktor in Full Screen and loads first 4 tracks into Decks A-D
"""

import os
import sys
import glob
import re
import uuid
import time
import shutil
import platform
import subprocess
import xml.etree.ElementTree as ET

# ANSI Colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"

def get_traktor_version():
    """Detect installed Traktor version on macOS."""
    app_candidates = [
        "/Applications/Native Instruments/Traktor Pro 3/Traktor.app/Contents/Info.plist",
        "/Applications/Native Instruments/Traktor 3/Traktor.app/Contents/Info.plist",
        "/Applications/Traktor Pro 3.app/Contents/Info.plist",
        "/Applications/Traktor.app/Contents/Info.plist",
    ]
    for plist in app_candidates:
        if os.path.isfile(plist):
            try:
                out = subprocess.check_output(
                    ["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString", plist],
                    stderr=subprocess.DEVNULL, text=True
                ).strip()
                ver = out.split()[0]
                if ver:
                    return ver
            except Exception:
                pass

    # Check Documents directory name
    base = os.path.expanduser("~/Documents/Native Instruments")
    if os.path.isdir(base):
        tdirs = sorted([d for d in os.listdir(base) if d.startswith("Traktor 3") and os.path.isdir(os.path.join(base, d))])
        if tdirs:
            return tdirs[-1].replace("Traktor ", "").strip()

    return "3"

def find_traktor_user_dir():
    """Locate the active Traktor user directory containing collection.nml and History."""
    base = os.path.expanduser("~/Documents/Native Instruments")
    if not os.path.isdir(base):
        return None
    tdirs = sorted(
        [os.path.join(base, d) for d in os.listdir(base) if d.startswith("Traktor 3") and os.path.isdir(os.path.join(base, d))],
        key=os.path.getmtime,
        reverse=True
    )
    if tdirs:
        return tdirs[0]
    return None

def is_traktor_running():
    """Check if Traktor is currently running on the system."""
    try:
        out = subprocess.check_output(["pgrep", "-x", "Traktor"], stderr=subprocess.DEVNULL)
        return bool(out.strip())
    except Exception:
        return False

def quit_traktor():
    """Gracefully quit Traktor on macOS so it flushes collection cleanly."""
    try:
        subprocess.run(["osascript", "-e", 'tell application "Traktor" to quit'], check=False)
        for _ in range(10):
            if not is_traktor_running():
                return True
            time.sleep(0.5)
    except Exception:
        pass
    return not is_traktor_running()

def parse_history_file(hf_path):
    """Parse a Traktor history NML file to extract all track metadata and playlist sequence."""
    try:
        tree = ET.parse(hf_path)
        root = tree.getroot()
    except Exception as e:
        print(f"{RED}Error reading XML from {hf_path}: {e}{NC}")
        return [], []

    # Map collection tracks by primary key
    track_db = {}
    col = root.find("COLLECTION")
    if col is not None:
        for entry in col.findall("ENTRY"):
            title = entry.attrib.get("TITLE", "Unknown Title")
            artist = entry.attrib.get("ARTIST", "Unknown Artist")
            loc = entry.find("LOCATION")
            info = entry.find("INFO")
            tempo = entry.find("TEMPO")
            mkey = entry.find("MUSICAL_KEY")

            pkey = None
            if loc is not None:
                vol = loc.attrib.get("VOLUME", "")
                directory = loc.attrib.get("DIR", "")
                file_name = loc.attrib.get("FILE", "")
                pkey = f"{vol}{directory}{file_name}"

            key_str = info.attrib.get("KEY", "") if info is not None else ""
            mval = -1
            if mkey is not None:
                try:
                    mval = int(mkey.attrib.get("VALUE", -1))
                except Exception:
                    pass

            bpm = 0.0
            if tempo is not None and "BPM" in tempo.attrib:
                try:
                    bpm = float(tempo.attrib.get("BPM", 0.0))
                except Exception:
                    pass

            dur = 0
            if info is not None and "PLAYTIME" in info.attrib:
                try:
                    dur = int(float(info.attrib.get("PLAYTIME", 0)))
                except Exception:
                    pass

            if pkey:
                track_db[pkey] = {
                    "title": title,
                    "artist": artist,
                    "key": key_str,
                    "mval": mval,
                    "bpm": bpm,
                    "duration": dur,
                    "pkey": pkey,
                    "entry_elem": entry
                }

    # Extract played sequence from PLAYLIST
    pl_node = root.find(".//PLAYLIST")
    history_tracks = []
    if pl_node is not None:
        for e in pl_node.findall("ENTRY"):
            pk = e.find("PRIMARYKEY")
            if pk is not None:
                k = pk.attrib.get("KEY", "")
                track = track_db.get(k)
                if not track:
                    track = {
                        "title": os.path.basename(k),
                        "artist": "Unknown Artist",
                        "key": "",
                        "mval": -1,
                        "bpm": 0.0,
                        "duration": 0,
                        "pkey": k,
                        "entry_elem": None
                    }
                history_tracks.append(track)

    return history_tracks, list(track_db.values())

def key_sort_rank(track):
    """
    Sorting rank for Traktor Key Field Ascending order:
    1. Open Key / Camelot (1m, 1d, 2m, 2d ... 12m, 12d / 1A, 1B ... 12A, 12B)
    2. Musical key value (0 to 23)
    3. Musical key string (A, Am, B, Bm, C, Cm...)
    """
    k = (track.get("key") or "").strip()
    m = re.match(r"^(\d{1,2})([a-zA-Z]?)$", k)
    if m:
        num = int(m.group(1))
        letter = m.group(2).lower()
        return (0, num, letter, track.get("title", ""))

    mv = track.get("mval", -1)
    if mv >= 0:
        return (1, mv, "", track.get("title", ""))

    if k:
        return (2, k.lower(), "", track.get("title", ""))

    return (3, 999, "", track.get("title", ""))

def format_duration(sec):
    """Format duration in mm:ss."""
    m = sec // 60
    s = sec % 60
    return f"{m:02d}:{s:02d}"

def display_history_tracklist(hf_name, tracks, sorted_tracks):
    """Display a clean formatted table of tracks in console."""
    os.system("clear 2>/dev/null || true")
    print(f"{BOLD}{MAGENTA}========================================================================================================{NC}")
    print(f"{BOLD}{CYAN}                          TRAKTOR HISTORY TRACKLIST: {hf_name}{NC}")
    print(f"{BOLD}{MAGENTA}========================================================================================================{NC}")
    print(f" {BOLD}{'#':<3} {'KEY':<5} {'BPM':<7} {'TIME':<7} {'ARTIST':<32} {'TITLE':<42}{NC}")
    print(f"{BLUE}────────────────────────────────────────────────────────────────────────────────────────────────────────{NC}")

    for i, t in enumerate(tracks, 1):
        art = t["artist"][:30]
        tit = t["title"][:40]
        k = t["key"] or (f"K{t['mval']}" if t.get("mval", -1) >= 0 else "-")
        bpm_str = f"{t['bpm']:.1f}" if t['bpm'] > 0 else "-"
        dur_str = format_duration(t["duration"]) if t["duration"] > 0 else "-"
        print(f" {i:<3} {k:<5} {bpm_str:<7} {dur_str:<7} {art:<32} {tit:<42}")

    print(f"{BLUE}────────────────────────────────────────────────────────────────────────────────────────────────────────{NC}")
    print(f"{BOLD}{YELLOW}Preview: First 4 tracks when arranged in Key Field Ascending Order (ready for Decks A-D):{NC}")
    deck_labels = ["Deck A", "Deck B", "Deck C", "Deck D"]
    for i, d_label in enumerate(deck_labels):
        if i < len(sorted_tracks):
            st = sorted_tracks[i]
            sk = st["key"] or (f"K{st['mval']}" if st.get("mval", -1) >= 0 else "-")
            sb = f"{st['bpm']:.1f}" if st['bpm'] > 0 else "-"
            print(f"  {BOLD}{GREEN}• {d_label}:{NC} [{BOLD}{sk:3s}{NC} | {sb:5s} BPM] {st['artist']} - {st['title']}")
    print(f"{BOLD}{MAGENTA}========================================================================================================{NC}\n")

def insert_playlist_into_collection(collection_nml_path, playlist_name, sorted_tracks):
    """Insert a new playlist into Traktor's collection.nml under $ROOT."""
    if not os.path.isfile(collection_nml_path):
        print(f"{RED}Error: collection.nml not found at {collection_nml_path}!{NC}")
        return False

    # 1. Backup collection.nml
    ts = time.strftime("%Y%m%d_%H%M%S")
    backup_path = f"{collection_nml_path}.bak_{ts}"
    shutil.copy2(collection_nml_path, backup_path)
    print(f"  {GREEN}✓ Backed up collection to:{NC} {os.path.basename(backup_path)}")

    # 2. Parse collection.nml
    try:
        tree = ET.parse(collection_nml_path)
        root = tree.getroot()
    except Exception as e:
        print(f"{RED}Error parsing collection.nml: {e}{NC}")
        return False

    # 3. Find <PLAYLISTS><NODE TYPE="FOLDER" NAME="$ROOT"><SUBNODES>
    playlists_node = root.find("PLAYLISTS")
    if playlists_node is None:
        playlists_node = ET.SubElement(root, "PLAYLISTS")

    root_folder = None
    for n in playlists_node.findall("NODE"):
        if n.attrib.get("TYPE") == "FOLDER" and n.attrib.get("NAME") == "$ROOT":
            root_folder = n
            break

    if root_folder is None:
        root_folder = ET.SubElement(playlists_node, "NODE", {"TYPE": "FOLDER", "NAME": "$ROOT"})

    subnodes = root_folder.find("SUBNODES")
    if subnodes is None:
        subnodes = ET.SubElement(root_folder, "SUBNODES")

    # Remove existing playlist with same name if present
    for node in list(subnodes.findall("NODE")):
        if node.attrib.get("TYPE") == "PLAYLIST" and node.attrib.get("NAME") == playlist_name:
            subnodes.remove(node)
            print(f"  {YELLOW}Replaced existing playlist with name '{playlist_name}'.{NC}")

    # Build new playlist node
    pl_node = ET.SubElement(subnodes, "NODE", {"TYPE": "PLAYLIST", "NAME": playlist_name})
    new_uuid = uuid.uuid4().hex
    pl_content = ET.SubElement(pl_node, "PLAYLIST", {
        "ENTRIES": str(len(sorted_tracks)),
        "TYPE": "LIST",
        "UUID": new_uuid
    })

    # Also check if any track needs to be in <COLLECTION>
    col_node = root.find("COLLECTION")
    existing_keys = set()
    if col_node is not None:
        for entry in col_node.findall("ENTRY"):
            loc = entry.find("LOCATION")
            if loc is not None:
                existing_keys.add(f"{loc.attrib.get('VOLUME', '')}{loc.attrib.get('DIR', '')}{loc.attrib.get('FILE', '')}")

    for t in sorted_tracks:
        e = ET.SubElement(pl_content, "ENTRY")
        ET.SubElement(e, "PRIMARYKEY", {"TYPE": "TRACK", "KEY": t["pkey"]})
        # Add to collection if missing and entry_elem exists
        if col_node is not None and t["pkey"] not in existing_keys and t.get("entry_elem") is not None:
            col_node.append(t["entry_elem"])
            existing_keys.add(t["pkey"])

    if col_node is not None:
        col_node.attrib["ENTRIES"] = str(len(col_node.findall("ENTRY")))

    # 4. Write back collection.nml with XML declaration
    try:
        tree.write(collection_nml_path, encoding="utf-8", xml_declaration=True)
        print(f"  {GREEN}✓ Successfully wrote playlist into Traktor collection.nml!{NC}")
        return True
    except Exception as e:
        print(f"{RED}Error writing updated collection.nml: {e}{NC}")
        shutil.copy2(backup_path, collection_nml_path)
        return False

def update_traktor_settings_tsi(traktor_dir, playlist_name):
    """Configure Traktor Settings.tsi to boot in Full Screen and select the new playlist."""
    tsi_path = os.path.join(traktor_dir, "Traktor Settings.tsi")
    if not os.path.isfile(tsi_path):
        return

    try:
        tree = ET.parse(tsi_path)
        root = tree.getroot()
        ts = root.find("TraktorSettings")
        if ts is not None:
            # Full Screen On Startup = 1
            fs_entry = None
            sel_entry = None
            for child in ts.findall("Entry"):
                name = child.attrib.get("Name", "")
                if name == "Misc.Fullscreen.OnStartup":
                    fs_entry = child
                elif name == "Browser.Tree.SelectedPath":
                    sel_entry = child

            if fs_entry is not None:
                fs_entry.attrib["Value"] = "1"
            else:
                ET.SubElement(ts, "Entry", {"Name": "Misc.Fullscreen.OnStartup", "Type": "0", "Value": "1"})

            pl_path_val = f"$PLAYLIST/t{playlist_name}"
            if sel_entry is not None:
                sel_entry.attrib["Value"] = pl_path_val
            else:
                ET.SubElement(ts, "Entry", {"Name": "Browser.Tree.SelectedPath", "Type": "3", "Value": pl_path_val})

            tree.write(tsi_path, encoding="utf-8", xml_declaration=True)
            print(f"  {GREEN}✓ Configured Traktor Settings: Full Screen on Startup & Select Playlist.{NC}")
    except Exception:
        pass

def launch_traktor_and_load_decks(traktor_dir, playlist_name, top_tracks):
    """Launch Traktor in Full Screen and load top 4 tracks into Decks A, B, C, D."""
    update_traktor_settings_tsi(traktor_dir, playlist_name)

    print(f"\n{BOLD}{YELLOW}Launching Native Instruments Traktor Pro in Full Screen...{NC}")
    subprocess.run(["open", "-a", "Traktor"], check=False)

    print(f"{CYAN}Waiting for Traktor interface to initialize...{NC}")
    time.sleep(3.5)

    # AppleScript to verify full screen and load top 4 tracks into Decks A, B, C, D
    ascript = """
tell application "Traktor" to activate
delay 1.5
tell application "System Events"
    tell process "Traktor"
        -- Ensure Full Screen
        try
            set value of attribute "AXFullScreen" of window 1 to true
        end try
        delay 0.8

        -- Move to top of browser playlist
        key code 126
        delay 0.1
        key code 126
        delay 0.1
        key code 126
        delay 0.2

        -- Load Track 1 -> Deck A (Cmd + Left Arrow)
        key code 123 using {command down}
        delay 0.5

        -- Load Track 2 -> Deck B (Down Arrow, then Cmd + Right Arrow)
        key code 125
        delay 0.2
        key code 124 using {command down}
        delay 0.5

        -- Load Track 3 -> Deck C (Down Arrow, then Cmd + Shift + Left Arrow)
        key code 125
        delay 0.2
        key code 123 using {command down, shift down}
        delay 0.5

        -- Load Track 4 -> Deck D (Down Arrow, then Cmd + Shift + Right Arrow)
        key code 125
        delay 0.2
        key code 124 using {command down, shift down}
        delay 0.5

        -- Reset selection back to top
        key code 126
        delay 0.1
        key code 126
        delay 0.1
        key code 126
    end tell
end tell
"""
    try:
        res = subprocess.run(["osascript", "-e", ascript], capture_output=True, text=True, check=False)
        if res.returncode == 0:
            print(f"\n{BOLD}{GREEN}======================================================================{NC}")
            print(f"{BOLD}{GREEN}✓ Traktor Pro is running in Full Screen!{NC}")
            print(f"{BOLD}{GREEN}✓ Top 4 Key-Arranged Tracks Loaded into Decks A, B, C, D!{NC}")
            for i, d in enumerate(["Deck A", "Deck B", "Deck C", "Deck D"]):
                if i < len(top_tracks):
                    t = top_tracks[i]
                    k = t["key"] or (f"K{t['mval']}" if t.get("mval", -1) >= 0 else "-")
                    print(f"  • {BOLD}{d}:{NC} [{k}] {t['artist']} - {t['title']}")
            print(f"{BOLD}{GREEN}======================================================================{NC}\n")
        else:
            print(f"\n{YELLOW}Note: AppleScript deck load completed with status: {res.stderr.strip() or 'OK'}{NC}")
            print(f"Traktor is opened with the playlist selected in the browser tree.")
    except Exception as e:
        print(f"{YELLOW}Warning: UI deck loading automation reported: {e}{NC}")

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--version-only":
        print(get_traktor_version())
        return

    if platform.system() != "Darwin":
        print(f"\n{BOLD}{RED}═══════════════════════════════════════════════════════════════════════════════{NC}")
        print(f"{BOLD}{RED}            ⚠️  PLATFORM NOT SUPPORTED FOR TRAKTOR PLAYLISTS ⚠️                 {NC}")
        print(f"{BOLD}{RED}═══════════════════════════════════════════════════════════════════════════════{NC}")
        print(f"  • {BOLD}Platform:{NC}      {platform.system()}")
        print(f"  • {BOLD}Notice:{NC}        Traktor Pro does not run on Linux natively.")
        print(f"                   This feature is exclusively supported on {BOLD}{GREEN}macOS{NC}.")
        print(f"{BOLD}{RED}═══════════════════════════════════════════════════════════════════════════════{NC}\n")
        input("Press [Enter] to return...")
        return

    traktor_ver = get_traktor_version()
    traktor_dir = find_traktor_user_dir()

    if not traktor_dir or not os.path.isdir(traktor_dir):
        print(f"{RED}Error: Traktor user folder not found in ~/Documents/Native Instruments!{NC}")
        input("Press [Enter] to return...")
        return

    history_dir = os.path.join(traktor_dir, "History")
    collection_nml = os.path.join(traktor_dir, "collection.nml")

    if not os.path.isdir(history_dir):
        print(f"{RED}Error: History folder not found at {history_dir}!{NC}")
        input("Press [Enter] to return...")
        return

    # Scan history files sorted newest first
    hfiles = sorted(glob.glob(os.path.join(history_dir, "history_*.nml")), key=os.path.getmtime, reverse=True)
    if not hfiles:
        print(f"{YELLOW}No Traktor History (.nml) files found in {history_dir}.{NC}")
        input("Press [Enter] to return...")
        return

    page = 0
    page_size = 15

    while True:
        os.system("clear 2>/dev/null || true")
        print(f"{BOLD}{MAGENTA}==================================================================================={NC}")
        print(f"{BOLD}{MAGENTA}       TRAKTOR {traktor_ver}: GENERATE PLAYLIST FROM HISTORY DATABASE               {NC}")
        print(f"{BOLD}{MAGENTA}==================================================================================={NC}")
        print(f"  {BOLD}Traktor Directory:{NC} {traktor_dir}")
        print(f"  {BOLD}Total History Files:{NC} {len(hfiles)}")
        print(f"{BLUE}───────────────────────────────────────────────────────────────────────────────────{NC}\n")

        start_idx = page * page_size
        end_idx = min(start_idx + page_size, len(hfiles))

        print(f"{BOLD}Select a History Session to Generate Playlist [Page {page + 1} of {(len(hfiles) + page_size - 1) // page_size}]:{NC}")
        for i in range(start_idx, end_idx):
            hf = hfiles[i]
            fname = os.path.basename(hf)
            m = re.search(r"history_(\d{4})y(\d{2})m(\d{2})d_(\d{2})h(\d{2})m(\d{2})s", fname)
            dt_str = f"{m.group(1)}-{m.group(2)}-{m.group(3)} {m.group(4)}:{m.group(5)}:{m.group(6)}" if m else "Unknown Date"
            
            # Quick track count
            track_cnt = "?"
            try:
                with open(hf, "r", errors="ignore") as f:
                    content_chunk = f.read(65536)
                    cnt_m = re.search(r'<(?:COLLECTION|PLAYLIST)\s+ENTRIES=[\x27\x22](\d+)[\x27\x22]', content_chunk)
                    if cnt_m:
                        track_cnt = cnt_m.group(1)
            except Exception:
                pass

            print(f"  {BOLD}{CYAN}{i + 1:2d}){NC} {dt_str}  ({track_cnt:>2s} tracks)  {DIM}{fname}{NC}")

        print(f"\n{BLUE}───────────────────────────────────────────────────────────────────────────────────{NC}")
        nav_options = []
        if end_idx < len(hfiles):
            nav_options.append(f"{BOLD}[N]{NC}ext Page")
        if page > 0:
            nav_options.append(f"{BOLD}[P]{NC}revious Page")
        nav_options.append(f"{BOLD}[Q]{NC}uit / Return")
        print(f"  Options: {' | '.join(nav_options)}")
        print(f"{BLUE}───────────────────────────────────────────────────────────────────────────────────{NC}")

        choice = input(f"Enter choice [1-{len(hfiles)}, N, P, Q]: ").strip()

        if choice.lower() == 'q' or choice == '0':
            return
        elif choice.lower() == 'n' and end_idx < len(hfiles):
            page += 1
            continue
        elif choice.lower() == 'p' and page > 0:
            page -= 1
            continue

        if not choice.isdigit() or int(choice) < 1 or int(choice) > len(hfiles):
            print(f"{RED}Invalid selection.{NC}")
            time.sleep(1)
            continue

        chosen_idx = int(choice) - 1
        chosen_hf = hfiles[chosen_idx]
        chosen_name = os.path.basename(chosen_hf)

        # Parse the chosen history session
        print(f"\n{CYAN}Reading tracks from {chosen_name}...{NC}")
        history_tracks, all_col = parse_history_file(chosen_hf)

        if not history_tracks:
            print(f"{RED}No tracks found in {chosen_name}!{NC}")
            input("Press [Enter] to continue...")
            continue

        # Sort in Key Field Ascending order
        sorted_tracks = sorted(history_tracks, key=key_sort_rank)

        # Prompt user: View or Generate
        while True:
            os.system("clear 2>/dev/null || true")
            print(f"{BOLD}{MAGENTA}==================================================================================={NC}")
            print(f"{BOLD}{CYAN}  SELECTED HISTORY FILE: {chosen_name}{NC}")
            print(f"  Tracks in session: {BOLD}{len(history_tracks)}{NC}")
            print(f"{BOLD}{MAGENTA}==================================================================================={NC}\n")
            print(f"  {BOLD}{CYAN}1){NC} {BOLD}View Tracklist in Console{NC} (Inspect tracks, keys, BPM before generating)")
            print(f"  {BOLD}{CYAN}2){NC} {BOLD}{GREEN}Commit & Generate Traktor Playlist in Key Field Ascending Order{NC}")
            print(f"  {BOLD}{CYAN}3){NC} Select a Different History File")
            print(f"  {BOLD}{CYAN}0){NC} Return to Main Menu\n")

            sub_choice = input("Enter choice [1-3, 0 to cancel]: ").strip()

            if sub_choice == '1':
                display_history_tracklist(chosen_name, history_tracks, sorted_tracks)
                commit_choice = input("Commit to generating Traktor Playlist from this History? [Y/n]: ").strip()
                if commit_choice.lower() in ['', 'y', 'yes']:
                    sub_choice = '2'
                else:
                    continue

            if sub_choice == '2':
                # Derive default playlist name
                m = re.search(r"history_(\d{4})y(\d{2})m(\d{2})d_(\d{2})h(\d{2})m(\d{2})s", chosen_name)
                if m:
                    default_pl_name = f"SOF Mix {m.group(1)}-{m.group(2)}-{m.group(3)} ({m.group(4)}h{m.group(5)}m)"
                else:
                    default_pl_name = f"History Playlist {time.strftime('%Y-%m-%d')}"

                print("")
                user_pl_name = input(f"Enter Traktor Playlist Name [Default: '{default_pl_name}']: ").strip()
                final_pl_name = user_pl_name if user_pl_name else default_pl_name

                # Check if Traktor is currently running
                if is_traktor_running():
                    print(f"\n{BOLD}{YELLOW}⚠️  Traktor Pro is currently running!{NC}")
                    print("Traktor holds its collection in memory while open. It must be closed to safely save the new playlist.")
                    close_ask = input("Close Traktor cleanly now so the playlist can be written? [Y/n]: ").strip()
                    if close_ask.lower() in ['', 'y', 'yes']:
                        print(f"{CYAN}Closing Traktor...{NC}")
                        if not quit_traktor():
                            print(f"{RED}Could not close Traktor automatically. Please close Traktor manually and try again.{NC}")
                            input("Press [Enter] to continue...")
                            break
                        print(f"{GREEN}✓ Traktor closed safely.{NC}")
                    else:
                        print(f"{YELLOW}Operation cancelled to avoid database conflicts.{NC}")
                        input("Press [Enter] to continue...")
                        break

                print(f"\n{CYAN}Generating playlist '{final_pl_name}' with {len(sorted_tracks)} tracks in Key Ascending order...{NC}")
                success = insert_playlist_into_collection(collection_nml, final_pl_name, sorted_tracks)

                if success:
                    update_traktor_settings_tsi(traktor_dir, final_pl_name)
                    print(f"\n{BOLD}{GREEN}======================================================================{NC}")
                    print(f"{BOLD}{GREEN}✓ Playlist '{final_pl_name}' is Ready in Traktor's Default Root Playlists!{NC}")
                    print(f"  • Total Tracks: {len(sorted_tracks)}")
                    print(f"  • Sorting: Key Field Ascending Order")
                    print(f"{BOLD}{GREEN}======================================================================{NC}\n")

                    # Ask user if they want to launch Traktor now
                    launch_ask = input(f"{BOLD}Do you want to open the playlist in Traktor now ready to make a mix? [Y/n]: {NC}").strip()
                    if launch_ask.lower() in ['', 'y', 'yes']:
                        launch_traktor_and_load_decks(traktor_dir, final_pl_name, sorted_tracks[:4])

                input("Press [Enter] to continue...")
                return

            elif sub_choice == '3':
                break
            elif sub_choice in ['0', 'q']:
                return

if __name__ == '__main__':
    main()
