#!/usr/bin/env bash
# ==============================================================================
# scripts/beszel.sh
# Purpose: Start, stop, restart, and monitor Beszel Hub and Beszel Agent
#          (Lightweight Server Monitoring Hub & Hardware/GPU Agent via Podman)
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

BESZEL_DIR="${BESZEL_DIR:-$HOME/beszel-hub}"
HUB_PORT="${BESZEL_HUB_PORT:-8090}"
HUB_URL="http://localhost:${HUB_PORT}"

# Helper: check container running
is_container_running() {
    local cname="$1"
    podman ps --format '{{.Names}}' 2>/dev/null | grep -q -E "^${cname}$"
}

# Helper: check container exists
does_container_exist() {
    local cname="$1"
    podman ps -a --format '{{.Names}}' 2>/dev/null | grep -q -E "^${cname}$"
}

# Helper: ensure user podman socket is active
ensure_podman_socket() {
    if command -v systemctl >/dev/null 2>&1; then
        if ! systemctl --user is-active podman.socket >/dev/null 2>&1; then
            echo -e "  ${YELLOW}Activating user podman.socket...${NC}"
            systemctl --user start podman.socket 2>/dev/null || true
            sleep 0.5
        fi
    fi
}

# Helper: open URL in browser
open_dashboard_browser() {
    echo -e "${CYAN}Opening Beszel Dashboard in browser: ${BOLD}${HUB_URL}${NC}"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$HUB_URL" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome "$HUB_URL" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v firefox >/dev/null 2>&1; then
        firefox "$HUB_URL" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$(uname -s)" == "Darwin"* ]]; then
        open "$HUB_URL" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        cmd.exe /c start "" "$HUB_URL" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
}

start_hub() {
    echo -e "\n${BOLD}${BLUE}=== STARTING BESZEL HUB ===${NC}"
    if is_container_running "beszel"; then
        echo -e "${GREEN}✓ Beszel Hub is already running on ${HUB_URL}.${NC}"
        return 0
    fi

    if does_container_exist "beszel"; then
        echo -e "Starting existing 'beszel' container..."
        if podman start beszel >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Beszel Hub container started.${NC}"
        else
            echo -e "${RED}Failed to start existing container. Attempting recreate...${NC}"
            if [ -f "$BESZEL_DIR/launch_beszel_hub_replace.sh" ]; then
                (cd "$BESZEL_DIR" && bash ./launch_beszel_hub_replace.sh)
            else
                podman run --replace -d --name beszel --restart unless-stopped -p "${HUB_PORT}:8090" -v "$BESZEL_DIR/beszel_data:/beszel_data:Z" docker.io/henrygd/beszel:latest
            fi
        fi
    else
        echo -e "Creating and starting 'beszel' container..."
        mkdir -p "$BESZEL_DIR/beszel_data"
        if [ -f "$BESZEL_DIR/launch_beszel_hub_replace.sh" ]; then
            (cd "$BESZEL_DIR" && bash ./launch_beszel_hub_replace.sh)
        else
            podman run --replace -d --name beszel --restart unless-stopped -p "${HUB_PORT}:8090" -v "$BESZEL_DIR/beszel_data:/beszel_data:Z" docker.io/henrygd/beszel:latest
        fi
    fi

    # Verify HTTP endpoint
    sleep 1.5
    if curl -s -o /dev/null -w "%{http_code}" "$HUB_URL/" | grep -q "200"; then
        echo -e "${GREEN}✓ Beszel Hub web dashboard is live at ${BOLD}${HUB_URL}${NC}"
    elif is_container_running "beszel"; then
        echo -e "${YELLOW}Beszel Hub container is running. Web server initializing on ${HUB_URL}...${NC}"
    else
        echo -e "${RED}Error: Beszel Hub failed to start. Check podman logs beszel.${NC}"
        return 1
    fi
    return 0
}

start_agent() {
    echo -e "\n${BOLD}${BLUE}=== STARTING BESZEL AGENT ===${NC}"
    ensure_podman_socket

    if is_container_running "beszel-agent"; then
        echo -e "${GREEN}✓ Beszel Agent is already running.${NC}"
        return 0
    fi

    if does_container_exist "beszel-agent"; then
        echo -e "Starting existing 'beszel-agent' container..."
        if podman start beszel-agent >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Beszel Agent container started.${NC}"
        else
            echo -e "${RED}Failed to start existing container. Attempting recreate...${NC}"
            if [ -f "$BESZEL_DIR/launch_beszel_agent_replace.sh" ]; then
                bash "$BESZEL_DIR/launch_beszel_agent_replace.sh"
            fi
        fi
    else
        echo -e "Creating and starting 'beszel-agent' container..."
        if [ -f "$BESZEL_DIR/launch_beszel_agent_replace.sh" ]; then
            bash "$BESZEL_DIR/launch_beszel_agent_replace.sh"
        else
            echo -e "${RED}Error: launch_beszel_agent_replace.sh not found in ${BESZEL_DIR}.${NC}"
            return 1
        fi
    fi

    sleep 1.5
    if is_container_running "beszel-agent"; then
        echo -e "${GREEN}✓ Beszel Agent is running and connected to Hub.${NC}"
    else
        echo -e "${RED}Error: Beszel Agent failed to start. Check podman logs beszel-agent.${NC}"
        return 1
    fi
    return 0
}

start_both() {
    start_hub
    local hub_ret=$?
    sleep 1
    start_agent
    local agent_ret=$?

    if [ "$hub_ret" -eq 0 ] && [ "$agent_ret" -eq 0 ]; then
        echo -e "\n${BOLD}${GREEN}✓ Beszel Hub & Agent are both running successfully!${NC}"
    fi
}

stop_hub() {
    echo -e "\n${BOLD}${YELLOW}Stopping Beszel Hub...${NC}"
    if is_container_running "beszel"; then
        podman stop beszel
        echo -e "${GREEN}✓ Beszel Hub stopped.${NC}"
    else
        echo -e "Beszel Hub is not running."
    fi
}

stop_agent() {
    echo -e "\n${BOLD}${YELLOW}Stopping Beszel Agent...${NC}"
    if is_container_running "beszel-agent"; then
        podman stop beszel-agent
        echo -e "${GREEN}✓ Beszel Agent stopped.${NC}"
    else
        echo -e "Beszel Agent is not running."
    fi
}

stop_both() {
    stop_agent
    stop_hub
    echo -e "\n${BOLD}${GREEN}✓ Both Beszel Hub and Agent have been stopped.${NC}"
}

restart_both() {
    echo -e "\n${BOLD}${MAGENTA}Restarting Beszel Hub & Agent...${NC}"
    stop_both
    sleep 1
    start_both
}

show_status() {
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                   BESZEL MONITORING SUITE STATUS                     ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    # Hub status
    if is_container_running "beszel"; then
        local hub_up
        hub_up=$(podman ps --filter "name=beszel" --format '{{.RunningFor}}' 2>/dev/null | head -n 1)
        echo -e "  Beszel Hub:     ${BOLD}${GREEN}● RUNNING${NC} (Uptime: ${hub_up:-Active})"
        echo -e "  Web Dashboard:  ${BOLD}${CYAN}${HUB_URL}${NC}"
        if curl -s -o /dev/null -w "%{http_code}" "$HUB_URL/" 2>/dev/null | grep -q "200"; then
            echo -e "  HTTP Health:    ${GREEN}HTTP 200 OK (Dashboard Ready)${NC}"
        else
            echo -e "  HTTP Health:    ${YELLOW}Initializing...${NC}"
        fi
    elif does_container_exist "beszel"; then
        echo -e "  Beszel Hub:     ${BOLD}${RED}○ STOPPED${NC} (Container exists)"
    else
        echo -e "  Beszel Hub:     ${BOLD}${RED}○ NOT CREATED${NC}"
    fi

    echo ""

    # Agent status
    if is_container_running "beszel-agent"; then
        local agent_up
        agent_up=$(podman ps --filter "name=beszel-agent" --format '{{.RunningFor}}' 2>/dev/null | head -n 1)
        echo -e "  Beszel Agent:   ${BOLD}${GREEN}● RUNNING${NC} (Uptime: ${agent_up:-Active})"
        local last_log
        last_log=$(podman logs beszel-agent --tail 2 2>/dev/null | tr '\n' ' ')
        if echo "$last_log" | grep -q "WebSocket connected"; then
            echo -e "  Hub Connection: ${GREEN}WebSocket Connected to ${HUB_URL}${NC}"
        fi
    elif does_container_exist "beszel-agent"; then
        echo -e "  Beszel Agent:   ${BOLD}${RED}○ STOPPED${NC} (Container exists)"
    else
        echo -e "  Beszel Agent:   ${BOLD}${RED}○ NOT CREATED${NC}"
    fi

    # Podman socket status
    if systemctl --user is-active podman.socket >/dev/null 2>&1; then
        echo -e "  Podman Socket:  ${GREEN}Active (${HOME}/.local/share/containers or /run/user/1000/podman/podman.sock)${NC}"
    fi

    # NVIDIA GPU visibility
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -n 1)
        [ -n "$gpu_name" ] && echo -e "  NVIDIA GPU:     ${GREEN}${gpu_name}${NC}"
    fi
    echo ""
}

view_logs_menu() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                      BESZEL CONTAINER LOGS                           ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} View Beszel Hub Logs (Last 50 lines)"
        echo -e "  ${BOLD}${CYAN}2)${NC} Follow Beszel Hub Logs (Real-time stream, Ctrl+C to exit)"
        echo -e "  ${BOLD}${CYAN}3)${NC} View Beszel Agent Logs (Last 50 lines)"
        echo -e "  ${BOLD}${CYAN}4)${NC} Follow Beszel Agent Logs (Real-time stream, Ctrl+C to exit)"
        echo -e "  ${BOLD}${CYAN}5)${NC} Return to Beszel Menu\n"
        read -r -p "Enter choice [1-5]: " log_choice

        case "$log_choice" in
            1)
                echo -e "\n${BOLD}${BLUE}=== BESZEL HUB LOGS ===${NC}\n"
                podman logs beszel --tail 50
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            2)
                echo -e "\n${BOLD}${BLUE}=== FOLLOWING BESZEL HUB LOGS (Ctrl+C to return) ===${NC}\n"
                podman logs -f beszel
                ;;
            3)
                echo -e "\n${BOLD}${BLUE}=== BESZEL AGENT LOGS ===${NC}\n"
                podman logs beszel-agent --tail 50
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            4)
                echo -e "\n${BOLD}${BLUE}=== FOLLOWING BESZEL AGENT LOGS (Ctrl+C to return) ===${NC}\n"
                podman logs -f beszel-agent
                ;;
            5|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

interactive_menu() {
    while true; do
        clear
        show_status
        echo -e "${BOLD}${MAGENTA}----------------------------------------------------------------------${NC}"
        echo -e "${BOLD}Select a Beszel operation:${NC}\n"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Start ${BOLD}${GREEN}Both${NC} (Beszel Hub & Agent)"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Start Beszel Hub Only (Web Dashboard Server on :8090)"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Start Beszel Agent Only (Metrics & GPU Passthrough)"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Open Beszel Web Dashboard in Browser (${CYAN}${HUB_URL}${NC})"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Stop ${BOLD}${RED}Both${NC} (Beszel Hub & Agent)"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Stop Beszel Hub"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Stop Beszel Agent"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Restart Both (Re-launch / Recreate Containers)"
        echo -e "  ${BOLD}${CYAN} 9)${NC} View Beszel Logs (Hub & Agent)"
        echo -e "  ${BOLD}${CYAN}10)${NC} Return to Previous Menu\n"
        read -r -p "Enter choice [1-10, or q to return]: " b_choice

        case "$b_choice" in
            1)
                start_both
                echo ""
                read -r -p "Open web dashboard in browser now? (y/n): " open_now
                [[ "$open_now" =~ ^[Yy]$ ]] && open_dashboard_browser
                read -r -p "Press Enter to continue..."
                ;;
            2)
                start_hub
                echo ""
                read -r -p "Open web dashboard in browser now? (y/n): " open_now
                [[ "$open_now" =~ ^[Yy]$ ]] && open_dashboard_browser
                read -r -p "Press Enter to continue..."
                ;;
            3)
                start_agent
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            4)
                open_dashboard_browser
                sleep 1
                ;;
            5)
                stop_both
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            6)
                stop_hub
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            7)
                stop_agent
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            8)
                restart_both
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            9)
                view_logs_menu
                ;;
            10|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# CLI Argument handling
case "${1:-}" in
    start|start-both|both)
        start_both
        ;;
    start-hub|hub)
        start_hub
        ;;
    start-agent|agent)
        start_agent
        ;;
    stop|stop-both)
        stop_both
        ;;
    stop-hub)
        stop_hub
        ;;
    stop-agent)
        stop_agent
        ;;
    restart)
        restart_both
        ;;
    status)
        show_status
        ;;
    dashboard|open|web)
        open_dashboard_browser
        ;;
    logs)
        view_logs_menu
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo "Usage: $(basename "$0") {start|start-hub|start-agent|stop|stop-hub|stop-agent|restart|status|dashboard|logs}"
        exit 1
        ;;
esac
