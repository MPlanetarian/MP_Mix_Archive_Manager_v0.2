#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Go Shopping for New Music & High-Res Tracks
# Opens Beatport, Apple Music, and Bandcamp in browser tabs.
# ==============================================================================

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

URL_BEATPORT="https://www.beatport.com"
URL_APPLE="https://music.apple.com"
URL_BANDCAMP="https://bandcamp.com"

open_browser_urls() {
    local urls=("$@")
    if [ ${#urls[@]} -eq 0 ]; then
        urls=("$URL_BEATPORT" "$URL_APPLE" "$URL_BANDCAMP")
    fi

    echo -e "${CYAN}Opening music platforms in your web browser...${NC}"
    for u in "${urls[@]}"; do
        echo -e "  • ${WHITE}${u}${NC}"
    done

    # 1. macOS
    if [ "$(uname -s)" = "Darwin" ]; then
        open "${urls[@]}" >/dev/null 2>&1 &
        return 0
    fi

    # 2. Windows / WSL
    if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${COMSPEC:-}" ] || [ -n "${WINDIR:-}" ]; then
        for u in "${urls[@]}"; do
            if command -v cmd.exe >/dev/null 2>&1; then
                cmd.exe /c start "" "$u" >/dev/null 2>&1 &
            elif command -v wslview >/dev/null 2>&1; then
                wslview "$u" >/dev/null 2>&1 &
            fi
            sleep 0.2
        done
        return 0
    fi

    # 3. Linux (Bazzite / SteamOS / Fedora / Ubuntu)
    # Prefer launching browser directly so all URLs open in tabs within the same window
    if command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "com.google.Chrome"; then
        flatpak run com.google.Chrome "${urls[@]}" >/dev/null 2>&1 &
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome "${urls[@]}" >/dev/null 2>&1 &
    elif command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "org.mozilla.firefox"; then
        flatpak run org.mozilla.firefox "${urls[@]}" >/dev/null 2>&1 &
    elif command -v firefox >/dev/null 2>&1; then
        firefox "${urls[@]}" >/dev/null 2>&1 &
    elif command -v chromium >/dev/null 2>&1; then
        chromium "${urls[@]}" >/dev/null 2>&1 &
    elif command -v brave-browser >/dev/null 2>&1; then
        brave-browser "${urls[@]}" >/dev/null 2>&1 &
    else
        for u in "${urls[@]}"; do
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$u" >/dev/null 2>&1 &
            fi
            sleep 0.25
        done
    fi
}

shop_menu() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}               🛒 GO SHOPPING FOR NEW MUSIC & TRACKS                  ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    echo -e "  Quick-launch curated electronic music stores in your web browser:\n"
    echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}Open All 3 Stores in Browser Tabs${NC} (${GREEN}Beatport + Apple Music + Bandcamp${NC})"
    echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}Beatport${NC} (${DIM}https://www.beatport.com${NC})"
    echo -e "  ${BOLD}${CYAN} 3)${NC} ${BOLD}Apple Music${NC} (${DIM}https://music.apple.com${NC})"
    echo -e "  ${BOLD}${CYAN} 4)${NC} ${BOLD}Bandcamp${NC} (${DIM}https://bandcamp.com${NC})"
    echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu\n"
    read -r -p "Enter choice [1-4, or 0 to return]: " shop_choice

    case "$shop_choice" in
        1|"")
            open_browser_urls "$URL_BEATPORT" "$URL_APPLE" "$URL_BANDCAMP"
            echo -e "\n${GREEN}✓ Opened Beatport, Apple Music, and Bandcamp tabs!${NC}"
            sleep 1.2
            ;;
        2)
            open_browser_urls "$URL_BEATPORT"
            echo -e "\n${GREEN}✓ Opened Beatport!${NC}"
            sleep 1
            ;;
        3)
            open_browser_urls "$URL_APPLE"
            echo -e "\n${GREEN}✓ Opened Apple Music!${NC}"
            sleep 1
            ;;
        4)
            open_browser_urls "$URL_BANDCAMP"
            echo -e "\n${GREEN}✓ Opened Bandcamp!${NC}"
            sleep 1
            ;;
        0|[qQ])
            return 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice.${NC}"
            sleep 1
            ;;
    esac
}

if [ "${1:-}" = "--all" ]; then
    open_browser_urls "$URL_BEATPORT" "$URL_APPLE" "$URL_BANDCAMP"
elif [ "${1:-}" = "--beatport" ]; then
    open_browser_urls "$URL_BEATPORT"
elif [ "${1:-}" = "--apple" ]; then
    open_browser_urls "$URL_APPLE"
elif [ "${1:-}" = "--bandcamp" ]; then
    open_browser_urls "$URL_BANDCAMP"
else
    shop_menu
fi
