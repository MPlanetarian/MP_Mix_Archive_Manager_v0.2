#!/usr/bin/env bash

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
CORRUPT_DIR="FLAC_CORRUPTED_FILES"
LOG_DIR="VERIFY_LOGS"

mkdir -p "$CORRUPT_DIR"
mkdir -p "$LOG_DIR"

TODAY=$(date '+%Y-%m-%d')
LOG_FILE="${LOG_DIR}/verify_${TODAY}.log"

echo "==================================================" | tee -a "$LOG_FILE"
echo "FLAC INTEGRITY CHECK STARTED AT $(date)" | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"

shopt -s nullglob nocaseglob
flac_files=("${OUTPUT_DIR}"/*.flac)

if [ ${#flac_files[@]} -eq 0 ]; then
    echo "No FLAC files found in '$OUTPUT_DIR'." | tee -a "$LOG_FILE"
    exit 0
fi

echo "Scanning ${#flac_files[@]} FLAC files for corruption..."
echo "This will decode each file to verify completeness. Please wait..."
echo "--------------------------------------------------"

# Run parallel checks and capture outputs using all available CPU cores
results=$(printf '%s\n' "${flac_files[@]}" | xargs -d '\n' -P "$(nproc)" -I {} bash -c '
    flac="{}"
    filename=$(basename "$flac")
    error_output=$(ffmpeg -v error -i "$flac" -f null - 2>&1)
    status=$?
    if [ $status -ne 0 ] || [ -n "$error_output" ]; then
        # Clean newlines from error detail to keep output parsable on a single line
        clean_detail=$(echo "$error_output" | tr "\n" " ")
        echo "FAIL|$flac|$status|$clean_detail"
    else
        echo "OK|$flac"
    fi
')

checked_count=0
corrupt_count=0

while IFS='|' read -r status flac err_code err_detail; do
    [ -z "$status" ] && continue
    filename=$(basename "$flac")
    if [ "$status" = "FAIL" ]; then
        echo -e "Checking: $filename ... ${RED}CORRUPT${NC}"
        echo "[CORRUPT] $filename - Error status: $err_code. Detail: $err_detail" >> "$LOG_FILE"
        
        # Move corrupt FLAC file
        mv "$flac" "$CORRUPT_DIR/"
        echo " -> Moved to $CORRUPT_DIR/" | tee -a "$LOG_FILE"
        
        # Also move corresponding tracklist if exists
        flac_base="${filename%.*}"
        txt_path="${OUTPUT_DIR}/${flac_base}.txt"
        if [ -f "$txt_path" ]; then
            mv "$txt_path" "$CORRUPT_DIR/"
            echo " -> Moved tracklist $(basename "$txt_path") to $CORRUPT_DIR/" >> "$LOG_FILE"
        fi
        
        ((corrupt_count++))
    else
        echo -e "Checking: $filename ... ${GREEN}OK${NC}"
    fi
    
    ((checked_count++))
done <<< "$results"

echo "--------------------------------------------------" | tee -a "$LOG_FILE"
echo "Verification complete." | tee -a "$LOG_FILE"
echo "Total checked: $checked_count" | tee -a "$LOG_FILE"
echo "Total corrupt moved: $corrupt_count" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "==================================================" | tee -a "$LOG_FILE"
