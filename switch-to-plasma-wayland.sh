#!/usr/bin/env bash
# ==============================================================================
# Script: switch-to-plasma-wayland.sh
# Location: /home/mplanetarian/Documents/BASH_SCRIPTS/switch-to-plasma-wayland.sh
# Purpose: Switch Desktop from X11 to Plasma Wayland for HDR gaming on Hisense
#          4K TV, set Hisense as primary display, ensure HDMI ALSA audio output,
#          suppress Defasten video playback, and load Steam Big Picture Mode.
# ==============================================================================

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${MAGENTA}==============================================================${NC}"
echo -e "${BOLD}${MAGENTA}     SWITCH TO PLASMA WAYLAND (HDR HISENSE & STEAM BPM)      ${NC}"
echo -e "${BOLD}${MAGENTA}==============================================================${NC}"
echo ""

HDMI_SINK="alsa_output.pci-0000_17_00.1.hdmi-stereo"

# 1. Check current session type
echo -e "${BOLD}${BLUE}[1/5] Checking current session...${NC}"
CURRENT_SESSION="${XDG_SESSION_TYPE:-unknown}"
echo -e "      Current session type: ${BOLD}${CYAN}${CURRENT_SESSION}${NC}"

if [ "$CURRENT_SESSION" = "wayland" ]; then
    echo -e "${GREEN}[✓] Already running in Plasma Wayland!${NC}"
    echo ""
    echo -e "${BOLD}${BLUE}[*] Ensuring Hisense 4K HDR display configuration...${NC}"
    if command -v kscreen-doctor >/dev/null 2>&1; then
        kscreen-doctor output.HDMI-A-1.priority.1 output.HDMI-A-1.hdr.enable output.HDMI-A-1.wcg.enable 2>/dev/null || true
        echo -e "${GREEN}[✓] Hisense (HDMI-A-1) configured as Priority 1 (Default) with HDR & WCG enabled.${NC}"
    fi

    echo -e "${BOLD}${BLUE}[*] Ensuring HDMI ALSA audio sink is default...${NC}"
    pactl set-default-sink "$HDMI_SINK" 2>/dev/null || true
    pactl set-sink-mute "$HDMI_SINK" 0 2>/dev/null || true
    pactl set-sink-volume "$HDMI_SINK" 100% 2>/dev/null || true
    echo -e "${GREEN}[✓] Audio set to: GA102 HDMI Digital Stereo (${HDMI_SINK})${NC}"

    echo -e "${BOLD}${BLUE}[*] Checking Steam Big Picture Mode...${NC}"
    if ! pgrep -fa "steam" | grep -qv "defasten"; then
        echo -e "${YELLOW}Starting Steam in Big Picture Mode...${NC}"
        nohup steam -gamepadui >/dev/null 2>&1 &
    else
        echo -e "${GREEN}[✓] Steam is already running.${NC}"
    fi
    echo ""
    read -rp "Press [Enter] to exit..."
    exit 0
fi

# 2. Configure HDMI ALSA Audio interface now so WirePlumber / PipeWire state is updated
echo ""
echo -e "${BOLD}${BLUE}[2/5] Configuring HDMI ALSA Audio Interface...${NC}"
pactl set-default-sink "$HDMI_SINK" 2>/dev/null || true
pactl set-sink-mute "$HDMI_SINK" 0 2>/dev/null || true
pactl set-sink-volume "$HDMI_SINK" 100% 2>/dev/null || true
echo -e "${GREEN}[✓] Verified HDMI Audio Sink: GA102 Digital Stereo (${HDMI_SINK})${NC}"

# 3. Configure plasmalogin to preselect Plasma Wayland
echo ""
echo -e "${BOLD}${BLUE}[3/5] Configuring Display Manager for Plasma Wayland...${NC}"
PLASMALogin_CONF_D="/etc/plasmalogin.conf.d"
CONF_FILE="$PLASMALogin_CONF_D/10-preselect-x11.conf"

if [ "$EUID" -eq 0 ]; then
    mkdir -p "$PLASMALogin_CONF_D"
    echo -e "[Greeter]
PreselectedSession=plasma.desktop" > "$CONF_FILE"
    sed -i 's/^Session=.*/Session=plasma.desktop/' /etc/plasmalogin.conf 2>/dev/null || true
else
    echo -e "      Updating plasmalogin configuration requires administrator privileges."
    if [ -t 0 ]; then
        sudo bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasma.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasma.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasma.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasma.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    elif command -v kdesu >/dev/null 2>&1; then
        kdesu -- bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasma.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasma.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    else
        sudo bash -c "mkdir -p '$PLASMALogin_CONF_D' && echo '[Greeter]' > '$CONF_FILE' && echo 'PreselectedSession=plasma.desktop' >> '$CONF_FILE' && sed -i 's/^Session=.*/Session=plasma.desktop/' /etc/plasmalogin.conf 2>/dev/null || true"
    fi
fi
echo -e "${GREEN}[✓] Plasma Wayland (plasma.desktop) preselected for next session.${NC}"

# 4. Gracefully close X11 background applications (preserving terminal/manager)
echo ""
echo -e "${BOLD}${BLUE}[4/5] Closing open desktop application windows...${NC}"
if [ -x "/home/mplanetarian/Desktop/DESKTOP/close_allapps.sh" ]; then
    /home/mplanetarian/Desktop/DESKTOP/close_allapps.sh >/dev/null 2>&1 || true
fi
pkill -f "play_defasten" 2>/dev/null || true
pkill -f "Defasten" 2>/dev/null || true
echo -e "${GREEN}[✓] Background media players and applications closed.${NC}"

# 5. Prompt to switch session (logout)
echo ""
echo -e "${BOLD}${BLUE}[5/5] Ready to switch to Plasma Wayland!${NC}"
echo -e "      ${YELLOW}When you log in to Wayland:${NC}"
echo -e "      • ${GREEN}Hisense 4K Display will be set as Default / Primary with HDR enabled${NC}"
echo -e "      • ${GREEN}GA102 HDMI ALSA Audio will remain active${NC}"
echo -e "      • ${GREEN}Steam Big Picture Mode (Gamepad UI) will launch automatically${NC}"
echo -e "      • ${GREEN}Defasten videos and background tools will NOT run${NC}"
echo ""

read -r -p "Log out of X11 now to enter Plasma Wayland? [Y/n]: " response
response=${response:-Y}

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BOLD}${GREEN}Logging out of current X11 session... See you in Plasma Wayland!${NC}"
    sleep 1
    if command -v qdbus >/dev/null 2>&1; then
        qdbus org.kde.Shutdown /Shutdown logout || loginctl terminate-session "$XDG_SESSION_ID"
    else
        loginctl terminate-session "$XDG_SESSION_ID"
    fi
else
    echo ""
    echo -e "${CYAN}Configuration saved! Next time you log out or restart, Plasma Wayland will be active.${NC}"
    read -rp "Press [Enter] to exit..."
fi
