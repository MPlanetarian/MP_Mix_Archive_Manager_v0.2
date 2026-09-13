#!/usr/bin/env python3
"""
detect_and_move_people.py

Scans a directory of images (.webp, .png, .jpg, .jpeg) for people using YOLOv8 object detection.
If a person is detected in an image, the file is converted to a .jpeg image
and moved into a newly created 'DETECTED_PERSON' subdirectory inside the target folder.
"""

import os
import sys
import shutil
from pathlib import Path
from PIL import Image, ImageOps

try:
    from ultralytics import YOLO
except ImportError:
    print("Error: 'ultralytics' package is not installed.")
    print("Please install it using: pip install ultralytics")
    sys.exit(1)


# Supported image extensions
SUPPORTED_EXTENSIONS = {".webp", ".png", ".jpg", ".jpeg"}

# Detection confidence threshold (0.0 to 1.0)
PERSON_CONFIDENCE_THRESHOLD = 0.45


def get_target_directory() -> Path:
    """Prompts the user for a directory path and validates it."""
    ext_list = ", ".join(sorted(SUPPORTED_EXTENSIONS))
    while True:
        try:
            user_input = input(f"Enter path to directory containing images ({ext_list}): ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nAborted by user.")
            sys.exit(0)

        if not user_input:
            print("Path cannot be empty. Please try again.")
            continue

        # Strip surrounding quotes from drag-and-drop or copy-pasting
        cleaned = user_input.strip("\"'")
        path = Path(os.path.expanduser(cleaned)).resolve()

        if not path.exists():
            print(f"Directory not found: '{path}'. Please try again.")
            continue
        if not path.is_dir():
            print(f"Path is not a directory: '{path}'. Please try again.")
            continue

        return path


def get_unique_dest_path(dest_dir: Path, filename: str, new_ext: str = ".jpeg") -> Path:
    """Generates a non-colliding destination path if a file already exists."""
    stem = Path(filename).stem
    target = dest_dir / f"{stem}{new_ext}"
    if not target.exists():
        return target

    counter = 1
    while target.exists():
        target = dest_dir / f"{stem}_{counter}{new_ext}"
        counter += 1
    return target


def convert_image_to_jpeg(src_path: Path, dest_path: Path, quality: int = 95) -> bool:
    """Converts an image to .jpeg, handling RGB, RGBA transparency, and EXIF orientation cleanly."""
    try:
        with Image.open(src_path) as img:
            img = ImageOps.exif_transpose(img)
            if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                # Composite transparent background onto white
                background = Image.new("RGB", img.size, (255, 255, 255))
                alpha = img.convert("RGBA").split()[-1]
                background.paste(img, mask=alpha)
                rgb_img = background
            else:
                rgb_img = img.convert("RGB")

            save_kwargs = {"quality": quality}
            if "icc_profile" in img.info:
                save_kwargs["icc_profile"] = img.info["icc_profile"]

            rgb_img.save(dest_path, "JPEG", **save_kwargs)
        return True
    except Exception as e:
        print(f"Error converting '{src_path.name}' to JPEG: {e}")
        return False


# Backward compatibility alias
convert_webp_to_jpeg = convert_image_to_jpeg


def has_person(model: YOLO, image_path: Path) -> bool:
    """Runs YOLO detection on an image and returns True if a person is detected."""
    try:
        # Run inference with verbose logging turned off
        results = model(str(image_path), conf=PERSON_CONFIDENCE_THRESHOLD, verbose=False)
        for r in results:
            if r.boxes is not None:
                for cls_id in r.boxes.cls:
                    # COCO class 0 is 'person'
                    if int(cls_id) == 0:
                        return True
    except Exception as e:
        print(f"Warning: Could not process {image_path.name}: {e}")
        return False

    return False


def main():
    target_dir = get_target_directory()

    # Locate destination folder
    dest_dir = target_dir / "DETECTED_PERSON"

    # Find all supported image files in the selected directory (ignoring the DETECTED_PERSON dir if it exists)
    image_files = [
        f for f in sorted(target_dir.iterdir())
        if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS
    ]

    if not image_files:
        ext_list = ", ".join(sorted(SUPPORTED_EXTENSIONS))
        print(f"No supported image files ({ext_list}) found in: {target_dir}")
        return

    print(f"\nFound {len(image_files)} image file(s) in: {target_dir}")
    print("Loading detection model...")

    # Load YOLOv8 nano model (lightweight, fast, accurate)
    # Automatically resolves or downloads yolov8n.pt if needed
    model_path = Path(__file__).resolve().parent / "yolov8n.pt"
    if model_path.exists():
        model = YOLO(str(model_path))
    else:
        model = YOLO("yolov8n.pt")

    print("Scanning images for persons...\n")

    moved_count = 0
    skipped_count = 0

    for idx, file_path in enumerate(image_files, start=1):
        filename = file_path.name

        if has_person(model, file_path):
            # Ensure DETECTED_PERSON directory exists
            dest_dir.mkdir(parents=True, exist_ok=True)

            dest_path = get_unique_dest_path(dest_dir, filename, new_ext=".jpeg")
            if convert_image_to_jpeg(file_path, dest_path):
                try:
                    file_path.unlink()
                    print(f"[{idx}/{len(image_files)}] Person detected: converted & moved '{filename}' -> DETECTED_PERSON/{dest_path.name}")
                    moved_count += 1
                except Exception as e:
                    print(f"[{idx}/{len(image_files)}] Converted '{filename}' -> '{dest_path.name}', but error deleting original: {e}")
                    moved_count += 1
            else:
                print(f"[{idx}/{len(image_files)}] Conversion failed for '{filename}', file kept in place.")
        else:
            print(f"[{idx}/{len(image_files)}] No person detected: '{filename}'")
            skipped_count += 1

    print("\n" + "=" * 40)
    print("Processing Complete!")
    print(f"Total images scanned:            {len(image_files)}")
    print(f"Images converted & moved (JPEG): {moved_count}")
    print(f"Images kept in place:            {skipped_count}")
    if moved_count > 0:
        print(f"Destination directory:           {dest_dir}")
    print("=" * 40)


if __name__ == "__main__":
    main()
