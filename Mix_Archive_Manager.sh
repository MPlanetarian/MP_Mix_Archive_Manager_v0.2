#!/usr/bin/env bash

# Colors for terminal styling & Theme Engine
set_theme_colors() {
    local theme_name="${1:-cyberpunk}"
    NC='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    
    case "$theme_name" in
        dracula)
            RED='\033[38;5;212m'     # Dracula Coral Pink / Red
            GREEN='\033[38;5;84m'    # Dracula Neon Green
            YELLOW='\033[38;5;228m'  # Dracula Pale Gold
            BLUE='\033[38;5;62m'     # Dracula Lavender Blue
            MAGENTA='\033[38;5;141m' # Dracula Purple
            CYAN='\033[38;5;117m'    # Dracula Sky Cyan
            CURRENT_THEME="dracula"
            ;;
        nord)
            RED='\033[38;5;167m'     # Nord Aurora Red
            GREEN='\033[38;5;108m'   # Nord Aurora Green / Sage
            YELLOW='\033[38;5;221m'  # Nord Aurora Yellow
            BLUE='\033[38;5;110m'    # Nord Frost Slate Blue
            MAGENTA='\033[38;5;139m' # Nord Aurora Purple
            CYAN='\033[38;5;117m'    # Nord Frost Polar Cyan
            CURRENT_THEME="nord"
            ;;
        matrix)
            RED='\033[38;5;124m'     # Dark Terminal Crimson
            GREEN='\033[38;5;46m'    # Pure Phosphor Green
            YELLOW='\033[38;5;190m'  # Electric Yellow-Green
            BLUE='\033[38;5;29m'     # Deep Matrix Green
            MAGENTA='\033[38;5;35m'  # Forest Emerald
            CYAN='\033[38;5;120m'    # Light Phosphor Mint
            CURRENT_THEME="matrix"
            ;;
        solarized)
            RED='\033[38;5;166m'     # Solarized Red
            GREEN='\033[38;5;64m'    # Solarized Green
            YELLOW='\033[38;5;136m'  # Solarized Yellow
            BLUE='\033[38;5;33m'     # Solarized Blue
            MAGENTA='\033[38;5;125m' # Solarized Magenta
            CYAN='\033[38;5;37m'     # Solarized Cyan
            CURRENT_THEME="solarized"
            ;;
        tokyo)
            RED='\033[38;5;203m'     # Tokyo Red/Coral
            GREEN='\033[38;5;114m'   # Tokyo Sage Green
            YELLOW='\033[38;5;222m'  # Tokyo Warm Sand
            BLUE='\033[38;5;111m'    # Tokyo Soft Blue
            MAGENTA='\033[38;5;176m' # Tokyo Neon Purple
            CYAN='\033[38;5;73m'     # Tokyo Cyan
            CURRENT_THEME="tokyo"
            ;;
        monokai)
            RED='\033[38;5;197m'     # Monokai Pink/Red
            GREEN='\033[38;5;148m'   # Monokai Lime Green
            YELLOW='\033[38;5;220m'  # Monokai Gold Yellow
            BLUE='\033[38;5;141m'    # Monokai Purple Blue
            MAGENTA='\033[38;5;208m' # Monokai Bright Orange
            CYAN='\033[38;5;81m'     # Monokai Bright Blue/Cyan
            CURRENT_THEME="monokai"
            ;;
        gruvbox)
            RED='\033[38;5;167m'     # Gruvbox Rust Red
            GREEN='\033[38;5;142m'   # Gruvbox Olive Green
            YELLOW='\033[38;5;214m'  # Gruvbox Warm Yellow
            BLUE='\033[38;5;109m'    # Gruvbox Slate Blue
            MAGENTA='\033[38;5;175m' # Gruvbox Dusty Rose
            CYAN='\033[38;5;108m'    # Gruvbox Aqua
            CURRENT_THEME="gruvbox"
            ;;
        emerald)
            RED='\033[38;5;204m'     # Soft Coral
            GREEN='\033[38;5;48m'    # Pure Spring Emerald
            YELLOW='\033[38;5;221m'  # Gold Amber
            BLUE='\033[38;5;31m'     # Deep Ocean
            MAGENTA='\033[38;5;78m'  # Light Seafoam
            CYAN='\033[38;5;86m'     # Mint Cyan
            CURRENT_THEME="emerald"
            ;;
        classic)
            RED='\033[0;31m'
            GREEN='\033[0;32m'
            YELLOW='\033[0;33m'
            BLUE='\033[0;34m'
            MAGENTA='\033[0;35m'
            CYAN='\033[0;36m'
            CURRENT_THEME="classic"
            ;;
        cyberpunk|*)
            RED='\033[38;5;196m'     # Cyberpunk Neon Red
            GREEN='\033[38;5;48m'    # Cyberpunk Acid Green
            YELLOW='\033[38;5;226m'  # Cyberpunk High Voltage Yellow
            BLUE='\033[38;5;45m'     # Cyberpunk Deep Cyan/Blue
            MAGENTA='\033[38;5;198m' # Cyberpunk Hot Pink
            CYAN='\033[38;5;51m'     # Cyberpunk Electric Cyan
            CURRENT_THEME="cyberpunk"
            ;;
    esac
}

load_theme() {
    local theme_file="$HOME/.config/mix-manager/theme"
    if [ -f "$theme_file" ]; then
        local saved_theme
        saved_theme="$(tr -d ' \t\n\r' < "$theme_file" 2>/dev/null)"
        if [ -n "$saved_theme" ]; then
            set_theme_colors "$saved_theme"
            return
        fi
    fi
    set_theme_colors "cyberpunk"
}

save_theme() {
    local new_theme="$1"
    mkdir -p "$HOME/.config/mix-manager" 2>/dev/null
    echo "$new_theme" > "$HOME/.config/mix-manager/theme" 2>/dev/null
    set_theme_colors "$new_theme"
}

load_theme
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# OS Platform Detection (Linux, macOS, Windows 10/11)
OS_TYPE="linux"
case "$(uname -s)" in
    Darwin*)
        OS_TYPE="macos"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        OS_TYPE="windows"
        ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS_TYPE="wsl"
        else
            OS_TYPE="linux"
        fi
        ;;
    *)
        OS_TYPE="linux"
        ;;
esac

# Cross-Platform Open Path (File/Directory opener for Linux, macOS, and Windows)
open_path() {
    local target="$1"
    [ -z "$target" ] && return 0
    if [ "$OS_TYPE" = "macos" ]; then
        open "$target" >/dev/null 2>&1 &
    elif [ "$OS_TYPE" = "windows" ]; then
        if command -v cygpath >/dev/null 2>&1; then
            local win_p
            win_p="$(cygpath -w "$target" 2>/dev/null || echo "$target")"
            cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
        else
            explorer.exe "$target" >/dev/null 2>&1 &
        fi
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wslview >/dev/null 2>&1; then
            wslview "$target" >/dev/null 2>&1 &
        elif command -v explorer.exe >/dev/null 2>&1; then
            explorer.exe "$(wslpath -w "$target" 2>/dev/null || echo "$target")" >/dev/null 2>&1 &
        fi
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target" >/dev/null 2>&1 &
    fi
}

# Cross-Platform Clipboard Copy (Linux wl-copy/xclip, macOS pbcopy, Windows clip.exe)
copy_to_clipboard() {
    local text="$1"
    if [ "$OS_TYPE" = "macos" ] && command -v pbcopy >/dev/null 2>&1; then
        printf "%s" "$text" | pbcopy
        return 0
    elif [ "$OS_TYPE" = "windows" ] && command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        return 0
    elif [ "$OS_TYPE" = "wsl" ] && command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        return 0
    elif command -v wl-copy >/dev/null 2>&1; then
        printf "%s" "$text" | wl-copy
        return 0
    elif command -v xclip >/dev/null 2>&1; then
        printf "%s" "$text" | xclip -selection clipboard
        return 0
    elif command -v pbcopy >/dev/null 2>&1; then
        printf "%s" "$text" | pbcopy
        return 0
    elif command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        return 0
    fi
    return 1
}

# Cross-Platform Launch Command in New Terminal Tab or Window
launch_in_terminal() {
    local title="$1"
    local cmd="$2"
    local mode="${3:-tab}" # "tab" or "window"

    if [ "$OS_TYPE" = "macos" ]; then
        local escaped_pwd escaped_cmd
        escaped_pwd=$(printf '%s' "$PWD" | sed 's/"/\\"/g')
        escaped_cmd=$(printf '%s' "$cmd" | sed 's/"/\\"/g')
        osascript -e "tell application \"Terminal\" to do script \"cd \\\"$escaped_pwd\\\" && $escaped_cmd\"" >/dev/null 2>&1 &
        return 0
    elif [ "$OS_TYPE" = "windows" ]; then
        if command -v wt.exe >/dev/null 2>&1; then
            if [ "$mode" = "tab" ]; then
                wt.exe new-tab --title "$title" bash -c "$cmd" >/dev/null 2>&1 &
            else
                wt.exe -w new --title "$title" bash -c "$cmd" >/dev/null 2>&1 &
            fi
            return 0
        elif command -v start >/dev/null 2>&1; then
            start "$title" bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v cmd.exe >/dev/null 2>&1; then
            cmd.exe /c start "$title" bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wt.exe >/dev/null 2>&1; then
            wt.exe -w 0 nt --title "$title" wsl.exe -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    fi

    # Linux native terminal emulators
    if [ "$mode" = "window" ]; then
        if command -v konsole >/dev/null 2>&1; then
            nohup konsole --separate --workdir "$PWD" -p tabtitle="$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xdg-terminal-exec >/dev/null 2>&1; then
            nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v gnome-terminal >/dev/null 2>&1; then
            nohup gnome-terminal --title="$title" -- bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xterm >/dev/null 2>&1; then
            nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    else
        # default to tab or preferred terminal
        if command -v konsole >/dev/null 2>&1; then
            nohup konsole --new-tab -p tabtitle="$title" --workdir "$PWD" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xdg-terminal-exec >/dev/null 2>&1; then
            nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v gnome-terminal >/dev/null 2>&1; then
            nohup gnome-terminal --title="$title" -- bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xterm >/dev/null 2>&1; then
            nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    fi

    return 1
}

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

# Determine target working archive directory across Linux, macOS, and Windows
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
    cd "$MIX_ARCHIVE_DIR" || exit 1
elif [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" ]; then
    cd "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" || exit 1
elif [ -d "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" ]; then
    cd "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" || exit 1
elif [ -d "/Volumes/WD BLACK B/MIX_ARCHIVE" ]; then
    cd "/Volumes/WD BLACK B/MIX_ARCHIVE" || exit 1
elif [ -d "/Volumes/MIX_ARCHIVE" ]; then
    cd "/Volumes/MIX_ARCHIVE" || exit 1
elif [ -d "/d/MIX_ARCHIVE" ]; then
    cd "/d/MIX_ARCHIVE" || exit 1
elif [ -d "/e/MIX_ARCHIVE" ]; then
    cd "/e/MIX_ARCHIVE" || exit 1
elif [ -d "D:/MIX_ARCHIVE" ]; then
    cd "D:/MIX_ARCHIVE" || exit 1
elif [ -d "E:/MIX_ARCHIVE" ]; then
    cd "E:/MIX_ARCHIVE" || exit 1
elif [ -d "/mnt/d/MIX_ARCHIVE" ]; then
    cd "/mnt/d/MIX_ARCHIVE" || exit 1
elif [ -d "/mnt/e/MIX_ARCHIVE" ]; then
    cd "/mnt/e/MIX_ARCHIVE" || exit 1
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
                    "/Volumes/WD BLACK B/MIX_ARCHIVE" \
                    "/Volumes/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" \
                    "/Volumes/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" \
                    "/Volumes/MIX_ARCHIVE" \
                    "/d/MIX_ARCHIVE" \
                    "/e/MIX_ARCHIVE" \
                    "D:/MIX_ARCHIVE" \
                    "E:/MIX_ARCHIVE" \
                    "/mnt/d/MIX_ARCHIVE" \
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
        open_path "$selected_cover"
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

    if launch_in_terminal "cliamp" "$cliamp_bin" "window"; then
        echo -e "${GREEN}✓ cliamp launched in a new window.${NC}"
        sleep 1.2
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window.${NC}"
        press_enter
        return 1
    fi
}

monitor_cliamp_live() {
    echo -e "\n${BOLD}${YELLOW}Starting Real-Time cliamp Monitor (Press 'q' or Ctrl+C to exit)...${NC}\n"
    sleep 0.5
    trap 'break' INT
    while true; do
        if ! get_cliamp_track_info 2>/dev/null; then
            clear
            echo -e "${BOLD}${MAGENTA}=== CLIAMP LIVE TRACKLIST MONITOR ===${NC}\n"
            echo -e "${YELLOW}cliamp is currently idle or no active track is playing.${NC}"
            echo -e "${DIM}Waiting for playback... (Press 'q' to quit)${NC}"
            read -r -t 1 -n 1 key 2>/dev/null || true
            if [[ "$key" == "q" || "$key" == "Q" ]]; then break; fi
            continue
        fi

        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}           CLIAMP LIVE REAL-TIME MONITOR          ${NC}"
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

        echo -e "  Status:        ${st_badge}"
        echo -e "  Title:         ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC}"
        echo -e "  Artist:        ${BOLD}${WHITE}${CLIAMP_ARTIST}${NC}"
        echo -e "  Position:      ${BOLD}${CYAN}${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}${NC} [${bar}] (${CLIAMP_PROGRESS_PCT}%)"
        echo ""
        echo -e "  ${BOLD}${GREEN}Current File:${NC}  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
        if [ "$CLIAMP_FILE_EXISTS" -eq 1 ]; then
            echo -e "  File Size:     ${GREEN}${CLIAMP_FILE_SIZE}${NC}"
        else
            echo -e "  File Status:   ${RED}File not found at path${NC}"
        fi
        echo ""
        echo -e "${DIM}Shortcuts: [p] Play/Pause  [n] Next  [b] Prev  [c] Copy Path  [o] Open Folder  [q] Exit${NC}"

        read -r -t 1 -n 1 key 2>/dev/null || true
        case "$key" in
            c|C)
                copy_to_clipboard "$CLIAMP_RESOLVED_PATH" || true
                ;;
            o|O)
                open_path "$(dirname "$CLIAMP_RESOLVED_PATH")"
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
        echo -e "  ${BOLD}${CYAN}1)${NC} Copy File Path to Clipboard (${GREEN}System Clipboard${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Open Containing Folder in File Browser (${GREEN}File Manager${NC})"
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
                if copy_to_clipboard "$CLIAMP_RESOLVED_PATH"; then
                    echo -e "\n${GREEN}✓ File path copied to clipboard!${NC}"
                else
                    echo -e "\n${YELLOW}Clipboard utility not available.${NC}"
                fi
                sleep 1.2
                ;;
            2|[oO])
                local folder_dir
                folder_dir=$(dirname "$CLIAMP_RESOLVED_PATH")
                if [ -d "$folder_dir" ]; then
                    echo -e "\n${GREEN}Opening $folder_dir in file manager...${NC}"
                    open_path "$folder_dir"
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
                    open_path "${spek_matches[0]}"
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

    if [ "$OS_TYPE" = "macos" ]; then
        osascript -e 'tell application "System Events"
            set appList to name of every application process whose visible is true and name is not "Terminal" and name is not "iTerm2" and name is not "Finder" and name is not "Ghostty" and name is not "Alacritty" and name is not "kitty"
            repeat with appName in appList
                tell application appName to quit
            end repeat
        end tell' 2>/dev/null
        echo -e "${GREEN}✓ Closed open macOS applications.${NC}"
        press_enter
        return 0
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        powershell.exe -Command "Get-Process | Where-Object { \$_.MainWindowTitle -ne '' -and \$_.ProcessName -notmatch 'bash|cmd|powershell|WindowsTerminal|mintty|conhost|explorer' } | ForEach-Object { \$_.CloseMainWindow() }" 2>/dev/null
        echo -e "${GREEN}✓ Closed open Windows desktop applications.${NC}"
        press_enter
        return 0
    fi

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
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}${YELLOW}macOS uses Quartz / WindowServer compositor.${NC}"
        echo -e "${CYAN}Opening macOS Display Settings...${NC}"
        open "x-apple.systempreferences:com.apple.Displays-Settings.extension" 2>/dev/null || open /System/Library/PreferencePanes/Displays.prefPane 2>/dev/null
        press_enter
        return 0
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Windows 10/11 uses Desktop Window Manager (DWM).${NC}"
        echo -e "${CYAN}Opening Windows Display Settings...${NC}"
        cmd.exe /c start ms-settings:display 2>/dev/null
        press_enter
        return 0
    fi

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
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}${YELLOW}macOS Audio & Sound Configuration.${NC}"
        echo -e "${CYAN}Opening Audio MIDI Setup...${NC}"
        open -a "Audio MIDI Setup" 2>/dev/null || open /System/Applications/Utilities/Audio\ MIDI\ Setup.app 2>/dev/null
        press_enter
        return 0
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Windows Audio Control Panel.${NC}"
        echo -e "${CYAN}Opening Windows Sound Settings...${NC}"
        cmd.exe /c start control.exe mmsys.cpl 2>/dev/null
        press_enter
        return 0
    fi

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

    if launch_in_terminal "$title" "$cmd" "tab"; then
        echo -e "${GREEN}✓ WAN2GP launched in a new console tab/window (Profile $profile).${NC}"
        sleep 1.2
        return 0
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
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

    if launch_in_terminal "$title" "$cmd" "tab"; then
        echo -e "${GREEN}✓ Flux 2 Klein 9B Batch Processor launched in a new console tab/window.${NC}"
        sleep 1.2
        return 0
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
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

    if launch_in_terminal "$title" "$cmd" "tab"; then
        echo -e "${GREEN}✓ LTX Video ${model^^} Batch Processor launched in a new console tab/window.${NC}"
        sleep 1.2
        return 0
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
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
        if [ "$OS_TYPE" = "macos" ]; then
            echo -e "${BOLD}${MAGENTA}         macOS SYSTEM MAINTENANCE & CLEANUP       ${NC}"
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            echo -e "${BOLD}${MAGENTA}       WINDOWS 10/11 MAINTENANCE & CLEANUP        ${NC}"
        else
            echo -e "${BOLD}${MAGENTA}       BAZZITE SYSTEM MAINTENANCE & CLEANUP       ${NC}"
        fi
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        if [ "$OS_TYPE" = "macos" ]; then
            local brew_count="N/A"
            if command -v brew >/dev/null 2>&1; then
                brew_count=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
                brew_formulae=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
                echo -e "  Homebrew Packages Installed: ${CYAN}${brew_formulae} formulae, ${brew_count} casks${NC}"
            fi
            echo -e "  macOS Version:               ${GREEN}$(sw_vers -productVersion 2>/dev/null || uname -r)${NC}"
            echo ""
            echo -e "${BOLD}Select a maintenance operation:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Clean Homebrew Caches & Old Packages (${GREEN}brew cleanup -s && brew autoremove${NC})"
            echo -e "  ${BOLD}${CYAN}2)${NC} Full System & Homebrew Update (${GREEN}brew update && brew upgrade${NC})"
            echo -e "  ${BOLD}${CYAN}3)${NC} Purge Inactive System RAM Memory (${GREEN}sudo purge${NC})"
            echo -e "  ${BOLD}${CYAN}4)${NC} Clear User Caches & Temporary Files (${GREEN}rm -rf ~/Library/Caches/*${NC})"
            echo -e "  ${BOLD}${CYAN}5)${NC} ${BOLD}${YELLOW}Run Complete macOS Maintenance Suite${NC}"
            echo -e "  ${BOLD}${CYAN}6)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [1-6]: " m_choice
            case "$m_choice" in
                1)
                    echo -e "\n${BOLD}${YELLOW}Cleaning Homebrew...${NC}\n"
                    brew cleanup -s && brew autoremove
                    press_enter
                    ;;
                2)
                    echo -e "\n${BOLD}${YELLOW}Updating Homebrew & packages...${NC}\n"
                    brew update && brew upgrade
                    press_enter
                    ;;
                3)
                    echo -e "\n${BOLD}${YELLOW}Purging inactive memory...${NC}\n"
                    sudo purge 2>/dev/null || purge 2>/dev/null || echo "Purge completed."
                    press_enter
                    ;;
                4)
                    echo -e "\n${BOLD}${YELLOW}Clearing user caches...${NC}\n"
                    rm -rf ~/Library/Caches/* 2>/dev/null || true
                    echo -e "${GREEN}✓ User caches cleared.${NC}"
                    press_enter
                    ;;
                5)
                    echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE macOS CLEANUP SUITE ===${NC}\n"
                    command -v brew >/dev/null 2>&1 && brew cleanup -s && brew autoremove
                    rm -rf ~/Library/Caches/* 2>/dev/null || true
                    sudo purge 2>/dev/null || true
                    echo -e "${GREEN}✓ Cleanup suite finished!${NC}"
                    press_enter
                    ;;
                6|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid choice!${NC}"
                    sleep 1.2
                    ;;
            esac
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            echo -e "  Windows Edition:             ${GREEN}$(cmd.exe /c "ver" 2>/dev/null | tr -d '\r\n' || echo "Windows 10/11")${NC}"
            echo ""
            echo -e "${BOLD}Select a maintenance operation:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Upgrade All Installed Packages (${GREEN}winget upgrade --all${NC})"
            echo -e "  ${BOLD}${CYAN}2)${NC} Clear Windows Temporary Files (${GREEN}%TEMP% & System Temp${NC})"
            echo -e "  ${BOLD}${CYAN}3)${NC} Empty Windows Recycle Bin (${GREEN}Clear-RecycleBin${NC})"
            echo -e "  ${BOLD}${CYAN}4)${NC} Optimize / TRIM Primary Drive C: (${GREEN}Optimize-Volume${NC})"
            echo -e "  ${BOLD}${CYAN}5)${NC} ${BOLD}${YELLOW}Run Complete Windows Maintenance Suite${NC}"
            echo -e "  ${BOLD}${CYAN}6)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [1-6]: " m_choice
            case "$m_choice" in
                1)
                    echo -e "\n${BOLD}${YELLOW}Upgrading packages via winget...${NC}\n"
                    cmd.exe /c "winget upgrade --all" 2>/dev/null || echo -e "${RED}winget not found.${NC}"
                    press_enter
                    ;;
                2)
                    echo -e "\n${BOLD}${YELLOW}Clearing Windows temp directory...${NC}\n"
                    powershell.exe -Command "Remove-Item -Path \$env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    echo -e "${GREEN}✓ Temporary files removed.${NC}"
                    press_enter
                    ;;
                3)
                    echo -e "\n${BOLD}${YELLOW}Emptying Recycle Bin...${NC}\n"
                    powershell.exe -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    echo -e "${GREEN}✓ Recycle bin emptied.${NC}"
                    press_enter
                    ;;
                4)
                    echo -e "\n${BOLD}${YELLOW}Optimizing C: drive...${NC}\n"
                    powershell.exe -Command "Optimize-Volume -DriveLetter C -Verbose" 2>/dev/null || true
                    press_enter
                    ;;
                5)
                    echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE WINDOWS CLEANUP SUITE ===${NC}\n"
                    powershell.exe -Command "Remove-Item -Path \$env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    powershell.exe -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    cmd.exe /c "winget upgrade --all" 2>/dev/null || true
                    echo -e "${GREEN}✓ Windows maintenance suite finished!${NC}"
                    press_enter
                    ;;
                6|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid choice!${NC}"
                    sleep 1.2
                    ;;
            esac
        else
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
                6|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid option!${NC}"
                    sleep 1.5
                    ;;
            esac
        fi
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
    echo -e "  ${BOLD}${CYAN}1)${NC} New Terminal Tab (Default - keeps Manager running in background)"
    echo -e "  ${BOLD}${CYAN}2)${NC} New Standalone Terminal Window"
    echo -e "  ${BOLD}${CYAN}3)${NC} Current Terminal Window (Returns to Manager upon exit)"
    read -r -p "Enter choice [1-3, default: 1]: " t_choice

    case "$t_choice" in
        2)
            echo -e "\n${BOLD}${GREEN}Launching ${title} in a new window...${NC}\n"
            local full_cmd="$run_cmd; echo ''; echo 'Session ended. Press [Enter] to close window...'; read -r"
            if launch_in_terminal "$title" "$full_cmd" "window"; then
                echo -e "${GREEN}✓ ${title} launched in a new window.${NC}"
                sleep 1.2
            else
                echo -e "${YELLOW}No external terminal emulator found; launching in current window...${NC}"
                sleep 0.5
                trap ':' INT
                eval "$run_cmd"
                trap - INT
                press_enter
                return 0
            fi
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
            echo -e "\n${BOLD}${GREEN}Launching ${title} in a new terminal tab...${NC}\n"
            local full_cmd="$run_cmd; echo ''; echo 'Session ended. Press [Enter] to close tab...'; read -r"
            if launch_in_terminal "$title" "$full_cmd" "tab"; then
                echo -e "${GREEN}✓ ${title} launched in a new terminal tab.${NC}"
                sleep 1.2
            else
                echo -e "${YELLOW}No external terminal emulator found; launching in current window...${NC}"
                sleep 0.5
                trap ':' INT
                eval "$run_cmd"
                trap - INT
                press_enter
                return 0
            fi
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

    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}Available External USB Drives (macOS diskutil):${NC}"
        diskutil list external
        echo ""
        read -r -p "Enter target disk name (e.g. disk2 or /dev/disk2): " target_dev
        target_dev=$(echo "$target_dev" | tr -d ' ' | sed 's|^/dev/||')
        if [ -z "$target_dev" ]; then
            echo -e "${RED}Error: Target disk cannot be empty!${NC}"
            press_enter
            return 1
        fi
        local full_dev="/dev/$target_dev"
        if ! diskutil info "$full_dev" >/dev/null 2>&1; then
            echo -e "${RED}Error: Disk '$full_dev' not found!${NC}"
            press_enter
            return 1
        fi
        if diskutil info "$full_dev" | grep -qi "Internal:[[:space:]]*Yes"; then
            echo -e "${BOLD}${RED}FATAL: $full_dev is reported as an INTERNAL drive! Aborting for safety.${NC}"
            press_enter
            return 1
        fi
        echo -e "\n${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
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
        echo -e "\n${CYAN}Unmounting $full_dev...${NC}"
        diskutil unmountDisk "$full_dev"
        local r_dev="/dev/r${target_dev}"
        echo -e "\n${BOLD}${GREEN}Executing dd (writing ISO to $r_dev)...${NC}\n"
        sudo dd if="$iso_path" of="$r_dev" bs=4m status=progress
        local dd_status=$?
        if [ $dd_status -eq 0 ]; then
            echo -e "\n${BOLD}${GREEN}✓ Successfully wrote ISO to $r_dev!${NC}"
            echo -e "${CYAN}Disk ejected. USB drive is ready to boot.${NC}"
            diskutil eject "$full_dev" 2>/dev/null || true
        else
            echo -e "\n${BOLD}${RED}✗ Error occurred during dd write (exit code: $dd_status)!${NC}"
        fi
        press_enter
        return $dd_status
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}Available Disks (Windows PowerShell):${NC}"
        powershell.exe -NoProfile -Command "Get-Disk | Select-Object Number, FriendlyName, BusType, @{Name='Size_GB';Expression={[math]::Round(\$_.Size / 1GB, 2)}} | Format-Table -AutoSize" 2>/dev/null
        echo -e "\n${YELLOW}Note: Direct block-level raw writing to physical drives on Windows requires elevated privileges.${NC}"
        echo -e "${CYAN}For Windows 10/11, it is highly recommended to use:${NC}"
        echo -e "  • ${BOLD}Rufus${NC} (https://rufus.ie) - Best for bootable USB creation"
        echo -e "  • ${BOLD}BalenaEtcher${NC} (https://etcher.balena.io) - Easy cross-platform image flasher"
        echo ""
        read -r -p "Press [Enter] to open Rufus download page or 'q' to return: " w_burn_opt
        if [ "$w_burn_opt" != "q" ] && [ "$w_burn_opt" != "Q" ]; then
            open_path "https://rufus.ie"
        fi
        return 0
    fi

    # Display available USB storage devices (Linux)
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

is_app_installed() {
    local bin_name="$1"
    local flatpak_id="$2"
    local mac_app_name="$3"
    local win_exe_name="$4"

    if [ -n "$bin_name" ] && command -v "$bin_name" >/dev/null 2>&1; then
        return 0
    fi
    if [ "$OS_TYPE" = "macos" ] && [ -n "$mac_app_name" ]; then
        if [ -d "/Applications/${mac_app_name}.app" ] || [ -d "$HOME/Applications/${mac_app_name}.app" ] || osascript -e "id of application \"$mac_app_name\"" >/dev/null 2>&1; then
            return 0
        fi
    fi
    if { [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; } && [ -n "$win_exe_name" ]; then
        if [ -f "/c/Program Files/${win_exe_name}" ] || [ -f "/c/Program Files (x86)/${win_exe_name}" ] || [ -f "$LOCALAPPDATA/${win_exe_name}" ]; then
            return 0
        fi
        if command -v cmd.exe >/dev/null 2>&1; then
            if [ -n "$bin_name" ] && cmd.exe /c "where $bin_name" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    if [ -n "$flatpak_id" ] && command -v flatpak >/dev/null 2>&1; then
        if flatpak info "$flatpak_id" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

launch_gui_app() {
    local app_name="$1"
    local bin_name="$2"
    local flatpak_id="$3"
    local mac_app_name="$4"
    local brew_cask="$5"
    local win_exe_name="$6"
    local winget_id="$7"

    echo -e "\n${BOLD}${YELLOW}Launching ${app_name}...${NC}\n"

    # 1. Native CLI binary in PATH (works across Linux, macOS with Homebrew, Windows with Git Bash)
    if [ -n "$bin_name" ] && command -v "$bin_name" >/dev/null 2>&1; then
        nohup "$bin_name" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ ${app_name} launched successfully.${NC}"
        sleep 1.2
        return 0
    fi

    # 2. macOS Platform Support (.app in /Applications or ~/Applications)
    if [ "$OS_TYPE" = "macos" ]; then
        if [ -n "$mac_app_name" ]; then
            if osascript -e "id of application \"$mac_app_name\"" >/dev/null 2>&1 || [ -d "/Applications/${mac_app_name}.app" ] || [ -d "$HOME/Applications/${mac_app_name}.app" ]; then
                open -a "$mac_app_name" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ ${app_name} launched (macOS App).${NC}"
                sleep 1.2
                return 0
            fi
        fi
        if [ -n "$brew_cask" ] && command -v brew >/dev/null 2>&1; then
            echo -e "${YELLOW}${app_name} is not installed.${NC}"
            read -r -p "Install ${app_name} via Homebrew now? [y/N]: " mac_inst
            if [[ "$mac_inst" =~ ^[Yy]$ ]]; then
                echo -e "${CYAN}Running: brew install --cask ${brew_cask}...${NC}"
                if brew install --cask "$brew_cask"; then
                    open -a "$mac_app_name" >/dev/null 2>&1 &
                    echo -e "${GREEN}✓ ${app_name} installed and launched!${NC}"
                    sleep 1.2
                    return 0
                else
                    echo -e "${RED}Error: Homebrew installation failed.${NC}"
                    press_enter
                    return 1
                fi
            fi
        fi
        echo -e "${RED}Error: ${app_name} is not installed!${NC}"
        press_enter
        return 1
    fi

    # 3. Windows Platform Support (Git Bash / MSYS2 / WSL)
    if [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        if [ -n "$win_exe_name" ]; then
            local win_paths=(
                "/c/Program Files/${win_exe_name}"
                "/c/Program Files (x86)/${win_exe_name}"
                "$LOCALAPPDATA/${win_exe_name}"
            )
            for p in "${win_paths[@]}"; do
                if [ -f "$p" ]; then
                    if command -v cygpath >/dev/null 2>&1; then
                        cmd.exe /c start "" "$(cygpath -w "$p")" >/dev/null 2>&1 &
                    else
                        cmd.exe /c start "" "$p" >/dev/null 2>&1 &
                    fi
                    echo -e "${GREEN}✓ ${app_name} launched (Windows).${NC}"
                    sleep 1.2
                    return 0
                fi
            done
        fi
        if [ -n "$bin_name" ] && command -v cmd.exe >/dev/null 2>&1; then
            if cmd.exe /c "where $bin_name" >/dev/null 2>&1; then
                cmd.exe /c start "" "$bin_name" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ ${app_name} launched (Windows).${NC}"
                sleep 1.2
                return 0
            fi
        fi
        if [ -n "$winget_id" ] && command -v winget.exe >/dev/null 2>&1; then
            echo -e "${YELLOW}${app_name} is not installed.${NC}"
            read -r -p "Install ${app_name} via winget now? [y/N]: " win_inst
            if [[ "$win_inst" =~ ^[Yy]$ ]]; then
                echo -e "${CYAN}Running: winget install ${winget_id}...${NC}"
                winget.exe install --id "$winget_id" -e --accept-source-agreements --accept-package-agreements
                echo -e "${GREEN}✓ Installation finished. Please re-run to launch.${NC}"
                press_enter
                return 0
            fi
        fi
        echo -e "${RED}Error: ${app_name} is not installed!${NC}"
        press_enter
        return 1
    fi

    # 4. Linux Platform Support (Flatpak / Native)
    if [ -n "$flatpak_id" ] && command -v flatpak >/dev/null 2>&1; then
        if flatpak info "$flatpak_id" >/dev/null 2>&1; then
            nohup flatpak run "$flatpak_id" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ ${app_name} launched (Flatpak).${NC}"
            sleep 1.2
            return 0
        fi
        echo -e "${YELLOW}${app_name} is not installed on this system.${NC}"
        read -r -p "Would you like to install ${app_name} via Flatpak now? [y/N]: " do_install
        if [[ "$do_install" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Installing ${flatpak_id} from Flathub...${NC}"
            if flatpak install -y --user flathub "$flatpak_id"; then
                nohup flatpak run "$flatpak_id" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ ${app_name} installed and launched!${NC}"
                sleep 1.2
                return 0
            fi
        fi
    fi

    echo -e "${RED}Error: ${app_name} is not installed!${NC}"
    press_enter
    return 1
}

launch_audacity() {
    launch_gui_app "Audacity" "audacity" "org.audacityteam.Audacity" "Audacity" "audacity" "Audacity/Audacity.exe" "Audacity.Audacity"
}

launch_or_install_picard() {
    launch_gui_app "MusicBrainz Picard" "picard" "org.musicbrainz.Picard" "MusicBrainz Picard" "musicbrainz-picard" "MusicBrainz Picard/picard.exe" "MusicBrainz.Picard"
}

launch_vlc() {
    launch_gui_app "VLC Media Player" "vlc" "org.videolan.VLC" "VLC" "vlc" "VideoLAN/VLC/vlc.exe" "VideoLAN.VLC"
}

launch_haruna() {
    launch_gui_app "Haruna Media Player" "haruna" "org.kde.haruna" "IINA" "iina" "mpv/mpv.exe" ""
}

launch_kodi() {
    launch_gui_app "Kodi" "kodi" "tv.kodi.Kodi" "Kodi" "kodi" "Kodi/kodi.exe" "XBMCFoundation.Kodi"
}

launch_strawberry() {
    launch_gui_app "Strawberry Music Player" "strawberry" "org.strawberrymusicplayer.strawberry" "Strawberry" "strawberry" "Strawberry Music Player/strawberry.exe" "JonasKvinge.Strawberry"
}

launch_gimp() {
    launch_gui_app "GIMP Image Editor" "gimp" "org.gimp.GIMP" "GIMP" "gimp" "GIMP 2/bin/gimp-2.10.exe" "GIMP.GIMP"
}

launch_electricsheep() {
    if [ -x "$HOME/.local/share/electricsheep/electricsheep.AppImage" ]; then
        nohup "$HOME/.local/share/electricsheep/electricsheep.AppImage" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Electric Sheep launched (AppImage).${NC}"
        sleep 1.2
        return 0
    fi
    launch_gui_app "Electric Sheep" "electricsheep" "" "Electric Sheep" "" "ElectricSheep/electricsheep.exe" ""
}

launch_or_install_flatpak_app() {
    local app_id="$1"
    local bin_name="$2"
    local app_name="$3"
    local mac_app_name="${4:-$app_name}"
    local brew_cask="${5:-$bin_name}"
    local win_exe="${6:-$bin_name.exe}"
    local winget_id="${7:-}"
    launch_gui_app "$app_name" "$bin_name" "$app_id" "$mac_app_name" "$brew_cask" "$win_exe" "$winget_id"
}

manage_daws() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}     DIGITAL AUDIO WORKSTATIONS (DAWs) & EDITORS    ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        local current_datetime
        current_datetime=$(date "+%A, %B %d, %Y  •  %T %Z")
        echo -e "       ${BOLD}${CYAN}📅 ${current_datetime}${NC}"
        echo ""

        local reaper_badge="${RED}[NOT INSTALLED]${NC}"
        local audacity_badge="${RED}[NOT INSTALLED]${NC}"
        local ardour_badge="${YELLOW}[AVAILABLE]${NC}"
        local lmms_badge="${YELLOW}[AVAILABLE]${NC}"
        local bitwig_badge="${YELLOW}[AVAILABLE]${NC}"
        local bespoke_badge="${YELLOW}[AVAILABLE]${NC}"

        is_app_installed "reaper" "fm.reaper.Reaper" "REAPER" "REAPER (x64)/reaper.exe" && reaper_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "audacity" "org.audacityteam.Audacity" "Audacity" "Audacity/Audacity.exe" && audacity_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "ardour" "org.ardour.Ardour" "Ardour" "Ardour/bin/ardour.exe" && ardour_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "lmms" "io.lmms.LMMS" "LMMS" "LMMS/lmms.exe" && lmms_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "bitwig-studio" "com.bitwig.BitwigStudio" "Bitwig Studio" "Bitwig Studio/bin/BitwigStudio.exe" && bitwig_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "bespokesynth" "com.bespokesynth.BespokeSynth" "BespokeSynth" "BespokeSynth/BespokeSynth.exe" && bespoke_badge="${GREEN}✓ INSTALLED${NC}"

        echo -e "${BOLD}Select a DAW or Audio Editor to launch (or install):${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Launch REAPER DAW (${reaper_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Launch Audacity Audio Editor (${audacity_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Launch / Install Ardour DAW (${ardour_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Launch / Install LMMS Studio (${lmms_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} Launch / Install Bitwig Studio (${bitwig_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}6)${NC} Launch / Install Bespoke Synth (${bespoke_badge}${NC})"
        if [ "$OS_TYPE" = "macos" ]; then
            echo -e "  ${BOLD}${CYAN}7)${NC} Launch Apple Logic Pro / GarageBand"
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            echo -e "  ${BOLD}${CYAN}7)${NC} Launch FL Studio (Image-Line)"
        fi
        echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-7]: " d_choice

        case "$d_choice" in
            1)
                launch_gui_app "REAPER" "reaper" "fm.reaper.Reaper" "REAPER" "reaper" "REAPER (x64)/reaper.exe" "Cockos.REAPER"
                ;;
            2)
                launch_audacity
                ;;
            3)
                launch_gui_app "Ardour" "ardour" "org.ardour.Ardour" "Ardour" "ardour" "Ardour/bin/ardour.exe" ""
                ;;
            4)
                launch_gui_app "LMMS" "lmms" "io.lmms.LMMS" "LMMS" "lmms" "LMMS/lmms.exe" "LMMS.LMMS"
                ;;
            5)
                launch_gui_app "Bitwig Studio" "bitwig-studio" "com.bitwig.BitwigStudio" "Bitwig Studio" "bitwig-studio" "Bitwig Studio/bin/BitwigStudio.exe" "Bitwig.BitwigStudio"
                ;;
            6)
                launch_gui_app "Bespoke Synth" "bespokesynth" "com.bespokesynth.BespokeSynth" "BespokeSynth" "bespoke-synth" "BespokeSynth/BespokeSynth.exe" ""
                ;;
            7)
                if [ "$OS_TYPE" = "macos" ]; then
                    open -a "Logic Pro" 2>/dev/null || open -a "GarageBand" 2>/dev/null || echo -e "${RED}Neither Logic Pro nor GarageBand found.${NC}"
                    sleep 1.2
                elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
                    cmd.exe /c start "" "FL64.exe" 2>/dev/null || cmd.exe /c start "" "C:\\Program Files\\Image-Line\\FL Studio 2024\\FL64.exe" 2>/dev/null || cmd.exe /c start "" "C:\\Program Files\\Image-Line\\FL Studio 21\\FL64.exe" 2>/dev/null || echo -e "${RED}FL Studio executable not found.${NC}"
                    sleep 1.2
                fi
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_audio_players() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             AUDIO PLAYERS & PLAYBACK SUITE         ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        local current_datetime
        current_datetime=$(date "+%A, %B %d, %Y  •  %T %Z")
        echo -e "       ${BOLD}${CYAN}📅 ${current_datetime}${NC}"
        echo ""

        if get_cliamp_track_info 2>/dev/null; then
            local st_badge
            case "$CLIAMP_STATE" in
                playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
                paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
                stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
                *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
            esac
            echo -e "  cliamp Player:     ${st_badge} [${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}] (${CLIAMP_PROGRESS_PCT}%)"
            echo -e "  Current Track:     ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC} - ${CLIAMP_ARTIST}"
            echo -e "  Active File Path:  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
            echo -e "  --------------------------------------------------"
        fi

        echo -e "${BOLD}Select an Audio Player to launch / manage:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} cliamp Music Player & Current Track Info (${GREEN}Now Playing Path, Controls & Launch${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Launch Strawberry Music Player (New Window) (${GREEN}strawberry${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Launch VLC Media Player (${GREEN}vlc / org.videolan.VLC${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Launch Haruna Media Player (${GREEN}org.kde.haruna${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} Launch Kodi Entertainment Center (${GREEN}tv.kodi.Kodi${NC})"
        echo -e "  ${BOLD}${CYAN}6)${NC} Show Connected USB MIDI Devices (${GREEN}list-midi-devices${NC})"
        echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-6]: " p_choice

        case "$p_choice" in
            1)
                manage_cliamp
                ;;
            2)
                launch_strawberry
                ;;
            3)
                launch_vlc
                ;;
            4)
                launch_haruna
                ;;
            5)
                launch_kodi
                ;;
            6)
                list_usb_midi_devices
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

run_bash_cli() {
    echo -e "\n${BOLD}${MAGENTA}====================================================${NC}"
    echo -e "${BOLD}${MAGENTA}             Interactive Bash CLI Runner            ${NC}"
    echo -e "${BOLD}${MAGENTA}====================================================${NC}"
    echo -e "${CYAN}Choose an option:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Open an interactive Bash shell session ${DIM}(type 'exit' to return to Manager)${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} Execute a single Bash command and return"
    echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
    echo ""
    read -r -p "Enter choice [0-2]: " cli_choice
    case "$cli_choice" in
        1)
            echo -e "\n${BOLD}${GREEN}Spawning interactive Bash subshell. Type 'exit' to return.${NC}\n"
            export PS1="\[\033[01;32m\][MixManager-CLI] \[\033[01;34m\]\w\[\033[00m\]\$ "
            bash --norc -i 2>/dev/null || bash -i
            echo -e "\n${GREEN}Returned from Bash subshell.${NC}"
            sleep 1
            ;;
        2)
            echo ""
            read -r -p "Enter Bash command to execute: " user_cmd
            if [ -n "$user_cmd" ]; then
                echo -e "\n${BOLD}${YELLOW}Executing:${NC} $user_cmd\n"
                eval "$user_cmd"
                echo ""
                press_enter
            fi
            ;;
        0|[qQ])
            return 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice!${NC}"
            sleep 1.2
            ;;
    esac
}

manage_themes() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       Themes & Color Palette Switcher              ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "  Current Active Theme: ${BOLD}${YELLOW}${CURRENT_THEME}${NC}"
        echo ""
        echo -e "  ${BOLD}${CYAN} 1)${NC} Cyberpunk     ${DIM}[Neon Hot Pink, Electric Cyan & High-Volt Yellow]${NC} $([ "$CURRENT_THEME" = "cyberpunk" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Dracula       ${DIM}[Vampiric Purple, Neon Green & Coral Pink]${NC}        $([ "$CURRENT_THEME" = "dracula" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Nord          ${DIM}[Arctic Slate, Frost Polar Ice & Sage Aurora]${NC}     $([ "$CURRENT_THEME" = "nord" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 4)${NC} The Matrix    ${DIM}[Pure Phosphor Green, Terminal Crimson & Mint]${NC}    $([ "$CURRENT_THEME" = "matrix" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Solarized     ${DIM}[Warm Amber, Solar Yellow, Cyan & Terracotta]${NC}     $([ "$CURRENT_THEME" = "solarized" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Tokyo Night   ${DIM}[Deep Violet, Lavender, Soft Blue & Coral]${NC}        $([ "$CURRENT_THEME" = "tokyo" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Monokai       ${DIM}[Electric Pink, Tangerine, Lime & Vivid Blue]${NC}     $([ "$CURRENT_THEME" = "monokai" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Gruvbox       ${DIM}[Retro Warm Earth, Dusty Rose, Rust & Gold]${NC}       $([ "$CURRENT_THEME" = "gruvbox" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Emerald Isle  ${DIM}[Deep Ocean, Spring Emerald & Mint Cyan]${NC}          $([ "$CURRENT_THEME" = "emerald" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo -e "  ${BOLD}${CYAN}10)${NC} Classic ANSI  ${DIM}[Standard 16-Color Terminal Fallback]${NC}             $([ "$CURRENT_THEME" = "classic" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
        echo ""
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu ${DIM}(or b / q)${NC}"
        echo ""
        read -r -p "Select theme [1-10, or 0 to return]: " tchoice
        case "$tchoice" in
            1)
                save_theme "cyberpunk"
                echo -e "\n${GREEN}✓ Theme switched to Cyberpunk!${NC}"
                sleep 0.8
                ;;
            2)
                save_theme "dracula"
                echo -e "\n${GREEN}✓ Theme switched to Dracula!${NC}"
                sleep 0.8
                ;;
            3)
                save_theme "nord"
                echo -e "\n${GREEN}✓ Theme switched to Nord!${NC}"
                sleep 0.8
                ;;
            4)
                save_theme "matrix"
                echo -e "\n${GREEN}✓ Theme switched to The Matrix!${NC}"
                sleep 0.8
                ;;
            5)
                save_theme "solarized"
                echo -e "\n${GREEN}✓ Theme switched to Solarized!${NC}"
                sleep 0.8
                ;;
            6)
                save_theme "tokyo"
                echo -e "\n${GREEN}✓ Theme switched to Tokyo Night!${NC}"
                sleep 0.8
                ;;
            7)
                save_theme "monokai"
                echo -e "\n${GREEN}✓ Theme switched to Monokai!${NC}"
                sleep 0.8
                ;;
            8)
                save_theme "gruvbox"
                echo -e "\n${GREEN}✓ Theme switched to Gruvbox!${NC}"
                sleep 0.8
                ;;
            9)
                save_theme "emerald"
                echo -e "\n${GREEN}✓ Theme switched to Emerald Isle!${NC}"
                sleep 0.8
                ;;
            10)
                save_theme "classic"
                echo -e "\n${GREEN}✓ Theme switched to Classic ANSI!${NC}"
                sleep 0.8
                ;;
            0|[bB]|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

# ==============================================================================
# ADVANCED SYSTEM, AUDIO, TRACKLIST & ARCHIVE UTILITIES (OPTIONS 1-14, 32)
# ==============================================================================

get_system_perf_stats() {
    local cpu_info="" ram_info="" disk_info=""
    
    # 1. CPU / Load Info
    if [ -f /proc/loadavg ]; then
        read -r l1 l5 l15 _ < /proc/loadavg
        cpu_info="${l1} (1m), ${l5} (5m)"
    elif [ "$OS_TYPE" = "macos" ]; then
        local load
        load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2, $3}')
        [ -n "$load" ] && cpu_info="${load}" || cpu_info="Active"
    else
        cpu_info="Active"
    fi

    # 2. RAM Info
    if [ -f /proc/meminfo ]; then
        local mem_total mem_avail mem_used mem_total_g mem_used_g mem_pct
        mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        mem_avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ]; then
            mem_used=$((mem_total - mem_avail))
            mem_total_g=$(awk "BEGIN {printf \"%.1f\", $mem_total/1048576}")
            mem_used_g=$(awk "BEGIN {printf \"%.1f\", $mem_used/1048576}")
            mem_pct=$(( (mem_used * 100) / mem_total ))
            ram_info="${mem_used_g}G/${mem_total_g}G (${mem_pct}%)"
        fi
    fi
    [ -z "$ram_info" ] && ram_info="Available"

    # 3. Disk Info (Mix Drive Only)
    local mix_target="$PWD"
    if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
        mix_target="$MIX_ARCHIVE_DIR"
    elif [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" ]; then
        mix_target="/run/media/$USER/WD BLACK B/MIX_ARCHIVE"
    elif [ -d "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" ]; then
        mix_target="/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"
    fi
    local d_avail="" d_pct=""
    read -r _ _ _ d_avail d_pct _ < <(df -h "$mix_target" 2>/dev/null | tail -n 1)
    if [ -n "$d_avail" ]; then
        disk_info="${d_avail} free (${d_pct} used)"
    else
        disk_info="Mounted"
    fi

    echo -e "  ${BOLD}${CYAN}⚡ CPU Load:${NC} ${cpu_info}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🧠 RAM:${NC} ${ram_info}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}💾 Mix Drive Free:${NC} ${disk_info}"
}

show_mix_drive_space() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}             MIX STORAGE DRIVE - DISK SPACE USAGE REPORT             ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    local mix_target="$PWD"
    if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
        mix_target="$MIX_ARCHIVE_DIR"
    elif [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" ]; then
        mix_target="/run/media/$USER/WD BLACK B/MIX_ARCHIVE"
    elif [ -d "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE" ]; then
        mix_target="/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE"
    fi

    echo -e "${BOLD}Target Archive Location:${NC} ${GREEN}${mix_target}${NC}\n"

    # Only show THIS drive
    local df_output
    df_output=$(df -h -T "$mix_target" 2>/dev/null || df -h "$mix_target" 2>/dev/null)
    
    echo -e "${BOLD}${CYAN}Filesystem Mount & Capacity Details (Mix Drive Only):${NC}"
    echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${NC}"
    echo "$df_output"
    echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${NC}\n"

    # Extract human readable metrics
    local line
    line=$(echo "$df_output" | tail -n 1)
    local fs type total used avail pct mount
    if [ "$(echo "$df_output" | head -n 1 | awk '{print NF}')" -ge 7 ]; then
        read -r fs type total used avail pct mount <<< "$line"
    else
        read -r fs total used avail pct mount <<< "$line"
        type="filesystem"
    fi

    echo -e "  • ${BOLD}Device Filesystem:${NC}   ${CYAN}${fs}${NC} (${type})"
    echo -e "  • ${BOLD}Mount Point:${NC}         ${GREEN}${mount}${NC}"
    echo -e "  • ${BOLD}Total Capacity:${NC}      ${total}"
    echo -e "  • ${BOLD}Space Used:${NC}          ${YELLOW}${used}${NC} (${pct})"
    echo -e "  • ${BOLD}Space Remaining:${NC}     ${BOLD}${GREEN}${avail}${NC} free\n"

    # Progress bar representation
    local pct_num
    pct_num=$(echo "$pct" | tr -dc '0-9')
    if [ -n "$pct_num" ]; then
        local bar_len=40
        local filled=$(( (pct_num * bar_len) / 100 ))
        local empty=$(( bar_len - filled ))
        local bar=""
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done
        
        local bar_color="${GREEN}"
        if [ "$pct_num" -ge 90 ]; then
            bar_color="${RED}"
        elif [ "$pct_num" -ge 75 ]; then
            bar_color="${YELLOW}"
        fi
        echo -e "  Usage: [${bar_color}${bar}${NC}] ${BOLD}${pct}${NC}\n"
    fi

    # Mix archive file counts
    local flac_count wav_count mp3_count
    flac_count=$(find "$mix_target" -maxdepth 2 -type f -name "*.flac" 2>/dev/null | wc -l)
    wav_count=$(find "$mix_target" -maxdepth 2 -type f -name "*.wav" 2>/dev/null | wc -l)
    mp3_count=$(find "$mix_target" -maxdepth 2 -type f -name "*.mp3" 2>/dev/null | wc -l)
    echo -e "${BOLD}Audio Files Hosted on Mix Drive:${NC}"
    echo -e "  • FLAC Master Mixes:   ${GREEN}${flac_count}${NC}"
    echo -e "  • Staging / Converted: ${CYAN}${wav_count}${NC} WAVs"
    echo -e "  • MP3 Deliverables:    ${YELLOW}${mp3_count}${NC} files\n"

    press_enter
}

manage_audio_conversion() {
    local script=""
    for s in "$SCRIPT_DIR/convert_audio_format.sh" "$SCRIPT_DIR/scripts/convert_audio_format.sh" "./convert_audio_format.sh"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: convert_audio_format.sh script not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                AUDIO FORMAT & BIT DEPTH CONVERTER                    ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Supported Formats: ${BOLD}MP3, Ogg Vorbis, Opus, Apple AAC, Apple ALAC, FLAC, WAV${NC}"
        echo -e "  WAV Bit Depths:    ${BOLD}32-bit Float, 32-bit Int, 24-bit PCM, 16-bit 44.1kHz PCM${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Convert Single Audio File (Interactive Selection)"
        echo -e "  ${BOLD}${CYAN}2)${NC} Convert Current Staging WAVs (in ${PWD})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Convert All WAVs in CONVERTED_WAV_FILES/"
        echo -e "  ${BOLD}${CYAN}4)${NC} Convert FLAC Outputs to MP3 (320kbps CBR) & Apple AAC"
        echo -e "  ${BOLD}${CYAN}5)${NC} WAV-to-WAV Bit Depth Conversion (16/24/32-bit Float)"
        echo -e "  ${BOLD}${CYAN}6)${NC} Launch Full Interactive Converter CLI"
        echo -e "  ${BOLD}${CYAN}7)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-7]: " conv_choice

        case "$conv_choice" in
            1)
                bash "$script" -i
                press_enter
                ;;
            2)
                bash "$script" -c
                press_enter
                ;;
            3)
                bash "$script" -w
                press_enter
                ;;
            4)
                bash "$script" -f -o mp3 -b 320k
                press_enter
                ;;
            5)
                bash "$script" -w -o wav -d 24
                press_enter
                ;;
            6)
                bash "$script"
                press_enter
                ;;
            7|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_tracklists() {
    local doc_script=""
    for s in "$SCRIPT_DIR/generate_tracklist_docs.py" "$SCRIPT_DIR/scripts/generate_tracklist_docs.py" "./generate_tracklist_docs.py"; do
        if [ -f "$s" ]; then doc_script="$s"; break; fi
    done

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                   TRACKLIST & METADATA MANAGEMENT                    ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Browse & View Tracklists (Select from Archive List)"
        echo -e "  ${BOLD}${CYAN}2)${NC} Search Tracklist by Title, Episode or Keyword"
        echo -e "  ${BOLD}${CYAN}3)${NC} View Tracklist of Currently Playing Track (cliamp)"
        echo -e "  ${BOLD}${CYAN}4)${NC} Export Tracklist to Styled HTML Document"
        echo -e "  ${BOLD}${CYAN}5)${NC} Export Tracklist to Printable PDF Document"
        echo -e "  ${BOLD}${CYAN}6)${NC} Batch Export All Archive Tracklists to HTML & PDF"
        echo -e "  ${BOLD}${CYAN}7)${NC} Scan & Generate Missing Tracklists (${GREEN}Check_Find_Tracklists.sh${NC})"
        echo -e "  ${BOLD}${CYAN}8)${NC} Generate Master Tracklist HTML Index (${GREEN}Generate_Master_Tracklist.sh${NC})"
        echo -e "  ${BOLD}${CYAN}9)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-9]: " tl_choice

        case "$tl_choice" in
            1)
                shopt -s nullglob nocaseglob
                local txt_files=("$PWD"/*.txt "$OUTPUT_DIR"/*.txt)
                shopt -u nullglob nocaseglob
                if [ ${#txt_files[@]} -eq 0 ]; then
                    echo -e "\n${YELLOW}No tracklist .txt files found in archive.${NC}"
                    press_enter
                    continue
                fi
                echo -e "\n${BOLD}${CYAN}Available Tracklists (${#txt_files[@]} found):${NC}"
                local idx=1
                local display_files=()
                for tf in "${txt_files[@]}"; do
                    local bname
                    bname=$(basename "$tf")
                    if [[ "$bname" != "requirements.txt" && "$bname" != "checksums"* ]]; then
                        printf "  %2d) %s\n" "$idx" "$bname"
                        display_files+=("$tf")
                        ((idx++))
                        if [ "$idx" -gt 35 ]; then
                            echo -e "  ${DIM}...and $(( ${#txt_files[@]} - 35 )) more (use search for specific mix)${NC}"
                            break
                        fi
                    fi
                done
                echo ""
                read -r -p "Enter number to view [1-${#display_files[@]}, or q to cancel]: " sel_idx
                if [[ "$sel_idx" =~ ^[0-9]+$ ]] && [ "$sel_idx" -ge 1 ] && [ "$sel_idx" -le "${#display_files[@]}" ]; then
                    local sel_file="${display_files[$((sel_idx - 1))]}"
                    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
                    echo -e "${BOLD}${CYAN}FILE: $(basename "$sel_file")${NC}"
                    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
                    if command -v bat >/dev/null 2>&1; then
                        bat --paging=always "$sel_file"
                    elif command -v less >/dev/null 2>&1; then
                        less -R "$sel_file"
                    else
                        cat "$sel_file"
                        press_enter
                    fi
                fi
                ;;
            2)
                read -r -p "Enter search keyword (e.g. 033, Escape, Episode): " query
                if [ -n "$query" ]; then
                    shopt -s nullglob nocaseglob
                    local matches=("$PWD"/*"$query"*.txt "$OUTPUT_DIR"/*"$query"*.txt)
                    shopt -u nullglob nocaseglob
                    if [ ${#matches[@]} -eq 0 ]; then
                        echo -e "\n${YELLOW}No tracklists matching '${query}' found.${NC}"
                        press_enter
                    else
                        echo -e "\n${BOLD}${GREEN}Matches Found:${NC}"
                        local m_idx=1
                        for m in "${matches[@]}"; do
                            printf "  %2d) %s\n" "$m_idx" "$(basename "$m")"
                            ((m_idx++))
                        done
                        read -r -p "Select file to view [1-${#matches[@]}]: " chosen
                        if [[ "$chosen" =~ ^[0-9]+$ ]] && [ "$chosen" -ge 1 ] && [ "$chosen" -le "${#matches[@]}" ]; then
                            local sel_file="${matches[$((chosen - 1))]}"
                            echo -e "\n${BOLD}${CYAN}=== TRACKLIST: $(basename "$sel_file") ===${NC}\n"
                            cat "$sel_file"
                            press_enter
                        fi
                    fi
                fi
                ;;
            3)
                if get_cliamp_track_info 2>/dev/null; then
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
                        echo -e "\n${BOLD}${CYAN}=== CURRENT TRACKLIST: $(basename "$found_tl") ===${NC}\n"
                        cat "$found_tl"
                    else
                        echo -e "\n${YELLOW}No tracklist found for current track '${CLIAMP_TITLE}'.${NC}"
                    fi
                else
                    echo -e "\n${YELLOW}cliamp is not currently running or has no track loaded.${NC}"
                fi
                press_enter
                ;;
            4)
                if [ -n "$doc_script" ]; then
                    python3 "$doc_script" -f html
                else
                    echo -e "\n${RED}Error: generate_tracklist_docs.py not found!${NC}"
                fi
                press_enter
                ;;
            5)
                if [ -n "$doc_script" ]; then
                    python3 "$doc_script" -f pdf
                else
                    echo -e "\n${RED}Error: generate_tracklist_docs.py not found!${NC}"
                fi
                press_enter
                ;;
            6)
                if [ -n "$doc_script" ]; then
                    echo -e "\n${BOLD}${YELLOW}Batch exporting all tracklists to HTML and PDF...${NC}\n"
                    python3 "$doc_script" -d "$OUTPUT_DIR" -f both
                else
                    echo -e "\n${RED}Error: generate_tracklist_docs.py not found!${NC}"
                fi
                press_enter
                ;;
            7)
                run_sub_script "Check_Find_Tracklists.sh"
                press_enter
                ;;
            8)
                run_sub_script "Generate_Master_Tracklist.sh"
                press_enter
                ;;
            9|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

search_and_play_mix() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}            SEARCH FOR MIX & AUTO-PLAY WITH LIVE TRACKLIST            ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    read -r -p "Enter mix search query (Episode #, Title, Date, Artist): " query
    if [ -z "$query" ]; then
        echo -e "\n${YELLOW}Search cancelled.${NC}"
        sleep 1
        return 0
    fi

    echo -e "\n${CYAN}Searching archive for '${query}'...${NC}"

    local search_dirs=("$OUTPUT_DIR" "$PWD" "${OUTPUT_DIR%/*}/CONVERTED_WAV_FILES" "/run/media/$USER/WD BLACK B/MIX_ARCHIVE" "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS")
    local matches=()
    local seen_names=()

    for d in "${search_dirs[@]}"; do
        if [ -d "$d" ]; then
            while IFS= read -r -d '' file; do
                local bname
                bname=$(basename "$file")
                if [[ ! " ${seen_names[*]} " =~ " ${bname} " ]]; then
                    matches+=("$file")
                    seen_names+=("$bname")
                fi
            done < <(find "$d" -maxdepth 2 -type f \( -name "*$query*.flac" -o -name "*$query*.wav" -o -name "*$query*.mp3" \) -print0 2>/dev/null)
        fi
    done

    if [ ${#matches[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}No audio mixes matching '${query}' were found in the archive.${NC}"
        press_enter
        return 0
    fi

    local selected_mix=""
    if [ ${#matches[@]} -eq 1 ]; then
        selected_mix="${matches[0]}"
        echo -e "\n${GREEN}Found 1 matching mix:${NC} $(basename "$selected_mix")"
    else
        echo -e "\n${BOLD}${CYAN}Multiple matches found (${#matches[@]} files):${NC}"
        for i in "${!matches[@]}"; do
            printf "  %2d) %s\n" "$((i + 1))" "$(basename "${matches[$i]}")"
        done
        echo ""
        read -r -p "Select mix to play [1-${#matches[@]}, or q to cancel]: " sel_idx
        if [[ "$sel_idx" =~ ^[0-9]+$ ]] && [ "$sel_idx" -ge 1 ] && [ "$sel_idx" -le "${#matches[@]}" ]; then
            selected_mix="${matches[$((sel_idx - 1))]}"
        else
            echo -e "\n${YELLOW}Selection cancelled.${NC}"
            sleep 1
            return 0
        fi
    fi

    echo -e "\n${BOLD}${YELLOW}Preparing playback for:${NC} $(basename "$selected_mix")"

    local cliamp_bin="cliamp"
    if ! command -v cliamp >/dev/null 2>&1; then
        if [ -x "$SCRIPT_DIR/bin/cliamp" ]; then
            cliamp_bin="$SCRIPT_DIR/bin/cliamp"
        elif [ -x "$HOME/.local/bin/cliamp" ]; then
            cliamp_bin="$HOME/.local/bin/cliamp"
        fi
    fi

    local is_cliamp_running=0
    if pgrep -x cliamp >/dev/null 2>&1; then
        is_cliamp_running=1
    fi

    if [ "$is_cliamp_running" -eq 1 ]; then
        echo -e "${CYAN}cliamp is already active; queuing and playing track...${NC}"
        "$cliamp_bin" queue "$selected_mix" 2>/dev/null || true
        sleep 0.4
        "$cliamp_bin" play 2>/dev/null || true
    else
        echo -e "${CYAN}Launching cliamp in a new console window...${NC}"
        local full_cmd=""$cliamp_bin" queue "$selected_mix" 2>/dev/null; "$cliamp_bin" --auto-play play 2>/dev/null || "$cliamp_bin" --auto-play"
        launch_in_terminal "cliamp - $(basename "$selected_mix")" "$full_cmd" "window"
    fi

    # Check if audio player actually started playing
    echo -e "${CYAN}Verifying playback status...${NC}"
    local started_playing=0
    for ((attempt=1; attempt<=10; attempt++)); do
        sleep 0.6
        if get_cliamp_track_info 2>/dev/null; then
            if [ "$CLIAMP_STATE" = "playing" ] || [ "$CLIAMP_RUNNING" -eq 1 ]; then
                started_playing=1
                break
            fi
        fi
    done

    if [ "$started_playing" -eq 1 ]; then
        echo -e "${BOLD}${GREEN}✓ Playback started successfully!${NC}"
        echo -e "${CYAN}Returning to manager and loading currently playing tracklist...${NC}\n"
        sleep 1.0

        # Display tracklist for the currently playing track
        local bname_no_ext
        bname_no_ext=$(basename "$selected_mix")
        bname_no_ext="${bname_no_ext%.*}"

        shopt -s nullglob nocaseglob
        local tl_candidates=(
            "${OUTPUT_DIR}/${bname_no_ext}.txt"
            "${selected_mix%.*}.txt"
            "$PWD/${bname_no_ext}.txt"
            "${OUTPUT_DIR}/"*${query}*".txt"
            "$PWD/"*${query}*".txt"
        )
        shopt -u nullglob nocaseglob

        local found_tl=""
        for tc in "${tl_candidates[@]}"; do
            if [ -f "$tc" ]; then found_tl="$tc"; break; fi
        done

        if [ -n "$found_tl" ]; then
            echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
            echo -e "${BOLD}${CYAN}           CURRENTLY PLAYING TRACKLIST: $(basename "$found_tl")      ${NC}"
            echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
            cat "$found_tl"
            echo ""
            echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
            echo -e "${DIM}Playback active in cliamp. Press [Enter] to return to Main Menu...${NC}"
            read -r
        else
            echo -e "\n${YELLOW}Track is playing, but no matching tracklist .txt file found for '${bname_no_ext}'.${NC}"
            press_enter
        fi
    else
        echo -e "\n${YELLOW}⚠️  Audio player did not start playback. Skipping tracklist view.${NC}"
        sleep 1.8
    fi
}

manage_cover_converter() {
    local script=""
    for s in "$SCRIPT_DIR/convert_cover_art.py" "$SCRIPT_DIR/scripts/convert_cover_art.py" "./convert_cover_art.py"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: convert_cover_art.py not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                   COVER ART CONVERTER & OPTIMIZER                    ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Supported Formats:  ${BOLD}JPEG, WebP, PNG, TIFF${NC}"
        echo -e "  Byte Target Modes:  ${BOLD}1MB Podcast, 500KB, 2MB, or Custom Target Size${NC}"
        echo -e "  Resolution Presets: ${BOLD}3000x3000, 1400x1400, 1080x1080, 500x500${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Optimize Cover to 1MB Podcast Standard (${GREEN}Strict <= 1MB Target${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Convert Cover to WebP Format (${GREEN}High efficiency web delivery${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Resize Cover Art (${GREEN}Square 3000x3000, 1400x1400, 1080x1080${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Custom Byte Target Compression (${GREEN}Specify any byte/KB/MB size${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} Batch Convert All Covers in COVERS/ Directory"
        echo -e "  ${BOLD}${CYAN}6)${NC} Launch Interactive Cover Converter CLI"
        echo -e "  ${BOLD}${CYAN}7)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-7]: " cover_choice

        case "$cover_choice" in
            1)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                if [ -f "$img_path" ]; then
                    python3 "$script" -i "$img_path" --bytes 1MB -f jpg
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            2)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                if [ -f "$img_path" ]; then
                    python3 "$script" -i "$img_path" -f webp -q 90
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            3)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                if [ -f "$img_path" ]; then
                    echo -e "Select resolution: 1) 3000x3000  2) 1400x1400  3) 1080x1080  4) 500x500"
                    read -r -p "Enter preset [1-4]: " res_sel
                    local res="1400x1400"
                    case "$res_sel" in
                        1) res="3000x3000" ;;
                        2) res="1400x1400" ;;
                        3) res="1080x1080" ;;
                        4) res="500x500" ;;
                    esac
                    python3 "$script" -i "$img_path" -r "$res"
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            4)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                read -r -p "Enter target max size (e.g. 500KB, 1MB, 2.5MB): " target_sz
                [ -z "$target_sz" ] && target_sz="1MB"
                if [ -f "$img_path" ]; then
                    python3 "$script" -i "$img_path" --bytes "$target_sz"
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            5)
                local cov_dir="$PWD/COVERS"
                [ ! -d "$cov_dir" ] && cov_dir="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/COVERS"
                if [ -d "$cov_dir" ]; then
                    echo -e "\n${BOLD}${YELLOW}Batch converting covers in: $cov_dir${NC}\n"
                    python3 "$script" -d "$cov_dir" --bytes 1MB -f jpg
                else
                    echo -e "\n${YELLOW}COVERS directory not found.${NC}"
                fi
                press_enter
                ;;
            6)
                python3 "$script" -h
                echo ""
                read -r -p "Enter custom arguments for convert_cover_art.py: " custom_args
                if [ -n "$custom_args" ]; then
                    python3 "$script" $custom_args
                fi
                press_enter
                ;;
            7|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

find_duplicate_audio_mixes() {
    local script=""
    for s in "$SCRIPT_DIR/find_duplicate_mixes.py" "$SCRIPT_DIR/scripts/find_duplicate_mixes.py" "./find_duplicate_mixes.py"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: find_duplicate_mixes.py not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             DUPLICATE AUDIO FILE DETECTOR & CLEANER                  ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Detects exact binary duplicates and multiple renders across:"
        echo -e "  • ${CYAN}FLAC_CONVERTED_OUTPUTS/${NC}"
        echo -e "  • ${CYAN}CONVERTED_WAV_FILES/${NC}"
        echo -e "  • ${CYAN}Current staging directory (${PWD})${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Scan & Generate Duplicate Mixes Report (${GREEN}Safe: Read Only${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Move Duplicates to Quarantine Directory (${YELLOW}DUPLICATES_QUARANTINE/${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Permanently Remove Duplicates (${RED}Prompt with safety confirmation${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Custom Directory Scan"
        echo -e "  ${BOLD}${CYAN}5)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-5]: " dup_choice

        case "$dup_choice" in
            1)
                echo -e "\n${BOLD}${YELLOW}Scanning archive for duplicate mixes...${NC}\n"
                python3 "$script" --action report
                press_enter
                ;;
            2)
                echo -e "\n${BOLD}${YELLOW}Scanning and moving duplicates to quarantine...${NC}\n"
                python3 "$script" --action quarantine
                press_enter
                ;;
            3)
                echo -e "\n${BOLD}${RED}⚠️  WARNING: DELETION REQUESTED ⚠️${NC}\n"
                read -r -p "Are you sure you want to permanently delete duplicate files? [y/N]: " del_confirm
                case "$del_confirm" in
                    [yY]|[yY][eE][sS])
                        python3 "$script" --action delete
                        ;;
                    *)
                        echo -e "\n${GREEN}Deletion cancelled.${NC}"
                        ;;
                esac
                press_enter
                ;;
            4)
                read -r -p "Enter directory path to scan for duplicates: " custom_dir
                if [ -d "$custom_dir" ]; then
                    python3 "$script" -d "$custom_dir" --action report
                else
                    echo -e "\n${RED}Directory not found: $custom_dir${NC}"
                fi
                press_enter
                ;;
            5|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

export_mixes_to_path() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                 EXPORT & COPY MIXES TO DESTINATION                   ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    read -r -p "Enter destination path (e.g. /media/USB_DRIVE/Mixes, ~/Music/Export): " dest_dir
    if [ -z "$dest_dir" ]; then
        echo -e "\n${YELLOW}Export cancelled.${NC}"
        sleep 1
        return 0
    fi

    dest_dir="${dest_dir/#\~/$HOME}"

    if [ ! -d "$dest_dir" ]; then
        echo -e "${YELLOW}Destination directory does not exist.${NC}"
        read -r -p "Create directory '${dest_dir}'? [Y/n]: " create_dir
        case "$create_dir" in
            [nN]*)
                echo -e "\n${YELLOW}Export cancelled.${NC}"
                sleep 1
                return 0
                ;;
            *)
                mkdir -p "$dest_dir" || { echo -e "${RED}Failed to create directory!${NC}"; press_enter; return 1; }
                echo -e "${GREEN}✓ Created directory: ${dest_dir}${NC}\n"
                ;;
        esac
    fi

    echo -e "${BOLD}Select items to export:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Complete Mix Package (FLAC + Cover Art + Tracklists TXT/HTML/PDF + Spek)"
    echo -e "  ${BOLD}${CYAN}2)${NC} Audio Files Only (FLAC / WAV / MP3)"
    echo -e "  ${BOLD}${CYAN}3)${NC} Tracklists & Documentation Only (.txt, .html, .pdf)"
    echo -e "  ${BOLD}${CYAN}4)${NC} Cover Art & Spectrograms Only"
    echo -e "  ${BOLD}${CYAN}5)${NC} Specific Mix by Search Keyword"
    echo -e "  ${BOLD}${CYAN}6)${NC} Cancel Export\n"
    read -r -p "Enter choice [1-6]: " exp_choice

    case "$exp_choice" in
        1)
            echo -e "\n${BOLD}${YELLOW}Exporting complete packages to: ${dest_dir}...${NC}\n"
            if [ -d "$OUTPUT_DIR" ]; then
                rsync -avh --progress "$OUTPUT_DIR"/*.flac "$dest_dir/" 2>/dev/null || true
                rsync -avh "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.html "$OUTPUT_DIR"/*.pdf "$dest_dir/" 2>/dev/null || true
            fi
            if [ -d "$PWD/COVERS" ]; then
                rsync -avh "$PWD/COVERS/" "$dest_dir/COVERS/" 2>/dev/null || true
            fi
            if [ -d "$PWD/SPEK_OUTPUTS" ]; then
                rsync -avh "$PWD/SPEK_OUTPUTS/" "$dest_dir/SPEK_OUTPUTS/" 2>/dev/null || true
            fi
            echo -e "\n${BOLD}${GREEN}✓ Complete mix package export finished.${NC}"
            ;;
        2)
            echo -e "\n${BOLD}${YELLOW}Exporting audio files to: ${dest_dir}...${NC}\n"
            if [ -d "$OUTPUT_DIR" ]; then
                rsync -avh --progress "$OUTPUT_DIR"/*.flac "$dest_dir/" 2>/dev/null || true
            fi
            rsync -avh --progress "$PWD"/*.flac "$PWD"/*.wav "$PWD"/*.mp3 "$dest_dir/" 2>/dev/null || true
            echo -e "\n${BOLD}${GREEN}✓ Audio file export finished.${NC}"
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Exporting tracklists and documentation to: ${dest_dir}...${NC}\n"
            rsync -avh "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.html "$OUTPUT_DIR"/*.pdf "$dest_dir/" 2>/dev/null || true
            rsync -avh "$PWD"/*.txt "$PWD"/*.html "$PWD"/*.pdf "$dest_dir/" 2>/dev/null || true
            echo -e "\n${BOLD}${GREEN}✓ Tracklist documentation export finished.${NC}"
            ;;
        4)
            echo -e "\n${BOLD}${YELLOW}Exporting cover art and spectrograms to: ${dest_dir}...${NC}\n"
            [ -d "$PWD/COVERS" ] && rsync -avh "$PWD/COVERS/" "$dest_dir/COVERS/" 2>/dev/null || true
            [ -d "$PWD/SPEK_OUTPUTS" ] && rsync -avh "$PWD/SPEK_OUTPUTS/" "$dest_dir/SPEK_OUTPUTS/" 2>/dev/null || true
            [ -f "$PWD/Cover.png" ] && cp -v "$PWD/Cover.png" "$dest_dir/" 2>/dev/null || true
            echo -e "\n${BOLD}${GREEN}✓ Visual assets export finished.${NC}"
            ;;
        5)
            read -r -p "Enter mix search term (Episode #, Title): " mix_kw
            if [ -n "$mix_kw" ]; then
                echo -e "\n${BOLD}${YELLOW}Exporting matching assets for '${mix_kw}' to: ${dest_dir}...${NC}\n"
                find "$OUTPUT_DIR" "$PWD" -maxdepth 2 -type f -iname "*${mix_kw}*" -exec cp -v {} "$dest_dir/" \; 2>/dev/null
                echo -e "\n${BOLD}${GREEN}✓ Matching mix assets exported.${NC}"
            fi
            ;;
        *)
            echo -e "\n${YELLOW}Export cancelled.${NC}"
            sleep 1
            return 0
            ;;
    esac
    press_enter
}

manage_audio_checksums() {
    local script=""
    for s in "$SCRIPT_DIR/manage_checksums.sh" "$SCRIPT_DIR/scripts/manage_checksums.sh" "./manage_checksums.sh"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: manage_checksums.sh not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             AUDIO FILE CHECKSUM CREATION & VERIFICATION              ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Cryptographic SHA-256 integrity protection for master mix files.\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Generate SHA-256 Checksums for FLAC Master Mixes (${GREEN}FLAC_CONVERTED_OUTPUTS${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Generate SHA-256 Checksums for Current Staging Directory (${GREEN}${PWD}${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Verify Archive Checksums & Detect Corruption (${GREEN}Verify against checksums.sha256${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} View Checksum Manifest File (${CYAN}checksums.sha256${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} View Historical Verification Logs (${CYAN}VERIFY_LOGS/${NC})"
        echo -e "  ${BOLD}${CYAN}6)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-6]: " cs_choice

        case "$cs_choice" in
            1)
                bash "$script" -g -d "$OUTPUT_DIR"
                press_enter
                ;;
            2)
                bash "$script" -g -d "$PWD"
                press_enter
                ;;
            3)
                bash "$script" -v
                press_enter
                ;;
            4)
                if [ -f "$PWD/checksums.sha256" ]; then
                    echo -e "\n${BOLD}${CYAN}=== CHECKSUMS MANIFEST ($PWD/checksums.sha256) ===${NC}\n"
                    head -n 40 "$PWD/checksums.sha256"
                elif [ -f "$OUTPUT_DIR/checksums.sha256" ]; then
                    echo -e "\n${BOLD}${CYAN}=== CHECKSUMS MANIFEST ($OUTPUT_DIR/checksums.sha256) ===${NC}\n"
                    head -n 40 "$OUTPUT_DIR/checksums.sha256"
                else
                    echo -e "\n${YELLOW}No checksums.sha256 manifest found. Generate one first with Option 1 or 2.${NC}"
                fi
                press_enter
                ;;
            5)
                local log_dir="$PWD/VERIFY_LOGS"
                if [ -d "$log_dir" ] && [ "$(ls -A "$log_dir" 2>/dev/null)" ]; then
                    echo -e "\n${BOLD}${CYAN}Verification Logs in $log_dir:${NC}"
                    ls -lh "$log_dir"
                else
                    echo -e "\n${YELLOW}No verification logs found in VERIFY_LOGS/.${NC}"
                fi
                press_enter
                ;;
            6|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

reboot_system() {
    echo -e "\n${BOLD}${RED}⚠️  SYSTEM REBOOT REQUESTED ⚠️${NC}\n"
    echo -e "${YELLOW}Are you sure you want to reboot the system?${NC}"
    read -r -p "Type 'yes' or 'y' to confirm reboot [y/N]: " confirm_reboot
    case "$confirm_reboot" in
        [yY]|[yY][eE][sS])
            echo -e "\n${BOLD}${RED}Rebooting system now... Goodbye!${NC}\n"
            sleep 1.5
            if [ "$OS_TYPE" = "macos" ]; then
                osascript -e 'tell app "System Events" to restart' 2>/dev/null || sudo shutdown -r now || shutdown -r now
            elif [ "$OS_TYPE" = "windows" ]; then
                shutdown.exe /r /t 0 2>/dev/null || shutdown /r /t 0
            elif [ "$OS_TYPE" = "wsl" ]; then
                cmd.exe /c shutdown /r /t 0 2>/dev/null || wsl.exe --shutdown
            else
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl reboot || sudo reboot || reboot
                else
                    sudo reboot || reboot
                fi
            fi
            ;;
        *)
            echo -e "\n${GREEN}Reboot cancelled.${NC}"
            sleep 1.2
            ;;
    esac
}

get_os_badge() {
    if [ "$OS_TYPE" = "macos" ]; then
        local mac_ver
        mac_ver=$(sw_vers -productVersion 2>/dev/null || uname -r)
        echo -e "${BOLD}${CYAN}🍏 macOS:${NC} ${mac_ver} ($(uname -m))"
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        local win_ver=""
        if command -v cmd.exe >/dev/null 2>&1; then
            win_ver=$(cmd.exe /c ver 2>/dev/null | tr -d '\r\n' | sed 's/.*\[Version \([^]]*\)\].*/\1/')
        fi
        [ -z "$win_ver" ] && win_ver="$(uname -r)"
        if [ "$OS_TYPE" = "wsl" ]; then
            echo -e "${BOLD}${CYAN}🪟 Windows (WSL2):${NC} ${win_ver}"
        else
            echo -e "${BOLD}${CYAN}🪟 Windows:${NC} ${win_ver}"
        fi
    else
        echo -e "${BOLD}${CYAN}🐧 Kernel:${NC} $(uname -r)"
    fi
}

# ==============================================================================
# MAIN APPLICATION LOOP
# ==============================================================================

while true; do
    clear
    echo -e "${BOLD}${MAGENTA}===================================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                     Mix Archive Manager (MP_Mix_Manager_v0.1)                     ${NC}"
    echo -e "${BOLD}${MAGENTA}===================================================================================${NC}"
    os_badge=$(get_os_badge)
    shell_info="Bash ${BASH_VERSION%%(*}"
    current_datetime=$(date "+%A, %B %d, %Y • %T %Z")
    echo -e "  ${os_badge}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🐚 Shell:${NC} ${shell_info}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}📅 Date:${NC} ${current_datetime}"
    sys_perf=$(get_system_perf_stats)
    echo -e "${sys_perf}"
    echo -e "${BOLD}${MAGENTA}-----------------------------------------------------------------------------------${NC}"
    echo ""
    
    show_stats
    
    echo ""
    echo -e "${BOLD}Select an operation:${NC}"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 1: MIX ARCHIVE WORKFLOW & INGESTION ] ─────────${NC}"
    echo -e "  ${BOLD}${CYAN} 1)${NC} Run FLAC Conversion Process (${GREEN}Make_SOF_FLAC_CONVERSION.sh${NC})"
    echo -e "  ${BOLD}${CYAN} 2)${NC} Convert Audio Formats & Bit Depths (${GREEN}WAV to MP3, OGG, AAC, ALAC, WAV 32/24/16${NC})"
    echo -e "  ${BOLD}${CYAN} 3)${NC} Retrieve Unconverted WAVs from Archive (${GREEN}MOVE_NOT_CONVERTED_WAVS.sh${NC})"
    echo -e "  ${BOLD}${CYAN} 4)${NC} Import New Mixes from SMB Share (${GREEN}import_new_mixes.sh${NC})"
    echo -e "  ${BOLD}${CYAN} 5)${NC} Rename a Mix and Associated Assets (FLAC, Tracklist, Spek)"
    echo -e "  ${BOLD}${CYAN} 6)${NC} Find & Remove Duplicate Audio Files / Mixes (${GREEN}Exact Content & Episode Match${NC})"
    echo -e "  ${BOLD}${CYAN} 7)${NC} Export / Copy Mixes to Specified Path (${GREEN}Audio, Covers, Tracklists, Spek${NC})"
    echo -e "  ${BOLD}${CYAN} 8)${NC} Manage Audio Integrity Checksums (${GREEN}SHA-256 Manifest & Verification${NC})"
    echo -e "  ${BOLD}${CYAN} 9)${NC} Verify FLAC Files for Integrity & Corruption (${GREEN}Verify_FLAC_Files.sh${NC})"
    echo -e "  ${BOLD}${CYAN}10)${NC} Back up FLAC Outputs to Google Drive (${GREEN}backup_to_gdrive.sh${NC})"
    echo -e "  ${BOLD}${CYAN}11)${NC} Show Mix Storage Drive Space Remaining (${GREEN}Mix Drive Only${NC})"
    echo -e "  ${BOLD}${CYAN}12)${NC} Refresh Archive Status & File Counts (Rescan WAVs, FLACs & Tracklists)"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 2: TRACKLIST & METADATA MANAGEMENT ] ──────────${NC}"
    echo -e "  ${BOLD}${CYAN}13)${NC} Tracklist Management Suite (${GREEN}Browse, Search, View, Export HTML & PDF${NC})"
    echo -e "  ${BOLD}${CYAN}14)${NC} Search for Mix & Auto-Play with Live Tracklist View (${GREEN}cliamp Window${NC})"
    echo -e "  ${BOLD}${CYAN}15)${NC} Scan & Generate Missing Tracklists (${GREEN}Check_Find_Tracklists.sh${NC})"
    echo -e "  ${BOLD}${CYAN}16)${NC} Generate Master Tracklist HTML Index (${GREEN}Generate_Master_Tracklist.sh${NC})"
    echo -e "  ${BOLD}${CYAN}17)${NC} Launch MusicBrainz Picard Meta Tag Editor (${GREEN}Auto-install if missing${NC})"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 3: AUDIO PLAYBACK, DAWS & SOUND SUITE ] ───────${NC}"
    echo -e "  ${BOLD}${CYAN}18)${NC} Digital Audio Workstations (DAWs) Menu (${GREEN}Reaper, Ardour, LMMS, Bitwig...${NC})"
    echo -e "  ${BOLD}${CYAN}19)${NC} Launch Audacity Audio Editor (${GREEN}audacity${NC})"
    echo -e "  ${BOLD}${CYAN}20)${NC} Launch Audio Players Menu (${GREEN}cliamp, Strawberry, VLC, Haruna, Kodi${NC})"
    echo -e "  ${BOLD}${CYAN}21)${NC} cliamp Music Player & Track Control (${GREEN}Now Playing Path, Controls & Launch${NC})"
    echo -e "  ${BOLD}${CYAN}22)${NC} Launch Strawberry Music Player (New Window) (${GREEN}strawberry${NC})"
    echo -e "  ${BOLD}${CYAN}23)${NC} Launch VLC Media Player (${GREEN}vlc / org.videolan.VLC${NC})"
    echo -e "  ${BOLD}${CYAN}24)${NC} Launch Haruna Media Player (${GREEN}org.kde.haruna${NC})"
    echo -e "  ${BOLD}${CYAN}25)${NC} Launch Kodi Entertainment Center (${GREEN}tv.kodi.Kodi${NC})"
    echo -e "  ${BOLD}${CYAN}26)${NC} Show Connected USB MIDI Devices (${GREEN}list-midi-devices${NC})"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 4: VIDEO PRODUCTION, ART & VISUAL MEDIA ] ─────${NC}"
    echo -e "  ${BOLD}${CYAN}27)${NC} Generate 1080p YouTube Video (${GREEN}Make_SOF_Episode_From_PNG_FLAC_Output_MP4_1080p_Video.sh${NC})"
    echo -e "  ${BOLD}${CYAN}28)${NC} Cut Video File (.mp4 / .mkv) (${GREEN}Cut_Video.sh${NC})"
    echo -e "  ${BOLD}${CYAN}29)${NC} Launch Video Playlists (NFT Videos (VLC))"
    echo -e "  ${BOLD}${CYAN}30)${NC} Launch VLC Video Player (${GREEN}vlc${NC})"
    echo -e "  ${BOLD}${CYAN}31)${NC} Launch GIMP Image Editor (${GREEN}gimp / org.gimp.GIMP${NC})"
    echo -e "  ${BOLD}${CYAN}32)${NC} Convert Cover Art & Resize / Byte Target (${GREEN}1MB Podcast, WebP/JPG/PNG, Sizes${NC})"
    echo -e "  ${BOLD}${CYAN}33)${NC} View Cover Art by Mix Number (External Viewer)"
    echo -e "  ${BOLD}${CYAN}34)${NC} Launch Electric Sheep Generative Screensaver (${GREEN}electricsheep / infinidream${NC})"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 5: LIVE MONITORS & SYSTEM DIAGNOSTICS ] ───────${NC}"
    echo -e "  ${BOLD}${CYAN}35)${NC} Launch Live Tracklist Monitor (${GREEN}SOF_Live_Tracker.sh${NC})"
    echo -e "  ${BOLD}${CYAN}36)${NC} Launch Live File Transfer Monitor (${GREEN}transfer-monitor${NC})"
    echo -e "  ${BOLD}${CYAN}37)${NC} Launch Chrome Upload Monitor (${GREEN}Podcast Connect / Web Uploads${NC})"
    echo -e "  ${BOLD}${CYAN}38)${NC} View Advanced Archive Statistics (${GREEN}SOF_Archive_Stats.sh${NC})"
    echo -e "  ${BOLD}${CYAN}39)${NC} View Running Background Tasks"
    echo -e "  ${BOLD}${CYAN}40)${NC} Launch Resource Monitor (${GREEN}btop${NC})"
    echo -e "  ${BOLD}${CYAN}41)${NC} Launch GPU Process Monitor (${GREEN}nvtop${NC})"
    echo -e "  ${BOLD}${CYAN}42)${NC} Launch System Process Monitor (${GREEN}top${NC})"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 6: SYSTEM, NETWORK & HARDWARE MANAGEMENT ] ────${NC}"
    echo -e "  ${BOLD}${CYAN}43)${NC} Manage WAN2GP Server (Start, Stop, Restart in Profile 2 or 4.5)"
    echo -e "  ${BOLD}${CYAN}44)${NC} Manage Network Services (SSH, Samba, FTP - Start, Stop, Restart All)"
    echo -e "  ${BOLD}${CYAN}45)${NC} Block Internet Access (LAN Only) (${GREEN}block-internet${NC})"
    echo -e "  ${BOLD}${CYAN}46)${NC} Restore / Unblock Internet Access (${GREEN}unblock-internet${NC})"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "  ${BOLD}${CYAN}47)${NC} Open macOS Display Settings (${GREEN}Displays, Arrangement & HDR${NC})"
        echo -e "  ${BOLD}${CYAN}48)${NC} Open macOS Audio MIDI Setup (${GREEN}Sample Rates & Output Devices${NC})"
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "  ${BOLD}${CYAN}47)${NC} Open Windows Display Settings (${GREEN}ms-settings:display - HDR & Scale${NC})"
        echo -e "  ${BOLD}${CYAN}48)${NC} Open Windows Sound Settings (${GREEN}control.exe mmsys.cpl${NC})"
    else
        echo -e "  ${BOLD}${CYAN}47)${NC} Switch Desktop to Plasma Wayland (HDR Gaming on Hisense & Steam BPM)"
        echo -e "  ${BOLD}${CYAN}48)${NC} Switch Desktop to Plasma X11 (Workstation 4-Screen Defasten)"
    fi
    echo -e "  ${BOLD}${CYAN}49)${NC} Close All Desktop Applications (Keep Manager Open)"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "  ${BOLD}${CYAN}50)${NC} macOS System Maintenance & Cleanup (${GREEN}brew cleanup, purge RAM, caches${NC})"
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "  ${BOLD}${CYAN}50)${NC} Windows System Maintenance & Cleanup (${GREEN}winget upgrade, clean temp, TRIM${NC})"
    else
        echo -e "  ${BOLD}${CYAN}50)${NC} Bazzite System Maintenance & Cleanup (${GREEN}ujust clean-system, update, trim, logs${NC})"
    fi
    echo -e "  ${BOLD}${CYAN}51)${NC} Launch GeeXLab Demo Launcher (${GREEN}FurMark_linux64/demo_launcher.sh${NC})"
    echo -e "  ${BOLD}${CYAN}52)${NC} Burn ISO Image to USB Drive (${GREEN}dd / diskutil with safety checks${NC})"
    
    echo -e "\n  ${BOLD}${BLUE}─── [ SECTION 7: AI, SHELL CLI & SETTINGS ] ──────────────────${NC}"
    echo -e "  ${BOLD}${CYAN}53)${NC} Launch AI Assistant / Models (${GREEN}Claude Opus, Claude Sonnet, GPT-OSS, Gemini${NC})"
    echo -e "  ${BOLD}${CYAN}54)${NC} Run Bash CLI Commands (${GREEN}Interactive Shell & Direct Runner${NC})"
    echo -e "  ${BOLD}${CYAN}55)${NC} Manager Themes & Color Palette Switcher (${GREEN}8 Themes + Classic${NC})"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "  ${BOLD}${CYAN}56)${NC} Reboot System (${RED}macOS restart with confirmation${NC})"
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "  ${BOLD}${CYAN}56)${NC} Reboot System (${RED}Windows restart with confirmation${NC})"
    else
        echo -e "  ${BOLD}${CYAN}56)${NC} Reboot System (${RED}systemctl reboot with confirmation${NC})"
    fi
    
    echo -e "\n  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN}57)${NC} Exit Manager ${DIM}(or 0 / q)${NC}"
    echo ""
    read -r -p "Enter choice [1-57, or q to exit]: " choice
    
    case $choice in
        1)
            echo -e "\n${BOLD}${YELLOW}Starting FLAC Conversion...${NC}\n"
            run_sub_script "Make_SOF_FLAC_CONVERSION.sh"
            press_enter
            ;;
        2)
            manage_audio_conversion
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Retrieving unconverted WAV files...${NC}\n"
            run_sub_script "MOVE_NOT_CONVERTED_WAVS.sh"
            press_enter
            ;;
        4)
            echo -e "\n${BOLD}${YELLOW}Starting SMB Import Process...${NC}\n"
            run_sub_script "import_new_mixes.sh"
            press_enter
            ;;
        5)
            rename_mix
            press_enter
            ;;
        6)
            find_duplicate_audio_mixes
            ;;
        7)
            export_mixes_to_path
            ;;
        8)
            manage_audio_checksums
            ;;
        9)
            echo -e "\n${BOLD}${YELLOW}Starting FLAC File Integrity Scan...${NC}\n"
            run_sub_script "Verify_FLAC_Files.sh"
            press_enter
            ;;
        10)
            echo -e "\n${BOLD}${YELLOW}Starting Google Drive Backup...${NC}\n"
            run_sub_script "backup_to_gdrive.sh"
            press_enter
            ;;
        11)
            show_mix_drive_space
            ;;
        12)
            # Loop will naturally clear screen and refresh status
            ;;
        13)
            manage_tracklists
            ;;
        14)
            search_and_play_mix
            ;;
        15)
            echo -e "\n${BOLD}${YELLOW}Scanning & Generating Missing Tracklists...${NC}\n"
            run_sub_script "Check_Find_Tracklists.sh"
            press_enter
            ;;
        16)
            echo -e "\n${BOLD}${YELLOW}Starting Master Tracklist HTML Generation...${NC}\n"
            run_sub_script "Generate_Master_Tracklist.sh"
            press_enter
            ;;
        17)
            launch_or_install_picard
            ;;
        18)
            manage_daws
            ;;
        19)
            launch_audacity
            ;;
        20)
            manage_audio_players
            ;;
        21)
            manage_cliamp
            ;;
        22)
            launch_strawberry
            ;;
        23)
            launch_vlc
            ;;
        24)
            launch_haruna
            ;;
        25)
            launch_kodi
            ;;
        26)
            list_usb_midi_devices
            ;;
        27)
            generate_youtube_video
            press_enter
            ;;
        28)
            cut_video_clip
            press_enter
            ;;
        29)
            launch_video_playlists
            ;;
        30)
            launch_vlc
            ;;
        31)
            launch_gimp
            ;;
        32)
            manage_cover_converter
            ;;
        33)
            view_cover
            press_enter
            ;;
        34)
            launch_electricsheep
            ;;
        35)
            echo -e "\n${BOLD}${YELLOW}Launching Live Tracklist Monitor (Press Ctrl+C to return to menu)...${NC}\n"
            sleep 1
            trap ':' INT
            run_sub_script "SOF_Live_Tracker.sh"
            trap - INT
            press_enter
            ;;
        36)
            echo -e "\n${BOLD}${YELLOW}Launching Live File Transfer Monitor (Press Ctrl+C to return to menu)...${NC}\n"
            sleep 1
            trap ':' INT
            if command -v transfer-monitor >/dev/null 2>&1; then
                transfer-monitor
            elif [ -x "$HOME/.local/bin/transfer-monitor" ]; then
                "$HOME/.local/bin/transfer-monitor"
            else
                echo -e "${RED}Error: transfer-monitor command not found in PATH or ~/.local/bin!${NC}"
            fi
            trap - INT
            press_enter
            ;;
        37)
            echo -e "\n${BOLD}${YELLOW}Launching Chrome Upload Monitor (Press Ctrl+C to return to menu)...${NC}\n"
            sleep 1
            trap ':' INT
            if command -v chrome-upload-monitor >/dev/null 2>&1; then
                chrome-upload-monitor
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
                echo -e "${RED}Error: chrome-upload-monitor command not found in PATH or ~/.local/bin!${NC}"
            fi
            trap - INT
            press_enter
            ;;
        38)
            echo -e "\n${BOLD}${YELLOW}Loading Advanced Archive Statistics...${NC}\n"
            sleep 0.5
            run_sub_script "SOF_Archive_Stats.sh"
            press_enter
            ;;
        39)
            view_tasks
            press_enter
            ;;
        40)
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
        41)
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
        42)
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
        43)
            manage_wan2gp
            ;;
        44)
            manage_network_services
            ;;
        45)
            block_internet
            ;;
        46)
            unblock_internet
            ;;
        47)
            switch_to_wayland
            ;;
        48)
            switch_to_x11
            ;;
        49)
            close_all_desktop_apps
            ;;
        50)
            manage_system_maintenance
            ;;
        51)
            launch_geexlab_demos
            ;;
        52)
            burn_iso_to_usb
            ;;
        53)
            manage_ai_models
            ;;
        54)
            run_bash_cli
            ;;
        55)
            manage_themes
            ;;
        56)
            reboot_system
            ;;
        57|0|[qQ]|[eE][xX][iI][tT])
            echo -e "\n${BOLD}${GREEN}Exiting Mix Archive Manager. Goodbye!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid option! Please enter a number between 1 and 57 (or 'q' to exit).${NC}"
            sleep 2
            ;;
    esac
done
