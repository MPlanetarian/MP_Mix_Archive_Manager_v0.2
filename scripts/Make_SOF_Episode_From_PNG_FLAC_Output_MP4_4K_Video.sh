#!/usr/bin/env bash

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

AUDIO_FILE="${1:-FLAC_CONVERTED_OUTPUTS/MPlanetarian_-_Stream_of_Frequency_116_10_YEARS_PART2_2026-08-25.flac}"
IMAGE_FILE="${2:-/home/mplanetarian/Pictures/New_Desktop_Sept_2026.png}"
OUTPUT_DIR="${3:-/home/mplanetarian/Documents}"

if [ ! -f "$AUDIO_FILE" ]; then
    if [ -f "FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE" ]; then
        AUDIO_FILE="FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE"
    else
        echo -e "${RED}Error: Audio file '$AUDIO_FILE' not found!${NC}"
        exit 1
    fi
fi

if [ ! -f "$IMAGE_FILE" ]; then
    echo -e "${RED}Error: Cover/Background image '$IMAGE_FILE' not found!${NC}"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
AUDIO_BASE=$(basename "$AUDIO_FILE")
OUTPUT_NAME="${AUDIO_BASE%.*}_4K.mp4"
OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_NAME"

FPS=30
WIDTH=3840
HEIGHT=2160

echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${BOLD}${CYAN}         YOUTUBE 4K VIDEO GENERATION (NVENC)     ${NC}"
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "  Audio File:   ${GREEN}$AUDIO_FILE${NC}"
echo -e "  Cover Image:  ${GREEN}$IMAGE_FILE${NC}"
echo -e "  Output Video: ${GREEN}$OUTPUT_FILE${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Get audio duration
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")

if [ -z "$AUDIO_DURATION" ]; then
    echo -e "${RED}Error: Could not retrieve audio duration from $AUDIO_FILE${NC}"
    exit 1
fi

echo -e "Audio Duration: ${BOLD}${AUDIO_DURATION}s${NC}"
echo -e "Resolution:     ${BOLD}${WIDTH}x${HEIGHT} (4K UHD @ ${FPS}fps)${NC}"
echo -e "Encoder:        ${BOLD}h264_nvenc (NVENC Hardware Accelerated)${NC}"
echo -e "Audio Codec:    ${BOLD}libfdk_aac @ 320 kbps${NC}"
echo -e "Transitions:    ${BOLD}5s fade-in at start, 5s fade-out at end, 5s dip every 2 mins${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Build filter string using Python
VF=$(python3 -c "
import sys

dur = float(sys.argv[1])
w = sys.argv[2]
h = sys.argv[3]

filters = [
    f'scale={w}:{h}:force_original_aspect_ratio=decrease',
    f'pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:black',
    'setsar=1',
    'format=yuv420p',
    'fade=t=in:st=0:d=5'
]

interval = 120
t = interval
while t + 2.5 < (dur - 6):
    st_out = t - 2.5
    filters.append(f'fade=t=out:st={st_out:.2f}:d=2.5:enable=\'between(t,{st_out:.2f},{t:.2f})\'')
    filters.append(f'fade=t=in:st={t:.2f}:d=2.5:enable=\'between(t,{t:.2f},{t+2.5:.2f})\'')
    t += interval

end_fade_start = dur - 5
filters.append(f'fade=t=out:st={end_fade_start:.2f}:d=5')

print(','.join(filters))
" "$AUDIO_DURATION" "$WIDTH" "$HEIGHT")

echo -e "${YELLOW}Starting FFmpeg 4K render... Please wait.${NC}\n"

ffmpeg -y \
  -err_detect ignore_err \
  -loop 1 -framerate "$FPS" -t "$AUDIO_DURATION" -i "$IMAGE_FILE" \
  -i "$AUDIO_FILE" \
  -map 0:v:0 -map 1:a:0 \
  -vf "$VF" \
  -c:v h264_nvenc \
  -preset p3 \
  -cq 19 \
  -g 60 \
  -c:a libfdk_aac \
  -b:a 320k \
  "$OUTPUT_FILE"

STATUS=$?

echo -e "${BLUE}--------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}Successfully generated 4K video: $OUTPUT_FILE${NC}"
    ls -lh "$OUTPUT_FILE"
else
    echo -e "${BOLD}${RED}FFmpeg exited with error status: $STATUS${NC}"
    exit $STATUS
fi
