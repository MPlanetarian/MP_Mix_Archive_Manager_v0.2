#!/usr/bin/env bash

# Paths
MIX_ARCHIVE_DIR="/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"
PLAYLIST_FILE="${MIX_ARCHIVE_DIR}/Back to Trance Roots.m3u"
OUTPUT_DIR="${MIX_ARCHIVE_DIR}/FLAC_CONVERTED_OUTPUTS"
COVER_ART="${MIX_ARCHIVE_DIR}/Cover.png"
OUTPUT_FILE="${OUTPUT_DIR}/MPlanetarian - Stream of Frequency - Back to Trance Roots.flac"

echo "=================================================="
echo "Starting Playlist Merge to FLAC"
echo "=================================================="

# Check files
if [ ! -f "$PLAYLIST_FILE" ]; then
    echo "ERROR: Playlist file not found at $PLAYLIST_FILE"
    exit 1
fi

if [ ! -f "$COVER_ART" ]; then
    echo "ERROR: Cover art not found at $COVER_ART"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Parse playlist lines and build paths
declare -a WAV_FILES=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip carriage return and leading/trailing whitespace
    line=$(echo "$line" | tr -d '\r' | xargs)
    [ -z "$line" ] && continue
    # Skip comments
    [[ "$line" =~ ^# ]] && continue
    
    # Resolve relative path to absolute
    abs_path="${MIX_ARCHIVE_DIR}/${line}"
    if [ -f "$abs_path" ]; then
        WAV_FILES+=("$abs_path")
        echo "Found source WAV: $(basename "$abs_path")"
    else
        echo "ERROR: Source file not found: $abs_path"
        exit 1
    fi
done < "$PLAYLIST_FILE"

echo "Total WAV files to merge: ${#WAV_FILES[@]}"

# Prepare optimized cover art
echo " -> Optimizing cover art..."
OPTIMIZED_COVER=$(mktemp --suffix=.png)
ffmpeg -y -i "$COVER_ART" -vf "scale='min(1400,iw)':-1" "$OPTIMIZED_COVER" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "WARNING: Failed to optimize cover art. Using original Cover.png."
    cp "$COVER_ART" "$OPTIMIZED_COVER"
fi

# Concat list
concat_list=$(mktemp)
for w in "${WAV_FILES[@]}"; do
    echo "file '$w'" >> "$concat_list"
done

# Run ffmpeg conversion
echo " -> Merging WAV files and converting to FLAC with compression_level 12 and sample_fmt s32..."
ffmpeg -y -f concat -safe 0 -i "$concat_list" -i "$OPTIMIZED_COVER" \
  -c:a flac -sample_fmt s32 -compression_level 12 \
  -map 0:a -map 1:v \
  -metadata artist="MPlanetarian" \
  -metadata album="Stream of Frequency" \
  -metadata title="Back to Trance Roots" \
  -disposition:v:0 attached_pic \
  "$OUTPUT_FILE"

CONVERSION_STATUS=$?

rm -f "$concat_list"
rm -f "$OPTIMIZED_COVER"

if [ $CONVERSION_STATUS -eq 0 ]; then
    echo "=================================================="
    echo "SUCCESS: Converted to $OUTPUT_FILE"
    echo "=================================================="
else
    echo "=================================================="
    echo "ERROR: FFmpeg command failed with exit code $CONVERSION_STATUS"
    echo "=================================================="
    exit 1
fi
