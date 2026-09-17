#!/usr/bin/env bash
# ==============================================================================
# scripts/manage_ollama.sh
# Purpose: Start, stop, restart, and monitor Ollama Server (ollama serve)
#          Running inside distrobox container: ollama-container
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

OLLAMA_CONTAINER="${OLLAMA_CONTAINER:-ollama-container}"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_URL="http://${OLLAMA_HOST}:${OLLAMA_PORT}"
LOG_FILE="/tmp/ollama-serve.log"

is_ollama_running() {
    if curl -s --connect-timeout 1 "${OLLAMA_URL}/" 2>/dev/null | grep -qi "Ollama is running"; then
        return 0
    elif pgrep -f "ollama serve" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_ollama_pids() {
    pgrep -f "ollama serve" 2>/dev/null | tr '\n' ' '
}

ensure_container_started() {
    if command -v podman >/dev/null 2>&1; then
        if ! podman ps --filter "name=${OLLAMA_CONTAINER}" --format "{{.Names}}" 2>/dev/null | grep -q "^${OLLAMA_CONTAINER}$"; then
            echo -e "  ${YELLOW}Starting podman container '${OLLAMA_CONTAINER}'...${NC}"
            podman start "$OLLAMA_CONTAINER" >/dev/null 2>&1 || true
            sleep 1
        fi
    fi
}

start_ollama_bg() {
    echo -e "\n${BOLD}${BLUE}=== STARTING OLLAMA SERVER (BACKGROUND) ===${NC}"
    if is_ollama_running; then
        local pids
        pids=$(get_ollama_pids)
        echo -e "${GREEN}✓ Ollama server is already running (PID: ${pids% }, URL: ${OLLAMA_URL}).${NC}"
        return 0
    fi

    ensure_container_started

    echo -e "Launching 'ollama serve' in background via distrobox (${OLLAMA_CONTAINER})..."
    nohup distrobox enter -T "$OLLAMA_CONTAINER" -- ollama serve >"$LOG_FILE" 2>&1 &
    local launch_pid=$!

    echo -e "Waiting for Ollama API endpoint to become responsive..."
    local ready=false
    for _ in {1..20}; do
        if curl -s --connect-timeout 1 "${OLLAMA_URL}/" 2>/dev/null | grep -qi "Ollama is running"; then
            ready=true
            break
        fi
        sleep 0.5
    done

    if [ "$ready" = "true" ]; then
        local pids
        pids=$(get_ollama_pids)
        echo -e "${BOLD}${GREEN}✓ Ollama server successfully started!${NC}"
        echo -e "  • Status:       ${GREEN}RUNNING${NC}"
        echo -e "  • Endpoint:     ${BOLD}${CYAN}${OLLAMA_URL}${NC}"
        echo -e "  • PID(s):       ${YELLOW}${pids% }${NC}"
        echo -e "  • Log File:     ${LOG_FILE}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "Ollama" -i "dialog-ok" "Ollama Server" "✓ Ollama server is live on ${OLLAMA_URL}" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}Warning: Ollama server did not respond on ${OLLAMA_URL} within 10s.${NC}"
        echo -e "${YELLOW}Check logs with: tail -n 20 ${LOG_FILE}${NC}"
        return 1
    fi
}

start_ollama_window() {
    echo -e "\n${BOLD}${BLUE}=== STARTING OLLAMA SERVER (TERMINAL WINDOW) ===${NC}"
    if is_ollama_running; then
        local pids
        pids=$(get_ollama_pids)
        echo -e "${GREEN}✓ Ollama server is already running (PID: ${pids% }, URL: ${OLLAMA_URL}).${NC}"
        return 0
    fi

    ensure_container_started

    local TITLE="Ollama Server (${OLLAMA_CONTAINER})"
    local CMD="distrobox enter ${OLLAMA_CONTAINER} -- ollama serve; echo ''; echo 'Ollama server exited. Press [Enter] to close...'; read -r"

    echo -e "Opening terminal window for 'ollama serve'..."
    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab -p tabtitle="$TITLE" -e bash -c "$CMD" &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$TITLE" -- bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$TITLE" -e bash -c "$CMD" >/dev/null 2>&1 &
    else
        start_ollama_bg
        return $?
    fi

    echo -e "Waiting for Ollama to initialize..."
    sleep 2
    if is_ollama_running; then
        echo -e "${BOLD}${GREEN}✓ Ollama server running in new window (${OLLAMA_URL}).${NC}"
        return 0
    else
        echo -e "${YELLOW}Terminal window launched. Please check the new window for server logs.${NC}"
        return 0
    fi
}

stop_ollama() {
    echo -e "\n${BOLD}${YELLOW}Stopping Ollama Server...${NC}"
    if ! is_ollama_running; then
        echo -e "${YELLOW}Ollama server is not currently running.${NC}"
        return 0
    fi

    local pids
    pids=$(get_ollama_pids)
    echo -e "Terminating Ollama process(es): ${pids% }..."

    # Graceful TERM
    distrobox enter -T "$OLLAMA_CONTAINER" -- pkill -TERM -f "ollama serve" 2>/dev/null || true
    pkill -TERM -f "ollama serve" 2>/dev/null || true

    sleep 1.5

    if ! is_ollama_running; then
        echo -e "${BOLD}${GREEN}✓ Ollama server stopped successfully.${NC}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "Ollama" -i "dialog-ok" "Ollama Server" "✓ Ollama server stopped." 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}Process still running. Force killing...${NC}"
        distrobox enter -T "$OLLAMA_CONTAINER" -- pkill -9 -f "ollama serve" 2>/dev/null || true
        pkill -9 -f "ollama serve" 2>/dev/null || true
        sleep 1
        if ! is_ollama_running; then
            echo -e "${BOLD}${GREEN}✓ Ollama server force terminated.${NC}"
            return 0
        else
            echo -e "${RED}Error: Unable to terminate all Ollama processes.${NC}"
            return 1
        fi
    fi
}

restart_ollama() {
    echo -e "\n${BOLD}${MAGENTA}Restarting Ollama Server...${NC}"
    stop_ollama
    sleep 1
    start_ollama_bg
}

show_status() {
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                    OLLAMA SERVER STATUS & MODELS                     ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    if is_ollama_running; then
        local pids
        pids=$(get_ollama_pids)
        echo -e "  Server Status:    ${BOLD}${GREEN}● RUNNING${NC} (PID: ${pids% })"
        echo -e "  API Endpoint:     ${BOLD}${CYAN}${OLLAMA_URL}${NC}"
        echo -e "  HTTP Health:      ${GREEN}HTTP 200 OK (Ollama is running)${NC}"
        echo -e "  Container:        ${GREEN}${OLLAMA_CONTAINER}${NC} (distrobox/podman)"
    else
        echo -e "  Server Status:    ${BOLD}${RED}○ STOPPED${NC}"
        echo -e "  API Endpoint:     ${BOLD}${CYAN}${OLLAMA_URL}${NC} (Offline)"
        echo -e "  Container:        ${YELLOW}${OLLAMA_CONTAINER}${NC}"
    fi

    # GPU info
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_info
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -n 1)
        [ -n "$gpu_info" ] && echo -e "  Hardware Accel:   ${GREEN}${gpu_info}${NC} (CUDA Enabled)"
    fi

    echo ""
    echo -e "${BOLD}Installed Local Models in Ollama:${NC}"
    if is_ollama_running; then
        local model_list
        model_list=$(curl -s "${OLLAMA_URL}/api/tags" 2>/dev/null)
        if [ -n "$model_list" ] && command -v jq >/dev/null 2>&1; then
            echo "$model_list" | jq -r '.models[]? | "  • \(.name) (\((.size / 1073741824 * 10 | floor) / 10) GB, \(.details.parameter_size // "N/A"), \(.details.quantization_level // "N/A"))"' 2>/dev/null
        else
            distrobox enter -T "$OLLAMA_CONTAINER" -- ollama list 2>/dev/null | sed 's/^/  /'
        fi
    else
        echo -e "  ${YELLOW}(Start server to query models via API)${NC}"
        distrobox enter -T "$OLLAMA_CONTAINER" -- ollama list 2>/dev/null | sed 's/^/  /' || true
    fi
    echo ""
}

run_chat_cli() {
    if ! is_ollama_running; then
        echo -e "\n${YELLOW}Ollama server is not running. Starting server first...${NC}"
        start_ollama_bg
        sleep 1
    fi

    echo -e "\n${BOLD}${BLUE}=== CHAT WITH LOCAL OLLAMA MODEL ===${NC}\n"
    local models=()
    if is_ollama_running && command -v jq >/dev/null 2>&1; then
        mapfile -t models < <(curl -s "${OLLAMA_URL}/api/tags" 2>/dev/null | jq -r '.models[]?.name' 2>/dev/null)
    fi

    if [ ${#models[@]} -eq 0 ]; then
        mapfile -t models < <(distrobox enter -T "$OLLAMA_CONTAINER" -- ollama list 2>/dev/null | awk 'NR>1 {print $1}')
    fi

    if [ ${#models[@]} -eq 0 ]; then
        echo -e "${RED}No local models found in Ollama.${NC}"
        read -r -p "Press Enter to return..."
        return 1
    fi

    echo "Select a model to run:"
    local idx=1
    for m in "${models[@]}"; do
        printf "  %2d) %s\n" "$idx" "$m"
        ((idx++))
    done
    echo "   0) Cancel"
    echo ""
    read -r -p "Enter choice [1-${#models[@]}]: " m_choice
    if [ "$m_choice" = "0" ] || [ -z "$m_choice" ]; then
        return 0
    fi

    if [[ "$m_choice" =~ ^[0-9]+$ ]] && [ "$m_choice" -ge 1 ] && [ "$m_choice" -le ${#models[@]} ]; then
        local chosen_model="${models[$((m_choice - 1))]}"
        echo -e "\n${BOLD}${GREEN}Launching interactive chat with '${chosen_model}'...${NC}\n"
        echo -e "${CYAN}Type /bye or press Ctrl+D to exit the chat.${NC}\n"
        distrobox enter "$OLLAMA_CONTAINER" -- ollama run "$chosen_model"
    else
        echo -e "${RED}Invalid selection.${NC}"
        sleep 1
    fi
}

view_logs() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                       OLLAMA SERVER LOGS                             ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    if [ -f "$LOG_FILE" ]; then
        echo -e "Last 50 lines of ${LOG_FILE}:\n"
        tail -n 50 "$LOG_FILE"
    else
        echo -e "Log file ${LOG_FILE} does not exist yet (server may have been started in a terminal window)."
    fi
    echo ""
    read -r -p "Press Enter to return..."
}

interactive_menu() {
    while true; do
        clear
        show_status
        echo -e "${BOLD}${MAGENTA}----------------------------------------------------------------------${NC}"
        echo -e "${BOLD}Select an Ollama operation:${NC}\n"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Start Ollama Server (${BOLD}${GREEN}Background Daemon${NC}) [ollama serve]"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Start Ollama Server in ${BOLD}${YELLOW}New Terminal Window${NC} (Live Logs)"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Stop Running Ollama Server"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Restart Ollama Server"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Chat with a Local Model (Interactive CLI: Qwen, LLaMA...)"
        echo -e "  ${BOLD}${CYAN} 6)${NC} View Server Log File (${LOG_FILE})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Return to Previous Menu\n"
        read -r -p "Enter choice [1-7, or q to return]: " o_choice

        case "$o_choice" in
            1)
                start_ollama_bg
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            2)
                start_ollama_window
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            3)
                stop_ollama
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            4)
                restart_ollama
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            5)
                run_chat_cli
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
    start|serve|bg)
        start_ollama_bg
        ;;
    start-window|window|terminal)
        start_ollama_window
        ;;
    stop)
        stop_ollama
        ;;
    restart)
        restart_ollama
        ;;
    status)
        show_status
        ;;
    models|list)
        distrobox enter -T "$OLLAMA_CONTAINER" -- ollama list
        ;;
    chat|run)
        shift
        if [ -n "$1" ]; then
            distrobox enter "$OLLAMA_CONTAINER" -- ollama run "$1"
        else
            run_chat_cli
        fi
        ;;
    logs)
        view_logs
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo "Usage: $(basename "$0") {start|start-window|stop|restart|status|models|chat|logs}"
        exit 1
        ;;
esac
