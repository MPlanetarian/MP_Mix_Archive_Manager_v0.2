#!/usr/bin/env bash
# ==============================================================================
# scripts/dsh_mobile.sh
# Purpose: Start, stop, restart, and monitor DeepSeek Harness (dsh-mobile)
#          Web UI server listening on port 3080 with LAN mobile access
#          (http://192.168.1.11:3080 / http://localhost:3080)
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"

DSH_DIR="${DSH_DIR:-/var/home/mplanetarian/beszel-hub/deepseek-harness}"
if [ ! -d "$DSH_DIR" ] && [ -d "$HOME/beszel-hub/deepseek-harness" ]; then
    DSH_DIR="$HOME/beszel-hub/deepseek-harness"
elif [ ! -d "$DSH_DIR" ] && [ -d "/var/home/mplanetarian/deepseek-harness" ]; then
    DSH_DIR="/var/home/mplanetarian/deepseek-harness"
elif [ ! -d "$DSH_DIR" ] && [ -d "$HOME/deepseek-harness" ]; then
    DSH_DIR="$HOME/deepseek-harness"
fi

DSH_PORT="${DSH_PORT:-3080}"
DSH_LAN_IP="${DSH_LAN_IP:-}"
if [ -z "$DSH_LAN_IP" ]; then
    DSH_LAN_IP=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
    [ -z "$DSH_LAN_IP" ] && DSH_LAN_IP="192.168.1.11"
fi
DSH_LOCAL_URL="http://localhost:${DSH_PORT}"
DSH_LAN_URL="http://${DSH_LAN_IP}:${DSH_PORT}"
LOG_FILE="/tmp/dsh-mobile.log"

is_dsh_running() {
    if ss -tuln 2>/dev/null | grep -q ":${DSH_PORT} "; then
        return 0
    elif command -v lsof >/dev/null 2>&1 && lsof -ti:"${DSH_PORT}" >/dev/null 2>&1; then
        return 0
    elif pgrep -f "dsh.*web" >/dev/null 2>&1 || pgrep -f "apps/cli/src/bin\.ts.*web" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_dsh_pids() {
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
        pids=$(lsof -ti:"${DSH_PORT}" 2>/dev/null | tr '\n' ' ')
    fi
    if [ -z "$pids" ]; then
        pids=$(pgrep -f "dsh.*web|apps/cli/src/bin\.ts.*web" 2>/dev/null | tr '\n' ' ')
    fi
    echo "$pids"
}

start_dsh_window() {
    echo -e "\n${BOLD}${BLUE}=== LAUNCHING DSH-MOBILE (TERMINAL WINDOW) ===${NC}"
    if is_dsh_running; then
        local pids
        pids=$(get_dsh_pids)
        echo -e "${GREEN}✓ dsh-mobile is already running (PID: ${pids% }).${NC}"
        echo -e "  • Local URL:  ${BOLD}${CYAN}${DSH_LOCAL_URL}${NC}"
        echo -e "  • Mobile LAN: ${BOLD}${GREEN}${DSH_LAN_URL}${NC}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "DeepSeek Harness" -i "dialog-information" "DeepSeek Harness" "dsh-mobile is already running (${DSH_LAN_URL})." 2>/dev/null || true
        fi
        return 0
    fi

    if [ ! -d "$DSH_DIR" ]; then
        echo -e "${RED}Error: DeepSeek Harness directory not found at '$DSH_DIR'!${NC}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "DeepSeek Harness" -i "dialog-error" "DeepSeek Harness" "Directory not found at $DSH_DIR" 2>/dev/null || true
        fi
        return 1
    fi

    echo -e "Starting dsh web on port ${DSH_PORT} with LAN trust for ${DSH_LAN_IP}..."
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "DeepSeek Harness" -i "utilities-terminal" "DeepSeek Harness" "Launching dsh-mobile on ${DSH_LAN_URL}..." 2>/dev/null || true
    fi

    local TITLE="DeepSeek Harness (dsh-mobile)"
    local CMD="cd \"$DSH_DIR\" && pnpm dsh web --trusted-host ${DSH_LAN_IP}:${DSH_PORT} --trusted-host ${DSH_LAN_IP} --no-open; echo ''; echo 'dsh web finished. Press [Enter] to close...'; read -r"

    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab -p tabtitle="$TITLE" --workdir "$DSH_DIR" -e bash -c "$CMD" &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$TITLE" --working-directory="$DSH_DIR" -- bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$TITLE" -e bash -c "cd \"$DSH_DIR\" && $CMD" >/dev/null 2>&1 &
    else
        start_dsh_bg
        return $?
    fi

    echo -e "${GREEN}✓ Launch command dispatched to new terminal.${NC}"
    echo -e "Waiting for DeepSeek Harness port ${DSH_PORT} to listen..."
    local ready=false
    for _ in {1..20}; do
        if is_dsh_running; then
            ready=true
            break
        fi
        sleep 0.5
    done

    if [ "$ready" = "true" ]; then
        local pids
        pids=$(get_dsh_pids)
        echo -e "${BOLD}${GREEN}✓ dsh-mobile is online and listening!${NC}"
        echo -e "  • Status:     ${GREEN}RUNNING${NC}"
        echo -e "  • PID(s):     ${YELLOW}${pids% }${NC}"
        echo -e "  • Local URL:  ${BOLD}${CYAN}${DSH_LOCAL_URL}${NC}"
        echo -e "  • Mobile LAN: ${BOLD}${GREEN}${DSH_LAN_URL}${NC}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "DeepSeek Harness" -i "dialog-ok" "DeepSeek Harness" "✓ dsh-mobile is live on ${DSH_LAN_URL}" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${YELLOW}Terminal window launched. Web server initializing on ${DSH_LAN_URL}...${NC}"
        return 0
    fi
}

start_dsh_bg() {
    echo -e "\n${BOLD}${BLUE}=== STARTING DSH-MOBILE (BACKGROUND DAEMON) ===${NC}"
    if is_dsh_running; then
        local pids
        pids=$(get_dsh_pids)
        echo -e "${GREEN}✓ dsh-mobile is already running (PID: ${pids% }).${NC}"
        echo -e "  • Local URL:  ${BOLD}${CYAN}${DSH_LOCAL_URL}${NC}"
        echo -e "  • Mobile LAN: ${BOLD}${GREEN}${DSH_LAN_URL}${NC}"
        return 0
    fi

    if [ ! -d "$DSH_DIR" ]; then
        echo -e "${RED}Error: DeepSeek Harness directory not found at '$DSH_DIR'!${NC}"
        return 1
    fi

    echo -e "Launching dsh web in background..."
    (cd "$DSH_DIR" && nohup pnpm dsh web --trusted-host "${DSH_LAN_IP}:${DSH_PORT}" --trusted-host "${DSH_LAN_IP}" --no-open >"$LOG_FILE" 2>&1 &)

    echo -e "Waiting for server to listen on port ${DSH_PORT}..."
    local ready=false
    for _ in {1..20}; do
        if is_dsh_running; then
            ready=true
            break
        fi
        sleep 0.5
    done

    if [ "$ready" = "true" ]; then
        local pids
        pids=$(get_dsh_pids)
        echo -e "${BOLD}${GREEN}✓ dsh-mobile successfully started!${NC}"
        echo -e "  • Status:     ${GREEN}RUNNING${NC}"
        echo -e "  • PID(s):     ${YELLOW}${pids% }${NC}"
        echo -e "  • Local URL:  ${BOLD}${CYAN}${DSH_LOCAL_URL}${NC}"
        echo -e "  • Mobile LAN: ${BOLD}${GREEN}${DSH_LAN_URL}${NC}"
        echo -e "  • Log File:   ${LOG_FILE}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "DeepSeek Harness" -i "dialog-ok" "DeepSeek Harness" "✓ dsh-mobile is live on ${DSH_LAN_URL}" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}Warning: dsh-mobile did not bind port ${DSH_PORT} within 10s.${NC}"
        echo -e "${YELLOW}Check logs with: tail -n 20 ${LOG_FILE}${NC}"
        return 1
    fi
}

stop_dsh() {
    echo -e "\n${BOLD}${BLUE}=== STOPPING DSH-MOBILE ===${NC}"
    local pids
    pids=$(get_dsh_pids)
    if [ -z "$pids" ]; then
        echo -e "${YELLOW}dsh-mobile is not currently running.${NC}"
        return 0
    fi

    echo -e "Stopping dsh-mobile processes (PID: ${YELLOW}${pids% }${NC})..."
    for pid in $pids; do
        kill -TERM "$pid" 2>/dev/null || true
    done

    local stopped=false
    for _ in {1..10}; do
        if ! is_dsh_running; then
            stopped=true
            break
        fi
        sleep 0.5
    done

    if [ "$stopped" = "false" ]; then
        echo -e "${YELLOW}Forcing termination with SIGKILL...${NC}"
        local rem_pids
        rem_pids=$(get_dsh_pids)
        for pid in $rem_pids; do
            kill -9 "$pid" 2>/dev/null || true
        done
        if command -v fuser >/dev/null 2>&1; then
            fuser -k "${DSH_PORT}/tcp" >/dev/null 2>&1 || true
        fi
        sleep 0.5
    fi

    if ! is_dsh_running; then
        echo -e "${BOLD}${GREEN}✓ dsh-mobile has been stopped successfully.${NC}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "DeepSeek Harness" -i "dialog-information" "DeepSeek Harness" "dsh-mobile has been stopped." 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}Error: Failed to stop some dsh-mobile processes.${NC}"
        return 1
    fi
}

restart_dsh() {
    echo -e "\n${BOLD}${BLUE}=== RESTARTING DSH-MOBILE ===${NC}"
    stop_dsh
    sleep 1
    start_dsh_window
}

open_dsh_browser() {
    echo -e "\n${BOLD}${BLUE}=== OPENING DSH-MOBILE WEB UI ===${NC}"
    if ! is_dsh_running; then
        echo -e "${YELLOW}dsh-mobile is not currently running. Starting it now...${NC}"
        start_dsh_window
        sleep 2
    fi

    local target_url="${DSH_LAN_URL}"
    echo -e "Opening in browser: ${BOLD}${GREEN}${target_url}${NC}"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v firefox >/dev/null 2>&1; then
        firefox "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        cmd.exe /c start "" "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    else
        echo -e "Please open manually in your browser: ${BOLD}${CYAN}${target_url}${NC}"
    fi
}

show_status() {
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}        DEEPSEEK HARNESS (DSH-MOBILE) SERVER MANAGER                  ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo ""
    local pids
    pids=$(get_dsh_pids)
    if is_dsh_running; then
        echo -e "  Server Status:  ${BOLD}${GREEN}● RUNNING${NC} (PID: ${YELLOW}${pids% }${NC})"
        echo -e "  Local URL:      ${BOLD}${CYAN}${DSH_LOCAL_URL}${NC}"
        echo -e "  Mobile LAN URL: ${BOLD}${GREEN}${DSH_LAN_URL}${NC}  ${DIM}(Trusted host active)${NC}"
        echo -e "  Listen Port:    ${CYAN}${DSH_PORT}/tcp${NC}"
    else
        echo -e "  Server Status:  ${BOLD}${RED}○ STOPPED${NC}"
        echo -e "  Target LAN URL: ${DIM}${DSH_LAN_URL}${NC}"
    fi
    echo -e "  Harness Dir:    ${CYAN}${DSH_DIR}${NC}"
    if [ -d "$DSH_DIR" ]; then
        local dsh_git=""
        if [ -d "$DSH_DIR/.git" ]; then
            dsh_git=$(git -C "$DSH_DIR" log -1 --format="%h (%s)" 2>/dev/null || true)
            [ -n "$dsh_git" ] && echo -e "  Git Version:    ${DIM}${dsh_git}${NC}"
        fi
    fi
    echo ""
}

view_logs() {
    echo -e "\n${BOLD}${BLUE}=== DSH-MOBILE LOG FILE ===${NC}\n"
    if [ -f "$LOG_FILE" ]; then
        echo -e "Log file: ${LOG_FILE} (Last 50 lines):\n"
        tail -n 50 "$LOG_FILE"
    else
        echo -e "Log file ${LOG_FILE} does not exist yet (server may have been launched in a dedicated terminal window)."
    fi
    echo ""
    read -r -p "Press Enter to return..."
}

interactive_menu() {
    while true; do
        clear
        show_status
        echo -e "${BOLD}${MAGENTA}----------------------------------------------------------------------${NC}"
        echo -e "${BOLD}Select a DeepSeek Harness operation:${NC}\n"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Launch dsh-mobile in ${BOLD}${GREEN}Terminal Window / Tab${NC} (Standard)"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Launch dsh-mobile in ${BOLD}${YELLOW}Background Daemon${NC} (Log to file)"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Open dsh-mobile Web UI in ${BOLD}${CYAN}Browser${NC} (${DSH_LAN_URL})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Stop Running dsh-mobile Server"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Restart dsh-mobile Server"
        echo -e "  ${BOLD}${CYAN} 6)${NC} View Server Log File (${LOG_FILE})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Return to Previous Menu\n"
        read -r -p "Enter choice [1-7, or q to return]: " d_choice

        case "$d_choice" in
            1)
                start_dsh_window
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            2)
                start_dsh_bg
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            3)
                open_dsh_browser
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            4)
                stop_dsh
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            5)
                restart_dsh
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            6)
                view_logs
                ;;
            7|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

case "${1:-}" in
    start|launch|window|term)
        start_dsh_window
        ;;
    start-bg|bg|daemon)
        start_dsh_bg
        ;;
    stop)
        stop_dsh
        ;;
    restart)
        restart_dsh
        ;;
    web|browser|open|dashboard)
        open_dsh_browser
        ;;
    status)
        show_status
        ;;
    logs)
        view_logs
        ;;
    "")
        if [ ! -t 0 ] || [ -z "${TERM:-}" ]; then
            start_dsh_window
        else
            interactive_menu
        fi
        ;;
    *)
        echo "Usage: $(basename "$0") {start|start-bg|stop|restart|web|status|logs}"
        exit 1
        ;;
esac
