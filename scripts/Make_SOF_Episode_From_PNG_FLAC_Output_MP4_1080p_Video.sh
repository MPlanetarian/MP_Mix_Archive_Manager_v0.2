#!/usr/bin/env bash

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

AUDIO_FILE="$1"
IMAGE_FILE="$2"

if [ -z "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: Audio file not specified!${NC}"
    echo "Usage: $0 <path_to_audio.flac> [path_to_cover.png]"
    exit 1
fi

if [ ! -f "$AUDIO_FILE" ]; then
    # Try looking in FLAC_CONVERTED_OUTPUTS if not found directly
    if [ -f "FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE" ]; then
        AUDIO_FILE="FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE"
    elif [ -f "FLAC_CORRUPTED_FILES/$AUDIO_FILE" ]; then
        AUDIO_FILE="FLAC_CORRUPTED_FILES/$AUDIO_FILE"
    else
        echo -e "${RED}Error: Audio file '$AUDIO_FILE' not found!${NC}"
        exit 1
    fi
fi

if [ -z "$IMAGE_FILE" ]; then
    IMAGE_FILE="Cover.png"
fi

if [ ! -f "$IMAGE_FILE" ]; then
    # Try looking in COVERS/
    if [ -f "COVERS/$IMAGE_FILE" ]; then
        IMAGE_FILE="COVERS/$IMAGE_FILE"
    elif [ -f "Cover.png" ]; then
        echo -e "${YELLOW}Warning: Cover file '$IMAGE_FILE' not found. Falling back to default Cover.png.${NC}"
        IMAGE_FILE="Cover.png"
    else
        echo -e "${RED}Error: Cover image '$IMAGE_FILE' not found and default Cover.png is missing!${NC}"
        exit 1
    fi
fi

# Deriving Output filename
AUDIO_BASE=$(basename "$AUDIO_FILE")
OUTPUT_NAME="${AUDIO_BASE%.*}.mp4"
OUTPUT_FILE="FLAC_CONVERTED_OUTPUTS/$OUTPUT_NAME"

FPS=30
WIDTH=1920
HEIGHT=1080

clear
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${BOLD}${BLUE}             YOUTUBE VIDEO GENERATION             ${NC}"
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "  Audio File:  $AUDIO_FILE"
echo -e "  Cover Image: $IMAGE_FILE"
echo -e "  Output Video: $OUTPUT_FILE"
echo -e "${BLUE}--------------------------------------------------${NC}"

# 1. Get exact audio duration
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")

if [ -z "$AUDIO_DURATION" ]; then
    echo -e "${RED}Error: Could not retrieve duration from $AUDIO_FILE${NC}"
    exit 1
fi

TOTAL_SEC=$(printf "%.0f" "$AUDIO_DURATION")
FADE_OUT_START=$((TOTAL_SEC - 5))

echo "Audio Duration: ${AUDIO_DURATION}s"
echo "Fade-in: 0s to 5s | Fade-out: ${FADE_OUT_START}s to ${TOTAL_SEC}s"
echo -e "${YELLOW}Starting FFmpeg render... Please wait.${NC}\n"

# 2. Run FFmpeg with libfdk_aac locked at pristine 320kbps
ffmpeg -y \
  -err_detect ignore_err \
  -loop 1 -framerate "$FPS" -t "$AUDIO_DURATION" -i "$IMAGE_FILE" \
  -i "$AUDIO_FILE" \
  -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,fade=t=in:st=0:d=5:color=black,fade=t=out:st=${FADE_OUT_START}:d=5:color=black,format=yuv420p" \
  -c:v libx264 \
  -preset medium \
  -crf 23 \
  -c:a libfdk_aac \
  -b:a 320k \
  "$OUTPUT_FILE"

STATUS=$?

echo -e "${BLUE}--------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}Finished generating $OUTPUT_FILE!${NC}"
else
    echo -e "${BOLD}${RED}Video rendering failed!${NC}"
fi
echo -e "${BLUE}==================================================${NC}"
exit $STATUS
