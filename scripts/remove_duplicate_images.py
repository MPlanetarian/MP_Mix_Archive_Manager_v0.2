#!/usr/bin/env python3
"""
remove_duplicate_images.py

Scans a directory of images and removes duplicate images that are byte-for-byte identical.
Prompts the user for the directory path upon starting.

Features:
  - Supports common image formats (.jpg, .jpeg, .png, .webp, .bmp, .gif, .tiff, .tif, .avif, .heic, .heif, .svg, .ico, .jfif)
  - Interactive prompt for directory path (with quote-stripping for drag-and-drop)
  - Optional recursive scanning of subdirectories
  - High-performance multi-stage comparison:
      1. File size grouping (instant filter, ignores unique file sizes)
      2. Chunked SHA-256 cryptographic hashing (efficient memory usage)
      3. Exact byte-by-byte verification (filecmp, 100% collision-free guarantee)
  - Smart original selection (preserves earliest/cleanest filename, deletes copies)
  - Detailed duplicate summary with disk space savings
  - Interactive confirmation prompt before permanent deletion
  - CLI argument support (--recursive, --dry-run, --yes)
"""

import os
import sys
import argparse
import hashlib
import filecmp
import time
from pathlib import Path
from typing import List, Dict, Tuple, Set
import re

# Supported image file extensions
SUPPORTED_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif",
    ".tiff", ".tif", ".avif", ".heic", ".heif", ".svg",
    ".ico", ".jfif", ".pjpeg", ".pjp"
}

# Regex pattern to identify copy indicators in filenames
COPY_PATTERN = re.compile(r'(\s*[-_]?copy|\s*\(\d+\)|[_-]\d+$)', re.IGNORECASE)


class Colors:
    """ANSI color codes for formatted terminal output."""
    if sys.stdout.isatty():
        RESET = "\033[0m"
        BOLD = "\033[1m"
        RED = "\033[31m"
        GREEN = "\033[32m"
        YELLOW = "\033[33m"
        BLUE = "\033[34m"
        MAGENTA = "\033[35m"
        CYAN = "\033[36m"
        DIM = "\033[2m"
    else:
        RESET = ""
        BOLD = ""
        RED = ""
        GREEN = ""
        YELLOW = ""
        BLUE = ""
        MAGENTA = ""
        CYAN = ""
        DIM = ""


def format_size(num_bytes: int) -> str:
    """Formats bytes into human-readable format (B, KB, MB, GB, TB)."""
    n = float(num_bytes)
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(n) < 1024.0 or unit == 'TB':
            return f"{n:.2f} {unit}" if unit != 'B' else f"{int(n)} B"
        n /= 1024.0
    return f"{n:.2f} PB"


def format_mtime(timestamp: float) -> str:
    """Formats epoch timestamp into readable datetime string."""
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(timestamp))


def get_target_directory() -> Path:
    """Prompts the user for a directory path, cleans input, and validates existence."""
    while True:
        try:
            user_input = input(f"{Colors.BOLD}{Colors.CYAN}Enter path to directory containing images: {Colors.RESET}").strip()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{Colors.YELLOW}Operation cancelled by user.{Colors.RESET}")
            sys.exit(0)

        if not user_input:
            print(f"{Colors.RED}Path cannot be empty. Please try again.{Colors.RESET}")
            continue

        if user_input.lower() in ("q", "quit", "exit"):
            print(f"{Colors.YELLOW}Exiting.{Colors.RESET}")
            sys.exit(0)

        # Strip surrounding quotes from terminal drag-and-drop
        cleaned = user_input.strip("\"'")
        path = Path(os.path.expanduser(cleaned)).resolve()

        if not path.exists():
            print(f"{Colors.RED}Error: Path does not exist: '{path}'. Please try again.{Colors.RESET}")
            continue
        if not path.is_dir():
            print(f"{Colors.RED}Error: Path is not a directory: '{path}'. Please try again.{Colors.RESET}")
            continue

        return path


def ask_recursive() -> bool:
    """Asks the user whether to scan subdirectories recursively."""
    while True:
        try:
            ans = input(f"{Colors.BOLD}Scan subdirectories recursively? [y/N] (default: n): {Colors.RESET}").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{Colors.YELLOW}Operation cancelled by user.{Colors.RESET}")
            sys.exit(0)

        if not ans or ans in ('n', 'no'):
            return False
        if ans in ('y', 'yes'):
            return True
        print(f"{Colors.YELLOW}Please enter 'y' or 'n'.{Colors.RESET}")


def find_image_files(directory: Path, recursive: bool = False) -> List[Path]:
    """Discovers all supported image files in the target directory."""
    image_files: List[Path] = []
    iterator = directory.rglob("*") if recursive else directory.glob("*")

    for path in iterator:
        try:
            if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
                image_files.append(path)
        except (OSError, PermissionError) as e:
            print(f"{Colors.YELLOW}Warning: Skipping inaccessible path '{path}': {e}{Colors.RESET}")

    return sorted(image_files)


def compute_sha256(path: Path, chunk_size: int = 131072) -> str:
    """Computes SHA-256 hash of a file in 128KB chunks for memory efficiency."""
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(chunk_size):
            hasher.update(chunk)
    return hasher.hexdigest()


def score_for_original(path: Path) -> Tuple[int, float, int, str]:
    """
    Scoring function to choose the original file to keep.
    Lower score is preferred as the original.
      1. Has copy pattern in filename: 0 for clean name, 1 for copy/duplicate.
      2. Earlier modification time: older file is prioritized as the original.
      3. Shorter filename length.
      4. Alphabetical tie-breaker for deterministic output.
    """
    has_copy = 1 if COPY_PATTERN.search(path.stem) else 0
    try:
        mtime = path.stat().st_mtime
    except OSError:
        mtime = float('inf')
    name_len = len(path.name)
    return (has_copy, mtime, name_len, str(path))


def find_duplicates(image_files: List[Path]) -> List[Tuple[Path, List[Path], int]]:
    """
    Finds byte-for-byte duplicate images using a three-stage filter:
      1. Exact file size grouping
      2. Cryptographic SHA-256 hashing
      3. Full byte-for-byte verification (filecmp.cmp)

    Returns a list of tuples: (original_to_keep, list_of_duplicates_to_delete, file_size_bytes)
    """
    # Stage 1: Group files by file size
    size_map: Dict[int, List[Path]] = {}
    for path in image_files:
        try:
            sz = path.stat().st_size
            # Ignore completely empty 0-byte files or group them
            size_map.setdefault(sz, []).append(path)
        except (OSError, PermissionError):
            continue

    # Filter out sizes with only 1 file (unique sizes cannot be duplicates)
    candidate_size_groups = [group for group in size_map.values() if len(group) > 1]
    if not candidate_size_groups:
        return []

    total_candidates = sum(len(g) for g in candidate_size_groups)
    print(f"Analyzing {total_candidates} files sharing identical file sizes...")

    duplicate_sets: List[Tuple[Path, List[Path], int]] = []

    # Stage 2 & 3: Hash and byte-by-byte compare
    for size_group in candidate_size_groups:
        file_size = size_group[0].stat().st_size

        # Group by SHA-256
        hash_map: Dict[str, List[Path]] = {}
        for path in size_group:
            try:
                h = compute_sha256(path)
                hash_map.setdefault(h, []).append(path)
            except Exception as e:
                print(f"{Colors.YELLOW}Warning: Could not hash '{path.name}': {e}{Colors.RESET}")

        # Byte-by-byte verification for matching hashes
        for hash_val, matching_files in hash_map.items():
            if len(matching_files) < 2:
                continue

            # In rare theoretical case of hash collision, cluster by filecmp
            unprocessed = list(matching_files)
            while len(unprocessed) >= 2:
                cluster = [unprocessed[0]]
                remaining = []
                for candidate in unprocessed[1:]:
                    try:
                        # shallow=False forces full byte-by-byte reading
                        if filecmp.cmp(cluster[0], candidate, shallow=False):
                            cluster.append(candidate)
                        else:
                            remaining.append(candidate)
                    except Exception:
                        remaining.append(candidate)

                if len(cluster) > 1:
                    # Choose the best file as original
                    cluster.sort(key=score_for_original)
                    original = cluster[0]
                    duplicates = cluster[1:]
                    duplicate_sets.append((original, duplicates, file_size))

                unprocessed = remaining

    return duplicate_sets


def confirm_deletion(duplicate_count: int, reclaim_bytes: int) -> bool:
    """Prompts user to confirm deletion of duplicate files."""
    print(f"\n{Colors.BOLD}{Colors.YELLOW}Ready to permanently delete {duplicate_count} duplicate image(s) ({format_size(reclaim_bytes)} space to reclaim).{Colors.RESET}")
    while True:
        try:
            ans = input(f"{Colors.BOLD}{Colors.RED}Proceed with permanent deletion? [y/N]: {Colors.RESET}").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{Colors.YELLOW}Operation cancelled by user.{Colors.RESET}")
            return False

        if ans in ('y', 'yes'):
            return True
        if not ans or ans in ('n', 'no'):
            return False
        print(f"{Colors.YELLOW}Please enter 'y' or 'n'.{Colors.RESET}")


def main():
    parser = argparse.ArgumentParser(
        description="Scan directory of images and remove byte-for-byte identical duplicates."
    )
    parser.add_argument("path", nargs="?", default=None, help="Directory path to scan")
    parser.add_argument("-r", "--recursive", action="store_true", help="Scan subdirectories recursively")
    parser.add_argument("--dry-run", action="store_true", help="Find and list duplicates without deleting")
    parser.add_argument("-y", "--yes", action="store_true", help="Automatically confirm deletion without prompt")
    args = parser.parse_args()

    print(f"{Colors.BOLD}{Colors.MAGENTA}======================================================================{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}             BYTE-FOR-BYTE DUPLICATE IMAGE REMOVER                    {Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}======================================================================{Colors.RESET}\n")

    # Step 1: Prompt user for path if not provided via command line
    if args.path:
        cleaned = args.path.strip("\"'")
        target_dir = Path(os.path.expanduser(cleaned)).resolve()
        if not target_dir.is_dir():
            print(f"{Colors.RED}Error: Provided path is not a directory: {target_dir}{Colors.RESET}")
            sys.exit(1)
    else:
        target_dir = get_target_directory()

    # Step 2: Determine recursive scanning
    recursive = args.recursive
    if not args.path:
        recursive = ask_recursive()

    scan_mode_str = "Recursively (including subdirectories)" if recursive else "Single Directory (top-level only)"
    print(f"\n{Colors.BOLD}Target Directory:{Colors.RESET} {Colors.CYAN}{target_dir}{Colors.RESET}")
    print(f"{Colors.BOLD}Scan Mode:{Colors.RESET}        {scan_mode_str}")
    print(f"Scanning for image files...\n")

    image_files = find_image_files(target_dir, recursive=recursive)
    if not image_files:
        print(f"{Colors.YELLOW}No image files found in '{target_dir}'.{Colors.RESET}")
        return

    print(f"Found {Colors.BOLD}{len(image_files)}{Colors.RESET} image file(s). Searching for byte-for-byte duplicates...")
    duplicate_groups = find_duplicates(image_files)

    if not duplicate_groups:
        print(f"\n{Colors.BOLD}{Colors.GREEN}✓ No duplicate images found! All {len(image_files)} image(s) are unique.{Colors.RESET}\n")
        return

    # Tally results
    total_duplicates = sum(len(dups) for _, dups, _ in duplicate_groups)
    total_reclaim_bytes = sum(len(dups) * sz for _, dups, sz in duplicate_groups)

    print(f"\n{Colors.BOLD}{Colors.YELLOW}Found {len(duplicate_groups)} group(s) of byte-for-byte identical images ({total_duplicates} duplicate files):{Colors.RESET}\n")

    for idx, (orig, dups, sz) in enumerate(duplicate_groups, start=1):
        try:
            orig_mtime = format_mtime(orig.stat().st_mtime)
        except OSError:
            orig_mtime = "Unknown"

        print(f"{Colors.BOLD}{Colors.CYAN}--- Group #{idx} ({format_size(sz)} each) ---{Colors.RESET}")
        print(f"  {Colors.GREEN}[KEEP ORIGINAL]{Colors.RESET} {orig} {Colors.DIM}(Modified: {orig_mtime}){Colors.RESET}")
        for dup in dups:
            try:
                dup_mtime = format_mtime(dup.stat().st_mtime)
            except OSError:
                dup_mtime = "Unknown"
            print(f"  {Colors.RED}[DUPLICATE]    {Colors.RESET} {dup} {Colors.DIM}(Modified: {dup_mtime}){Colors.RESET}")
        print()

    print(f"{Colors.BOLD}Summary:{Colors.RESET}")
    print(f"  Total images scanned:       {len(image_files)}")
    print(f"  Duplicate groups:           {len(duplicate_groups)}")
    print(f"  Duplicate files to remove:  {Colors.BOLD}{Colors.RED}{total_duplicates}{Colors.RESET}")
    print(f"  Disk space to reclaim:      {Colors.BOLD}{Colors.GREEN}{format_size(total_reclaim_bytes)}{Colors.RESET}")

    if args.dry_run:
        print(f"\n{Colors.YELLOW}[DRY-RUN MODE] No files were removed.{Colors.RESET}\n")
        return

    if not args.yes:
        if not confirm_deletion(total_duplicates, total_reclaim_bytes):
            print(f"\n{Colors.YELLOW}Operation cancelled. No files were deleted.{Colors.RESET}\n")
            return

    # Delete duplicates
    print(f"\n{Colors.BOLD}Removing duplicate images...{Colors.RESET}\n")
    deleted_count = 0
    reclaimed_bytes = 0

    for orig, dups, sz in duplicate_groups:
        for dup in dups:
            try:
                dup.unlink()
                deleted_count += 1
                reclaimed_bytes += sz
                print(f"  {Colors.GREEN}✓ Removed duplicate:{Colors.RESET} {dup}")
            except Exception as e:
                print(f"  {Colors.RED}✗ Error removing '{dup}': {e}{Colors.RESET}")

    print(f"\n{Colors.BOLD}{Colors.GREEN}======================================================================{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.GREEN}Cleanup Complete!{Colors.RESET}")
    print(f"  Successfully removed:       {deleted_count} file(s)")
    print(f"  Disk space recovered:       {format_size(reclaimed_bytes)}")
    print(f"{Colors.BOLD}{Colors.GREEN}======================================================================{Colors.RESET}\n")


if __name__ == "__main__":
    main()
