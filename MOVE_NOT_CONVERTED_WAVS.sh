#!/usr/bin/env bash

# ================================
# CONFIGURATION & PATHS
# ================================
ARCHIVE_DIR="CONVERTED_WAV_FILES"
OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
ROOT_DIR="."

echo "=================================================="
echo "Checking and retrieving unconverted WAV files..."
echo "=================================================="

if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "ERROR: Archive directory '$ARCHIVE_DIR' not found!"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "ERROR: Output directory '$OUTPUT_DIR' not found!"
    exit 1
fi

shopt -s nullglob nocaseglob

wav_files=("$ARCHIVE_DIR"/*.wav)

if [ ${#wav_files[@]} -eq 0 ]; then
    echo "No WAV files found in '$ARCHIVE_DIR'."
    exit 0
fi

retrieved_count=0

for wav in "${wav_files[@]}"; do
    filename=$(basename "$wav")
    
    # Strip split segment suffixes and extensions to find the core base name
    base_name=$(echo "$filename" | sed -E 's/_[0-9]{2}h[0-9]{2}m[0-9]{2}(\.[Ww][Aa][Vv])?$//' | sed -E 's/\.[Ww][Aa][Vv]$//')
    
    expected_flac="${OUTPUT_DIR}/${base_name}.flac"
    
    if [ ! -f "$expected_flac" ]; then
        echo " [UNCONVERTED] Moving $filename to root directory..."
        mv "$wav" "$ROOT_DIR/"
        ((retrieved_count++))
    else
        echo " [CONVERTED]   $filename (FLAC exists)"
    fi
done

echo "=================================================="
if [ "$retrieved_count" -eq 0 ]; then
    echo "Status: All files are converted. No files moved."
else
    echo "Status: Successfully moved $retrieved_count unconverted WAV file(s) to the root directory."
fi
echo "=================================================="
