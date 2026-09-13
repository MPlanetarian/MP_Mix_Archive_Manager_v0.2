#!/usr/bin/env bash
# ==============================================================================
# Script: clear-wan2gp-logs.sh
# Purpose: Find and clear/delete WAN2GP and Pinokio execution logs and reports
# Location: /home/mplanetarian/Documents/BASH_SCRIPTS/clear-wan2gp-logs.sh
# ==============================================================================

set -euo pipefail

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'
BOLD='\033[1m'

AUTO_CONFIRM=false
PAUSE_ON_EXIT=true
ACTION_MODE="delete" # default: delete, can also be truncate

for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            AUTO_CONFIRM=true
            ;;
        --truncate)
            ACTION_MODE="truncate"
            ;;
        --no-pause)
            PAUSE_ON_EXIT=false
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes      Automatically confirm and clear logs without prompting"
            echo "  --truncate     Truncate logs to 0 bytes instead of deleting them"
            echo "  --no-pause     Do not wait for Enter key on exit"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
    esac
done

press_enter() {
    if [ "$PAUSE_ON_EXIT" = true ]; then
        echo ""
        read -r -p "Press [Enter] to continue..."
    fi
}

echo -e "${BOLD}${MAGENTA}==================================================${NC}"
echo -e "${BOLD}${MAGENTA}             WAN2GP LOG CLEANER UTILITY           ${NC}"
echo -e "${BOLD}${MAGENTA}==================================================${NC}"
echo ""

# Collect log files
found_files=()

# 1. Check WAN2GP update reports and console logs
if [ -d "$HOME/Documents/WAN2GP_UPDATE_RERPORTS" ]; then
    for f in "$HOME/Documents/WAN2GP_UPDATE_RERPORTS"/*.log \
             "$HOME/Documents/WAN2GP_UPDATE_RERPORTS"/FULL_AGY_CONSOLE_LOG.txt; do
        [ -f "$f" ] && found_files+=("$f")
    done
fi

# 2. Check WAN2GP app directory logs (excluding virtualenv)
if [ -d "$HOME/pinokio/api/wan.git/app" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && found_files+=("$f")
    done < <(find "$HOME/pinokio/api/wan.git/app" -maxdepth 2 -name "*.log" -not -path "*/venv/*" 2>/dev/null || true)
fi

# 3. Check Pinokio wan.git logs directory
if [ -d "$HOME/pinokio/api/wan.git/logs" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && found_files+=("$f")
    done < <(find "$HOME/pinokio/api/wan.git/logs" -maxdepth 2 -type f 2>/dev/null || true)
fi

# 4. Check Pinokio cleaned shell task logs for wan.git
if [ -d "$HOME/pinokio/logs/shell/cleaned/api/wan.git" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && found_files+=("$f")
    done < <(find "$HOME/pinokio/logs/shell/cleaned/api/wan.git" -maxdepth 2 -type f 2>/dev/null || true)
fi

# Deduplicate found files
if [ ${#found_files[@]} -gt 0 ]; then
    eval "found_files=($(printf "%q\n" "${found_files[@]}" | sort -u))"
fi

local_count=${#found_files[@]}

if [ "$local_count" -eq 0 ]; then
    echo -e "${GREEN}✓ No WAN2GP log files found. Everything is already clean!${NC}"
    press_enter
    exit 0
fi

# Calculate total size
total_bytes=0
for f in "${found_files[@]}"; do
    if [ -f "$f" ]; then
        sz=$(stat -c %s "$f" 2>/dev/null || wc -c < "$f")
        total_bytes=$((total_bytes + sz))
    fi
done

total_kb=$(echo "scale=2; $total_bytes / 1024" | bc 2>/dev/null || echo "$((total_bytes / 1024))")

echo -e "${BOLD}${BLUE}Found ${local_count} WAN2GP log file(s) (${total_kb} KB total):${NC}"
idx=1
for f in "${found_files[@]}"; do
    sz_str=$(ls -lh "$f" 2>/dev/null | awk '{print $5}' || echo "0")
    mod_str=$(ls -lh "$f" 2>/dev/null | awk '{print $6, $7, $8}' || echo "")
    echo -e "  ${BOLD}${CYAN}${idx})${NC} $(basename "$f") ${DIM}(${sz_str}, ${mod_str})${NC}"
    echo -e "      ${DIM}$f${NC}"
    ((idx++))
done
echo ""

if [ "$AUTO_CONFIRM" = false ]; then
    echo -e "${BOLD}Select an action:${NC}"
    echo -e "  ${BOLD}${GREEN}1)${NC} Delete all log files (Recommended)"
    echo -e "  ${BOLD}${YELLOW}2)${NC} Truncate log files to 0 bytes (Keep empty files)"
    echo -e "  ${BOLD}${RED}3)${NC} Cancel"
    echo ""
    read -r -p "Enter choice [1-3] (Default: 1): " choice
    choice=${choice:-1}

    case "$choice" in
        1)
            ACTION_MODE="delete"
            ;;
        2)
            ACTION_MODE="truncate"
            ;;
        3|q|Q)
            echo -e "${BLUE}Operation canceled.${NC}"
            press_enter
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection. Canceled.${NC}"
            press_enter
            exit 1
            ;;
    esac
fi

echo ""
cleared_count=0
for f in "${found_files[@]}"; do
    if [ -f "$f" ]; then
        if [ "$ACTION_MODE" = "delete" ]; then
            rm -f "$f"
            echo -e "  ${GREEN}✓ Deleted:${NC} $(basename "$f")"
        else
            : > "$f"
            echo -e "  ${YELLOW}✓ Truncated:${NC} $(basename "$f") (0 bytes)"
        fi
        ((cleared_count++))
    fi
done

echo ""
if [ "$ACTION_MODE" = "delete" ]; then
    echo -e "${BOLD}${GREEN}✓ Successfully deleted ${cleared_count} WAN2GP log file(s) (${total_kb} KB freed).${NC}"
else
    echo -e "${BOLD}${GREEN}✓ Successfully truncated ${cleared_count} WAN2GP log file(s) to 0 bytes (${total_kb} KB freed).${NC}"
fi

press_enter
exit 0
