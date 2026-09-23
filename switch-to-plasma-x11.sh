#!/usr/bin/env bash
# ==============================================================================
# Script: switch-to-plasma-x11.sh
# Location: /home/mplanetarian/Documents/BASH_SCRIPTS/switch-to-plasma-x11.sh
# Purpose: Revert desktop to Plasma X11 session (enables 4-screen Defasten video
#          installation, hardware Konsole tabs, and Mix Archive Manager).
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${MAGENTA}==============================================================${NC}"
echo -e "${BOLD}${MAGENTA}           SWITCH TO PLASMA X11 (STANDARD WORKSTATION)        ${NC}"
echo -e "${BOLD}${MAGENTA}==============================================================${NC}"
echo ""

PLASMALogin_CONF_D="/etc/plasmalogin.conf.d"
CONF_FILE="$PLASMALogin_CONF_D/10-preselect-x11.conf"

echo -e "${BOLD}${BLUE}[1/2] Preselecting Plasma X11 in Display Manager...${NC}"
if [ "$EUID" -eq 0 ]; then
    mkdir -p "$PLASMALogin_CONF_D"
    echo -e "[Greeter]
PreselectedSession=plasmax11.desktop" > "$CONF_FILE"
    sed -i 's/^Session=.*/Session=plasmax11.desktop/' /etc/plasmalogin.conf 2>/dev/null || true
else
    if [ -t 0 ]; then
        sudo bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasmax11.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasmax11.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasmax11.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasmax11.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    elif command -v kdesu >/dev/null 2>&1; then
        kdesu -- bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasmax11.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasmax11.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    else
        sudo bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasmax11.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasmax11.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    fi
fi
rm -f "$HOME/.config/start_steam_gaming_session" 2>/dev/null || true
echo -e "${GREEN}[✓] Plasma X11 (plasmax11.desktop) preselected for next session.${NC}"

echo ""
echo -e "${BOLD}${BLUE}[2/2] Ready to return to Plasma X11!${NC}"
echo -e "      ${YELLOW}When you log in to X11:${NC}"
echo -e "      • ${GREEN}Standard multi-monitor desktop layout restored${NC}"
echo -e "      • ${GREEN}Defasten 4-Screen video installation will resume automatically${NC}"
echo -e "      • ${GREEN}Hardware Konsole tabs & Mix Archive Manager will launch on login${NC}"
echo ""

read -r -p "Log out now to enter Plasma X11? [Y/n]: " response
response=${response:-Y}

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BOLD}${GREEN}Logging out of current session... See you in Plasma X11!${NC}"
    sleep 1
    if command -v qdbus >/dev/null 2>&1; then
        qdbus org.kde.Shutdown /Shutdown logout || loginctl terminate-session "$XDG_SESSION_ID"
    else
        loginctl terminate-session "$XDG_SESSION_ID"
    fi
else
    echo ""
    echo -e "${CYAN}Configuration saved! Next time you log out or restart, Plasma X11 will be active.${NC}"
    read -rp "Press [Enter] to exit..."
fi
