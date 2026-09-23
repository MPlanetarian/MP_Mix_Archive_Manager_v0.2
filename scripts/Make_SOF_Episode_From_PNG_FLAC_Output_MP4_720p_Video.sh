#!/usr/bin/env bash
# ==============================================================================
# Make_SOF_Episode_From_PNG_FLAC_Output_MP4_720p_Video.sh
# Generates 720p HD YouTube Video (1280x720 @ 30fps) from FLAC Audio & Cover Image
# Hardware Accelerated (NVENC / VideoToolbox / libx264 fallback)
# ==============================================================================

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

AUDIO_FILE="${1:-}"
IMAGE_FILE="${2:-}"
OUTPUT_DIR="${3:-FLAC_CONVERTED_OUTPUTS}"

if [ -z "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: Audio file not specified!${NC}"
    echo "Usage: $0 <path_to_audio.flac> [path_to_cover.png] [output_dir]"
    exit 1
fi

# Locate audio file
if [ ! -f "$AUDIO_FILE" ]; then
    if [ -f "FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE" ]; then
        AUDIO_FILE="FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE"
    elif [ -f "$AUDIO_FILE.flac" ]; then
        AUDIO_FILE="$AUDIO_FILE.flac"
    elif [ -f "FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE.flac" ]; then
        AUDIO_FILE="FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE.flac"
    else
        echo -e "${RED}Error: Audio file '$AUDIO_FILE' not found!${NC}"
        exit 1
    fi
fi

# Locate image file
if [ -z "$IMAGE_FILE" ]; then
    IMAGE_FILE="Cover.png"
fi

if [ ! -f "$IMAGE_FILE" ]; then
    if [ -f "COVERS/$IMAGE_FILE" ]; then
        IMAGE_FILE="COVERS/$IMAGE_FILE"
    elif [ -f "Cover.png" ]; then
        echo -e "${YELLOW}Warning: Cover file '$IMAGE_FILE' not found. Using default Cover.png.${NC}"
        IMAGE_FILE="Cover.png"
    elif [ -f "assets/Cover.png" ]; then
        IMAGE_FILE="assets/Cover.png"
    else
        echo -e "${RED}Error: Cover image '$IMAGE_FILE' not found!${NC}"
        exit 1
    fi
fi

mkdir -p "$OUTPUT_DIR"
AUDIO_BASE=$(basename "$AUDIO_FILE")
OUTPUT_NAME="${AUDIO_BASE%.*}_720p.mp4"
OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_NAME"

FPS=30
WIDTH=1280
HEIGHT=720

clear 2>/dev/null || true
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "${BOLD}${CYAN}          YOUTUBE 720p HD VIDEO GENERATION (FAST)           ${NC}"
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "  Audio File:   ${GREEN}$AUDIO_FILE${NC}"
echo -e "  Cover Image:  ${GREEN}$IMAGE_FILE${NC}"
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
echo -e "Resolution:     ${BOLD}${WIDTH}x${HEIGHT} (720p HD @ ${FPS}fps)${NC}"

# Detect optimal Video Encoder
VCODEC="libx264"
VPRESET_ARGS=(-preset faster -crf 22)
if ffmpeg -f lavfi -i color=c=black:s=256x256 -frames:v 1 -c:v h264_nvenc -f null - >/dev/null 2>&1; then
    VCODEC="h264_nvenc"
    VPRESET_ARGS=(-preset p3 -cq 22)
    echo -e "Video Encoder:  ${BOLD}${GREEN}h264_nvenc (NVIDIA NVENC Hardware Accelerated)${NC}"
elif [ "$(uname -s)" = "Darwin" ] && ffmpeg -f lavfi -i color=c=black:s=256x256 -frames:v 1 -c:v h264_videotoolbox -f null - >/dev/null 2>&1; then
    VCODEC="h264_videotoolbox"
    VPRESET_ARGS=(-b:v 3500k)
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
echo -e "${YELLOW}Rendering 720p MP4 with FFmpeg... Please wait.${NC}\n"

ffmpeg -y \
  -err_detect ignore_err \
  -loop 1 -framerate "$FPS" -t "$AUDIO_DURATION" -i "$IMAGE_FILE" \
  -i "$AUDIO_FILE" \
  -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,fade=t=in:st=0:d=5:color=black,fade=t=out:st=${FADE_OUT_START}:d=5:color=black,format=yuv420p" \
  -c:v "$VCODEC" \
  "${VPRESET_ARGS[@]}" \
  -c:a "$ACODEC" \
  -b:a 320k \
  "$OUTPUT_FILE"

STATUS=$?

echo -e "\n${BLUE}------------------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✓ Successfully generated 720p video!${NC}"
    ls -lh "$OUTPUT_FILE"
else
    echo -e "${BOLD}${RED}✗ Video rendering failed with exit code $STATUS!${NC}"
fi
echo -e "${BOLD}${BLUE}============================================================${NC}"
exit $STATUS
