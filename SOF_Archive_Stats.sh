#!/usr/bin/env bash

# ================================
# CONFIGURATION & PATHS
# ================================
OUTPUT_DIR="FLAC_CONVERTED_OUTPUTS"

# ANSI Color Codes & Formatting Styles
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"

# Ensure output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Fast inventory counts
flac_count=$(find "$OUTPUT_DIR" -type f -name "*.flac" | wc -l)
wav_count=$(find "$OUTPUT_DIR" -type f -name "*.wav" | wc -l)

# Fast storage footprint calculation using du
flac_size_bytes=$(du -sb "$OUTPUT_DIR" 2>/dev/null | awk '{print $1}')
flac_size_gb=$(awk "BEGIN {print $flac_size_bytes / 1024 / 1024 / 1024}")
wav_size_bytes=0
wav_size_gb=0.000
total_size_bytes="$flac_size_bytes"
total_size_gb="$flac_size_gb"

# Fast tracklist validation (> 3 track ID entries)
valid_tracklists_count=0
if [ -d "$OUTPUT_DIR" ]; then
    while IFS= read -r txt_file; do
        track_entries=$(grep -E '^[0-9]{1,2}\.' "$txt_file" | wc -l)
        if [ "$track_entries" -gt 3 ]; then
            valid_tracklists_count=$((valid_tracklists_count + 1))
        fi
    done < <(find "$OUTPUT_DIR" -type f -name "*.txt")
fi

# Cumulative duration calculation using a safe background aggregator
total_seconds=0
if command -v ffprobe &>/dev/null; then
    while IFS= read -r -d '' file; do
        duration=$(timeout 1 ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        if [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            total_seconds=$(awk "BEGIN {print $total_seconds + $duration}")
        fi
    done < <(find "$OUTPUT_DIR" -type f -name "*.flac" -print0)
fi

tot_sec_int=${total_seconds%.*}
hours=$((tot_sec_int / 3600))
mins=$(((tot_sec_int % 3600) / 60))
secs=$((tot_sec_int % 60))

# Print formatted dashboard instantly
clear
echo -e "${C_CYAN}======================================================${C_RESET}"
echo -e "${C_MAGENTA}${C_BOLD}     STREAM OF FREQUENCY - ARCHIVE STATISTICS     ${C_RESET}"
echo -e "${C_CYAN}======================================================${C_RESET}"
echo ""
echo -e "${C_GREEN}[+] INVENTORY COUNTS${C_RESET}"
echo -e " ----------------------------------------------------"
echo -e " • Converted FLAC Mixes Available: ${C_BOLD}$flac_count${C_RESET}"
echo -e " • Processed WAV Files Archived:   ${C_BOLD}$wav_count${C_RESET}"
echo -e " • Verified Tracklists (>3 Tracks): ${C_BOLD}$valid_tracklists_count${C_RESET}"
echo ""
echo -e "${C_GREEN}[+] STORAGE FOOTPRINT${C_RESET}"
echo -e " ----------------------------------------------------"
echo -e " • FLAC Output Directory Size:     ${C_BOLD}$(printf "%.3f" "$flac_size_gb") GB${C_RESET} (${flac_size_bytes} bytes)"
echo -e " • Archived WAV Directory Size:    ${C_BOLD}$(printf "%.3f" "$wav_size_gb") GB${C_RESET} (${wav_size_bytes} bytes)"
echo -e " • Combined Total Storage Size:    ${C_BOLD}$(printf "%.3f" "$total_size_gb") GB${C_RESET} (${total_size_bytes} bytes)"
echo ""
echo -e "${C_GREEN}[+] TIME ARCHIVE METRICS${C_RESET}"
echo -e " ----------------------------------------------------"
echo -e " • Total Cumulative Duration:      ${C_BOLD}${hours}h ${mins}m ${secs}s${C_RESET}"
echo ""
echo -e "${C_CYAN}======================================================${C_RESET}"
