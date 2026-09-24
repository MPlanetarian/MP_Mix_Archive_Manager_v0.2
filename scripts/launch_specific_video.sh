#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Dedicated Video Player Launcher & Video Dispatcher
# Launches specific video files or streaming URLs in the default video player (VLC).
# Allows configuring startup custom YouTube video URL autoplay.
# ==============================================================================

set -o pipefail 2>/dev/null || true

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")/.." >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

# Load configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
fi

DEFAULT_VIDEO_PLAYER="${DEFAULT_VIDEO_PLAYER:-vlc}"
AUTO_PLAY_YOUTUBE_ON_STARTUP="${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}"
STARTUP_YOUTUBE_URL="${STARTUP_YOUTUBE_URL:-}"

save_config_setting() {
    local key="$1"
    local val="$2"
    local cfg_file="$SCRIPT_DIR/config.env"
    [ ! -f "$cfg_file" ] && cfg_file="$PWD/config.env"

    python3 -c "
import sys, re
key = sys.argv[1]
val = sys.argv[2]
path = sys.argv[3]
try:
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    pat = rf'^[ \t]*{re.escape(key)}=.*$'
    replacement = f'{key}=\"{val}\"'
    if re.search(pat, c, flags=re.MULTILINE):
        new_c = re.sub(pat, replacement, c, flags=re.MULTILINE)
    else:
        new_c = c.rstrip() + f'\n{replacement}\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_c)
except Exception:
    pass
" "$key" "$val" "$cfg_file" 2>/dev/null || true
}

dispatch_video() {
    local target="$1"
    [ -z "$target" ] && return 1

    echo -e "\n${BOLD}${CYAN}Dispatching video to ${GREEN}${DEFAULT_VIDEO_PLAYER}${NC}:"
    echo -e "  • ${WHITE}${target}${NC}\n"

    case "$DEFAULT_VIDEO_PLAYER" in
        vlc)
            if command -v vlc >/dev/null 2>&1; then
                vlc "$target" >/dev/null 2>&1 &
            elif command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "org.videolan.VLC"; then
                flatpak run org.videolan.VLC "$target" >/dev/null 2>&1 &
            elif [ "$(uname -s)" = "Darwin" ]; then
                open -a "VLC" "$target" >/dev/null 2>&1 &
            else
                xdg-open "$target" >/dev/null 2>&1 &
            fi
            ;;
        mpv)
            if command -v mpv >/dev/null 2>&1; then
                mpv "$target" >/dev/null 2>&1 &
            elif command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "io.mpv.Mpv"; then
                flatpak run io.mpv.Mpv "$target" >/dev/null 2>&1 &
            else
                xdg-open "$target" >/dev/null 2>&1 &
            fi
            ;;
        haruna)
            if command -v haruna >/dev/null 2>&1; then
                haruna "$target" >/dev/null 2>&1 &
            elif command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "org.kde.haruna"; then
                flatpak run org.kde.haruna "$target" >/dev/null 2>&1 &
            else
                xdg-open "$target" >/dev/null 2>&1 &
            fi
            ;;
        kodi)
            if command -v kodi >/dev/null 2>&1; then
                kodi "$target" >/dev/null 2>&1 &
            elif command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi"; then
                flatpak run tv.kodi.Kodi "$target" >/dev/null 2>&1 &
            else
                xdg-open "$target" >/dev/null 2>&1 &
            fi
            ;;
        *)
            if command -v "$DEFAULT_VIDEO_PLAYER" >/dev/null 2>&1; then
                "$DEFAULT_VIDEO_PLAYER" "$target" >/dev/null 2>&1 &
            else
                xdg-open "$target" >/dev/null 2>&1 &
            fi
            ;;
    esac

    echo -e "${GREEN}✓ Video playback started in background!${NC}"
    sleep 1.2
}

manage_video_menu() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}               🎬 DEDICATED VIDEO PLAYER & DISPATCHER                 ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  • ${BOLD}Default Video Player:${NC}        ${BOLD}${GREEN}${DEFAULT_VIDEO_PLAYER}${NC}"
        local yt_badge="${RED}DISABLED${NC}"
        [ "$AUTO_PLAY_YOUTUBE_ON_STARTUP" = "true" ] && yt_badge="${GREEN}ENABLED${NC}"
        echo -e "  • ${BOLD}Startup YouTube Autoplay:${NC}    ${yt_badge} (Plays only when mix audio is active)"
        if [ -n "$STARTUP_YOUTUBE_URL" ]; then
            echo -e "  • ${BOLD}Startup YouTube URL:${NC}         ${CYAN}${STARTUP_YOUTUBE_URL}${NC}"
        else
            echo -e "  • ${BOLD}Startup YouTube URL:${NC}         ${DIM}(Not Configured)${NC}"
        fi
        echo -e "\n${BOLD}Select an action:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}Browse & Play Video from Mix Archive / NFT Folders${NC}"
        echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}Enter Specific Video File Path to Play${NC}"
        echo -e "  ${BOLD}${CYAN} 3)${NC} ${BOLD}Enter Specific Video Stream / YouTube URL to Play${NC}"
        echo -e "  ${BOLD}${CYAN} 4)${NC} ${BOLD}Launch ${DEFAULT_VIDEO_PLAYER} directly${NC} (Empty player)"
        echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Set Default Video Player to: ${BOLD}VLC Media Player${NC} (vlc)"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Set Default Video Player to: ${BOLD}mpv Video Player${NC} (mpv)"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Set Default Video Player to: ${BOLD}Haruna Media Player${NC} (haruna)"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Set Custom Video Player Command"
        echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Toggle Startup YouTube Video Autoplay (${yt_badge})"
        echo -e "  ${BOLD}${CYAN}10)${NC} Configure Startup Custom YouTube Video URL"
        echo -e "  ${BOLD}${CYAN}11)${NC} Test-Play Startup YouTube URL Right Now"
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [0-11]: " v_choice

        case "$v_choice" in
            1)
                echo -e "\n${BOLD}${CYAN}Scanning for video files in archive and local directories...${NC}\n"
                local search_dirs=()
                [ -d "${NFT_VIDEOS_DIR:-}" ] && search_dirs+=("$NFT_VIDEOS_DIR")
                [ -d "${MIX_ARCHIVE_DIR:-}" ] && search_dirs+=("$MIX_ARCHIVE_DIR")
                [ -d "$SCRIPT_DIR" ] && search_dirs+=("$SCRIPT_DIR")
                [ -d "$HOME/Videos" ] && search_dirs+=("$HOME/Videos")

                local v_files=()
                while IFS= read -r f; do
                    [ -f "$f" ] && v_files+=("$f")
                done < <(find "${search_dirs[@]}" -maxdepth 3 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" -o -name "*.avi" \) 2>/dev/null | head -n 30)

                if [ ${#v_files[@]} -eq 0 ]; then
                    echo -e "${YELLOW}No video files found in scanned directories.${NC}"
                    sleep 1.5
                    continue
                fi

                echo -e "${BOLD}Found ${#v_files[@]} video files:${NC}"
                for i in "${!v_files[@]}"; do
                    printf "  ${BOLD}%2d)${NC} %s ${DIM}(%s)${NC}\n" "$((i+1))" "$(basename "${v_files[$i]}")" "$(ls -lh "${v_files[$i]}" 2>/dev/null | awk '{print $5}')"
                done
                echo ""
                read -r -p "Select video [1-${#v_files[@]}, or 0 to cancel]: " v_idx
                if [[ "$v_idx" =~ ^[0-9]+$ ]] && [ "$v_idx" -ge 1 ] && [ "$v_idx" -le "${#v_files[@]}" ]; then
                    dispatch_video "${v_files[$((v_idx-1))]}"
                fi
                ;;
            2)
                echo ""
                read -r -e -p "Enter video file path: " v_path
                v_path="${v_path/#\~/$HOME}"
                if [ -f "$v_path" ]; then
                    dispatch_video "$v_path"
                else
                    echo -e "${RED}Error: File '$v_path' not found!${NC}"
                    sleep 1.5
                fi
                ;;
            3)
                echo ""
                read -r -p "Enter video stream / YouTube URL: " v_url
                if [ -n "$v_url" ]; then
                    dispatch_video "$v_url"
                fi
                ;;
            4)
                dispatch_video ""
                ;;
            5)
                DEFAULT_VIDEO_PLAYER="vlc"
                save_config_setting "DEFAULT_VIDEO_PLAYER" "vlc"
                echo -e "\n${GREEN}✓ Default video player set to 'vlc'!${NC}"
                sleep 1
                ;;
            6)
                DEFAULT_VIDEO_PLAYER="mpv"
                save_config_setting "DEFAULT_VIDEO_PLAYER" "mpv"
                echo -e "\n${GREEN}✓ Default video player set to 'mpv'!${NC}"
                sleep 1
                ;;
            7)
                DEFAULT_VIDEO_PLAYER="haruna"
                save_config_setting "DEFAULT_VIDEO_PLAYER" "haruna"
                echo -e "\n${GREEN}✓ Default video player set to 'haruna'!${NC}"
                sleep 1
                ;;
            8)
                read -r -p "Enter custom video player command / executable: " cust_vp
                if [ -n "$cust_vp" ]; then
                    DEFAULT_VIDEO_PLAYER="$cust_vp"
                    save_config_setting "DEFAULT_VIDEO_PLAYER" "$cust_vp"
                    echo -e "\n${GREEN}✓ Default video player set to '$cust_vp'!${NC}"
                    sleep 1
                fi
                ;;
            9)
                if [ "$AUTO_PLAY_YOUTUBE_ON_STARTUP" = "true" ]; then
                    AUTO_PLAY_YOUTUBE_ON_STARTUP="false"
                else
                    AUTO_PLAY_YOUTUBE_ON_STARTUP="true"
                fi
                save_config_setting "AUTO_PLAY_YOUTUBE_ON_STARTUP" "$AUTO_PLAY_YOUTUBE_ON_STARTUP"
                echo -e "\n${GREEN}✓ Startup YouTube autoplay set to '${AUTO_PLAY_YOUTUBE_ON_STARTUP}'!${NC}"
                sleep 1
                ;;
            10)
                echo ""
                echo -e "Current YouTube URL: ${CYAN}${STARTUP_YOUTUBE_URL:-None}${NC}"
                read -r -p "Enter custom YouTube video URL: " new_yt
                if [ -n "$new_yt" ]; then
                    STARTUP_YOUTUBE_URL="$new_yt"
                    AUTO_PLAY_YOUTUBE_ON_STARTUP="true"
                    save_config_setting "STARTUP_YOUTUBE_URL" "$STARTUP_YOUTUBE_URL"
                    save_config_setting "AUTO_PLAY_YOUTUBE_ON_STARTUP" "true"
                    echo -e "\n${GREEN}✓ Startup YouTube URL updated and autoplay enabled!${NC}"
                else
                    STARTUP_YOUTUBE_URL=""
                    AUTO_PLAY_YOUTUBE_ON_STARTUP="false"
                    save_config_setting "STARTUP_YOUTUBE_URL" ""
                    save_config_setting "AUTO_PLAY_YOUTUBE_ON_STARTUP" "false"
                    echo -e "\n${YELLOW}✓ Startup YouTube URL cleared.${NC}"
                fi
                sleep 1.2
                ;;
            11)
                if [ -n "$STARTUP_YOUTUBE_URL" ]; then
                    dispatch_video "$STARTUP_YOUTUBE_URL"
                else
                    echo -e "\n${RED}Error: No startup YouTube URL configured! Set one in Option 10.${NC}"
                    sleep 1.5
                fi
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

if [ -n "${1:-}" ]; then
    dispatch_video "$1"
else
    manage_video_menu
fi
