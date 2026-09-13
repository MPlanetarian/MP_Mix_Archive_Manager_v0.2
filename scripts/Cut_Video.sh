#!/usr/bin/env bash
# ==============================================================================
# Script: Cut_Video.sh
# Purpose: Cut video clips (.mp4 and .mkv) based on start and end points in seconds,
#          save cut video in the same directory, and open a file manager window.
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ensure required utilities exist
for tool in ffmpeg ffprobe; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo -e "${RED}Error: Required tool '$tool' is not installed or not in PATH.${NC}"
        exit 1
    fi
done

open_file_manager() {
    local target_dir="$1"
    if [ -z "$target_dir" ] || [ ! -d "$target_dir" ]; then
        return 0
    fi
    echo -e "${CYAN}Opening file manager in: ${BOLD}${target_dir}${NC}"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v dolphin >/dev/null 2>&1; then
        dolphin "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v nautilus >/dev/null 2>&1; then
        nautilus "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
}

echo -e "${BOLD}${MAGENTA}==================================================${NC}"
echo -e "${BOLD}${MAGENTA}        VIDEO CUTTING UTILITY (.MP4 / .MKV)       ${NC}"
echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"

# 1. Ask user for full path to the video (or use CLI argument $1)
input_path="$1"

while true; do
    if [ -z "$input_path" ]; then
        read -r -e -p "Enter full path to the video file (.mp4 or .mkv): " input_path
    fi

    # Clean input quotes and spaces from drag & drop or copy-paste
    input_path=$(echo "$input_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    if [ -z "$input_path" ]; then
        echo -e "${RED}Error: Video file path cannot be empty!${NC}\n"
        input_path=""
        [ -n "$1" ] && exit 1
        continue
    fi

    # Expand tilde if present
    if [[ "$input_path" == ~* ]]; then
        input_path="${input_path/#~/$HOME}"
    fi

    # Check if file exists
    if [ ! -f "$input_path" ]; then
        echo -e "${RED}Error: File not found at '$input_path'!${NC}\n"
        input_path=""
        [ -n "$1" ] && exit 1
        continue
    fi

    # Resolve full path
    input_path=$(realpath "$input_path" 2>/dev/null || readlink -f "$input_path" 2>/dev/null || echo "$input_path")

    # Validate file format / extension (.mp4 or .mkv)
    fname=$(basename "$input_path")
    fext="${fname##*.}"
    fext_lower=$(echo "$fext" | tr '[:upper:]' '[:lower:]')

    if [ "$fext_lower" != "mp4" ] && [ "$fext_lower" != "mkv" ]; then
        echo -e "${RED}Error: Unsupported format '.$fext'! Only .mp4 and .mkv videos are supported.${NC}\n"
        input_path=""
        [ -n "$1" ] && exit 1
        continue
    fi

    break
done

# Read video metadata using ffprobe
video_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_path" 2>/dev/null)
file_size=$(ls -lh "$input_path" 2>/dev/null | awk '{print $5}')
video_res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$input_path" 2>/dev/null | head -n 1)

echo -e "\n${BOLD}${GREEN}✓ Loaded Video:${NC} $(basename "$input_path")"
echo -e "  Directory:  $(dirname "$input_path")"
echo -e "  File Size:  $file_size"
[ -n "$video_res" ] && echo -e "  Resolution: $video_res"

if [ -n "$video_duration" ]; then
    dur_formatted=$(awk -v d="$video_duration" 'BEGIN {
        sec=int(d)
        h=int(sec/3600)
        m=int((sec%3600)/60)
        s=sec%60
        if (h > 0) printf "%02d:%02d:%02d (%.2f sec)", h, m, s, d
        else printf "%02d:%02d (%.2f sec)", m, s, d
    }')
    echo -e "  Duration:   $dur_formatted"
fi
echo ""

# 2. Ask for start point in seconds (or use CLI argument $2)
start_sec="$2"
while true; do
    if [ -z "$start_sec" ]; then
        read -r -p "Enter start point in seconds (e.g. 0 or 15.5): " start_sec
    fi

    start_sec=$(echo "$start_sec" | tr -d '[:space:]')
    if ! [[ "$start_sec" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}Error: Start point must be a valid positive number or 0.${NC}"
        start_sec=""
        [ -n "$2" ] && exit 1
        continue
    fi

    if [ -n "$video_duration" ]; then
        if awk -v s="$start_sec" -v d="$video_duration" 'BEGIN { exit !(s >= d) }'; then
            echo -e "${RED}Error: Start point (${start_sec}s) is equal to or greater than video duration (${video_duration}s)!${NC}"
            start_sec=""
            [ -n "$2" ] && exit 1
            continue
        fi
    fi

    break
done

# 3. Ask for end point in seconds (or use CLI argument $3)
end_sec="$3"
while true; do
    if [ -z "$end_sec" ]; then
        read -r -p "Enter end point in seconds (e.g. 45 or 120): " end_sec
    fi

    end_sec=$(echo "$end_sec" | tr -d '[:space:]')
    if ! [[ "$end_sec" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo -e "${RED}Error: End point must be a valid positive number.${NC}"
        end_sec=""
        [ -n "$3" ] && exit 1
        continue
    fi

    if awk -v s="$start_sec" -v e="$end_sec" 'BEGIN { exit !(e <= s) }'; then
        echo -e "${RED}Error: End point (${end_sec}s) must be greater than start point (${start_sec}s)!${NC}"
        end_sec=""
        [ -n "$3" ] && exit 1
        continue
    fi

    if [ -n "$video_duration" ]; then
        if awk -v e="$end_sec" -v d="$video_duration" 'BEGIN { exit !(e > d) }'; then
            echo -e "${YELLOW}Notice: End point (${end_sec}s) exceeds video duration (${video_duration}s). Clip will cut to the end of the video.${NC}"
        fi
    fi

    break
done

# Cutting Mode Selection
# Default to Fast Lossless Stream Copy (mode 1). Frame-accurate re-encode (mode 2) can also be selected.
cut_mode="1"
if [ -n "$4" ]; then
    cut_mode="$4"
else
    echo -e "\n${BOLD}Cutting Mode:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Fast Stream Copy (Instant, lossless, cuts on keyframes) ${GREEN}[Default]${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} Frame-Accurate Re-encode (Exact frame cut, visually lossless CRF 18)"
    read -r -p "Select mode [1/2, default: 1]: " user_mode || true
    if [ "$user_mode" = "2" ]; then
        cut_mode="2"
    fi
fi

# 4. Save the cut video to the same directory as where the existing video is
video_dir=$(dirname "$input_path")
filename=$(basename "$input_path")
name_no_ext="${filename%.*}"
ext="${filename##*.}"

output_filename="${name_no_ext}_cut_${start_sec}s-${end_sec}s.${ext}"
output_path="${video_dir}/${output_filename}"

# Prevent collision / overwriting existing files
if [ -f "$output_path" ]; then
    seq=1
    while [ -f "${video_dir}/${name_no_ext}_cut_${start_sec}s-${end_sec}s_${seq}.${ext}" ]; do
        ((seq++))
    done
    output_path="${video_dir}/${name_no_ext}_cut_${start_sec}s-${end_sec}s_${seq}.${ext}"
    output_filename=$(basename "$output_path")
fi

echo -e "\n${BOLD}${BLUE}=== PROCESSING CUT ===${NC}"
echo -e "  Input:       $input_path"
echo -e "  Output:      $output_path"
echo -e "  Start Point: ${start_sec}s"
echo -e "  End Point:   ${end_sec}s"
cut_len=$(awk -v s="$start_sec" -v e="$end_sec" 'BEGIN { printf "%.2f", (e - s) }')
echo -e "  Length:      ~${cut_len}s"
if [ "$cut_mode" = "2" ]; then
    echo -e "  Mode:        Frame-Accurate Re-encode (libx264 veryfast CRF 18)"
else
    echo -e "  Mode:        Fast Stream Copy (lossless)"
fi
echo -e "${BLUE}--------------------------------------------------${NC}"

# Execute FFmpeg cut
if [ "$cut_mode" = "2" ]; then
    ffmpeg -y -hide_banner -loglevel warning -stats \
        -i "$input_path" \
        -ss "$start_sec" -to "$end_sec" \
        -c:v libx264 -preset veryfast -crf 18 -c:a copy \
        "$output_path"
    ffmpeg_status=$?
    # Fallback to aac audio if audio stream copy fails in re-encode mode
    if [ $ffmpeg_status -ne 0 ]; then
        echo -e "${YELLOW}Retrying with AAC audio re-encode...${NC}"
        ffmpeg -y -hide_banner -loglevel warning -stats \
            -i "$input_path" \
            -ss "$start_sec" -to "$end_sec" \
            -c:v libx264 -preset veryfast -crf 18 -c:a aac -b:a 320k \
            "$output_path"
        ffmpeg_status=$?
    fi
else
    ffmpeg -y -hide_banner -loglevel warning -stats \
        -i "$input_path" \
        -ss "$start_sec" -to "$end_sec" \
        -c copy -avoid_negative_ts make_zero -map 0 \
        "$output_path"
    ffmpeg_status=$?
    # Fallback if map 0 fails on extraneous data streams
    if [ $ffmpeg_status -ne 0 ]; then
        echo -e "${YELLOW}Retrying stream copy without extra metadata streams...${NC}"
        ffmpeg -y -hide_banner -loglevel warning -stats \
            -i "$input_path" \
            -ss "$start_sec" -to "$end_sec" \
            -c:v copy -c:a copy -avoid_negative_ts make_zero \
            "$output_path"
        ffmpeg_status=$?
    fi
fi

echo -e "${BLUE}--------------------------------------------------${NC}"

if [ $ffmpeg_status -eq 0 ] && [ -f "$output_path" ] && [ -s "$output_path" ]; then
    final_size=$(ls -lh "$output_path" 2>/dev/null | awk '{print $5}')
    final_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_path" 2>/dev/null)
    echo -e "${BOLD}${GREEN}✓ Video successfully cut and saved!${NC}"
    echo -e "  Path:     ${BOLD}${output_path}${NC}"
    echo -e "  Size:     ${final_size}"
    [ -n "$final_dur" ] && echo -e "  Duration: ${final_dur}s"
    echo ""
    
    # 5. Open file manager window immediately afterwards in the same directory
    open_file_manager "$video_dir"
    exit 0
else
    echo -e "${BOLD}${RED}✗ Error: Video cutting failed (exit code: $ffmpeg_status)!${NC}"
    [ -f "$output_path" ] && [ ! -s "$output_path" ] && rm -f "$output_path"
    exit 1
fi
