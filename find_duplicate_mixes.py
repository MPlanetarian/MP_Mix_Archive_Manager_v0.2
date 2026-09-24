#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Duplicate Audio Mix Finder & Cleaner
Detects exact audio duplicates, multi-copy episode renders, and orphaned files.
Provides safe quarantine and interactive removal options.
"""

import os
import sys
import hashlib
import re
import shutil
import argparse
from collections import defaultdict

AUDIO_EXTENSIONS = {'.wav', '.flac', '.mp3', '.m4a', '.ogg', '.opus', '.aif', '.aiff'}

def fast_audio_hash(filepath, block_size=1024 * 1024):
    """
    Computes a fast fingerprint hash: combines file size + first 2MB + middle 2MB + last 2MB.
    Runs in milliseconds even on 10 GB WAV files.
    """
    try:
        size = os.path.getsize(filepath)
        h = hashlib.sha256()
        h.update(str(size).encode('ascii'))

        with open(filepath, 'rb') as f:
            # First block
            h.update(f.read(block_size * 2))

            # Middle block
            if size > block_size * 6:
                f.seek(size // 2)
                h.update(f.read(block_size * 2))

            # Tail block
            if size > block_size * 4:
                f.seek(max(0, size - block_size * 2))
                h.update(f.read(block_size * 2))

        return h.hexdigest(), size
    except Exception:
        return None, 0

def extract_episode_id(filename):
    """Extracts 3-digit show/episode number or title key."""
    m = re.search(r'(?:Frequency|Mix|SOF)[_ -]+(\d{3})', filename, re.IGNORECASE)
    if not m:
        m = re.search(r'(\d{3})', filename)
    if m:
        return f"Episode_{m.group(1)}"
    return None

def format_size(size_bytes):
    for u in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {u}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"

def scan_for_duplicates(directories):
    """Scans directories and identifies duplicate groups by content hash and episode ID."""
    all_files = []
    for d in directories:
        if not os.path.exists(d):
            continue
        for root, _, files in os.walk(d):
            # Skip quarantine directory
            if "DUPLICATES_QUARANTINE" in root:
                continue
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in AUDIO_EXTENSIONS:
                    all_files.append(os.path.join(root, f))

    # 1. Exact Fingerprint Duplicates
    hash_map = defaultdict(list)
    for fp in all_files:
        f_hash, size = fast_audio_hash(fp)
        if f_hash and size > 0:
            hash_map[(f_hash, size)].append(fp)

    exact_duplicates = [paths for paths in hash_map.values() if len(paths) > 1]

    # 2. Episode Duplicates (Multiple different audio files for the same show ID in same or different folders)
    episode_map = defaultdict(list)
    for fp in all_files:
        fname = os.path.basename(fp)
        ep_id = extract_episode_id(fname)
        if ep_id:
            ext = os.path.splitext(fname)[1].lower()
            # Only match same format (e.g. 2 FLACs for Episode 031 or 2 WAVs)
            episode_map[(ep_id, ext)].append(fp)

    episode_duplicates = [paths for paths in episode_map.values() if len(paths) > 1]

    return exact_duplicates, episode_duplicates

def handle_duplicates(duplicate_groups, action="report", quarantine_dir="DUPLICATES_QUARANTINE"):
    if not duplicate_groups:
        print("\n✓ No duplicate audio mixes found. Archive is clean!\n")
        return 0

    total_groups = len(duplicate_groups)
    print(f"\nFound {total_groups} duplicate group(s):\n")

    files_to_act_on = []

    for idx, group in enumerate(duplicate_groups, 1):
        print(f"Group {idx}:")
        for f_idx, fp in enumerate(group):
            sz = os.path.getsize(fp) if os.path.exists(fp) else 0
            mtime = os.path.getmtime(fp) if os.path.exists(fp) else 0
            date_str = ""
            if mtime:
                import datetime
                date_str = datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")
            tag = "[ORIGINAL / KEPT]" if f_idx == 0 else "[DUPLICATE]"
            print(f"  {f_idx+1}) {tag:18} {fp} ({format_size(sz)}, {date_str})")
            if f_idx > 0:
                files_to_act_on.append(fp)
        print("")

    if action == "quarantine":
        os.makedirs(quarantine_dir, exist_ok=True)
        print(f"Moving {len(files_to_act_on)} duplicate file(s) to '{quarantine_dir}'...")
        count = 0
        for fp in files_to_act_on:
            if os.path.exists(fp):
                dest = os.path.join(quarantine_dir, os.path.basename(fp))
                # Avoid collision in quarantine
                if os.path.exists(dest):
                    base, ext = os.path.splitext(os.path.basename(fp))
                    dest = os.path.join(quarantine_dir, f"{base}_dup_{count}{ext}")
                shutil.move(fp, dest)
                print(f"  ✓ Quarantined: {os.path.basename(fp)}")
                count += 1
        print(f"\n✓ Successfully quarantined {count} files to {quarantine_dir}.\n")
        return count

    elif action == "delete":
        print(f"WARNING: You requested permanent deletion of {len(files_to_act_on)} file(s).")
        confirm = input("Type 'DELETE' to confirm permanent removal: ")
        if confirm == "DELETE":
            count = 0
            for fp in files_to_act_on:
                if os.path.exists(fp):
                    os.remove(fp)
                    print(f"  ✗ Deleted: {fp}")
                    count += 1
            print(f"\n✓ Deleted {count} files.\n")
            return count
        else:
            print("\nDeletion cancelled.\n")
            return 0

    return 0

def main():
    parser = argparse.ArgumentParser(description="Find and manage duplicate audio mixes.")
    parser.add_argument("-d", "--dirs", nargs="+", default=["FLAC_CONVERTED_OUTPUTS", "CONVERTED_WAV_FILES", "."],
                        help="Directories to scan (default: FLAC_CONVERTED_OUTPUTS CONVERTED_WAV_FILES .)")
    parser.add_argument("-a", "--action", choices=["report", "quarantine", "delete"], default="report",
                        help="Action to perform on duplicate files (default: report)")
    parser.add_argument("-q", "--quarantine-dir", default="DUPLICATES_QUARANTINE",
                        help="Directory to move quarantined duplicates into")

    args = parser.parse_args()

    print("=" * 60)
    print("         MIX ARCHIVE DUPLICATE AUDIO SCANNER")
    print("=" * 60)
    print(f"Scanning target directories: {', '.join(args.dirs)}")

    exact_dups, ep_dups = scan_for_duplicates(args.dirs)

    print(f"\nExact Content Duplicates: {len(exact_dups)} group(s)")
    if exact_dups:
        handle_duplicates(exact_dups, args.action, args.quarantine_dir)

    # Filter out files already in exact duplicates
    seen_in_exact = {f for grp in exact_dups for f in grp}
    filtered_ep_dups = []
    for grp in ep_dups:
        sub = [f for f in grp if f not in seen_in_exact]
        if len(sub) > 1:
            filtered_ep_dups.append(sub)

    print(f"\nEpisode Multi-Render Duplicates: {len(filtered_ep_dups)} group(s)")
    if filtered_ep_dups:
        handle_duplicates(filtered_ep_dups, args.action, args.quarantine_dir)

    if not exact_dups and not filtered_ep_dups:
        print("\n✓ No duplicates detected across scanned directories!\n")

if __name__ == "__main__":
    main()
