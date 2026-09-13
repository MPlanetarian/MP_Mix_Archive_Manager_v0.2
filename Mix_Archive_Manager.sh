#!/usr/bin/env bash

# Colors for terminal styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$HOME/bin:$PATH"

# Load optional user configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
elif [ -f "$HOME/.config/mix-manager/config.env" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.config/mix-manager/config.env"
fi

OUTPUT_DIR="${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}"
ARCHIVE_DIR="${ARCHIVE_DIR:-CONVERTED_WAV_FILES}"

# Determine target working archive directory
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
    cd "$MIX_ARCHIVE_DIR" || exit 1
elif [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" ]; then
    cd "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" || exit 1
elif [ -d "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" ]; then
    cd "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" || exit 1
elif [ -d "$SCRIPT_DIR" ]; then
    cd "$SCRIPT_DIR" || exit 1
fi

run_sub_script() {
    local script_name="$1"
    shift
    if [ -x "./$script_name" ]; then
        "./$script_name" "$@"
    elif [ -f "./$script_name" ]; then
        bash "./$script_name" "$@"
    elif [ -x "$SCRIPT_DIR/$script_name" ]; then
        "$SCRIPT_DIR/$script_name" "$@"
    elif [ -f "$SCRIPT_DIR/$script_name" ]; then
        bash "$SCRIPT_DIR/$script_name" "$@"
    elif [ -x "$SCRIPT_DIR/scripts/$script_name" ]; then
        "$SCRIPT_DIR/scripts/$script_name" "$@"
    elif [ -f "$SCRIPT_DIR/scripts/$script_name" ]; then
        bash "$SCRIPT_DIR/scripts/$script_name" "$@"
    elif command -v "$script_name" >/dev/null 2>&1; then
        "$script_name" "$@"
    else
        echo -e "${RED}Error: Script '$script_name' not found in $(pwd) or $SCRIPT_DIR!${NC}"
        return 1
    fi
}

get_cliamp_track_info() {
    CLIAMP_RUNNING=0
    CLIAMP_STATE=""
    CLIAMP_TITLE=""
    CLIAMP_ARTIST=""
    CLIAMP_RAW_PATH=""
    CLIAMP_RESOLVED_PATH=""
    CLIAMP_FILE_EXISTS=0
    CLIAMP_FILE_SIZE=""
    CLIAMP_POSITION=0
    CLIAMP_DURATION=0
    CLIAMP_POS_FMT="00:00"
    CLIAMP_DUR_FMT="00:00"
    CLIAMP_PROGRESS_PCT=0

    local cliamp_bin="cliamp"
    if ! command -v cliamp >/dev/null 2>&1; then
        if [ -x "$SCRIPT_DIR/bin/cliamp" ]; then
            cliamp_bin="$SCRIPT_DIR/bin/cliamp"
        elif [ -x "$HOME/.local/bin/cliamp" ]; then
            cliamp_bin="$HOME/.local/bin/cliamp"
        else
            return 1
        fi
    fi

    local pids
    pids=$(pgrep -x cliamp 2>/dev/null)
    if [ -z "$pids" ]; then
        return 1
    fi
    CLIAMP_RUNNING=1

    local status_json
    status_json=$("$cliamp_bin" status --json 2>/dev/null)
    if [ -z "$status_json" ] || ! echo "$status_json" | jq -e . >/dev/null 2>&1; then
        return 1
    fi

    local ok
    ok=$(echo "$status_json" | jq -r '.ok // false')
    if [ "$ok" != "true" ]; then
        return 1
    fi

    CLIAMP_STATE=$(echo "$status_json" | jq -r '.state // "unknown"')
    CLIAMP_TITLE=$(echo "$status_json" | jq -r '.track.title // ""')
    CLIAMP_ARTIST=$(echo "$status_json" | jq -r '.track.artist // ""')
    CLIAMP_RAW_PATH=$(echo "$status_json" | jq -r '.track.path // ""')
    CLIAMP_POSITION=$(echo "$status_json" | jq -r '.position // 0' | awk '{printf "%d", $1}')
    CLIAMP_DURATION=$(echo "$status_json" | jq -r '.duration // 0' | awk '{printf "%d", $1}')

    format_seconds_cliamp() {
        local t=$1
        local h=$((t / 3600))
        local m=$(( (t % 3600) / 60 ))
        local s=$((t % 60))
        if [ $h -gt 0 ]; then
            printf "%02d:%02d:%02d" $h $m $s
        else
            printf "%02d:%02d" $m $s
        fi
    }
    CLIAMP_POS_FMT=$(format_seconds_cliamp "$CLIAMP_POSITION")
    CLIAMP_DUR_FMT=$(format_seconds_cliamp "$CLIAMP_DURATION")

    if [ "$CLIAMP_DURATION" -gt 0 ]; then
        CLIAMP_PROGRESS_PCT=$((CLIAMP_POSITION * 100 / CLIAMP_DURATION))
    else
        CLIAMP_PROGRESS_PCT=0
    fi

    CLIAMP_RESOLVED_PATH="$CLIAMP_RAW_PATH"
    if [ -e "$CLIAMP_RESOLVED_PATH" ]; then
        CLIAMP_FILE_EXISTS=1
    else
        local alt="${CLIAMP_RAW_PATH/#\/media\//\/run\/media\/}"
        if [ -e "$alt" ]; then
            CLIAMP_RESOLVED_PATH="$alt"
            CLIAMP_FILE_EXISTS=1
        else
            for pid in $pids; do
                for fd in /proc/"$pid"/fd/*; do
                    if [ -e "$fd" ]; then
                        local target
                        target=$(readlink "$fd" 2>/dev/null)
                        if [ -n "$target" ] && [ "$(basename "$CLIAMP_RAW_PATH")" = "$(basename "$target")" ] && [ -e "$target" ]; then
                            CLIAMP_RESOLVED_PATH="$target"
                            CLIAMP_FILE_EXISTS=1
                            break 2
                        fi
                    fi
                done
            done
            if [ "$CLIAMP_FILE_EXISTS" -eq 0 ]; then
                local bname
                bname=$(basename "$CLIAMP_RAW_PATH")
                for dir in \
                    "${MIX_ARCHIVE_DIR:-}" \
                    "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" \
                    "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" \
                    "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" \
                    "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" \
                    "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" \
                    "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" \
                    "$SCRIPT_DIR" \
                    "$SCRIPT_DIR/CONVERTED_WAV_FILES" \
                    "$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS" \
                    "$PWD"; do
                    if [ -n "$dir" ] && [ -f "$dir/$bname" ]; then
                        CLIAMP_RESOLVED_PATH="$dir/$bname"
                        CLIAMP_FILE_EXISTS=1
                        break
                    fi
                done
            fi
        fi
    fi

    if [ "$CLIAMP_FILE_EXISTS" -eq 1 ]; then
        CLIAMP_FILE_SIZE=$(ls -lh "$CLIAMP_RESOLVED_PATH" 2>/dev/null | awk '{print $5}')
    fi

    return 0
}

# Command-line flags for quick inspection without full interactive menu
if [ "$1" = "--track" ] || [ "$1" = "--current-track" ] || [ "$1" = "--cliamp-path" ] || [ "$1" = "-p" ]; then
    if get_cliamp_track_info 2>/dev/null; then
        echo "$CLIAMP_RESOLVED_PATH"
        exit 0
    else
        echo "Error: cliamp is not running or no track playing." >&2
        exit 1
    fi
elif [ "$1" = "--cliamp-info" ]; then
    if get_cliamp_track_info 2>/dev/null; then
        echo "State: $CLIAMP_STATE"
        echo "Title: $CLIAMP_TITLE"
        echo "Artist: $CLIAMP_ARTIST"
        echo "Time: $CLIAMP_POS_FMT / $CLIAMP_DUR_FMT ($CLIAMP_PROGRESS_PCT%)"
        echo "Path: $CLIAMP_RESOLVED_PATH"
        [ -n "$CLIAMP_FILE_SIZE" ] && echo "Size: $CLIAMP_FILE_SIZE"
        exit 0
    else
        echo "Error: cliamp is not running or no track playing." >&2
        exit 1
    fi
fi

show_stats() {
    echo -e "${BOLD}${BLUE}=== CURRENT STATUS & STATISTICS ===${NC}"
    
    # 1. Unconverted WAVs in root
    shopt -s nullglob nocaseglob
    local root_wavs=(./*.wav)
    local root_wav_count=${#root_wavs[@]}
    local root_wav_size=0
    for w in "${root_wavs[@]}"; do
        if [ -f "$w" ]; then
            local sz
            sz=$(stat -c %s "$w" 2>/dev/null || stat -f %z "$w" 2>/dev/null || wc -c < "$w")
            root_wav_size=$((root_wav_size + sz))
        fi
    done
    local root_wav_size_mb=$((root_wav_size / 1024 / 1024))

    # 2. Converted WAVs in archive
    local archive_wavs=("${ARCHIVE_DIR}"/*.wav)
    local archive_wav_count=${#archive_wavs[@]}
    local archive_wav_size=0
    for w in "${archive_wavs[@]}"; do
        if [ -f "$w" ]; then
            local sz
            sz=$(stat -c %s "$w" 2>/dev/null || stat -f %z "$w" 2>/dev/null || wc -c < "$w")
            archive_wav_size=$((archive_wav_size + sz))
        fi
    done
    local archive_wav_size_gb=$(echo "scale=2; $archive_wav_size / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "$((archive_wav_size / 1024 / 1024 / 1024))")

    # 3. FLAC files in output
    local flac_files=("${OUTPUT_DIR}"/*.flac)
    local flac_count=${#flac_files[@]}

    # 4. Missing tracklists
    local missing_tl_count=0
    for f in "${flac_files[@]}"; do
        local flac_base
        flac_base=$(basename "$f" .flac)
        if [ ! -f "${OUTPUT_DIR}/${flac_base}.txt" ]; then
            ((missing_tl_count++))
        fi
    done

    echo -e "  Root Directory WAVs (Pending Conversion):  ${BOLD}${YELLOW}${root_wav_count}${NC} files (${root_wav_size_mb} MB)"
    echo -e "  Archive Directory WAVs (Converted):       ${BOLD}${GREEN}${archive_wav_count}${NC} files (${archive_wav_size_gb} GB)"
    echo -e "  Total FLAC Files Generated:               ${BOLD}${CYAN}${flac_count}${NC} files"
    if [ "$missing_tl_count" -gt 0 ]; then
        echo -e "  FLAC Files Missing Tracklists:            ${BOLD}${RED}${missing_tl_count}${NC} files"
    else
        echo -e "  FLAC Files Missing Tracklists:            ${BOLD}${GREEN}0${NC} files (All complete!)"
    fi

    # 5. CLI Amp Live Player Status
    if get_cliamp_track_info 2>/dev/null; then
        local st_badge
        case "$CLIAMP_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
        esac
        echo -e "  --------------------------------------------------"
        echo -e "  cliamp Music Player:                      ${st_badge} [${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}] (${CLIAMP_PROGRESS_PCT}%)"
        echo -e "  cliamp Current Track:                     ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC} - ${CLIAMP_ARTIST}"
        echo -e "  cliamp Active File Path:                  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
    fi
    echo -e "${BLUE}===================================${NC}"
}

press_enter() {
    echo ""
    read -r -p "Press [Enter] to return to the main menu..."
}

rename_mix() {
    echo -e "\n${BOLD}${BLUE}=== RENAME MIX FILE & ASSOCIATED ASSETS ===${NC}"
    read -r -p "Enter the current FLAC filename to search for: " src_flac
    
    # Clean and locate file
    src_flac_name=$(basename "$src_flac" | tr -d '\r' | tr -d '\n')
    src_path="${OUTPUT_DIR}/${src_flac_name}"
    
    if [ ! -f "$src_path" ]; then
        echo -e "${RED}Error: File '$src_path' not found in $OUTPUT_DIR!${NC}"
        return
    fi
    
    read -r -p "Enter the destination filename for the final FLAC: " dest_flac
    dest_flac_name=$(basename "$dest_flac" | tr -d '\r' | tr -d '\n')
    dest_path="${OUTPUT_DIR}/${dest_flac_name}"
    
    if [ -f "$dest_path" ]; then
        echo -e "${RED}Error: Destination file '$dest_path' already exists!${NC}"
        return
    fi
    
    # Rename FLAC
    mv "$src_path" "$dest_path"
    echo -e "${GREEN}✓ Renamed FLAC: $src_flac_name ➔ $dest_flac_name${NC}"
    
    # Base names without extension
    src_base="${src_flac_name%.*}"
    dest_base="${dest_flac_name%.*}"
    
    # Rename Tracklist if exists
    src_txt="${OUTPUT_DIR}/${src_base}.txt"
    dest_txt="${OUTPUT_DIR}/${dest_base}.txt"
    if [ -f "$src_txt" ]; then
        mv "$src_txt" "$dest_txt"
        echo -e "${GREEN}✓ Renamed Tracklist: $(basename "$src_txt") ➔ $(basename "$dest_txt")${NC}"
    fi
    
    # Rename Spek if exists
    src_spek="SPEK_OUTPUTS/${src_base}_spectrogram.png"
    dest_spek="SPEK_OUTPUTS/${dest_base}_spectrogram.png"
    if [ -f "$src_spek" ]; then
        mv "$src_spek" "$dest_spek"
        echo -e "${GREEN}✓ Renamed Spectrogram: $(basename "$src_spek") ➔ $(basename "$dest_spek")${NC}"
    fi
}

view_tasks() {
    echo -e "\n${BOLD}${BLUE}=== RUNNING BACKGROUND TASKS ===${NC}"
    local tasks_found=0
    
    if pgrep -f "Make_SOF_FLAC_CONVERSION.sh" > /dev/null || pgrep -x "ffmpeg" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] FLAC Conversion Batch Job (Make_SOF_FLAC_CONVERSION.sh / ffmpeg)"
        ((tasks_found++))
    fi
    if pgrep -f "Check_Find_Tracklists.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] Tracklist Generator Job (Check_Find_Tracklists.sh)"
        ((tasks_found++))
    fi
    if pgrep -f "Verify_FLAC_Files.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] FLAC Verification Scan (Verify_FLAC_Files.sh)"
        ((tasks_found++))
    fi
    if pgrep -f "backup_to_gdrive.sh" > /dev/null || pgrep -x "rclone" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] Google Drive Backup / Active Rclone Transfer (backup_to_gdrive.sh / rclone)"
        ((tasks_found++))
    fi
    if pgrep -f "import_new_mixes.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] SMB Import Process (import_new_mixes.sh)"
        ((tasks_found++))
    fi
    if pgrep -f "SOF_Live_Tracker.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] Live Tracklist Monitor (SOF_Live_Tracker.sh)"
        ((tasks_found++))
    fi
    local chrome_upload_info=""
    if command -v chrome-upload-monitor >/dev/null 2>&1; then
        chrome_upload_info=$(chrome-upload-monitor --check 2>/dev/null || true)
    elif [ -x "$HOME/.local/bin/chrome-upload-monitor" ]; then
        chrome_upload_info=$("$HOME/.local/bin/chrome-upload-monitor" --check 2>/dev/null || true)
    elif [ -x "./chrome_upload_monitor.py" ]; then
        chrome_upload_info=$(python3 ./chrome_upload_monitor.py --check 2>/dev/null || true)
    fi
    if [ -n "$chrome_upload_info" ]; then
        echo -e "  [${YELLOW}RUNNING${NC}] Chrome Podcast Connect / Web Upload: ${CYAN}${chrome_upload_info}${NC}"
        ((tasks_found++))
    fi
    if pgrep -f "python.*wgp\.py" > /dev/null; then
        local wgp_pids
        wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WAN2GP AI Video Server (PID: ${wgp_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "wan2gp_flux_batch" > /dev/null; then
        local flux_pids
        flux_pids=$(pgrep -f "wan2gp_flux_batch" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WAN2GP Flux 2 Klein Batch Processor (PID: ${flux_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "wan2gp_ltx.*batch" > /dev/null; then
        local ltx_pids
        ltx_pids=$(pgrep -f "wan2gp_ltx.*batch" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WAN2GP LTX Video Batch Processor (PID: ${ltx_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "detect_and_move_people\.py" > /dev/null; then
        local pd_pids
        pd_pids=$(pgrep -f "detect_and_move_people\.py" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WebP Person Detector & Converter (PID: ${pd_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "remove_duplicate_images\.py" > /dev/null; then
        local dup_pids
        dup_pids=$(pgrep -f "remove_duplicate_images\.py" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Duplicate Image Remover (PID: ${dup_pids})"
        ((tasks_found++))
    fi
    if systemctl is-active --quiet sshd || pgrep -x sshd > /dev/null; then
        local ssh_pids
        ssh_pids=$(pgrep -x sshd | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] SSH Server (sshd - Port 22, PID: ${ssh_pids})"
        ((tasks_found++))
    fi
    if systemctl is-active --quiet smb || pgrep -x smbd > /dev/null; then
        local smb_pids
        smb_pids=$(pgrep -x smbd | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Samba File Sharing (smbd, nmbd, wsdd - Ports 139, 445, PID: ${smb_pids})"
        ((tasks_found++))
    fi
    if systemctl is-active --quiet vsftpd || pgrep -x vsftpd > /dev/null; then
        local ftp_pids
        ftp_pids=$(pgrep -x vsftpd | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] FTP Server (vsftpd - Port 21, PID: ${ftp_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "ujust" > /dev/null || pgrep -f "rpm-ostree" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] System Maintenance / Update (ujust / rpm-ostree)"
        ((tasks_found++))
    fi
    if pgrep -x "cliamp" > /dev/null; then
        local cliamp_pids cliamp_desc=""
        cliamp_pids=$(pgrep -x cliamp | tr '\n' ' ')
        if get_cliamp_track_info 2>/dev/null; then
            cliamp_desc=" [${CLIAMP_STATE^^}: ${CLIAMP_TITLE} - ${CLIAMP_POS_FMT}/${CLIAMP_DUR_FMT}]"
        fi
        echo -e "  [${GREEN}RUNNING${NC}] cliamp Retro Music Player (PID: ${cliamp_pids})${cliamp_desc}"
        ((tasks_found++))
    fi
    
    if [ $tasks_found -eq 0 ]; then
        echo -e "  ${GREEN}No active background tasks found.${NC}"
    fi
    echo -e "${BLUE}================================${NC}"
}

view_cover() {
    echo -e "\n${BOLD}${BLUE}=== VIEW COVER ART BY MIX NUMBER ===${NC}"
    read -r -p "Enter the mix/episode number (e.g. 037, 063): " mix_num
    
    if [ -z "$mix_num" ]; then
        echo -e "${RED}Error: Mix number cannot be empty.${NC}"
        return
    fi
    
    # Search for matching covers in COVERS/ directory
    shopt -s nullglob nocaseglob
    local matches=(COVERS/*"${mix_num}"*.png COVERS/*"${mix_num}"*.jpg COVERS/*"${mix_num}"*.jpeg)
    
    if [ ${#matches[@]} -eq 0 ]; then
        echo -e "${YELLOW}No matching cover art found in COVERS/ for mix number '${mix_num}'.${NC}"
        return
    fi
    
    echo -e "${GREEN}Found match(es):${NC}"
    local i=1
    for m in "${matches[@]}"; do
        echo "  $i) $(basename "$m")"
        ((i++))
    done
    
    local choice=1
    if [ ${#matches[@]} -gt 1 ]; then
        read -r -p "Select which file to view [1-$((i-1))]: " choice
    fi
    
    local target_index=$((choice - 1))
    local selected_cover="${matches[$target_index]}"
    
    if [ -f "$selected_cover" ]; then
        echo -e "${CYAN}Launching external image viewer for $(basename "$selected_cover")...${NC}"
        xdg-open "$selected_cover" > /dev/null 2>&1 &
    else
        echo -e "${RED}Error: Selected file does not exist.${NC}"
    fi
}

generate_youtube_video() {
    echo -e "\n${BOLD}${BLUE}=== GENERATE 1080p YOUTUBE VIDEO ===${NC}"
    
    # Prompt for FLAC audio file
    read -r -p "Enter the filename of the .FLAC to use: " flac_input
    
    # Strip surrounding quotes from drag-and-drop or copy-paste
    flac_input=$(echo "$flac_input" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    if [ -z "$flac_input" ]; then
        echo -e "${RED}Error: FLAC file is required.${NC}"
        return
    fi
    
    # Prompt for Cover Image
    read -r -p "Enter the filename of the Cover PNG (leave empty for default Cover.png): " cover_input
    cover_input=$(echo "$cover_input" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    run_sub_script "Make_SOF_Episode_From_PNG_FLAC_Output_MP4_1080p_Video.sh" "$flac_input" "$cover_input"
}

cut_video_clip() {
    echo -e "\n${BOLD}${BLUE}=== CUT VIDEO FILE (.MP4 / .MKV) ===${NC}\n"
    run_sub_script "Cut_Video.sh"
}

launch_cliamp() {
    echo -e "\n${BOLD}${YELLOW}Launching cliamp Music Player in a new window...${NC}\n"
    local cliamp_bin
    if command -v cliamp >/dev/null 2>&1; then
        cliamp_bin="cliamp"
    elif [ -x "$SCRIPT_DIR/bin/cliamp" ]; then
        cliamp_bin="$SCRIPT_DIR/bin/cliamp"
    elif [ -x "$HOME/.local/bin/cliamp" ]; then
        cliamp_bin="$HOME/.local/bin/cliamp"
    else
        echo -e "${RED}Error: cliamp command not found in PATH or bin!${NC}"
        press_enter
        return 1
    fi

    if command -v konsole >/dev/null 2>&1; then
        nohup konsole --separate --workdir "$PWD" -p tabtitle="cliamp" -e "$cliamp_bin" >/dev/null 2>&1 &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec "$cliamp_bin" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="cliamp" -- "$cliamp_bin" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "cliamp" -e "$cliamp_bin" >/dev/null 2>&1 &
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window.${NC}"
        press_enter
        return 1
    fi
    echo -e "${GREEN}✓ cliamp launched in a new window.${NC}"
    sleep 1.2
}

monitor_cliamp_live() {
    echo -e "\n${BOLD}${YELLOW}Starting Real-Time cliamp Monitor (Press 'q' or Ctrl+C to exit)...${NC}\n"
    sleep 0.5
    trap 'break' INT
    while true; do
        if ! get_cliamp_track_info 2>/dev/null; then
            clear
            echo -e "${BOLD}${MAGENTA}==================================================${NC}"
            echo -e "${BOLD}${MAGENTA}           REAL-TIME CLIAMP MONITOR               ${NC}"
            echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"
            echo -e "  ${BOLD}${RED}cliamp is not running or no track playing.${NC}\n"
            echo -e "${DIM}Press 'q' to return to menu...${NC}"
            read -t 1 -n 1 key 2>/dev/null || true
            [ "$key" = "q" ] || [ "$key" = "Q" ] && break
            continue
        fi
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}           REAL-TIME CLIAMP MONITOR               ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"
        
        local st_badge
        case "$CLIAMP_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
        esac

        local bar_len=32
        local filled_len=$(( CLIAMP_PROGRESS_PCT * bar_len / 100 ))
        local empty_len=$(( bar_len - filled_len ))
        local bar=""
        for ((i=0; i<filled_len; i++)); do bar="${bar}="; done
        if [ $filled_len -lt $bar_len ]; then bar="${bar}>"; empty_len=$((empty_len - 1)); fi
        for ((i=0; i<empty_len; i++)); do bar="${bar}-"; done

        echo -e "  Playback State: ${st_badge}"
        echo -e "  Current Track:  ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC}"
        echo -e "  Artist:         ${BOLD}${WHITE}${CLIAMP_ARTIST}${NC}"
        echo -e "  Playback Time:  ${BOLD}${CYAN}${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}${NC} [${bar}] (${CLIAMP_PROGRESS_PCT}%)"
        echo ""
        echo -e "  Active File:    ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
        [ -n "$CLIAMP_FILE_SIZE" ] && echo -e "  File Size:      ${GREEN}${CLIAMP_FILE_SIZE}${NC}"
        echo ""
        echo -e "${DIM}Controls: [c]opy path | [o]pen folder | [p]lay/pause | [n]ext | [b]ack | [q]uit${NC}"
        read -t 1 -n 1 key 2>/dev/null || true
        case "$key" in
            c|C)
                if command -v wl-copy >/dev/null 2>&1; then
                    echo -n "$CLIAMP_RESOLVED_PATH" | wl-copy
                elif command -v xclip >/dev/null 2>&1; then
                    echo -n "$CLIAMP_RESOLVED_PATH" | xclip -selection clipboard
                fi
                ;;
            o|O)
                xdg-open "$(dirname "$CLIAMP_RESOLVED_PATH")" >/dev/null 2>&1 &
                ;;
            p|P) cliamp toggle 2>/dev/null || true ;;
            n|N) cliamp next 2>/dev/null || true ;;
            b|B) cliamp prev 2>/dev/null || true ;;
            q|Q) break ;;
        esac
    done
    trap - INT
}

manage_cliamp() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       CLIAMP MUSIC PLAYER & NOW PLAYING INFO     ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        if ! get_cliamp_track_info 2>/dev/null; then
            local cliamp_pids
            cliamp_pids=$(pgrep -x cliamp 2>/dev/null)
            if [ -z "$cliamp_pids" ]; then
                echo -e "  Player Status:  ${BOLD}${RED}○ NOT RUNNING${NC}"
            else
                echo -e "  Player Status:  ${BOLD}${YELLOW}● RUNNING (Idle / No Active Track)${NC} (PID: ${cliamp_pids})"
            fi
            echo ""
            echo -e "${BOLD}Options:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Launch cliamp in New Terminal Window"
            echo -e "  ${BOLD}${CYAN}2)${NC} Resume / Start Playback (${GREEN}cliamp play${NC})"
            echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [0-2]: " c_opt
            case "$c_opt" in
                1) launch_cliamp; break ;;
                2) cliamp play 2>/dev/null; sleep 0.5 ;;
                0|q|Q|"") break ;;
                *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
            esac
            continue
        fi

        local pids
        pids=$(pgrep -x cliamp 2>/dev/null | tr '\n' ' ')
        local st_badge
        case "$CLIAMP_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
        esac

        local bar_len=30
        local filled_len=$(( CLIAMP_PROGRESS_PCT * bar_len / 100 ))
        local empty_len=$(( bar_len - filled_len ))
        local bar=""
        for ((i=0; i<filled_len; i++)); do bar="${bar}="; done
        if [ $filled_len -lt $bar_len ]; then bar="${bar}>"; empty_len=$((empty_len - 1)); fi
        for ((i=0; i<empty_len; i++)); do bar="${bar}-"; done

        echo -e "  Player Status:  ${st_badge} (PID: ${pids})"
        echo -e "  Current Track:  ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC}"
        echo -e "  Artist:         ${BOLD}${WHITE}${CLIAMP_ARTIST}${NC}"
        echo -e "  Playback Time:  ${BOLD}${CYAN}${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}${NC} [${bar}] (${CLIAMP_PROGRESS_PCT}%)"
        echo ""
        echo -e "  ${BOLD}${GREEN}Current Track File Path:${NC}"
        echo -e "  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
        if [ "$CLIAMP_RAW_PATH" != "$CLIAMP_RESOLVED_PATH" ]; then
            echo -e "  ${DIM}(Raw cliamp Path: ${CLIAMP_RAW_PATH})${NC}"
        fi
        if [ "$CLIAMP_FILE_EXISTS" -eq 1 ]; then
            echo -e "  File Status:    ${GREEN}✓ File exists on disk${NC} (${CLIAMP_FILE_SIZE})"
        else
            echo -e "  File Status:    ${RED}✗ File not found at resolved location${NC}"
        fi
        echo ""
        echo -e "${BOLD}Select an operation:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Copy File Path to Clipboard (${GREEN}wl-copy${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Open Containing Folder in File Manager (${GREEN}xdg-open${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} View Spek Spectrogram of Current Track"
        echo -e "  ${BOLD}${CYAN}4)${NC} View Tracklist Text File of Current Track"
        echo -e "  ${BOLD}${CYAN}5)${NC} Play / Pause Toggle (${GREEN}cliamp toggle${NC})"
        echo -e "  ${BOLD}${CYAN}6)${NC} Skip to Next Track (${GREEN}cliamp next${NC})"
        echo -e "  ${BOLD}${CYAN}7)${NC} Skip to Previous Track (${GREEN}cliamp prev${NC})"
        echo -e "  ${BOLD}${CYAN}8)${NC} Launch / Bring Up cliamp Terminal Window"
        echo -e "  ${BOLD}${CYAN}9)${NC} Live Real-Time Monitor (Updates Every Second)"
        echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-9 or c/o/s/t/p/n/b/l/w/Enter]: " c_opt
        case "$c_opt" in
            1|[cC])
                if command -v wl-copy >/dev/null 2>&1; then
                    echo -n "$CLIAMP_RESOLVED_PATH" | wl-copy
                    echo -e "\n${GREEN}✓ File path copied to clipboard!${NC}"
                elif command -v xclip >/dev/null 2>&1; then
                    echo -n "$CLIAMP_RESOLVED_PATH" | xclip -selection clipboard
                    echo -e "\n${GREEN}✓ File path copied to clipboard!${NC}"
                else
                    echo -e "\n${YELLOW}Clipboard utility (wl-copy/xclip) not available.${NC}"
                fi
                sleep 1.2
                ;;
            2|[oO])
                local folder_dir
                folder_dir=$(dirname "$CLIAMP_RESOLVED_PATH")
                if [ -d "$folder_dir" ]; then
                    echo -e "\n${GREEN}Opening $folder_dir in file manager...${NC}"
                    xdg-open "$folder_dir" >/dev/null 2>&1 &
                else
                    echo -e "\n${RED}Directory $folder_dir does not exist!${NC}"
                fi
                sleep 1.2
                ;;
            3|[sS])
                local bname_no_ext
                bname_no_ext=$(basename "$CLIAMP_RESOLVED_PATH")
                bname_no_ext="${bname_no_ext%.*}"
                shopt -s nullglob nocaseglob
                local spek_matches=(SPEK_OUTPUTS/*"${bname_no_ext}"*.png SPEK_OUTPUTS/*"${CLIAMP_TITLE}"*.png)
                shopt -u nullglob nocaseglob
                if [ ${#spek_matches[@]} -gt 0 ] && [ -f "${spek_matches[0]}" ]; then
                    echo -e "\n${GREEN}Opening spectrogram: $(basename "${spek_matches[0]}")...${NC}"
                    xdg-open "${spek_matches[0]}" >/dev/null 2>&1 &
                else
                    echo -e "\n${YELLOW}No matching spectrogram found for '${bname_no_ext}' in SPEK_OUTPUTS/.${NC}"
                fi
                sleep 1.5
                ;;
            4|[tT])
                local bname_no_ext
                bname_no_ext=$(basename "$CLIAMP_RESOLVED_PATH")
                bname_no_ext="${bname_no_ext%.*}"
                shopt -s nullglob nocaseglob
                local tl_matches=("${OUTPUT_DIR}/${bname_no_ext}.txt" "${bname_no_ext}.txt" "${OUTPUT_DIR}/*${CLIAMP_TITLE}*.txt")
                shopt -u nullglob nocaseglob
                local found_tl=""
                for tm in "${tl_matches[@]}"; do
                    if [ -f "$tm" ]; then found_tl="$tm"; break; fi
                done
                if [ -n "$found_tl" ]; then
                    echo -e "\n${BOLD}${CYAN}=== TRACKLIST: $(basename "$found_tl") ===${NC}\n"
                    cat "$found_tl"
                    press_enter
                else
                    echo -e "\n${YELLOW}No tracklist .txt file found for '${bname_no_ext}'.${NC}"
                    sleep 1.5
                fi
                ;;
            5|[pP])
                cliamp toggle 2>/dev/null || true
                sleep 0.4
                ;;
            6|[nN])
                cliamp next 2>/dev/null || true
                sleep 0.5
                ;;
            7|[bB])
                cliamp prev 2>/dev/null || true
                sleep 0.5
                ;;
            8|[lL])
                launch_cliamp
                break
                ;;
            9|[wW])
                monitor_cliamp_live
                ;;
            0|q|Q|"")
                break
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

launch_strawberry() {
    echo -e "\n${BOLD}${YELLOW}Launching Strawberry Music Player in a new window...${NC}\n"
    if command -v strawberry >/dev/null 2>&1; then
        nohup strawberry >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Strawberry launched in a new window.${NC}"
        sleep 1.2
    else
        echo -e "${RED}Error: strawberry command not found in PATH!${NC}"
        press_enter
        return 1
    fi
}

launch_video_playlists() {
    echo -e "\n${BOLD}${BLUE}=== LAUNCH VIDEO PLAYLISTS (VLC) ===${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Play Defasten Playlist in VLC (${GREEN}Defasten.xspf${NC})"
    echo -e "  ${BOLD}${CYAN}2)${NC} Play NFT Videos Playlist in VLC (${GREEN}NFT_VIDEOS.xspf${NC})"
    echo -e "  ${BOLD}${CYAN}3)${NC} Play Defasten Across 4 Screens (${GREEN}play_defasten_4screens.sh${NC})"
    echo -e "  ${BOLD}${CYAN}4)${NC} Regenerate NFT Playlist from /run/media/mplanetarian/DATA/NFT_VIDEOS"
    echo -e "  ${BOLD}${CYAN}5)${NC} Return to Main Menu"
    echo ""
    read -r -p "Enter choice [1-5]: " v_choice

    case $v_choice in
        1)
            local defasten_pl="$HOME/Desktop/DESKTOP/Defasten.xspf"
            [ ! -f "$defasten_pl" ] && defasten_pl="$HOME/Desktop/Defasten.xspf"
            [ ! -f "$defasten_pl" ] && defasten_pl="$HOME/Desktop/DESKTOP/Defasten.m3u"
            [ ! -f "$defasten_pl" ] && defasten_pl="$HOME/Desktop/Defasten.m3u"
            if [ -f "$defasten_pl" ]; then
                echo -e "${GREEN}Launching VLC with Defasten playlist...${NC}"
                nohup vlc "$defasten_pl" >/dev/null 2>&1 &
                sleep 1.2
            else
                echo -e "${RED}Error: Defasten playlist not found on Desktop or Desktop/DESKTOP!${NC}"
                press_enter
            fi
            ;;
        2)
            if [ -x "$HOME/.local/bin/update-nft-playlist" ]; then
                "$HOME/.local/bin/update-nft-playlist" --quiet
            fi
            local nft_pl="$HOME/Desktop/DESKTOP/NFT_VIDEOS.xspf"
            [ ! -f "$nft_pl" ] && nft_pl="$HOME/Desktop/NFT_VIDEOS.xspf"
            [ ! -f "$nft_pl" ] && nft_pl="$HOME/Desktop/DESKTOP/NFT_VIDEOS.m3u"
            [ ! -f "$nft_pl" ] && nft_pl="$HOME/Desktop/NFT_VIDEOS.m3u"
            if [ -f "$nft_pl" ]; then
                echo -e "${GREEN}Launching VLC with NFT Videos playlist...${NC}"
                nohup vlc "$nft_pl" >/dev/null 2>&1 &
                sleep 1.2
            else
                echo -e "${RED}Error: NFT Videos playlist not found on Desktop or Desktop/DESKTOP!${NC}"
                press_enter
            fi
            ;;
        3)
            local script="$HOME/Desktop/DESKTOP/play_defasten_4screens.sh"
            [ ! -f "$script" ] && script="$HOME/Desktop/play_defasten_4screens.sh"
            if [ -f "$script" ]; then
                echo -e "${GREEN}Launching Defasten on 4 screens...${NC}"
                bash "$script" --detach || true
                sleep 1.2
            else
                echo -e "${RED}Error: $script not found!${NC}"
                press_enter
            fi
            ;;
        4)
            if [ -x "$HOME/.local/bin/update-nft-playlist" ]; then
                "$HOME/.local/bin/update-nft-playlist"
            else
                echo -e "${RED}Error: update-nft-playlist helper not found!${NC}"
            fi
            press_enter
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            sleep 1
            ;;
    esac
}

close_all_desktop_apps() {
    echo -e "\n${BOLD}${RED}=== CLOSE ALL DESKTOP APPLICATIONS ===${NC}"
    echo -e "${YELLOW}This will close all open desktop application windows while keeping the Manager open.${NC}"
    read -r -p "Are you sure you want to proceed? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Operation canceled.${NC}"
        sleep 1
        return
    fi

    echo -e "\n${CYAN}Identifying active Manager session and closing other windows...${NC}"

    # 1. Collect PID ancestry of the Manager so we never close it or its parent terminal
    local current_pid=$$
    local mgr_pids=("$current_pid")
    local p=$current_pid
    while [ "$p" -gt 1 ]; do
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        if [ -n "$p" ] && [ "$p" -gt 0 ]; then
            mgr_pids+=("$p")
        else
            break
        fi
    done

    # 2. Convert WINDOWID if present
    local my_win_hex=""
    if [ -n "${WINDOWID:-}" ]; then
        my_win_hex=$(printf "0x%08x" "$WINDOWID" 2>/dev/null || true)
    fi

    local closed_count=0
    if command -v wmctrl >/dev/null 2>&1; then
        while read -r win_id desktop_num win_pid host win_title; do
            # Skip system desktop panels and desktop background (-1)
            if [ "$desktop_num" -lt 0 ] || [[ "$win_title" == *"plasmashell"* ]]; then
                continue
            fi
            
            # Check if this window matches our WINDOWID
            if [ -n "$my_win_hex" ] && [ "$win_id" = "$my_win_hex" ]; then
                continue
            fi

            # Check if window PID belongs to our Manager process hierarchy
            local is_mgr=false
            for mp in "${mgr_pids[@]}"; do
                if [ "$win_pid" = "$mp" ]; then
                    is_mgr=true
                    break
                fi
            done
            if [ "$is_mgr" = true ]; then
                continue
            fi

            # Gracefully close window
            wmctrl -c "$win_id"
            ((closed_count++))
        done < <(wmctrl -lp 2>/dev/null)
    fi

    sleep 1

    # 3. Terminate background GUI / media processes without touching Konsole or Bash
    local apps_to_clean=(
        "vlc"
        "mpv"
        "strawberry"
        "cliamp"
        "btop"
        "nvtop"
        "top"
        "cpu-x"
        "GPUViewer"
        "steam"
        "steamwebhelper"
    )
    for app in "${apps_to_clean[@]}"; do
        pkill -f "$app" 2>/dev/null || true
    done

    echo -e "${GREEN}✓ Closed $closed_count application window(s).${NC}"
    echo -e "${GREEN}✓ Active Mix Archive Manager kept open and protected.${NC}"
    press_enter
}

block_internet() {
    echo -e "\n${BOLD}${RED}=== BLOCK INTERNET ACCESS (LAN ONLY) ===${NC}"
    local script="$HOME/Documents/BASH_SCRIPTS/block-internet"
    [ ! -f "$script" ] && script="$HOME/bin/block-internet"
    if [ -f "$script" ]; then
        echo -e "${YELLOW}Running $script...${NC}\n"
        sudo bash "$script"
    else
        echo -e "${RED}Error: block-internet script not found at $script!${NC}"
    fi
    press_enter
}

unblock_internet() {
    echo -e "\n${BOLD}${GREEN}=== RESTORE / UNBLOCK INTERNET ACCESS ===${NC}"
    local script="$HOME/Documents/BASH_SCRIPTS/unblock-internet"
    [ ! -f "$script" ] && script="$HOME/bin/unblock-internet"
    if [ -f "$script" ]; then
        echo -e "${YELLOW}Running $script...${NC}\n"
        sudo bash "$script"
    else
        echo -e "${RED}Error: unblock-internet script not found at $script!${NC}"
    fi
    press_enter
}

launch_geexlab_demos() {
    echo -e "\n${BOLD}${YELLOW}Launching GeeXLab Demo Launcher (FurMark)...${NC}\n"
    local furmark_dir="/var/home/mplanetarian/Documents/FurMark_linux64"
    if [ -d "$furmark_dir" ] && [ -x "$furmark_dir/demo_launcher.sh" ]; then
        sleep 0.5
        trap ':' INT
        (cd "$furmark_dir" && ./demo_launcher.sh)
        trap - INT
    else
        echo -e "${RED}Error: demo_launcher.sh not found or not executable in $furmark_dir!${NC}"
        press_enter
    fi
}

list_usb_midi_devices() {
    echo -e "\n${BOLD}${CYAN}=== CONNECTED USB MIDI DEVICES ===${NC}\n"
    if command -v list-midi-devices >/dev/null 2>&1; then
        list-midi-devices
    elif [ -x "$HOME/bin/list-midi-devices" ]; then
        "$HOME/bin/list-midi-devices"
    else
        echo -e "${RED}Error: list-midi-devices command not found in PATH or ~/bin!${NC}"
        press_enter
        return
    fi
    echo ""
    echo -e "${DIM}Options: Press [Enter] to return to menu, or [w] for real-time live monitor...${NC}"
    read -r -p "> " midi_opt
    if [[ "$midi_opt" =~ ^[wW]$ ]]; then
        echo -e "\n${BOLD}${YELLOW}Launching Live MIDI Monitor (Press Ctrl+C to return)...${NC}\n"
        sleep 0.5
        trap ':' INT
        if command -v list-midi-devices >/dev/null 2>&1; then
            list-midi-devices -w
        else
            "$HOME/bin/list-midi-devices" -w
        fi
        trap - INT
    fi
}

switch_to_wayland() {
    local script="$SCRIPT_DIR/switch-to-plasma-wayland.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/switch-to-plasma-wayland.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/switch-to-plasma-wayland.sh"
    if [ -x "$script" ]; then
        "$script"
    elif [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: Switch script not found at $script!${NC}"
        press_enter
    fi
}

switch_to_x11() {
    local script="$SCRIPT_DIR/switch-to-plasma-x11.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/switch-to-plasma-x11.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/switch-to-plasma-x11.sh"
    if [ -x "$script" ]; then
        "$script"
    elif [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: Switch script not found at $script!${NC}"
        press_enter
    fi
}

launch_wan2gp_terminal() {
    local profile="$1"
    local title="WAN2GP (Profile $profile)"
    local script="$SCRIPT_DIR/wan2gp.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/wan2gp.sh"
    [ ! -f "$script" ] && script="$HOME/wan2gp.sh"
    local cmd="bash \"$script\" \"$profile\"; echo ''; echo 'WAN2GP finished. Press [Enter] to exit...'; read -r"

    if command -v konsole >/dev/null 2>&1; then
        nohup konsole --new-tab -p tabtitle="$title" -e bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$title" -- bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
    echo -e "${GREEN}✓ WAN2GP launched in a new console tab/window (Profile $profile).${NC}"
    sleep 1.2
    return 0
}

launch_wan2gp_flux_batch_terminal() {
    local mode="$1"
    local title="WAN2GP Flux 2 Klein Batch"
    if [[ "$mode" == *"--multi-control"* ]]; then
        title="WAN2GP Flux Multi-Control Batch"
    fi
    local script="$SCRIPT_DIR/wan2gp_flux_batch.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/wan2gp_flux_batch.py"
    [ ! -f "$script" ] && script="$HOME/wan2gp_flux_batch.py"
    local cmd="\"$script\" $mode; echo ''; echo 'Batch process finished. Press [Enter] to exit...'; read -r"

    if command -v konsole >/dev/null 2>&1; then
        nohup konsole --new-tab -p tabtitle="$title" -e bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$title" -- bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
    echo -e "${GREEN}✓ Flux 2 Klein 9B Batch Processor launched in a new console tab/window.${NC}"
    sleep 1.2
    return 0
}

launch_wan2gp_ltx_batch_terminal() {
    local mode="$1"
    local model="${2:-2b}"
    local title="WAN2GP LTX Video ${model^^} Batch"
    if [[ "$mode" == *"--no-control"* ]]; then
        title="WAN2GP LTX Video ${model^^} (Pure I2V)"
    elif [[ "$mode" == *"--watch"* ]]; then
        title="WAN2GP LTX Video ${model^^} (Watch Mode)"
    fi
    local script="$SCRIPT_DIR/wan2gp_ltx_batch.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/wan2gp_ltx_batch.py"
    [ ! -f "$script" ] && script="$HOME/wan2gp_ltx_batch.py"
    local cmd="\"$script\" --model $model $mode; echo ''; echo 'Batch process finished. Press [Enter] to exit...'; read -r"

    if command -v konsole >/dev/null 2>&1; then
        nohup konsole --new-tab -p tabtitle="$title" -e bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$title" -- bash -c "$cmd" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
    echo -e "${GREEN}✓ LTX Video ${model^^} Batch Processor launched in a new console tab/window.${NC}"
    sleep 1.2
    return 0
}

clear_wan2gp_logs() {
    local script="$SCRIPT_DIR/clear-wan2gp-logs.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/clear-wan2gp-logs.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/clear-wan2gp-logs.sh"
    if [ -x "$script" ]; then
        "$script"
    elif [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: Clear WAN2GP logs script not found at $script!${NC}"
        press_enter
    fi
}

run_person_detector() {
    echo -e "\n${BOLD}${GREEN}=== WEBP PERSON DETECTION & JPEG CONVERTER ===${NC}\n"
    local script="./detect_and_move_people.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/detect_and_move_people.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/detect_and_move_people.py"
    [ ! -f "$script" ] && script="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/detect_and_move_people.py"
    [ ! -f "$script" ] && script="/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/detect_and_move_people.py"

    if [ -f "$script" ]; then
        python3 "$script"
    else
        echo -e "${RED}Error: detect_and_move_people.py not found at $script!${NC}"
    fi
    echo ""
    read -r -p "Press [Enter] to return to the WAN2GP menu..."
}

run_duplicate_image_remover() {
    echo -e "\n${BOLD}${GREEN}=== BYTE-FOR-BYTE DUPLICATE IMAGE REMOVER ===${NC}\n"
    local script="./remove_duplicate_images.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/remove_duplicate_images.py"

    if [ -f "$script" ]; then
        python3 "$script"
    else
        echo -e "${RED}Error: remove_duplicate_images.py not found at $script!${NC}"
    fi
    echo ""
    read -r -p "Press [Enter] to return to the WAN2GP menu..."
}


manage_wan2gp() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             WAN2GP SERVER MANAGER                ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""
        
        local wgp_pids
        wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
        if [ -n "$wgp_pids" ]; then
            echo -e "  Server Status:    ${BOLD}${GREEN}● RUNNING${NC} (PID: ${wgp_pids})"
        else
            echo -e "  Server Status:    ${BOLD}${RED}○ STOPPED${NC}"
        fi

        local flux_pids
        flux_pids=$(pgrep -f "wan2gp_flux_batch" | tr '\n' ' ')
        if [ -n "$flux_pids" ]; then
            echo -e "  Flux Batch:       ${BOLD}${GREEN}● RUNNING${NC} (PID: ${flux_pids})"
        else
            echo -e "  Flux Batch:       ${BOLD}${RED}○ STOPPED${NC}"
        fi

        local ltx_pids
        ltx_pids=$(pgrep -f "wan2gp_ltx.*batch" | tr '\n' ' ')
        if [ -n "$ltx_pids" ]; then
            echo -e "  LTX Video Batch:  ${BOLD}${GREEN}● RUNNING${NC} (PID: ${ltx_pids})"
        else
            echo -e "  LTX Video Batch:  ${BOLD}${RED}○ STOPPED${NC}"
        fi

        local ltx_ctrl_dir="/run/media/mplanetarian/DATA/WAN2GP_LTX_BATCH/CTRL_VIDEO"
        if [ -d "$ltx_ctrl_dir" ]; then
            shopt -s nullglob nocaseglob
            local ltx_ctrl_vids=("$ltx_ctrl_dir"/*.mp4 "$ltx_ctrl_dir"/*.mov "$ltx_ctrl_dir"/*.avi "$ltx_ctrl_dir"/*.mkv "$ltx_ctrl_dir"/*.webm)
            shopt -u nullglob nocaseglob
            if [ ${#ltx_ctrl_vids[@]} -gt 0 ]; then
                echo -e "  LTX Control Video:${BOLD}${YELLOW} ${#ltx_ctrl_vids[@]} video(s) detected in CTRL_VIDEO${NC}"
            fi
        fi

        local person_pids
        person_pids=$(pgrep -f "detect_and_move_people\.py" | tr '\n' ' ')
        if [ -n "$person_pids" ]; then
            echo -e "  Person Detector:  ${BOLD}${GREEN}● RUNNING${NC} (PID: ${person_pids})"
        fi

        local dup_pids
        dup_pids=$(pgrep -f "remove_duplicate_images\.py" | tr '\n' ' ')
        if [ -n "$dup_pids" ]; then
            echo -e "  Duplicate Cleaner:${BOLD}${GREEN}● RUNNING${NC} (PID: ${dup_pids})"
        fi
        echo ""
        echo -e "${BOLD}Select a WAN2GP operation:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Start in ${BOLD}${GREEN}Profile 2${NC} (High Speed / 2B Models & VRAM-Resident) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}2)${NC} Start in ${BOLD}${YELLOW}Profile 4.5${NC} (Low VRAM / 14B Models Offload) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}3)${NC} Stop Running WAN2GP Server"
        echo -e "  ${BOLD}${CYAN}4)${NC} Restart in ${BOLD}${GREEN}Profile 2${NC} (High Speed / 2B Models) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}5)${NC} Restart in ${BOLD}${YELLOW}Profile 4.5${NC} (Low VRAM / 14B Models) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}6)${NC} View Detailed Status & Memory Usage"
        echo -e "  ${BOLD}${CYAN}7)${NC} Clear WAN2GP Logs (${GREEN}clear-wan2gp-logs.sh${NC})"
        echo -e "  ${BOLD}${CYAN}8)${NC} Run Flux2 Klein 9B Batch Image Processor [Single Control Image]"
        echo -e "  ${BOLD}${CYAN}9)${NC} Run Flux2 Klein 9B Batch Image Processor [${BOLD}${YELLOW}Multi-Control Images${NC}] (All in CTRL_IMAGE)"
        echo -e "  ${BOLD}${CYAN}10)${NC} Run Flux2 Klein 9B in ${BOLD}${GREEN}Watch Mode${NC} [Single Control Image]"
        echo -e "  ${BOLD}${CYAN}11)${NC} Run Flux2 Klein 9B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}${YELLOW}Multi-Control Images${NC}]"
        echo -e "  ${BOLD}${CYAN}12)${NC} Run LTX Video 2B Batch Video Processor [${BOLD}${YELLOW}Single Control Video${NC}] (${GREEN}CTRL_VIDEO${NC})"
        echo -e "  ${BOLD}${CYAN}13)${NC} Run LTX Video 2B Batch Video Processor [${BOLD}Pure Image-to-Video${NC}] (No Control Video)"
        echo -e "  ${BOLD}${CYAN}14)${NC} Run LTX Video 2B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}${YELLOW}Single Control Video${NC}]"
        echo -e "  ${BOLD}${CYAN}15)${NC} Run LTX Video 2B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}Pure Image-to-Video${NC}]"
        echo -e "  ${BOLD}${CYAN}16)${NC} Run LTX Video 13B Batch Video Processor [${BOLD}${YELLOW}Single Control Video${NC}] (${GREEN}CTRL_VIDEO${NC})"
        echo -e "  ${BOLD}${CYAN}17)${NC} Run LTX Video 13B Batch Video Processor [${BOLD}Pure Image-to-Video${NC}] (No Control Video)"
        echo -e "  ${BOLD}${CYAN}18)${NC} Run LTX Video 13B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}${YELLOW}Single Control Video${NC}]"
        echo -e "  ${BOLD}${CYAN}19)${NC} Run LTX Video 13B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}Pure Image-to-Video${NC}]"
        echo -e "  ${BOLD}${CYAN}20)${NC} Detect Persons in WebP & Move/Convert to JPEG (${GREEN}detect_and_move_people.py${NC})"
        echo -e "  ${BOLD}${CYAN}21)${NC} Scan & Remove Byte-for-Byte Duplicate Images (${GREEN}remove_duplicate_images.py${NC})"
        echo -e "  ${BOLD}${CYAN}22)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-22]: " w_choice

        case $w_choice in
            1)
                if [ -n "$wgp_pids" ]; then
                    echo -e "\n${YELLOW}WAN2GP is already running (PID: $wgp_pids). Stop or restart it first.${NC}"
                    sleep 2
                else
                    echo -e "\n${GREEN}Launching WAN2GP in Profile 2...${NC}"
                    launch_wan2gp_terminal "2"
                fi
                ;;
            2)
                if [ -n "$wgp_pids" ]; then
                    echo -e "\n${YELLOW}WAN2GP is already running (PID: $wgp_pids). Stop or restart it first.${NC}"
                    sleep 2
                else
                    echo -e "\n${YELLOW}Launching WAN2GP in Profile 4.5...${NC}"
                    launch_wan2gp_terminal "4.5"
                fi
                ;;
            3)
                echo -e "\n${YELLOW}Stopping WAN2GP...${NC}"
                run_sub_script "wan2gp.sh" stop
                press_enter
                ;;
            4)
                echo -e "\n${YELLOW}Stopping existing WAN2GP instance...${NC}"
                run_sub_script "wan2gp.sh" stop
                sleep 1
                echo -e "${GREEN}Restarting WAN2GP in Profile 2...${NC}"
                launch_wan2gp_terminal "2"
                ;;
            5)
                echo -e "\n${YELLOW}Stopping existing WAN2GP instance...${NC}"
                run_sub_script "wan2gp.sh" stop
                sleep 1
                echo -e "${YELLOW}Restarting WAN2GP in Profile 4.5...${NC}"
                launch_wan2gp_terminal "4.5"
                ;;
            6)
                echo -e "\n${BOLD}${BLUE}=== WAN2GP STATUS ===${NC}\n"
                run_sub_script "wan2gp.sh" status
                press_enter
                ;;
            7)
                clear_wan2gp_logs
                ;;
            8)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B Batch Image Processor (Single Control)...${NC}"
                launch_wan2gp_flux_batch_terminal "--single-control"
                ;;
            9)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B Batch Image Processor (Multi-Control Images)...${NC}"
                launch_wan2gp_flux_batch_terminal "--multi-control"
                ;;
            10)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B in Watch Mode (Single Control)...${NC}"
                launch_wan2gp_flux_batch_terminal "--watch --single-control"
                ;;
            11)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B in Watch Mode (Multi-Control Images)...${NC}"
                launch_wan2gp_flux_batch_terminal "--watch --multi-control"
                ;;
            12)
                echo -e "\n${GREEN}Launching LTX Video 2B Batch Video Processor (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "2b"
                ;;
            13)
                echo -e "\n${GREEN}Launching LTX Video 2B Batch Video Processor (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--no-control" "2b"
                ;;
            14)
                echo -e "\n${GREEN}Launching LTX Video 2B in Watch Mode (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch" "2b"
                ;;
            15)
                echo -e "\n${GREEN}Launching LTX Video 2B in Watch Mode (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch --no-control" "2b"
                ;;
            16)
                echo -e "\n${GREEN}Launching LTX Video 13B Batch Video Processor (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "13b"
                ;;
            17)
                echo -e "\n${GREEN}Launching LTX Video 13B Batch Video Processor (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--no-control" "13b"
                ;;
            18)
                echo -e "\n${GREEN}Launching LTX Video 13B in Watch Mode (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch" "13b"
                ;;
            19)
                echo -e "\n${GREEN}Launching LTX Video 13B in Watch Mode (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch --no-control" "13b"
                ;;
            20)
                run_person_detector
                ;;
            21)
                run_duplicate_image_remover
                ;;
            22)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

manage_network_services() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}          NETWORK SERVICES MANAGER                ${NC}"
        echo -e "${BOLD}${MAGENTA}       (SSH, Samba File Sharing, vsftpd FTP)      ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        local ssh_status="${BOLD}${RED}○ STOPPED${NC}"
        if systemctl is-active --quiet sshd || pgrep -x sshd >/dev/null; then
            local ssh_pids
            ssh_pids=$(pgrep -x sshd | tr '\n' ' ')
            ssh_status="${BOLD}${GREEN}● RUNNING${NC} (Port 22, PID: ${ssh_pids})"
        fi

        local smb_status="${BOLD}${RED}○ STOPPED${NC}"
        if systemctl is-active --quiet smb || pgrep -x smbd >/dev/null; then
            local smb_pids
            smb_pids=$(pgrep -x smbd | tr '\n' ' ')
            smb_status="${BOLD}${GREEN}● RUNNING${NC} (Ports 139, 445, PID: ${smb_pids})"
        fi

        local ftp_status="${BOLD}${RED}○ STOPPED${NC}"
        if systemctl is-active --quiet vsftpd || pgrep -x vsftpd >/dev/null; then
            local ftp_pids
            ftp_pids=$(pgrep -x vsftpd | tr '\n' ' ')
            ftp_status="${BOLD}${GREEN}● RUNNING${NC} (Port 21, PID: ${ftp_pids})"
        fi

        echo -e "  SSH Server (sshd):          ${ssh_status}"
        echo -e "  Samba Share (smbd/wsdd):    ${smb_status}"
        echo -e "  FTP Server (vsftpd):        ${ftp_status}"
        echo ""
        echo -e "${BOLD}Bulk Actions (All Services):${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} ${GREEN}Start All Services${NC}   (SSH, SMB, FTP)"
        echo -e "  ${BOLD}${CYAN}2)${NC} ${RED}Stop All Services${NC}    (SSH, SMB, FTP)"
        echo -e "  ${BOLD}${CYAN}3)${NC} ${YELLOW}Restart All Services${NC} (SSH, SMB, FTP)"
        echo ""
        echo -e "${BOLD}Individual Service Controls:${NC}"
        echo -e "  ${BOLD}${CYAN}4)${NC} Start SSH               ${BOLD}${CYAN}7)${NC} Start Samba (SMB)        ${BOLD}${CYAN}10)${NC} Start FTP"
        echo -e "  ${BOLD}${CYAN}5)${NC} Stop SSH                ${BOLD}${CYAN}8)${NC} Stop Samba (SMB)         ${BOLD}${CYAN}11)${NC} Stop FTP"
        echo -e "  ${BOLD}${CYAN}6)${NC} Restart SSH             ${BOLD}${CYAN}9)${NC} Restart Samba (SMB)      ${BOLD}${CYAN}12)${NC} Restart FTP"
        echo ""
        echo -e "  ${BOLD}${CYAN}13)${NC} View Detailed Service Status (${GREEN}systemctl status${NC})"
        echo -e "  ${BOLD}${CYAN}14)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-14]: " s_choice

        case $s_choice in
            1)
                echo -e "\n${BOLD}${GREEN}Starting all network services (SSH, SMB, FTP)...${NC}\n"
                sudo systemctl start sshd smb nmb wsdd vsftpd
                sleep 1
                press_enter
                ;;
            2)
                echo -e "\n${BOLD}${RED}Stopping all network services (SSH, SMB, FTP)...${NC}\n"
                sudo systemctl stop sshd smb nmb wsdd vsftpd
                sleep 1
                press_enter
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}Restarting all network services (SSH, SMB, FTP)...${NC}\n"
                sudo systemctl restart sshd smb nmb wsdd vsftpd
                sleep 1
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${GREEN}Starting SSH Server (sshd)...${NC}\n"
                sudo systemctl start sshd
                sleep 1
                press_enter
                ;;
            5)
                echo -e "\n${BOLD}${RED}Stopping SSH Server (sshd)...${NC}\n"
                sudo systemctl stop sshd
                sleep 1
                press_enter
                ;;
            6)
                echo -e "\n${BOLD}${YELLOW}Restarting SSH Server (sshd)...${NC}\n"
                sudo systemctl restart sshd
                sleep 1
                press_enter
                ;;
            7)
                echo -e "\n${BOLD}${GREEN}Starting Samba Server (smb, nmb, wsdd)...${NC}\n"
                sudo systemctl start smb nmb wsdd
                sleep 1
                press_enter
                ;;
            8)
                echo -e "\n${BOLD}${RED}Stopping Samba Server (smb, nmb, wsdd)...${NC}\n"
                sudo systemctl stop smb nmb wsdd
                sleep 1
                press_enter
                ;;
            9)
                echo -e "\n${BOLD}${YELLOW}Restarting Samba Server (smb, nmb, wsdd)...${NC}\n"
                sudo systemctl restart smb nmb wsdd
                sleep 1
                press_enter
                ;;
            10)
                echo -e "\n${BOLD}${GREEN}Starting FTP Server (vsftpd)...${NC}\n"
                sudo systemctl start vsftpd
                sleep 1
                press_enter
                ;;
            11)
                echo -e "\n${BOLD}${RED}Stopping FTP Server (vsftpd)...${NC}\n"
                sudo systemctl stop vsftpd
                sleep 1
                press_enter
                ;;
            12)
                echo -e "\n${BOLD}${YELLOW}Restarting FTP Server (vsftpd)...${NC}\n"
                sudo systemctl restart vsftpd
                sleep 1
                press_enter
                ;;
            13)
                echo -e "\n${BOLD}${BLUE}=== DETAILED NETWORK SERVICES STATUS ===${NC}\n"
                systemctl status sshd smb wsdd vsftpd --no-pager -l
                echo ""
                press_enter
                ;;
            14)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

manage_system_maintenance() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       BAZZITE SYSTEM MAINTENANCE & CLEANUP       ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        local journal_usage
        journal_usage=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B*' || echo "N/A")
        echo -e "  System Journal Log Usage:   ${CYAN}${journal_usage}${NC}"

        local ostree_status
        ostree_status=$(rpm-ostree status 2>/dev/null | grep -E '^\*? State:' | head -n 1 | awk '{print $2}' || echo "idle")
        [ -z "$ostree_status" ] && ostree_status="idle"
        echo -e "  rpm-ostree Deployment:      ${GREEN}Bazzite (State: ${ostree_status})${NC}"
        echo ""
        echo -e "${BOLD}Select a maintenance operation:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Clean System (${GREEN}ujust clean-system${NC}) [Podman, Flatpak, ostree, Homebrew]"
        echo -e "  ${BOLD}${CYAN}2)${NC} Full System & Package Update (${GREEN}ujust update${NC}) [OS, Flatpaks, Brew]"
        echo -e "  ${BOLD}${CYAN}3)${NC} Vacuum System Logs (${GREEN}sudo journalctl --vacuum-size=200M${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Optimize & Trim SSD Storage (${GREEN}sudo fstrim -av${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} ${BOLD}${YELLOW}Run Complete Cleanup Suite${NC} (Clean System + Vacuum Logs + SSD Trim)"
        echo -e "  ${BOLD}${CYAN}6)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-6]: " m_choice

        case $m_choice in
            1)
                echo -e "\n${BOLD}${YELLOW}Running Bazzite System Cleanup (ujust clean-system)...${NC}\n"
                ujust clean-system
                echo ""
                press_enter
                ;;
            2)
                echo -e "\n${BOLD}${YELLOW}Running Full System & Package Update (ujust update)...${NC}\n"
                ujust update
                echo ""
                press_enter
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}Vacuuming system logs down to 200MB...${NC}\n"
                sudo journalctl --vacuum-size=200M
                echo ""
                journalctl --disk-usage
                echo ""
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${YELLOW}Trimming and optimizing SSD storage (fstrim)...${NC}\n"
                sudo fstrim -av
                echo ""
                press_enter
                ;;
            5)
                echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE CLEANUP SUITE ===${NC}\n"
                echo -e "${BOLD}${BLUE}[1/3] Running ujust clean-system...${NC}"
                ujust clean-system
                echo ""
                echo -e "${BOLD}${BLUE}[2/3] Vacuuming system logs to 200MB...${NC}"
                sudo journalctl --vacuum-size=200M
                echo ""
                echo -e "${BOLD}${BLUE}[3/3] Trimming SSD filesystems (fstrim)...${NC}"
                sudo fstrim -av
                echo ""
                echo -e "${BOLD}${GREEN}[✓] Complete cleanup finished!${NC}"
                journalctl --disk-usage
                echo ""
                press_enter
                ;;
            6)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

launch_ai_session() {
    local target_arg="$1"
    local title="$2"
    local agy_bin
    if command -v agy >/dev/null 2>&1; then
        agy_bin="agy"
    elif [ -x "$HOME/.local/bin/agy.bin" ]; then
        agy_bin="$HOME/.local/bin/agy.bin"
    else
        agy_bin="agy"
    fi

    local run_cmd="\"$agy_bin\""
    if [ -n "$target_arg" ]; then
        if [[ "$target_arg" =~ ^-- ]]; then
            run_cmd="\"$agy_bin\" $target_arg"
        else
            run_cmd="\"$agy_bin\" --model \"$target_arg\""
        fi
    fi

    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo -e "\n${BOLD}${YELLOW}No GUI display detected; launching ${title} in current terminal...${NC}\n"
        sleep 0.8
        trap ':' INT
        eval "$run_cmd"
        trap - INT
        press_enter
        return 0
    fi

    echo ""
    echo -e "${BOLD}Select launch target for ${title}:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} New Konsole Tab (Default - keeps Manager running in background)"
    echo -e "  ${BOLD}${CYAN}2)${NC} New Standalone Konsole Window"
    echo -e "  ${BOLD}${CYAN}3)${NC} Current Terminal Window (Returns to Manager upon exit)"
    read -r -p "Enter choice [1-3, default: 1]: " t_choice

    case "$t_choice" in
        2)
            echo -e "\n${BOLD}${GREEN}Launching ${title} in a new window...${NC}\n"
            local full_cmd="$run_cmd; echo ''; echo 'Session ended. Press [Enter] to close window...'; read -r"
            if command -v konsole >/dev/null 2>&1; then
                nohup konsole --separate --workdir "$PWD" -p tabtitle="$title" -e bash -c "$full_cmd" >/dev/null 2>&1 &
            elif command -v xdg-terminal-exec >/dev/null 2>&1; then
                nohup xdg-terminal-exec bash -c "$full_cmd" >/dev/null 2>&1 &
            elif command -v gnome-terminal >/dev/null 2>&1; then
                nohup gnome-terminal --title="$title" -- bash -c "$full_cmd" >/dev/null 2>&1 &
            elif command -v xterm >/dev/null 2>&1; then
                nohup xterm -T "$title" -e bash -c "$full_cmd" >/dev/null 2>&1 &
            else
                echo -e "${YELLOW}No external terminal emulator found; launching in current window...${NC}"
                sleep 0.5
                trap ':' INT
                eval "$run_cmd"
                trap - INT
                press_enter
                return 0
            fi
            echo -e "${GREEN}✓ ${title} launched in a new window.${NC}"
            sleep 1.2
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Launching ${title} in current terminal (Type /exit or Ctrl+D twice to return)...${NC}\n"
            sleep 0.8
            trap ':' INT
            eval "$run_cmd"
            trap - INT
            press_enter
            ;;
        *)
            echo -e "\n${BOLD}${GREEN}Launching ${title} in a new Konsole tab...${NC}\n"
            local full_cmd="$run_cmd; echo ''; echo 'Session ended. Press [Enter] to close tab...'; read -r"
            if command -v konsole >/dev/null 2>&1; then
                nohup konsole --new-tab -p tabtitle="$title" --workdir "$PWD" -e bash -c "$full_cmd" >/dev/null 2>&1 &
            elif command -v xdg-terminal-exec >/dev/null 2>&1; then
                nohup xdg-terminal-exec bash -c "$full_cmd" >/dev/null 2>&1 &
            elif command -v gnome-terminal >/dev/null 2>&1; then
                nohup gnome-terminal --title="$title" -- bash -c "$full_cmd" >/dev/null 2>&1 &
            elif command -v xterm >/dev/null 2>&1; then
                nohup xterm -T "$title" -e bash -c "$full_cmd" >/dev/null 2>&1 &
            else
                echo -e "${YELLOW}No external terminal emulator found; launching in current window...${NC}"
                sleep 0.5
                trap ':' INT
                eval "$run_cmd"
                trap - INT
                press_enter
                return 0
            fi
            echo -e "${GREEN}✓ ${title} launched in a new Konsole tab.${NC}"
            sleep 1.2
            ;;
    esac
}

manage_ai_models() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       AI ASSISTANT & MODEL LAUNCHER (AGY)        ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""
        echo -e "  Account:    ${CYAN}mathewkjohn2026@gmail.com${NC}"
        echo -e "  Workspace:  ${GREEN}${PWD}${NC}"
        echo ""
        echo -e "${BOLD}Claude & GPT Models (Shared Partner Quota):${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Claude Sonnet 4.6 (Thinking)         ${GREEN}[claude-sonnet-4-6]${NC}"
        echo -e "  ${BOLD}${CYAN}2)${NC} Claude Opus 4.6 (Thinking)           ${GREEN}[claude-opus-4-6-thinking]${NC}"
        echo -e "  ${BOLD}${CYAN}3)${NC} GPT-OSS 120B (Medium)                ${GREEN}[gpt-oss-120b-medium]${NC}"
        echo ""
        echo -e "${BOLD}Google Gemini Models (High Volume Quota):${NC}"
        echo -e "  ${BOLD}${CYAN}4)${NC} Gemini 3.8 Flash (High)              ${GREEN}[gemini-3.8-flash-high]${NC}"
        echo -e "  ${BOLD}${CYAN}5)${NC} Gemini 3.1 Pro (High)                ${GREEN}[gemini-3.1-pro-high]${NC}"
        echo ""
        echo -e "${BOLD}Sessions & Utilities:${NC}"
        echo -e "  ${BOLD}${CYAN}6)${NC} Launch Default Session               ${GREEN}[agy]${NC}"
        echo -e "  ${BOLD}${CYAN}7)${NC} Resume Most Recent Conversation      ${GREEN}[agy --continue]${NC}"
        echo -e "  ${BOLD}${CYAN}8)${NC} View All Available Models & Status   ${GREEN}[agy models]${NC}"
        echo -e "  ${BOLD}${CYAN}9)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-9]: " ai_choice

        case $ai_choice in
            1)
                launch_ai_session "claude-sonnet-4-6" "Claude Sonnet"
                ;;
            2)
                launch_ai_session "claude-opus-4-6-thinking" "Claude Opus"
                ;;
            3)
                launch_ai_session "gpt-oss-120b-medium" "GPT-OSS 120B"
                ;;
            4)
                launch_ai_session "gemini-3.8-flash-high" "Gemini 3.8 Flash"
                ;;
            5)
                launch_ai_session "gemini-3.1-pro-high" "Gemini 3.1 Pro"
                ;;
            6)
                launch_ai_session "" "Antigravity AI"
                ;;
            7)
                echo -e "\n${BOLD}${YELLOW}Resuming most recent conversation...${NC}\n"
                launch_ai_session "--continue" "Resume Session"
                ;;
            8)
                echo -e "\n${BOLD}${BLUE}=== AVAILABLE MODELS IN AGY ===${NC}\n"
                if command -v agy >/dev/null 2>&1; then
                    agy models
                elif [ -x "$HOME/.local/bin/agy.bin" ]; then
                    "$HOME/.local/bin/agy.bin" models
                fi
                echo ""
                press_enter
                ;;
            9)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

burn_iso_to_usb() {
    echo -e "\n${BOLD}${MAGENTA}==================================================${NC}"
    echo -e "${BOLD}${MAGENTA}          BURN ISO IMAGE TO USB DRIVE (DD)        ${NC}"
    echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"

    # Prompt user for ISO file path
    local iso_path=""
    read -r -e -p "Enter full path to the ISO file: " iso_path

    # Clean input quotes and spaces from drag & drop
    iso_path=$(echo "$iso_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    if [ -z "$iso_path" ]; then
        echo -e "${RED}Error: ISO file path cannot be empty!${NC}"
        press_enter
        return 1
    fi

    # Expand tilde if present
    if [[ "$iso_path" == ~* ]]; then
        iso_path="${iso_path/#~/$HOME}"
    fi

    if [ ! -f "$iso_path" ]; then
        echo -e "${RED}Error: File not found at '$iso_path'!${NC}"
        press_enter
        return 1
    fi

    local iso_size
    iso_size=$(ls -lh "$iso_path" 2>/dev/null | awk '{print $5}')
    echo -e "${GREEN}✓ Found ISO:${NC} $iso_path (${CYAN}${iso_size}${NC})"

    # Display available USB storage devices
    echo -e "\n${BOLD}Available USB Removable Devices:${NC}"
    lsblk -d -o NAME,MODEL,SIZE,TRAN,VENDOR,TYPE | grep -E "usb|NAME"
    echo ""

    local target_dev=""
    read -r -p "Enter target device name (e.g. sdf or /dev/sdf): " target_dev
    target_dev=$(echo "$target_dev" | tr -d ' ' | sed 's|^/dev/||')

    if [ -z "$target_dev" ]; then
        echo -e "${RED}Error: Target device cannot be empty!${NC}"
        press_enter
        return 1
    fi

    local full_dev="/dev/$target_dev"
    if [ ! -b "$full_dev" ]; then
        echo -e "${RED}Error: Block device '$full_dev' does not exist!${NC}"
        press_enter
        return 1
    fi

    # Ensure user specified a whole disk, not a partition (e.g. sdf, not sdf1)
    local dev_type
    dev_type=$(lsblk -no TYPE "$full_dev" 2>/dev/null | head -n 1)
    if [ "$dev_type" != "disk" ]; then
        echo -e "${RED}Error: '$full_dev' is a $dev_type, not a whole disk (e.g. specify 'sdf', not 'sdf1')!${NC}"
        press_enter
        return 1
    fi

    # Safety check: Prevent targeting OS drives
    local mounts
    mounts=$(lsblk -no MOUNTPOINTS "$full_dev" 2>/dev/null | tr '\n' ' ')
    if echo "$mounts" | grep -qE '(^|[[:space:]])/(sysroot|boot|var|etc|home|var/home)?([[:space:]]|$)'; then
        echo -e "${BOLD}${RED}FATAL: $full_dev contains active operating system mounts! Aborting.${NC}"
        press_enter
        return 1
    fi

    # Warn if not a USB transport
    local tran
    tran=$(lsblk -no TRAN "$full_dev" 2>/dev/null | head -n 1)
    if [ "$tran" != "usb" ]; then
        echo -e "${BOLD}${YELLOW}WARNING: Device $full_dev transport is '$tran' (not USB)!${NC}"
    fi

    echo -e "\n${BOLD}${BLUE}Target Drive Details:${NC}"
    lsblk -o NAME,MODEL,SIZE,LABEL,FSTYPE,MOUNTPOINTS "$full_dev"
    echo ""

    echo -e "${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
    echo -e "${BOLD}${RED}ALL EXISTING DATA ON $full_dev WILL BE PERMANENTLY ERASED!${NC}"
    echo -e "${BOLD}${RED}Source: $iso_path (${iso_size})${NC}"
    echo -e "${BOLD}${RED}Target: $full_dev${NC}"
    echo -e "${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}\n"

    read -r -p "Type 'YES' (in capitals) to confirm writing to $full_dev: " confirm_burn
    if [ "$confirm_burn" != "YES" ]; then
        echo -e "\n${YELLOW}Operation canceled. No changes were made.${NC}"
        press_enter
        return 0
    fi

    # Unmount any mounted partitions on the target drive
    echo -e "\n${CYAN}Unmounting any active partitions on $full_dev...${NC}"
    local part_names
    part_names=$(lsblk -lno NAME "$full_dev" 2>/dev/null | tail -n +2)
    for part in $part_names; do
        if grep -qs "/dev/$part" /proc/mounts; then
            echo -e "  Unmounting /dev/$part..."
            udisksctl unmount -b "/dev/$part" 2>/dev/null || sudo umount "/dev/$part" 2>/dev/null || true
        fi
    done

    echo -e "\n${BOLD}${GREEN}Executing dd (writing ISO to $full_dev)...${NC}\n"
    sudo dd if="$iso_path" of="$full_dev" bs=4M status=progress oflag=sync
    local dd_status=$?

    if [ $dd_status -eq 0 ]; then
        sync
        echo -e "\n${BOLD}${GREEN}✓ Successfully wrote ISO to $full_dev!${NC}"
        echo -e "${CYAN}Disk synced. The USB drive is now ready to boot.${NC}"
    else
        echo -e "\n${BOLD}${RED}✗ Error occurred during dd write (exit code: $dd_status)!${NC}"
    fi

    press_enter
    return $dd_status
}

while true; do
    clear
    echo -e "${BOLD}${MAGENTA}==================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       STREAM OF FREQUENCY MIX ARCHIVE MANAGER     ${NC}"
    echo -e "${BOLD}${MAGENTA}==================================================${NC}"
    echo ""
    
    show_stats
    
    echo ""
    echo -e "${BOLD}Select an operation:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Run FLAC Conversion Process (${GREEN}Make_SOF_FLAC_CONVERSION.sh${NC})"
    echo -e "  ${BOLD}${CYAN}2)${NC} Scan & Generate Missing Tracklists (${GREEN}Check_Find_Tracklists.sh${NC})"
    echo -e "  ${BOLD}${CYAN}3)${NC} Retrieve Unconverted WAVs from Archive (${GREEN}MOVE_NOT_CONVERTED_WAVS.sh${NC})"
    echo -e "  ${BOLD}${CYAN}4)${NC} Launch Live Tracklist Monitor (${GREEN}SOF_Live_Tracker.sh${NC})"
    echo -e "  ${BOLD}${CYAN}5)${NC} View Advanced Archive Statistics (${GREEN}SOF_Archive_Stats.sh${NC})"
    echo -e "  ${BOLD}${CYAN}6)${NC} Rename a Mix and Associated Assets (FLAC, Tracklist, Spek)"
    echo -e "  ${BOLD}${CYAN}7)${NC} Back up FLAC Outputs to Google Drive (${GREEN}backup_to_gdrive.sh${NC})"
    echo -e "  ${BOLD}${CYAN}8)${NC} Verify FLAC Files for Integrity & Corruption (${GREEN}Verify_FLAC_Files.sh${NC})"
    echo -e "  ${BOLD}${CYAN}9)${NC} Import New Mixes from SMB Share (${GREEN}import_new_mixes.sh${NC})"
    echo -e "  ${BOLD}${CYAN}10)${NC} View Running Background Tasks"
    echo -e "  ${BOLD}${CYAN}11)${NC} View Cover Art by Mix Number (External Viewer)"
    echo -e "  ${BOLD}${CYAN}12)${NC} Generate Master Tracklist HTML Index (${GREEN}Generate_Master_Tracklist.sh${NC})"
    echo -e "  ${BOLD}${CYAN}13)${NC} Generate 1080p YouTube Video (${GREEN}Make_SOF_Episode_From_PNG_FLAC_Output_MP4_1080p_Video.sh${NC})"
    echo -e "  ${BOLD}${CYAN}14)${NC} Launch Live File Transfer Monitor (${GREEN}transfer-monitor${NC})"
    echo -e "  ${BOLD}${CYAN}15)${NC} Launch Chrome Upload Monitor (${GREEN}Podcast Connect / Web Uploads${NC})"
    echo -e "  ${BOLD}${CYAN}16)${NC} Refresh Archive Status & File Counts (Rescan WAVs, FLACs & Tracklists)"
    echo -e "  ${BOLD}${CYAN}17)${NC} Launch System Process Monitor (${GREEN}top${NC})"
    echo -e "  ${BOLD}${CYAN}18)${NC} Launch GPU Process Monitor (${GREEN}nvtop${NC})"
    echo -e "  ${BOLD}${CYAN}19)${NC} Launch Resource Monitor (${GREEN}btop${NC})"
    echo -e "  ${BOLD}${CYAN}20)${NC} cliamp Music Player & Current Track Info (${GREEN}Now Playing Path, Controls & Launch${NC})"
    echo -e "  ${BOLD}${CYAN}21)${NC} Launch Strawberry Music Player (New Window) (${GREEN}strawberry${NC})"
    echo -e "  ${BOLD}${CYAN}22)${NC} Launch Video Playlists (NFT Videos (VLC))"
    echo -e "  ${BOLD}${CYAN}23)${NC} Close All Desktop Applications (Keep Manager Open)"
    echo -e "  ${BOLD}${CYAN}24)${NC} Block Internet Access (LAN Only) (${GREEN}block-internet${NC})"
    echo -e "  ${BOLD}${CYAN}25)${NC} Restore / Unblock Internet Access (${GREEN}unblock-internet${NC})"
    echo -e "  ${BOLD}${CYAN}26)${NC} Launch GeeXLab Demo Launcher (${GREEN}FurMark_linux64/demo_launcher.sh${NC})"
    echo -e "  ${BOLD}${CYAN}27)${NC} Show Connected USB MIDI Devices (${GREEN}list-midi-devices${NC})"
    echo -e "  ${BOLD}${CYAN}28)${NC} Switch Desktop to Plasma Wayland (HDR Gaming on Hisense & Steam BPM)"
    echo -e "  ${BOLD}${CYAN}29)${NC} Switch Desktop to Plasma X11 (Workstation 4-Screen Defasten)"
    echo -e "  ${BOLD}${CYAN}30)${NC} Manage WAN2GP Server (Start, Stop, Restart in Profile 2 or 4.5)"
    echo -e "  ${BOLD}${CYAN}31)${NC} Manage Network Services (SSH, Samba, FTP - Start, Stop, Restart All)"
    echo -e "  ${BOLD}${CYAN}32)${NC} Bazzite System Maintenance & Cleanup (${GREEN}ujust clean-system, update, trim, logs${NC})"
    echo -e "  ${BOLD}${CYAN}33)${NC} Launch AI Assistant / Models (${GREEN}Claude Opus, Claude Sonnet, GPT-OSS, Gemini${NC})"
    echo -e "  ${BOLD}${CYAN}34)${NC} Burn ISO Image to USB Drive (${GREEN}dd with safety checks${NC})"
    echo -e "  ${BOLD}${CYAN}35)${NC} Cut Video File (.mp4 / .mkv) (${GREEN}Cut_Video.sh${NC})"
    echo -e "  ${BOLD}${CYAN}36)${NC} Exit Manager"
    echo ""
    read -r -p "Enter choice [1-36]: " choice
    
    case $choice in
        1)
            echo -e "\n${BOLD}${YELLOW}Starting FLAC Conversion...${NC}\n"
            run_sub_script "Make_SOF_FLAC_CONVERSION.sh"
            press_enter
            ;;
        2)
            echo -e "\n${BOLD}${YELLOW}Scanning & Generating Missing Tracklists...${NC}\n"
            run_sub_script "Check_Find_Tracklists.sh"
            press_enter
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Retrieving unconverted WAV files...${NC}\n"
            run_sub_script "MOVE_NOT_CONVERTED_WAVS.sh"
            press_enter
            ;;
        4)
            echo -e "\n${BOLD}${YELLOW}Launching Live Tracklist Monitor (Press Ctrl+C to return to menu)...${NC}\n"
            sleep 1
            # Temporarily trap SIGINT so Ctrl+C only exits the tracker, not the menu manager
            trap ':' INT
            run_sub_script "SOF_Live_Tracker.sh"
            trap - INT
            press_enter
            ;;
        5)
            echo -e "\n${BOLD}${YELLOW}Loading Advanced Archive Statistics...${NC}\n"
            sleep 0.5
            run_sub_script "SOF_Archive_Stats.sh"
            press_enter
            ;;
        6)
            rename_mix
            press_enter
            ;;
        7)
            echo -e "\n${BOLD}${YELLOW}Starting Google Drive Backup...${NC}\n"
            run_sub_script "backup_to_gdrive.sh"
            press_enter
            ;;
        8)
            echo -e "\n${BOLD}${YELLOW}Starting FLAC File Integrity Scan...${NC}\n"
            run_sub_script "Verify_FLAC_Files.sh"
            press_enter
            ;;
        9)
            echo -e "\n${BOLD}${YELLOW}Starting SMB Import Process...${NC}\n"
            run_sub_script "import_new_mixes.sh"
            press_enter
            ;;
        10)
            view_tasks
            press_enter
            ;;
        11)
            view_cover
            press_enter
            ;;
        12)
            echo -e "\n${BOLD}${YELLOW}Starting Master Tracklist HTML Generation...${NC}\n"
            run_sub_script "Generate_Master_Tracklist.sh"
            press_enter
            ;;
        13)
            generate_youtube_video
            press_enter
            ;;
        14)
            echo -e "\n${BOLD}${YELLOW}Launching Live File Transfer Monitor (Press Ctrl+C to return to menu)...${NC}\n"
            sleep 1
            trap ':' INT
            if command -v transfer-monitor >/dev/null 2>&1; then
                transfer-monitor
            elif [ -x "$SCRIPT_DIR/bin/transfer-monitor" ]; then
                "$SCRIPT_DIR/bin/transfer-monitor"
            elif [ -x "$HOME/.local/bin/transfer-monitor" ]; then
                "$HOME/.local/bin/transfer-monitor"
            else
                echo -e "${RED}Error: transfer-monitor command not found in PATH or bin!${NC}"
            fi
            trap - INT
            press_enter
            ;;
        15)
            echo -e "\n${BOLD}${YELLOW}Launching Chrome Upload Monitor (Press Ctrl+C to return to menu)...${NC}\n"
            sleep 1
            trap ':' INT
            if command -v chrome-upload-monitor >/dev/null 2>&1; then
                chrome-upload-monitor
            elif [ -x "$SCRIPT_DIR/bin/chrome-upload-monitor" ]; then
                "$SCRIPT_DIR/bin/chrome-upload-monitor"
            elif [ -x "$HOME/.local/bin/chrome-upload-monitor" ]; then
                "$HOME/.local/bin/chrome-upload-monitor"
            elif [ -x "./chrome_upload_monitor.py" ]; then
                python3 ./chrome_upload_monitor.py
            elif [ -x "$SCRIPT_DIR/chrome_upload_monitor.py" ]; then
                python3 "$SCRIPT_DIR/chrome_upload_monitor.py"
            elif [ -x "./Monitor_Chrome_Uploads.sh" ]; then
                ./Monitor_Chrome_Uploads.sh
            elif [ -x "$SCRIPT_DIR/Monitor_Chrome_Uploads.sh" ]; then
                "$SCRIPT_DIR/Monitor_Chrome_Uploads.sh"
            else
                echo -e "${RED}Error: chrome-upload-monitor command not found in PATH or bin!${NC}"
            fi
            trap - INT
            press_enter
            ;;
        16)
            # Loop will naturally clear screen and show stats
            ;;
        17)
            echo -e "\n${BOLD}${YELLOW}Launching top Process Monitor (Press 'q' to exit)...${NC}\n"
            sleep 0.5
            trap ':' INT
            if command -v top >/dev/null 2>&1; then
                top
            else
                echo -e "${RED}Error: top command not found in PATH!${NC}"
                press_enter
            fi
            trap - INT
            ;;
        18)
            echo -e "\n${BOLD}${YELLOW}Launching nvtop GPU Monitor (Press 'q' to exit)...${NC}\n"
            sleep 0.5
            trap ':' INT
            if command -v nvtop >/dev/null 2>&1; then
                nvtop
            else
                echo -e "${RED}Error: nvtop command not found in PATH!${NC}"
                press_enter
            fi
            trap - INT
            ;;
        19)
            echo -e "\n${BOLD}${YELLOW}Launching btop Resource Monitor (Press 'q' to exit)...${NC}\n"
            sleep 0.5
            trap ':' INT
            if command -v btop >/dev/null 2>&1; then
                btop
            else
                echo -e "${RED}Error: btop command not found in PATH!${NC}"
                press_enter
            fi
            trap - INT
            ;;
        20)
            manage_cliamp
            ;;
        21)
            launch_strawberry
            ;;
        22)
            launch_video_playlists
            ;;
        23)
            close_all_desktop_apps
            ;;
        24)
            block_internet
            ;;
        25)
            unblock_internet
            ;;
        26)
            launch_geexlab_demos
            ;;
        27)
            list_usb_midi_devices
            ;;
        28)
            switch_to_wayland
            ;;
        29)
            switch_to_x11
            ;;
        30)
            manage_wan2gp
            ;;
        31)
            manage_network_services
            ;;
        32)
            manage_system_maintenance
            ;;
        33)
            manage_ai_models
            ;;
        34)
            burn_iso_to_usb
            ;;
        35)
            cut_video_clip
            press_enter
            ;;
        36)
            echo -e "\n${BOLD}${GREEN}Exiting Mix Archive Manager. Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option! Please enter a number between 1 and 36.${NC}"
            sleep 2
            ;;
    esac
done
