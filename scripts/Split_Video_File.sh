#!/usr/bin/env bash
# ==============================================================================
# Script: Split_Video_File.sh
# Purpose: Split a YouTube .mp4 video file into N equal parts.
#          Allows selecting from archive video directories or entering a custom path.
#          Always outputs split video parts to the same directory as the input file.
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Determine script directory
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

# Load configuration if present
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
elif [ -f "$PWD/config.env" ]; then
    # shellcheck source=/dev/null
    source "$PWD/config.env"
fi

# Ensure required utilities exist
for tool in ffmpeg ffprobe; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo -e "${RED}Error: Required tool '$tool' is not installed or not in PATH.${NC}"
        exit 1
    fi
done

format_seconds() {
    local total_sec
    total_sec=$(printf "%.0f" "$1" 2>/dev/null || echo "0")
    local h=$((total_sec / 3600))
    local m=$(( (total_sec % 3600) / 60 ))
    local s=$((total_sec % 60))
    if [ $h -gt 0 ]; then
        printf "%02d:%02d:%02d" $h $m $s
    else
        printf "%02d:%02d" $m $s
    fi
}

open_file_manager() {
    local target_dir="$1"
    [ -z "$target_dir" ] || [ ! -d "$target_dir" ] && return 0
    echo -e "${CYAN}Opening file manager in: ${BOLD}${target_dir}${NC}"
    if [[ "$OSTYPE" == "darwin"* ]] || [[ "$(uname -s)" == "Darwin"* ]]; then
        open "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        if command -v cygpath >/dev/null 2>&1; then
            local win_p
            win_p="$(cygpath -w "$target_dir" 2>/dev/null || echo "$target_dir")"
            cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
        else
            explorer.exe "$target_dir" >/dev/null 2>&1 &
        fi
        disown 2>/dev/null || true
    elif command -v xdg-open >/dev/null 2>&1; then
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

clean_path_input() {
    local p="$1"
    p=$(echo "$p" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    if [[ "$p" == ~* ]]; then
        p="${p/#~/$HOME}"
    fi
    echo "$p"
}

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}         SPLIT YOUTUBE .MP4 VIDEO FILE INTO EQUAL PARTS               ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

input_mp4="${1:-}"
num_parts="${2:-}"

# 1. Select the MP4 video file
if [ -z "$input_mp4" ]; then
    candidate_dirs=(
        "${MIX_ARCHIVE_DIR:-$PWD}/downloaded_videos"
        "${MIX_ARCHIVE_DIR:-$PWD}"
        "${NFT_VIDEOS_DIR:-}"
        "$PWD/downloaded_videos"
        "$PWD"
        "$SCRIPT_DIR"
    )

    found_videos=()
    shopt -s nullglob nocaseglob
    for cdir in "${candidate_dirs[@]}"; do
        if [ -n "$cdir" ] && [ -d "$cdir" ]; then
            for f in "$cdir"/*.mp4 "$cdir"/*/*.mp4; do
                [ -f "$f" ] && found_videos+=("$f")
            done
        fi
    done
    shopt -u nullglob nocaseglob

    # Deduplicate candidate files while preserving order
    unique_videos=()
    if [ ${#found_videos[@]} -gt 0 ]; then
        IFS=$'\n' read -r -d '' -a unique_videos < <(python3 -c "
import sys, os
seen = set()
res = []
for p in sys.argv[1:]:
    rp = os.path.realpath(p)
    if rp not in seen and os.path.isfile(rp):
        seen.add(rp)
        res.append(rp)
res.sort(key=lambda x: os.path.getmtime(x), reverse=True)
for r in res:
    print(r)
" "${found_videos[@]}" && printf '\0') || true
    fi

    if [ ${#unique_videos[@]} -gt 0 ]; then
        echo -e "${BOLD}${CYAN}Found ${#unique_videos[@]} MP4 video file(s) across archive directories:${NC}\n"
        max_show=25
        count=0
        for f in "${unique_videos[@]}"; do
            ((count++))
            [ $count -gt $max_show ] && break
            f_size=$(ls -lh "$f" 2>/dev/null | awk '{print $5}')
            echo -e "  ${BOLD}${CYAN}$(printf "%2d" $count))${NC} $(basename "$f") ${DIM}(${f_size})${NC}"
        done
        if [ ${#unique_videos[@]} -gt $max_show ]; then
            echo -e "  ${DIM}...and $(( ${#unique_videos[@]} - max_show )) more files${NC}"
        fi
        echo ""
        echo -e "  ${BOLD}${YELLOW} M)${NC} Manually enter / paste custom full path to a YouTube .mp4 file"
        echo -e "  ${BOLD}${RED} 0)${NC} Cancel / Exit\n"

        while true; do
            read -r -p "Select a video file [1-${#unique_videos[@]}, M for manual, 0 to exit]: " choice
            case "$choice" in
                0|[qQ])
                    echo -e "\n${YELLOW}Operation cancelled.${NC}"
                    exit 0
                    ;;
                [mM])
                    echo ""
                    read -r -e -p "Enter full path to the .mp4 video file: " manual_path
                    input_mp4=$(clean_path_input "$manual_path")
                    break
                    ;;
                *)
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#unique_videos[@]}" ]; then
                        input_mp4="${unique_videos[$((choice - 1))]}"
                        break
                    else
                        echo -e "${RED}Invalid choice! Please enter a number between 1 and ${#unique_videos[@]}, 'M', or '0'.${NC}"
                    fi
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}No MP4 video files automatically discovered in archive directories.${NC}"
        read -r -e -p "Enter full path to the .mp4 video file: " manual_path
        input_mp4=$(clean_path_input "$manual_path")
    fi
fi

# Clean & validate input path
input_mp4=$(clean_path_input "$input_mp4")

if [ -z "$input_mp4" ] || [ ! -f "$input_mp4" ]; then
    echo -e "${RED}Error: File not found at: '$input_mp4'${NC}"
    exit 1
fi

input_mp4=$(realpath "$input_mp4" 2>/dev/null || readlink -f "$input_mp4" 2>/dev/null || echo "$input_mp4")

# Validate MP4 extension
input_lower=$(echo "$input_mp4" | tr '[:upper:]' '[:lower:]')
if [[ "$input_lower" != *.mp4 && "$input_lower" != *.mkv ]]; then
    echo -e "${YELLOW}Warning: File extension is not .mp4, checking media stream format...${NC}"
fi

# Probe video duration and resolution
echo -e "\n${BOLD}${BLUE}Probing video stream specifications...${NC}"
duration_raw=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_mp4" 2>/dev/null || true)
video_res=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$input_mp4" 2>/dev/null || echo "Unknown")

if [ -z "$duration_raw" ] || [ "$duration_raw" = "N/A" ]; then
    echo -e "${RED}Error: Unable to probe duration for '$input_mp4'. Please ensure it is a valid video file.${NC}"
    exit 1
fi

total_sec=$(python3 -c "import sys; print(f'{float(sys.argv[1]):.4f}')" "$duration_raw" 2>/dev/null || echo "$duration_raw")
total_formatted=$(format_seconds "$total_sec")
file_size=$(ls -lh "$input_mp4" 2>/dev/null | awk '{print $5}')
target_dir=$(dirname "$input_mp4")
base_name=$(basename "$input_mp4")
stem="${base_name%.*}"
ext="${base_name##*.}"

echo -e "  • ${BOLD}Input Video:${NC}  ${BOLD}${GREEN}${base_name}${NC}"
echo -e "  • ${BOLD}Directory:${NC}    ${CYAN}${target_dir}${NC}"
echo -e "  • ${BOLD}Resolution:${NC}   ${WHITE}${video_res}${NC}"
echo -e "  • ${BOLD}Total Length:${NC} ${WHITE}${total_formatted}${NC} (${total_sec} seconds)"
echo -e "  • ${BOLD}File Size:${NC}    ${YELLOW}${file_size}${NC}\n"

# 2. Ask user for number of parts
while true; do
    if [ -z "$num_parts" ]; then
        read -r -p "How many parts do you want to split this video file into? (e.g. 2, 3, 4): " num_parts
    fi
    num_parts=$(echo "$num_parts" | tr -d '[:space:]')
    if [[ "$num_parts" =~ ^[0-9]+$ ]] && [ "$num_parts" -ge 2 ] && [ "$num_parts" -le 99 ]; then
        break
    else
        echo -e "${RED}Error: Number of parts must be a whole integer between 2 and 99.${NC}"
        num_parts=""
    fi
done

# Calculate duration per part
part_dur=$(python3 -c "import sys; print(f'{float(sys.argv[1]) / int(sys.argv[2]):.4f}')" "$total_sec" "$num_parts")
part_dur_fmt=$(format_seconds "$part_dur")

# 3. Select cutting mode
echo -e "\n${BOLD}Select Video Splitting Mode:${NC}"
echo -e "  ${BOLD}${CYAN}1)${NC} Fast Lossless Stream Copy (Instant, 0 quality loss, cuts on keyframes) ${GREEN}[Default]${NC}"
echo -e "  ${BOLD}${CYAN}2)${NC} Frame-Accurate Re-encode (libx264 veryfast, exact frame boundary cuts)"
read -r -p "Select mode [1/2, default: 1]: " cut_mode_choice || true
cut_mode_choice="${cut_mode_choice:-1}"

echo -e "\n${BOLD}${BLUE}=== SPLIT CONFIGURATION ===${NC}"
echo -e "  • ${BOLD}Total Parts:${NC}       ${BOLD}${GREEN}${num_parts}${NC}"
echo -e "  • ${BOLD}Duration Per Part:${NC} ~${BOLD}${CYAN}${part_dur_fmt}${NC} (${part_dur}s)"
if [ "$cut_mode_choice" = "2" ]; then
    echo -e "  • ${BOLD}Mode:${NC}              ${WHITE}Frame-Accurate Re-encode (libx264 / AAC)${NC}"
else
    echo -e "  • ${BOLD}Mode:${NC}              ${GREEN}Fast Lossless Stream Copy (Instant copy)${NC}"
fi
echo -e "  • ${BOLD}Output Directory:${NC}  ${BOLD}${YELLOW}${target_dir}${NC} ${DIM}(Always same directory as input)${NC}"
echo -e "  • ${BOLD}Naming Scheme:${NC}     ${stem}_Part01.${ext}, ${stem}_Part02.${ext}..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}\n"

read -r -p "Proceed with splitting? [Y/n]: " confirm
confirm=$(echo "${confirm:-y}" | tr '[:upper:]' '[:lower:]')
if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
    echo -e "${YELLOW}Operation cancelled by user.${NC}"
    exit 0
fi

echo -e "\n${BOLD}${MAGENTA}Starting Video Split Processing...${NC}\n"

generated_files=()
pad_width=2
[ "$num_parts" -ge 100 ] && pad_width=3

for ((part=1; part<=num_parts; part++)); do
    part_str=$(printf "%0*d" "$pad_width" "$part")
    out_file="${target_dir}/${stem}_Part${part_str}.${ext}"
    start_sec=$(python3 -c "import sys; print(f'{(int(sys.argv[1]) - 1) * float(sys.argv[2]):.4f}')" "$part" "$part_dur")
    start_fmt=$(format_seconds "$start_sec")

    if [ "$part" -lt "$num_parts" ]; then
        end_sec=$(python3 -c "import sys; print(f'{int(sys.argv[1]) * float(sys.argv[2]):.4f}')" "$part" "$part_dur")
        end_fmt=$(format_seconds "$end_sec")
        echo -e "${BOLD}${CYAN}[Part ${part}/${num_parts}]${NC} Processing: ${WHITE}${stem}_Part${part_str}.${ext}${NC} (${start_fmt} ➔ ${end_fmt})..."

        if [ "$cut_mode_choice" = "2" ]; then
            ffmpeg -y -hide_banner -loglevel warning -stats \
                -ss "$start_sec" -to "$end_sec" \
                -i "$input_mp4" \
                -c:v libx264 -preset veryfast -crf 18 -c:a copy \
                -movflags +faststart \
                "$out_file"
        else
            ffmpeg -y -hide_banner -loglevel warning -stats \
                -ss "$start_sec" -to "$end_sec" \
                -i "$input_mp4" \
                -c copy -avoid_negative_ts make_zero \
                -movflags +faststart \
                "$out_file"
        fi
    else
        echo -e "${BOLD}${CYAN}[Part ${part}/${num_parts}]${NC} Processing Final Part: ${WHITE}${stem}_Part${part_str}.${ext}${NC} (${start_fmt} ➔ End: ${total_formatted})..."

        if [ "$cut_mode_choice" = "2" ]; then
            ffmpeg -y -hide_banner -loglevel warning -stats \
                -ss "$start_sec" \
                -i "$input_mp4" \
                -c:v libx264 -preset veryfast -crf 18 -c:a copy \
                -movflags +faststart \
                "$out_file"
        else
            ffmpeg -y -hide_banner -loglevel warning -stats \
                -ss "$start_sec" \
                -i "$input_mp4" \
                -c copy -avoid_negative_ts make_zero \
                -movflags +faststart \
                "$out_file"
        fi
    fi

    if [ -f "$out_file" ]; then
        generated_files+=("$out_file")
    else
        echo -e "${RED}Warning: Failed to generate '$out_file'!${NC}"
    fi
done

echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}               ✓ VIDEO SPLIT COMPLETED SUCCESSFULLY!                  ${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

echo -e "Generated ${#generated_files[@]} of ${num_parts} parts in ${CYAN}${target_dir}${NC}:\n"
for f in "${generated_files[@]}"; do
    sz=$(ls -lh "$f" 2>/dev/null | awk '{print $5}')
    dur_f=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null || echo "0")
    dur_fmt=$(format_seconds "$dur_f")
    echo -e "  ${GREEN}✓${NC} ${BOLD}$(basename "$f")${NC}  ${DIM}[${dur_fmt} • ${sz}]${NC}"
done

echo ""
open_file_manager "$target_dir"
echo -e "${GREEN}All split parts safely written to the input video's directory.${NC}\n"
