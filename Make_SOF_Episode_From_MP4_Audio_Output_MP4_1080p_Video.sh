#!/usr/bin/env bash
# ==============================================================================
# Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh
# Generates YouTube Video (1080p Full HD @ 30fps default, also supports 4K / 720p)
# from an input MP4/MKV video and a FLAC/WAV audio soundtrack.
# Repeats the video seamlessly in segments with fade-in and fade-out to match
# the full duration of the audio, and adds optional Intro and Outro thumbnail cards.
# Hardware Accelerated (NVIDIA NVENC / Apple VideoToolbox / libx264 fallback).
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

ARG1="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"
ARG4="${4:-}"
ARG5="${5:-1080p}"

AUDIO_FILE=""
VIDEO_FILE=""
THUMB_FILE=""
OUTPUT_TARGET=""
RESOLUTION="$ARG5"

# Smart parameter detection: identify which argument is audio vs video
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
            if [ -f "$f" ]; then
                local has_v
                has_v=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null || true)
                local has_a
                has_a=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null || true)
                if [ -n "$has_v" ] && [ -z "$has_a" ]; then
                    echo "video"
                elif [ -n "$has_a" ] && [ -z "$has_v" ]; then
                    echo "audio"
                else
                    echo "unknown"
                fi
            else
                echo "unknown"
            fi
            ;;
    esac
}

t1=$(detect_media_type "$ARG1")
t2=$(detect_media_type "$ARG2")

if [ "$t1" = "audio" ] && [ "$t2" = "video" ]; then
    AUDIO_FILE="$ARG1"
    VIDEO_FILE="$ARG2"
elif [ "$t1" = "video" ] && [ "$t2" = "audio" ]; then
    VIDEO_FILE="$ARG1"
    AUDIO_FILE="$ARG2"
elif [ "$t1" = "audio" ]; then
    AUDIO_FILE="$ARG1"
    VIDEO_FILE="$ARG2"
elif [ "$t1" = "video" ]; then
    VIDEO_FILE="$ARG1"
    AUDIO_FILE="$ARG2"
else
    AUDIO_FILE="$ARG1"
    VIDEO_FILE="$ARG2"
fi

THUMB_FILE="$ARG3"
OUTPUT_TARGET="$ARG4"

# Interactive prompting if files missing
if [ -z "$AUDIO_FILE" ] || [ -z "$VIDEO_FILE" ]; then
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       YOUTUBE MP4-TO-MP4 VIDEO CREATOR (LOOPING & FADE SUITE)        ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    [ -z "$AUDIO_FILE" ] && read -r -p "Enter path to Audio file (.wav / .flac): " AUDIO_FILE
    [ -z "$VIDEO_FILE" ] && read -r -p "Enter path to Input Video file (.mp4 / .mkv): " VIDEO_FILE
    [ -z "$THUMB_FILE" ] && read -r -p "Enter path to Thumbnail/Cover image (optional): " THUMB_FILE
    [ -z "$OUTPUT_TARGET" ] && read -r -p "Enter output directory or file path (default: ${MP4_OUTPUT_DIR:-MP4_CONVERTED_OUTPUTS}): " OUTPUT_TARGET
fi

# Clean quotes
AUDIO_FILE=$(echo "$AUDIO_FILE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
VIDEO_FILE=$(echo "$VIDEO_FILE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
THUMB_FILE=$(echo "$THUMB_FILE" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
OUTPUT_TARGET=$(echo "$OUTPUT_TARGET" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

# Verify audio file
if [ ! -f "$AUDIO_FILE" ]; then
    for candidate in "$AUDIO_FILE" "${MP4_OUTPUT_DIR:-MP4_CONVERTED_OUTPUTS}/$AUDIO_FILE" "FLAC_CONVERTED_OUTPUTS/$AUDIO_FILE" "WAV_CONVERTED_OUTPUTS/$AUDIO_FILE" "CONVERTED_WAV_FILES/$AUDIO_FILE" "$AUDIO_FILE.wav" "$AUDIO_FILE.flac"; do
        if [ -f "$candidate" ]; then AUDIO_FILE="$candidate"; break; fi
    done
fi

if [ ! -f "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: Audio file '$AUDIO_FILE' not found!${NC}"
    exit 1
fi

# Verify video file
if [ ! -f "$VIDEO_FILE" ]; then
    echo -e "${RED}Error: Video file '$VIDEO_FILE' not found!${NC}"
    exit 1
fi

# Handle Thumbnail file
HAS_THUMB=0
if [ -n "$THUMB_FILE" ] && [ -f "$THUMB_FILE" ]; then
    HAS_THUMB=1
else
    # Auto-detection check
    for c in "$THUMB_FILE" "Cover.png" "assets/Cover.png" "COVERS/Cover.png"; do
        if [ -n "$c" ] && [ -f "$c" ]; then
            THUMB_FILE="$c"
            HAS_THUMB=1
            break
        fi
    done
fi

# Determine Resolution parameters
WIDTH=1920
HEIGHT=1080
RES_LABEL="1080p Full HD"
RES_SUFFIX=""
CRF=21
CQ=20
BITRATE_V="7500k"

case "${RESOLUTION,,}" in
    4k|2160p|uhd)
        WIDTH=3840
        HEIGHT=2160
        RES_LABEL="4K UHD (2160p)"
        RES_SUFFIX="_4K"
        CRF=19
        CQ=18
        BITRATE_V="18000k"
        ;;
    720p|hd)
        WIDTH=1280
        HEIGHT=720
        RES_LABEL="720p HD"
        RES_SUFFIX="_720p"
        CRF=22
        CQ=22
        BITRATE_V="3500k"
        ;;
    *)
        WIDTH=1920
        HEIGHT=1080
        RES_LABEL="1080p Full HD"
        RES_SUFFIX=""
        CRF=21
        CQ=20
        BITRATE_V="7500k"
        ;;
esac

# Output path calculation
AUDIO_BASE=$(basename "$AUDIO_FILE")
OUTPUT_NAME="${AUDIO_BASE%.*}${RES_SUFFIX}.mp4"

if [ -z "$OUTPUT_TARGET" ]; then
    OUTPUT_DIR="${MP4_OUTPUT_DIR:-MP4_CONVERTED_OUTPUTS}"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_NAME"
elif [[ "$OUTPUT_TARGET" == *.mp4 ]] || [[ "$OUTPUT_TARGET" == *.mkv ]]; then
    OUTPUT_FILE="$OUTPUT_TARGET"
    OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
    mkdir -p "$OUTPUT_DIR"
else
    OUTPUT_DIR="$OUTPUT_TARGET"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_NAME"
fi

# Detect optimal Video Encoder
VCODEC="libx264"
VPRESET_ARGS=(-preset medium -crf "$CRF")
if ffmpeg -f lavfi -i color=c=black:s=256x256 -frames:v 1 -c:v h264_nvenc -f null - >/dev/null 2>&1; then
    VCODEC="h264_nvenc"
    VPRESET_ARGS=(-preset p3 -cq "$CQ" -g 60)
    ENCODER_STR="h264_nvenc (NVIDIA NVENC Hardware Accelerated)"
elif [ "$(uname -s)" = "Darwin" ] && ffmpeg -f lavfi -i color=c=black:s=256x256 -frames:v 1 -c:v h264_videotoolbox -f null - >/dev/null 2>&1; then
    VCODEC="h264_videotoolbox"
    VPRESET_ARGS=(-b:v "$BITRATE_V")
    ENCODER_STR="h264_videotoolbox (Apple Silicon Hardware Accelerated)"
else
    ENCODER_STR="libx264 (CPU Software Encoder)"
fi

# Detect optimal Audio Encoder
ACODEC="aac"
if ffmpeg -encoders 2>/dev/null | grep -q "libfdk_aac"; then
    ACODEC="libfdk_aac"
    ACODEC_STR="libfdk_aac @ 320 kbps (Pristine)"
else
    ACODEC_STR="native aac @ 320 kbps"
fi

# Retrieve audio and video duration
AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE" 2>/dev/null || echo "")
if [ -z "$AUDIO_DURATION" ]; then
    echo -e "${RED}Error: Could not retrieve audio duration from $AUDIO_FILE${NC}"
    exit 1
fi

VIDEO_DURATION=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE" 2>/dev/null || echo "")
if [ -z "$VIDEO_DURATION" ] || [ "$VIDEO_DURATION" = "N/A" ]; then
    VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE" 2>/dev/null || echo "")
fi
if [ -z "$VIDEO_DURATION" ] || [ "$VIDEO_DURATION" = "N/A" ]; then
    echo -e "${RED}Error: Could not retrieve video duration from $VIDEO_FILE${NC}"
    exit 1
fi

INTRO_SEC=5.0
OUTRO_SEC=5.0
SEG_FADE_DUR=1.5
AUDIO_FADE_DUR=5.0

# Calculate durations using python
PLAN_OUTPUT=$(python3 -c "
import math

audio_dur = float('$AUDIO_DURATION')
video_dur = float('$VIDEO_DURATION')
has_thumb = int('$HAS_THUMB')
intro_sec = float('$INTRO_SEC') if has_thumb else 0.0
outro_sec = float('$OUTRO_SEC') if has_thumb else 0.0
fade_dur = float('$SEG_FADE_DUR')

if has_thumb and audio_dur <= (intro_sec + outro_sec + 2.0):
    intro_sec = max(1.0, audio_dur * 0.15)
    outro_sec = max(1.0, audio_dur * 0.15)

mid_dur = max(0.0, audio_dur - intro_sec - outro_sec)

if mid_dur <= 0.0:
    num_full = 0
    rem_dur = 0.0
elif video_dur >= mid_dur:
    num_full = 0
    rem_dur = mid_dur
else:
    num_full = int(mid_dur // video_dur)
    rem_dur = mid_dur - (num_full * video_dur)

print(f'{intro_sec:.6f}|{outro_sec:.6f}|{mid_dur:.6f}|{num_full}|{rem_dur:.6f}|{fade_dur:.6f}')
")

IFS='|' read -r CALC_INTRO CALC_OUTRO CALC_MID NUM_FULL REM_DUR CALC_FADE <<< "$PLAN_OUTPUT"

echo -e "\n${BOLD}${BLUE}============================================================${NC}"
echo -e "${BOLD}${CYAN}      YOUTUBE MP4-TO-MP4 VIDEO GENERATION - ${RES_LABEL}     ${NC}"
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "  Audio File:       ${GREEN}$AUDIO_FILE${NC}"
echo -e "  Audio Duration:   ${BOLD}${AUDIO_DURATION}s${NC}"
echo -e "  Video File:       ${GREEN}$VIDEO_FILE${NC}"
echo -e "  Video Duration:   ${BOLD}${VIDEO_DURATION}s${NC}"
if [ "$HAS_THUMB" -eq 1 ]; then
    echo -e "  Thumbnail Image:  ${GREEN}$THUMB_FILE${NC}"
    echo -e "  Intro / Outro:    ${BOLD}${CALC_INTRO}s Intro / ${CALC_OUTRO}s Outro (with fade)${NC}"
else
    echo -e "  Thumbnail Image:  ${YELLOW}None (Continuous Video Mode)${NC}"
fi
echo -e "  Video Repeats:    ${BOLD}${NUM_FULL} full repeats + ${REM_DUR}s final segment${NC}"
echo -e "  Segment Fades:    ${BOLD}${CALC_FADE}s fade-in / fade-out per segment${NC}"
echo -e "  Video Encoder:    ${BOLD}${GREEN}${ENCODER_STR}${NC}"
echo -e "  Audio Codec:      ${BOLD}${GREEN}${ACODEC_STR}${NC}"
echo -e "  Output Video:     ${GREEN}$OUTPUT_FILE${NC}"
echo -e "${BLUE}------------------------------------------------------------${NC}"
echo -e "${YELLOW}Rendering 1080p looped MP4 video with FFmpeg... Please wait.${NC}\n"

# Create a secure temporary directory
TEMP_DIR=$(mktemp -d -t yt_mp4_loop_XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

CONCAT_LIST="$TEMP_DIR/concat_list.txt"
> "$CONCAT_LIST"

# 1. Render Intro Card if Thumbnail is present
if [ "$HAS_THUMB" -eq 1 ] && (( $(echo "$CALC_INTRO > 0.1" | bc -l) )); then
    echo -e "  -> Rendering Intro Thumbnail card (${CALC_INTRO}s)..."
    INTRO_FADE_OUT=$(python3 -c "print(f'{max(0.0, $CALC_INTRO - $CALC_FADE):.6f}')")
    ffmpeg -y \
      -loop 1 -i "$THUMB_FILE" \
      -vf "fps=30,scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fade=t=in:st=0:d=${CALC_FADE}:color=black,fade=t=out:st=${INTRO_FADE_OUT}:d=${CALC_FADE}:color=black,format=yuv420p" \
      -t "$CALC_INTRO" \
      -c:v "$VCODEC" \
      "${VPRESET_ARGS[@]}" \
      "$TEMP_DIR/intro.mp4" >/dev/null 2>&1
    echo "file '$TEMP_DIR/intro.mp4'" >> "$CONCAT_LIST"
fi

# 2. Render Full Video Segment (if needed)
if [ "$NUM_FULL" -gt 0 ]; then
    echo -e "  -> Rendering Standard Looping Segment (${VIDEO_DURATION}s with fades)..."
    SEG_FADE_OUT=$(python3 -c "print(f'{max(0.0, $VIDEO_DURATION - $CALC_FADE):.6f}')")
    ffmpeg -y \
      -i "$VIDEO_FILE" \
      -vf "setpts=PTS-STARTPTS,fps=30,scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fade=t=in:st=0:d=${CALC_FADE}:color=black,fade=t=out:st=${SEG_FADE_OUT}:d=${CALC_FADE}:color=black,format=yuv420p" \
      -t "$VIDEO_DURATION" \
      -c:v "$VCODEC" \
      "${VPRESET_ARGS[@]}" \
      "$TEMP_DIR/seg_full.mp4" >/dev/null 2>&1

    for ((i=1; i<=NUM_FULL; i++)); do
        echo "file '$TEMP_DIR/seg_full.mp4'" >> "$CONCAT_LIST"
    done
fi

# 3. Render Final Partial Segment (if needed)
if (( $(echo "$REM_DUR > 0.05" | bc -l) )); then
    echo -e "  -> Rendering Final Trailing Segment (${REM_DUR}s with fades)..."
    REM_FADE_DUR=$(python3 -c "print(f'{min($CALC_FADE, $REM_DUR / 3.0):.6f}')")
    REM_FADE_OUT=$(python3 -c "print(f'{max(0.0, $REM_DUR - $REM_FADE_DUR):.6f}')")
    ffmpeg -y \
      -i "$VIDEO_FILE" \
      -vf "setpts=PTS-STARTPTS,fps=30,scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fade=t=in:st=0:d=${REM_FADE_DUR}:color=black,fade=t=out:st=${REM_FADE_OUT}:d=${REM_FADE_DUR}:color=black,format=yuv420p" \
      -t "$REM_DUR" \
      -c:v "$VCODEC" \
      "${VPRESET_ARGS[@]}" \
      "$TEMP_DIR/seg_last.mp4" >/dev/null 2>&1
    echo "file '$TEMP_DIR/seg_last.mp4'" >> "$CONCAT_LIST"
fi

# 4. Render Outro Card if Thumbnail is present
if [ "$HAS_THUMB" -eq 1 ] && (( $(echo "$CALC_OUTRO > 0.1" | bc -l) )); then
    echo -e "  -> Rendering Outro Thumbnail card (${CALC_OUTRO}s)..."
    OUTRO_FADE_OUT=$(python3 -c "print(f'{max(0.0, $CALC_OUTRO - $CALC_FADE):.6f}')")
    ffmpeg -y \
      -loop 1 -i "$THUMB_FILE" \
      -vf "fps=30,scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fade=t=in:st=0:d=${CALC_FADE}:color=black,fade=t=out:st=${OUTRO_FADE_OUT}:d=${CALC_FADE}:color=black,format=yuv420p" \
      -t "$CALC_OUTRO" \
      -c:v "$VCODEC" \
      "${VPRESET_ARGS[@]}" \
      "$TEMP_DIR/outro.mp4" >/dev/null 2>&1
    echo "file '$TEMP_DIR/outro.mp4'" >> "$CONCAT_LIST"
fi

# 5. Merge all video segments and mux WAV audio with studio fades
AUDIO_FADE_OUT_START=$(python3 -c "print(f'{max(0.0, float(\"$AUDIO_DURATION\") - $AUDIO_FADE_DUR):.6f}')")
echo -e "  -> Concatenating video loop and muxing 320kbps audio..."

ffmpeg -y \
  -f concat -safe 0 -i "$CONCAT_LIST" \
  -i "$AUDIO_FILE" \
  -map 0:v:0 -map 1:a:0 \
  -c:v copy \
  -af "afade=t=in:st=0:d=${AUDIO_FADE_DUR},afade=t=out:st=${AUDIO_FADE_OUT_START}:d=${AUDIO_FADE_DUR}" \
  -c:a "$ACODEC" \
  -b:a 320k \
  -t "$AUDIO_DURATION" \
  -movflags +faststart \
  "$OUTPUT_FILE"

STATUS=$?

echo -e "\n${BLUE}------------------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✓ Successfully generated ${RES_LABEL} MP4 Video!${NC}"
    ls -lh "$OUTPUT_FILE"
else
    echo -e "${BOLD}${RED}✗ Video generation failed with exit code $STATUS!${NC}"
fi
echo -e "${BOLD}${BLUE}============================================================${NC}"

exit $STATUS
