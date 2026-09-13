#!/usr/bin/env bash

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"
DEST_REMOTE="gdrive:MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"
LOG_DIR="BACKUP_LOGS"
BW_LIMIT="0" # Bandwidth limit (e.g. 10M, 50M, 0 for unlimited)
mkdir -p "$LOG_DIR"

TODAY=$(date '+%Y-%m-%d')
LOG_FILE="${LOG_DIR}/backup_${TODAY}.log"

START_DATE=$(date '+%A, %Y-%m-%d')
START_TIME=$(date '+%H:%M:%S')
START_SECONDS=$(date +%s)

clear
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${BOLD}${BLUE}             GOOGLE DRIVE BACKUP JOB              ${NC}"
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "  Start Date:   $START_DATE"
echo -e "  Start Time:   $START_TIME"
echo -e "  Source:       $OUTPUT_DIR"
echo -e "  Destination:  $DEST_REMOTE"
echo -e "  Log File:     $LOG_FILE"
echo -e "  BW Limit:     $BW_LIMIT"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${YELLOW}Starting rclone copy process... Please wait.${NC}\n"

# Run rclone copy with progress on terminal and info logging to log file
rclone copy "$OUTPUT_DIR" "$DEST_REMOTE" --bwlimit "$BW_LIMIT" --progress --log-file="$LOG_FILE" --log-level=INFO
RCLONE_STATUS=$?

END_TIME=$(date '+%H:%M:%S')
END_SECONDS=$(date +%s)
TOTAL_RUN_TIME=$((END_SECONDS - START_SECONDS))

# Format run time
hours=$((TOTAL_RUN_TIME / 3600))
mins=$(((TOTAL_RUN_TIME % 3600) / 60))
secs=$((TOTAL_RUN_TIME % 60))
FORMATTED_RUNTIME="${hours}h ${mins}m ${secs}s"

# Extract summary stats from the rclone log
COPIED_FILES_COUNT=$(grep -E -c "Copied \(new\)|Copied \(replaced\)" "$LOG_FILE" 2>/dev/null || echo "0")
SOURCE_SIZE=$(du -sh "$OUTPUT_DIR" | awk '{print $1}')

# Build summary text
SUMMARY_TEXT=$(cat << SUMMARY

==================================================
BACKUP JOB SUMMARY
==================================================
Status:       $( [ $RCLONE_STATUS -eq 0 ] && echo "SUCCESS" || echo "FAILED" )
Date:         $START_DATE
Start Time:   $START_TIME
End Time:     $END_TIME
Total Runtime: $FORMATTED_RUNTIME
Source Dir:   $OUTPUT_DIR ($SOURCE_SIZE)
Destination:  $DEST_REMOTE
Files Transferred: $COPIED_FILES_COUNT files
Log File:     $LOG_FILE
==================================================
SUMMARY
)

# Append summary to log file
echo "$SUMMARY_TEXT" >> "$LOG_FILE"

# Display summary to terminal
if [ $RCLONE_STATUS -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}Backup Completed Successfully!${NC}"
    echo -e "$SUMMARY_TEXT"
else
    echo -e "\n${BOLD}${RED}Backup Job Failed! Check the log file for errors.${NC}"
    echo -e "$SUMMARY_TEXT"
fi
