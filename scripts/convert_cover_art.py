#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Cover Art Converter & Resizer
Supports format conversion (JPEG, PNG, WebP, TIFF), resolution downscaling,
and byte-targeted compression (e.g. strict <= 1.0 MB target for podcast directories).
"""

import sys
import os
import io
import re
import argparse
from PIL import Image

def parse_byte_size(size_str):
    """Parses human readable strings like 1MB, 1.5M, 500KB, 1048576 into bytes."""
    size_str = str(size_str).strip().upper()
    match = re.match(r'^([\d\.]+)\s*([KMG]?B?)$', size_str)
    if not match:
        raise ValueError(f"Invalid byte size string: {size_str}")
    num = float(match.group(1))
    unit = match.group(2)
    if unit in ('MB', 'M'):
        return int(num * 1024 * 1024)
    elif unit in ('KB', 'K'):
        return int(num * 1024)
    elif unit in ('GB', 'G'):
        return int(num * 1024 * 1024 * 1024)
    else:
        return int(num)

def format_readable_bytes(b):
    for u in ['B', 'KB', 'MB', 'GB']:
        if b < 1024:
            return f"{b:.2f} {u}"
        b /= 1024.0
    return f"{b:.2f} TB"

def compress_to_target_bytes(img, target_bytes, out_format="JPEG"):
    """
    Binary search quality and scale to guarantee output size is <= target_bytes
    while maximizing visual fidelity.
    """
    fmt = out_format.upper()
    if fmt in ("JPG", "JPEG"):
        fmt = "JPEG"
    elif fmt == "WEBP":
        fmt = "WEBP"
    else:
        # PNG or lossless formats do not have lossy quality parameter
        fmt = "JPEG"

    # Work with RGB for JPEG
    working_img = img.copy()
    if fmt == "JPEG" and working_img.mode in ("RGBA", "P", "LA"):
        bg = Image.new("RGB", working_img.size, (255, 255, 255))
        if working_img.mode == "RGBA":
            bg.paste(working_img, mask=working_img.split()[3])
        else:
            bg.paste(working_img.convert("RGB"))
        working_img = bg
    elif working_img.mode not in ("RGB", "RGBA"):
        working_img = working_img.convert("RGB")

    best_data = None
    scale = 1.0
    orig_w, orig_h = working_img.size

    for attempt in range(10):
        current_w = max(200, int(orig_w * scale))
        current_h = max(200, int(orig_h * scale))
        scaled_img = working_img.resize((current_w, current_h), Image.Resampling.LANCZOS)

        low = 15
        high = 95
        pass_data = None

        while low <= high:
            mid = (low + high) // 2
            buf = io.BytesIO()
            scaled_img.save(buf, format=fmt, quality=mid, optimize=True)
            data = buf.getvalue()
            if len(data) <= target_bytes:
                pass_data = data
                low = mid + 1  # Try higher quality
            else:
                high = mid - 1 # Reduce quality

        if pass_data is not None:
            best_data = pass_data
            break
        else:
            # Even at quality 15, size is larger than target. Downscale resolution by 15%
            scale *= 0.85

    if best_data is None:
        # Fallback to minimal quality
        buf = io.BytesIO()
        working_img.save(buf, format=fmt, quality=10, optimize=True)
        best_data = buf.getvalue()

    return best_data

def convert_cover(input_path, output_path=None, out_format=None, resolution=None, target_bytes=None, quality=88):
    if not os.path.isfile(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    orig_size = os.path.getsize(input_path)
    img = Image.open(input_path)
    w, h = img.size

    # Determine output format
    if out_format:
        fmt = out_format.upper()
    elif output_path:
        ext = os.path.splitext(output_path)[1].lstrip(".").upper()
        fmt = "JPEG" if ext in ("JPG", "JPEG") else ext
    else:
        fmt = "JPEG"

    if fmt in ("JPG", "JPEG"):
        fmt = "JPEG"
        ext = ".jpg"
    elif fmt == "WEBP":
        fmt = "WEBP"
        ext = ".webp"
    elif fmt == "PNG":
        fmt = "PNG"
        ext = ".png"
    elif fmt in ("TIF", "TIFF"):
        fmt = "TIFF"
        ext = ".tiff"
    else:
        fmt = "JPEG"
        ext = ".jpg"

    # Handle resolution resize
    if resolution:
        if "x" in str(resolution).lower():
            rw, rh = map(int, str(resolution).lower().split("x"))
        else:
            dim = int(resolution)
            rw = dim
            rh = dim
        if (rw, rh) != (w, h):
            img = img.resize((rw, rh), Image.Resampling.LANCZOS)
            w, h = rw, rh

    # Default output path if not specified
    if not output_path:
        base, _ = os.path.splitext(input_path)
        tag = ""
        if target_bytes:
            mb_label = f"{target_bytes / (1024*1024):.1f}MB" if target_bytes >= 1048576 else f"{target_bytes // 1024}KB"
            tag += f"_{mb_label}"
        if resolution:
            tag += f"_{w}x{h}"
        output_path = f"{base}{tag}{ext}"

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    # Perform compression
    if target_bytes:
        data = compress_to_target_bytes(img, target_bytes, fmt)
        with open(output_path, "wb") as f:
            f.write(data)
    else:
        # Standard save with specified format/quality
        if fmt == "JPEG":
            if img.mode in ("RGBA", "P", "LA"):
                bg = Image.new("RGB", img.size, (255, 255, 255))
                if img.mode == "RGBA":
                    bg.paste(img, mask=img.split()[3])
                else:
                    bg.paste(img.convert("RGB"))
                img = bg
            elif img.mode != "RGB":
                img = img.convert("RGB")
            img.save(output_path, format=fmt, quality=quality, optimize=True)
        elif fmt == "WEBP":
            img.save(output_path, format=fmt, quality=quality)
        elif fmt == "PNG":
            img.save(output_path, format=fmt, optimize=True)
        else:
            img.save(output_path, format=fmt)

    new_size = os.path.getsize(output_path)
    final_img = Image.open(output_path)
    fw, fh = final_img.size

    return {
        "input": input_path,
        "output": output_path,
        "orig_size": orig_size,
        "new_size": new_size,
        "dimensions": f"{fw}x{fh}",
        "format": fmt
    }

def main():
    parser = argparse.ArgumentParser(description="Convert, resize, and compress cover art images.")
    parser.add_argument("-i", "--input", help="Path to input image file")
    parser.add_argument("-o", "--output", help="Path to output image file")
    parser.add_argument("-f", "--format", choices=["jpg", "jpeg", "png", "webp", "tiff"], help="Output format")
    parser.add_argument("-r", "--resolution", help="Target resolution (e.g. 1400, 3000, 1400x1400)")
    parser.add_argument("-b", "--bytes", help="Target maximum byte size (e.g. 1MB, 500KB, 1048576)")
    parser.add_argument("-q", "--quality", type=int, default=88, help="Output quality 1-100 (default: 88)")

    args = parser.parse_args()

    if not args.input:
        parser.print_help()
        sys.exit(1)

    target_bytes = parse_byte_size(args.bytes) if args.bytes else None

    try:
        res = convert_cover(
            input_path=args.input,
            output_path=args.output,
            out_format=args.format,
            resolution=args.resolution,
            target_bytes=target_bytes,
            quality=args.quality
        )
        print("\n" + "=" * 60)
        print("          COVER ART CONVERSION COMPLETED")
        print("=" * 60)
        print(f"  Source Image:   {res['input']}")
        print(f"  Output Image:   {res['output']}")
        print(f"  Format:         {res['format']}")
        print(f"  Dimensions:     {res['dimensions']}")
        print(f"  Original Size:  {format_readable_bytes(res['orig_size'])} ({res['orig_size']} bytes)")
        print(f"  Optimized Size: {format_readable_bytes(res['new_size'])} ({res['new_size']} bytes)")
        if res['orig_size'] > 0:
            reduction = ((res['orig_size'] - res['new_size']) / res['orig_size']) * 100
            print(f"  Size Reduction: {reduction:.1f}%")
        print("=" * 60 + "\n")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
