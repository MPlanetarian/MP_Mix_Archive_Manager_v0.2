import os
import sys
import subprocess
import re

MIX_ARCHIVE_DIR = "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"
PLAYLIST_FILE = os.path.join(MIX_ARCHIVE_DIR, "Back to Trance Roots.m3u")
COVER_ART = os.path.join(MIX_ARCHIVE_DIR, "Cover.png")
OUTPUT_DIR = os.path.join(MIX_ARCHIVE_DIR, "BACK_TO_TRANCE_ROOTS")

# Output files
MERGED_FLAC = os.path.join(OUTPUT_DIR, "MPlanetarian - Stream of Frequency - Back to Trance Roots.flac")
PART1_FLAC = os.path.join(OUTPUT_DIR, "MPlanetarian - Stream of Frequency - Back to Trance Roots (Part 1).flac")
PART2_FLAC = os.path.join(OUTPUT_DIR, "MPlanetarian - Stream of Frequency - Back to Trance Roots (Part 2).flac")
PART1_MP4 = os.path.join(OUTPUT_DIR, "MPlanetarian - Stream of Frequency - Back to Trance Roots (Part 1).mp4")
PART2_MP4 = os.path.join(OUTPUT_DIR, "MPlanetarian - Stream of Frequency - Back to Trance Roots (Part 2).mp4")

def run_cmd(cmd, shell=False):
    print(f"Running command: {cmd if isinstance(cmd, str) else ' '.join(cmd)}")
    res = subprocess.run(cmd, shell=shell, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print(f"Error executing command. Code: {res.returncode}")
        print(f"Stdout:\n{res.stdout}")
        print(f"Stderr:\n{res.stderr}")
        raise RuntimeError(f"Command failed: {cmd}")
    return res.stdout, res.stderr

def get_audio_duration(file_path):
    cmd = [
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", file_path
    ]
    out, _ = run_cmd(cmd)
    return float(out.strip())

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    if not os.path.exists(PLAYLIST_FILE):
        print(f"ERROR: Playlist not found: {PLAYLIST_FILE}")
        sys.exit(1)
        
    if not os.path.exists(COVER_ART):
        print(f"ERROR: Cover art not found: {COVER_ART}")
        sys.exit(1)

    # 1. Parse Playlist
    print("Reading playlist...")
    wav_files = []
    with open(PLAYLIST_FILE, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            abs_path = os.path.abspath(os.path.join(MIX_ARCHIVE_DIR, line))
            if not os.path.exists(abs_path):
                print(f"ERROR: WAV file not found: {abs_path}")
                sys.exit(1)
            wav_files.append(abs_path)
            
    print(f"Found {len(wav_files)} WAV files to merge.")

    # 2. Optimize Cover
    print("Optimizing cover image...")
    optimized_cover = "/tmp/optimized_cover.png"
    run_cmd(["ffmpeg", "-y", "-i", COVER_ART, "-vf", "scale='min(1400,iw)':-1", optimized_cover])

    # 3. Concatenate and Convert to single FLAC
    print("Merging to single FLAC...")
    concat_list_path = "/tmp/concat_list.txt"
    with open(concat_list_path, 'w', encoding='utf-8') as f:
        for wav in wav_files:
            # Escape single quotes for ffmpeg concat filter
            escaped_path = wav.replace("'", "'\\''")
            f.write(f"file '{escaped_path}'\n")

    merge_cmd = [
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", concat_list_path,
        "-i", optimized_cover,
        "-c:a", "flac", "-sample_fmt", "s32", "-compression_level", "12",
        "-map", "0:a", "-map", "1:v",
        "-metadata", "artist=MPlanetarian",
        "-metadata", "album=Stream of Frequency",
        "-metadata", "title=Back to Trance Roots",
        "-disposition:v:0", "attached_pic",
        MERGED_FLAC
    ]
    run_cmd(merge_cmd)
    print(f"Merged FLAC created: {MERGED_FLAC}")

    # 4. Split FLAC in half
    total_duration = get_audio_duration(MERGED_FLAC)
    half_duration = total_duration / 2.0
    print(f"Total duration: {total_duration:.2f} seconds. Half duration: {half_duration:.2f} seconds.")

    print("Splitting into Part 1...")
    # Split first half (note: using s32/compression 12 to ensure same quality settings)
    split_part1_cmd = [
        "ffmpeg", "-y", "-i", MERGED_FLAC, "-i", optimized_cover,
        "-t", str(half_duration),
        "-c:a", "flac", "-sample_fmt", "s32", "-compression_level", "12",
        "-map", "0:a", "-map", "1:v",
        "-metadata", "artist=MPlanetarian",
        "-metadata", "album=Stream of Frequency",
        "-metadata", "title=Back to Trance Roots (Part 1)",
        "-disposition:v:0", "attached_pic",
        PART1_FLAC
    ]
    run_cmd(split_part1_cmd)

    print("Splitting into Part 2...")
    # Split second half
    split_part2_cmd = [
        "ffmpeg", "-y", "-ss", str(half_duration), "-i", MERGED_FLAC, "-i", optimized_cover,
        "-c:a", "flac", "-sample_fmt", "s32", "-compression_level", "12",
        "-map", "0:a", "-map", "1:v",
        "-metadata", "artist=MPlanetarian",
        "-metadata", "album=Stream of Frequency",
        "-metadata", "title=Back to Trance Roots (Part 2)",
        "-disposition:v:0", "attached_pic",
        PART2_FLAC
    ]
    run_cmd(split_part2_cmd)
    print("Splitting completed.")

    # 5. Generate YouTube Videos
    for audio_file, video_file, title in [
        (PART1_FLAC, PART1_MP4, "Back to Trance Roots (Part 1)"),
        (PART2_FLAC, PART2_MP4, "Back to Trance Roots (Part 2)")
    ]:
        print(f"Generating video for {title}...")
        dur = get_audio_duration(audio_file)
        fade_out_start = max(0.0, dur - 5.0)
        
        # Test if libfdk_aac is available, else fallback to standard aac
        aac_codec = "libfdk_aac"
        try:
            run_cmd(["ffmpeg", "-encoders"])
        except Exception:
            pass
            
        video_cmd = [
            "ffmpeg", "-y", "-err_detect", "ignore_err",
            "-loop", "1", "-framerate", "30", "-t", str(dur), "-i", COVER_ART,
            "-i", audio_file,
            "-vf", f"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,fade=t=in:st=0:d=5:color=black,fade=t=out:st={fade_out_start:.2f}:d=5:color=black,format=yuv420p",
            "-c:v", "libx264", "-preset", "medium", "-crf", "23",
            "-c:a", aac_codec, "-b:a", "320k",
            video_file
        ]
        
        try:
            run_cmd(video_cmd)
        except RuntimeError:
            print("libfdk_aac failed or is unavailable, falling back to standard aac...")
            video_cmd[video_cmd.index("-c:a") + 1] = "aac"
            run_cmd(video_cmd)
            
        print(f"Video created: {video_file}")

    # Cleanup
    for tmp in [concat_list_path, optimized_cover]:
        if os.path.exists(tmp):
            os.remove(tmp)
            
    print("==================================================")
    print("ALL STEPS COMPLETED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    main()
