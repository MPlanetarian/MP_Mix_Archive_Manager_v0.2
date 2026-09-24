#!/usr/bin/env bash
# ==============================================================================
# generate_youtube_video.sh
# Universal Multi-Resolution YouTube Video Creator (4K UHD, 1080p, 720p)
# Supports:
#   1. Still Cover Art + Audio (Classic YouTube Episode from Image + FLAC/WAV)
#   2. Looping MP4 Video + Audio (MP4 to MP4 Looper with Segment Fades & Intro/Outro Cards)
# Hardware Acceleration: NVIDIA NVENC, Apple VideoToolbox, and CPU libx264
# ==============================================================================

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AUDIO_FILE=""
VIDEO_FILE=""
IMAGE_FILE=""
OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
RESOLUTION="1080p"
MODE=""

usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options]"
    echo ""
    echo "Options:"
    echo "  -r, --res RES          Target resolution: 4k, 1080p, 720p (default: 1080p)"
    echo "  -i, --input, -a FILE   Input FLAC/WAV audio file"
    echo "  -v, --video FILE       Input MP4/MKV video file (enables MP4-to-MP4 looping mode)"
    echo "  -c, --cover, -t FILE   Input Cover Art image / Intro-Outro Thumbnail (default: auto-find or Cover.png)"
    echo "  -o, --output DIR       Output directory or output file path (default: FLAC_CONVERTED_OUTPUTS)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -r 1080p -i mix.wav -c cover.png"
    echo "  $0 -r 1080p -i mix.wav -v video.mp4 -t thumb.jpeg -o ~/Documents"
    echo "  $0                     (Interactive mode)"
    exit 0
}

# Smart media type detector for positional arguments
detect_media_type() {
    local f="$1"
    [ -z "$f" ] && echo "unknown" && return
    local ext="${f##*.}"
    ext="${ext,,}"
    case "$ext" in
        wav|flac|aiff|aif|mp3|m4a|ogg|opus)
            echo "audio"
            ;;
        mp4|mkv|mov|avi|webm)
            echo "video"
            ;;
        png|jpg|jpeg|webp|ppm)
            echo "image"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--res|--resolution)
            RESOLUTION="$2"
            shift 2
            ;;
        -i|--input|--audio|-a)
            AUDIO_FILE="$2"
            shift 2
            ;;
        -v|--video|--input-video)
            VIDEO_FILE="$2"
            shift 2
            ;;
        -c|--cover|--image|-t|--thumb|--thumbnail)
            IMAGE_FILE="$2"
            shift 2
            ;;
        -o|--output|--out-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            mtype=$(detect_media_type "$1")
            if [ "$mtype" = "video" ] && [ -z "$VIDEO_FILE" ]; then
                VIDEO_FILE="$1"
            elif [ "$mtype" = "audio" ] && [ -z "$AUDIO_FILE" ]; then
                AUDIO_FILE="$1"
            elif [ "$mtype" = "image" ] && [ -z "$IMAGE_FILE" ]; then
                IMAGE_FILE="$1"
            elif [ -z "$AUDIO_FILE" ]; then
                AUDIO_FILE="$1"
            elif [ -z "$VIDEO_FILE" ]; then
                VIDEO_FILE="$1"
            elif [ -z "$IMAGE_FILE" ]; then
                IMAGE_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Interactive mode if neither audio nor video file specified
if [ -z "$AUDIO_FILE" ] && [ -z "$VIDEO_FILE" ]; then
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}          YOUTUBE VIDEO GENERATION SUITE (4K / 1080p / 720p)          ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    echo -e "${BOLD}Select Video Generation Mode:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Still Cover Art + Audio (${GREEN}Classic YouTube Episode from Image + FLAC/WAV${NC})"
    echo -e "  ${BOLD}${CYAN}2)${NC} Looping MP4 Video + Audio (${GREEN}MP4 to MP4 Looper with Segment Fades & Intro/Outro Cards${NC})\n"
    read -r -p "Enter mode choice [1-2, default: 1]: " mode_sel
    [ "$mode_sel" = "2" ] && MODE="video" || MODE="image"

    echo -e "\n${BOLD}Select Target Resolution:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} 4K UHD (3840x2160 @ 30fps) - ${GREEN}Pristine Ultra High Definition${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} 1080p Full HD (1920x1080 @ 30fps) - ${GREEN}Standard High Definition${NC}"
    echo -e "  ${BOLD}${CYAN}3)${NC} 720p HD (1280x720 @ 30fps) - ${YELLOW}Fast Export & Compact Size${NC}\n"
    read -r -p "Enter resolution choice [1-3, default: 2]: " res_sel
    case "$res_sel" in
        1) RESOLUTION="4k" ;;
        3) RESOLUTION="720p" ;;
        *) RESOLUTION="1080p" ;;
    esac

    if [ "$MODE" = "video" ]; then
        read -r -p "Enter path to Input Video file (.mp4 / .mkv): " VIDEO_FILE
        read -r -p "Enter path to Audio file (.wav / .flac): " AUDIO_FILE
        read -r -p "Enter path to Intro/Outro Thumbnail image (leave blank for none / Cover.png): " IMAGE_FILE
        read -r -p "Enter output directory or file (default: Documents or FLAC_CONVERTED_OUTPUTS): " user_out
        [ -n "$user_out" ] && OUTPUT_DIR="$user_out"
    else
        # Search for available FLACs in FLAC_CONVERTED_OUTPUTS or current directory
        shopt -s nullglob nocaseglob
        flac_list=("$OUTPUT_DIR"/*.flac ./*.flac)
        shopt -u nullglob nocaseglob

        if [ ${#flac_list[@]} -gt 0 ]; then
            echo -e "\n${BOLD}${CYAN}Available Audio Mixes (${#flac_list[@]} found):${NC}"
            limit=15
            [ ${#flac_list[@]} -lt $limit ] && limit=${#flac_list[@]}
            for ((i=0; i<limit; i++)); do
                printf "  %2d) %s\n" "$((i + 1))" "$(basename "${flac_list[$i]}")"
            done
            if [ ${#flac_list[@]} -gt 15 ]; then
                echo -e "  ${DIM}...and $(( ${#flac_list[@]} - 15 )) more${NC}"
            fi
            echo ""
            read -r -p "Select mix number [1-${limit}] or type filename / path: " user_choice
            if [[ "$user_choice" =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "$limit" ]; then
                AUDIO_FILE="${flac_list[$((user_choice - 1))]}"
            elif [ -n "$user_choice" ]; then
                AUDIO_FILE="$user_choice"
            fi
        fi

        if [ -z "$AUDIO_FILE" ]; then
            read -r -p "Enter the path or filename of the audio file (.flac / .wav): " AUDIO_FILE
        fi

        # Cover art prompt
        read -r -p "Enter cover art image path (leave blank for auto-detect / Cover.png): " user_cover
        [ -n "$user_cover" ] && IMAGE_FILE="$user_cover"
    fi
fi

# Clean quotes
AUDIO_FILE=$(echo "$AUDIO_FILE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
VIDEO_FILE=$(echo "$VIDEO_FILE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
IMAGE_FILE=$(echo "$IMAGE_FILE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

# ------------------------------------------------------------------------------
# If Video File is specified -> Run MP4 to MP4 Looping Video Routine
# ------------------------------------------------------------------------------
if [ -n "$VIDEO_FILE" ]; then
    helper=""
    for h in "./Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh" \
             "$SCRIPT_DIR/Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh" \
             "$SCRIPT_DIR/scripts/Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh"; do
        if [ -f "$h" ]; then helper="$h"; break; fi
    done

    if [ -n "$helper" ]; then
        exec bash "$helper" "$AUDIO_FILE" "$VIDEO_FILE" "$IMAGE_FILE" "$OUTPUT_DIR" "$RESOLUTION"
    else
        echo -e "${RED}Error: Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh not found!${NC}"
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# Classic Still Image + Audio Flow
# ------------------------------------------------------------------------------

# Verify audio file
if [ ! -f "$AUDIO_FILE" ]; then
    if [ -f "$OUTPUT_DIR/$AUDIO_FILE" ]; then
        AUDIO_FILE="$OUTPUT_DIR/$AUDIO_FILE"
    elif [ -f "$AUDIO_FILE.flac" ]; then
        AUDIO_FILE="$AUDIO_FILE.flac"
    elif [ -f "$OUTPUT_DIR/$AUDIO_FILE.flac" ]; then
        AUDIO_FILE="$OUTPUT_DIR/$AUDIO_FILE.flac"
    elif [ -f "$AUDIO_FILE.wav" ]; then
        AUDIO_FILE="$AUDIO_FILE.wav"
    else
        echo -e "\n${RED}Error: Audio file '$AUDIO_FILE' not found!${NC}"
        exit 1
    fi
fi

# Auto-detect cover if not given
if [ -z "$IMAGE_FILE" ]; then
    audio_stem=$(basename "$AUDIO_FILE")
    audio_stem="${audio_stem%.*}"
    shopt -s nullglob nocaseglob
    cov_matches=("COVERS/*$audio_stem*" "COVERS/"*.png "COVERS/"*.jpg "Cover.png" "assets/Cover.png")
    shopt -u nullglob nocaseglob
    for cm in "${cov_matches[@]}"; do
        if [ -f "$cm" ]; then IMAGE_FILE="$cm"; break; fi
    done
fi

[ -z "$IMAGE_FILE" ] && IMAGE_FILE="Cover.png"

if [ ! -f "$IMAGE_FILE" ]; then
    echo -e "\n${RED}Error: Cover image '$IMAGE_FILE' not found!${NC}"
    exit 1
fi

# Map resolution parameters
WIDTH=1920
HEIGHT=1080
RES_LABEL="1080p Full HD"
RES_SUFFIX=""
CRF=23
CQ=21
BITRATE_V="7500k"

case "${RESOLUTION,,}" in
    4k|2160p|uhd)
        WIDTH=3840
        HEIGHT=2160
        RES_LABEL="4K UHD (2160p)"
        RES_SUFFIX="_4K"
        CRF=20
        CQ=19
        BITRATE_V="18000k"
        ;;
    720p|hd)
        WIDTH=1280
        HEIGHT=720
        RES_LABEL="720p HD"
        RES_SUFFIX="_720p"
        CRF=22
        CQ=23
        BITRATE_V="3500k"
        ;;
    *)
        WIDTH=1920
        HEIGHT=1080
        RES_LABEL="1080p Full HD"
        RES_SUFFIX=""
        CRF=23
        CQ=21
        BITRATE_V="7500k"
        ;;
esac

mkdir -p "$OUTPUT_DIR"
AUDIO_BASE=$(basename "$AUDIO_FILE")
OUTPUT_NAME="${AUDIO_BASE%.*}${RES_SUFFIX}.mp4"
OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_NAME"

clear 2>/dev/null || true
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "${BOLD}${CYAN}      YOUTUBE VIDEO GENERATOR - ${RES_LABEL}               ${NC}"
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "  Audio File:   ${GREEN}$AUDIO_FILE${NC}"
echo -e "  Cover Image:  ${GREEN}$IMAGE_FILE${NC}"
echo -e "  Resolution:   ${BOLD}${WIDTH}x${HEIGHT} @ 30fps${NC}"
echo -e "  Output Video: ${GREEN}$OUTPUT_FILE${NC}"
echo -e "${BLUE}------------------------------------------------------------${NC}"

# Get audio duration
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null || echo "")

if [ -z "$AUDIO_DURATION" ]; then
    echo -e "${RED}Error: Could not retrieve duration from $AUDIO_FILE${NC}"
    exit 1
fi

TOTAL_SEC=$(printf "%.0f" "$AUDIO_DURATION")
FADE_OUT_START=$((TOTAL_SEC - 5))
[ "$FADE_OUT_START" -lt 0 ] && FADE_OUT_START=0

echo -e "Audio Duration: ${BOLD}${AUDIO_DURATION}s${NC}"

# Detect optimal Video Encoder
VCODEC="libx264"
VPRESET_ARGS=(-preset medium -crf "$CRF")
if ffmpeg -f lavfi -i color=c=black:s=256x256 -frames:v 1 -c:v h264_nvenc -f null - >/dev/null 2>&1; then
    VCODEC="h264_nvenc"
    VPRESET_ARGS=(-preset p3 -cq "$CQ" -g 60)
    echo -e "Video Encoder:  ${BOLD}${GREEN}h264_nvenc (NVIDIA NVENC Hardware Accelerated)${NC}"
elif [ "$(uname -s)" = "Darwin" ] && ffmpeg -f lavfi -i color=c=black:s=256x256 -frames:v 1 -c:v h264_videotoolbox -f null - >/dev/null 2>&1; then
    VCODEC="h264_videotoolbox"
    VPRESET_ARGS=(-b:v "$BITRATE_V")
    echo -e "Video Encoder:  ${BOLD}${GREEN}h264_videotoolbox (Apple Silicon Hardware Accelerated)${NC}"
else
    echo -e "Video Encoder:  ${BOLD}${YELLOW}libx264 (CPU Software Encoder)${NC}"
fi

# Detect optimal Audio Encoder
ACODEC="aac"
if ffmpeg -encoders 2>/dev/null | grep -q "libfdk_aac"; then
    ACODEC="libfdk_aac"
    echo -e "Audio Codec:    ${BOLD}${GREEN}libfdk_aac @ 320 kbps (Pristine)${NC}"
else
    echo -e "Audio Codec:    ${BOLD}${YELLOW}native aac @ 320 kbps${NC}"
fi

echo -e "Transitions:    ${BOLD}5s fade-in, 5s fade-out${NC}"
echo -e "${BLUE}------------------------------------------------------------${NC}"
echo -e "${YELLOW}Rendering ${RES_LABEL} with FFmpeg... Please wait.${NC}\n"

ffmpeg -y \
  -err_detect ignore_err \
  -loop 1 -framerate 30 -t "$AUDIO_DURATION" -i "$IMAGE_FILE" \
  -i "$AUDIO_FILE" \
  -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,fade=t=in:st=0:d=5:color=black,fade=t=out:st=${FADE_OUT_START}:d=5:color=black,format=yuv420p" \
  -c:v "$VCODEC" \
  "${VPRESET_ARGS[@]}" \
  -c:a "$ACODEC" \
  -b:a 320k \
  -movflags +faststart \
  "$OUTPUT_FILE"

STATUS=$?

echo -e "\n${BLUE}------------------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✓ Successfully generated ${RES_LABEL} video!${NC}"
    ls -lh "$OUTPUT_FILE"
else
    echo -e "${BOLD}${RED}✗ Video rendering failed with exit code $STATUS!${NC}"
fi
echo -e "${BOLD}${BLUE}============================================================${NC}"
exit $STATUS
