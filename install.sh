#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.1 - Automated Installer for Bazzite Linux
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}        Mix Archive Manager Installer (MP_Mix_Manager_v0.1)           ${NC}"
echo -e "${BOLD}${MAGENTA}                   Tailored for Bazzite Linux / SteamOS               ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo ""

# 1. Verify Bazzite / Fedora Atomic Environment
echo -e "${BOLD}${BLUE}[1/7] Detecting Host Environment...${NC}"
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    echo -e "      OS: ${CYAN}${PRETTY_NAME:-Linux}${NC}"
    if [[ "${ID:-}" != *"bazzite"* ]] && [[ "${VARIANT_ID:-}" != *"bazzite"* ]] && [[ "${NAME:-}" != *"Bazzite"* ]]; then
        echo -e "${YELLOW}      Notice: System does not identify as Bazzite. Continuing installation in compatibility mode.${NC}"
    else
        echo -e "${GREEN}      ✓ Verified Bazzite Linux installation.${NC}"
    fi
else
    echo -e "${YELLOW}      Notice: /etc/os-release not found. Continuing.${NC}"
fi
echo ""

# 2. Ensure Executable Permissions
echo -e "${BOLD}${BLUE}[2/7] Configuring Script & Binary Permissions...${NC}"
chmod +x "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/bin/* 2>/dev/null || true
if [ -d "$SCRIPT_DIR/scripts" ]; then
    chmod +x "$SCRIPT_DIR"/scripts/*.sh 2>/dev/null || true
fi
chmod +x "$SCRIPT_DIR"/bin/cliamp 2>/dev/null || true
echo -e "${GREEN}      ✓ Executable permissions granted.${NC}"
echo ""

# 3. Create Scaffold Working Directories
echo -e "${BOLD}${BLUE}[3/7] Setting Up Archive Directory Structure...${NC}"
mkdir -p "$SCRIPT_DIR"/{FLAC_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,SPEK_OUTPUTS,BACKUP_LOGS,VERIFY_LOGS,IMPORT_LOGS,COVERS}
touch "$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/CONVERTED_WAV_FILES/.gitkeep"
touch "$SCRIPT_DIR/SPEK_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/BACKUP_LOGS/.gitkeep"
touch "$SCRIPT_DIR/VERIFY_LOGS/.gitkeep"
touch "$SCRIPT_DIR/IMPORT_LOGS/.gitkeep"
touch "$SCRIPT_DIR/COVERS/.gitkeep"
echo -e "${GREEN}      ✓ Archive and log directories ready.${NC}"
echo ""

# 4. Check & Report Dependencies
echo -e "${BOLD}${BLUE}[4/7] Checking System Dependencies...${NC}"
declare -A TOOLS=(
    ["ffmpeg"]="Audio/video conversion, encoding, and integrity verification"
    ["ffprobe"]="Audio stream duration and codec inspection"
    ["sox"]="Spectrogram and high-resolution signal processing"
    ["flac"]="Native lossless audio encoding and decoding"
    ["rclone"]="Automated Google Drive and cloud synchronisation"
    ["jq"]="JSON parser for cliamp and system inspection"
    ["wmctrl"]="Window management and graceful process shielding"
    ["btop"]="High-performance terminal system resource monitor"
    ["nvtop"]="NVIDIA/GPU process and hardware monitor"
    ["konsole"]="KDE Plasma terminal emulator"
    ["nft"]="Nftables firewall management for internet toggle"
)

MISSING_BREW=()
for tool in "${!TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "      [${GREEN}FOUND${NC}] $tool"
    else
        echo -e "      [${RED}MISSING${NC}] ${BOLD}$tool${NC} (${TOOLS[$tool]})"
        if [ "$tool" != "konsole" ] && [ "$tool" != "nft" ]; then
            MISSING_BREW+=("$tool")
        fi
    fi
done

if [ ${#MISSING_BREW[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}      To install missing command-line dependencies on Bazzite, run:${NC}"
    echo -e "${CYAN}      brew install ${MISSING_BREW[*]}${NC}"
fi
echo ""

# 5. User Configuration Setup
echo -e "${BOLD}${BLUE}[5/7] Checking Configuration File...${NC}"
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    if [ -f "$SCRIPT_DIR/config.env.example" ]; then
        cp "$SCRIPT_DIR/config.env.example" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}      ✓ Created default config.env from template.${NC}"
    fi
else
    echo -e "${GREEN}      ✓ Active config.env found.${NC}"
fi
echo ""

# 6. Install Global/Local User Symlinks
echo -e "${BOLD}${BLUE}[6/7] Installing Local User Symlinks (~/.local/bin)...${NC}"
mkdir -p "$HOME/.local/bin"

ln -sf "$SCRIPT_DIR/bin/cliamp" "$HOME/.local/bin/cliamp"
ln -sf "$SCRIPT_DIR/bin/mix-archive-manager" "$HOME/.local/bin/mix-archive-manager"
ln -sf "$SCRIPT_DIR/bin/mix-archive-manager" "$HOME/.local/bin/manager"
ln -sf "$SCRIPT_DIR/bin/launch-manager-fullscreen" "$HOME/.local/bin/launch-manager-fullscreen"
ln -sf "$SCRIPT_DIR/bin/transfer-monitor" "$HOME/.local/bin/transfer-monitor"
ln -sf "$SCRIPT_DIR/bin/chrome-upload-monitor" "$HOME/.local/bin/chrome-upload-monitor"
ln -sf "$SCRIPT_DIR/bin/update-nft-playlist" "$HOME/.local/bin/update-nft-playlist"
ln -sf "$SCRIPT_DIR/bin/watch-nft-copy-and-update.sh" "$HOME/.local/bin/watch-nft-copy-and-update.sh"
ln -sf "$SCRIPT_DIR/bin/list-midi-devices" "$HOME/.local/bin/list-midi-devices"
ln -sf "$SCRIPT_DIR/Cut_Video.sh" "$HOME/.local/bin/cut-video"
ln -sf "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$HOME/manager.sh"

echo -e "${GREEN}      ✓ Installed symlinks into ~/.local/bin and ~/manager.sh.${NC}"
echo ""

# 7. Desktop Entry Installation
echo -e "${BOLD}${BLUE}[7/7] Installing Desktop Integration...${NC}"
mkdir -p "$HOME/.local/share/applications"
DESKTOP_SRC="$SCRIPT_DIR/desktop/Mix_Archive_Manager.desktop"

if [ -f "$DESKTOP_SRC" ]; then
    cp -p "$DESKTOP_SRC" "$HOME/.local/share/applications/Mix_Archive_Manager.desktop"
    if [ -d "$HOME/Desktop" ]; then
        cp -p "$DESKTOP_SRC" "$HOME/Desktop/Mix_Archive_Manager.desktop"
        chmod +x "$HOME/Desktop/Mix_Archive_Manager.desktop" 2>/dev/null || true
    fi
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    echo -e "${GREEN}      ✓ Mix Archive Manager application shortcut installed.${NC}"
fi

echo ""
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}              MIX ARCHIVE MANAGER INSTALLATION COMPLETE!              ${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo ""
echo -e "You can launch Mix Archive Manager in three ways:"
echo -e "  1. Run from anywhere in terminal: ${BOLD}${CYAN}manager${NC} or ${BOLD}${CYAN}~/manager.sh${NC}"
echo -e "  2. Launch directly from source:   ${BOLD}${CYAN}cd $SCRIPT_DIR && ./Mix_Archive_Manager.sh${NC}"
echo -e "  3. Open from Desktop or Application Menu: ${BOLD}${CYAN}Mix Archive Manager${NC}"
echo ""
