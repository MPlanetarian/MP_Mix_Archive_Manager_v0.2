#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.1 - Cross-Platform Automated Installer
# Supports Linux (Bazzite / SteamOS / Fedora / Ubuntu), macOS, and Windows
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}        Mix Archive Manager Installer (MP_Mix_Manager_v0.1)           ${NC}"
echo -e "${BOLD}${MAGENTA}          Cross-Platform: Linux • macOS • Windows 10 & 11             ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo ""

# 1. Detect Host Environment
echo -e "${BOLD}${BLUE}[1/7] Detecting Host Platform & Environment...${NC}"
HOST_OS="linux"
case "$(uname -s)" in
    Darwin*)
        HOST_OS="macos"
        MAC_VER=$(sw_vers -productVersion 2>/dev/null || uname -r)
        MAC_ARCH=$(uname -m)
        echo -e "      Platform:     ${GREEN}Apple macOS${NC} (${CYAN}${MAC_VER}${NC}, ${MAC_ARCH})"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        HOST_OS="windows"
        echo -e "      Platform:     ${GREEN}Microsoft Windows${NC} (Git Bash / MSYS2)"
        ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            HOST_OS="wsl"
            echo -e "      Platform:     ${GREEN}Microsoft Windows${NC} (WSL2 Linux Subsystem)"
        else
            HOST_OS="linux"
            if [ -f /etc/os-release ]; then
                # shellcheck source=/dev/null
                source /etc/os-release
                echo -e "      Platform:     ${GREEN}Linux${NC} (${CYAN}${PRETTY_NAME:-Linux}${NC})"
                if [[ "${ID:-}" == *"bazzite"* ]] || [[ "${VARIANT_ID:-}" == *"bazzite"* ]] || [[ "${NAME:-}" == *"Bazzite"* ]]; then
                    echo -e "${GREEN}      ✓ Verified Bazzite Linux environment.${NC}"
                fi
            else
                echo -e "      Platform:     ${GREEN}Generic Linux${NC}"
            fi
        fi
        ;;
    *)
        HOST_OS="linux"
        echo -e "      Platform:     ${YELLOW}Unknown (${OS})${NC}"
        ;;
esac
echo ""

# 2. Ensure Executable Permissions
echo -e "${BOLD}${BLUE}[2/7] Configuring Script & Binary Permissions...${NC}"
chmod +x "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/*.command "$SCRIPT_DIR"/bin/* 2>/dev/null || true
if [ -d "$SCRIPT_DIR/scripts" ]; then
    chmod +x "$SCRIPT_DIR"/scripts/*.sh 2>/dev/null || true
fi
chmod +x "$SCRIPT_DIR"/bin/cliamp 2>/dev/null || true
echo -e "${GREEN}      ✓ Executable permissions granted across all scripts and tools.${NC}"
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
echo -e "${GREEN}      ✓ Archive, output, and log directories ready.${NC}"
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
)

MISSING_TOOLS=()
for tool in "${!TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "      [${GREEN}FOUND${NC}] $tool"
    else
        echo -e "      [${RED}MISSING${NC}] ${BOLD}$tool${NC} (${TOOLS[$tool]})"
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    if [ "$HOST_OS" = "macos" ]; then
        echo -e "${YELLOW}      To install missing dependencies on macOS using Homebrew, run:${NC}"
        echo -e "${CYAN}      brew install ${MISSING_TOOLS[*]}${NC}"
        echo -e "${DIM}      Optional GUI apps: brew install --cask vlc audacity strawberry musicbrainz-picard gimp reaper${NC}"
    elif [ "$HOST_OS" = "windows" ] || [ "$HOST_OS" = "wsl" ]; then
        echo -e "${YELLOW}      To install missing dependencies on Windows using winget, run:${NC}"
        echo -e "${CYAN}      winget install Gyan.FFmpeg Rclone.Rclone jqlang.jq${NC}"
        echo -e "${DIM}      Optional GUI apps: winget install VideoLAN.VLC Audacity.Audacity MusicBrainz.Picard GIMP.GIMP Cockos.REAPER${NC}"
    else
        echo -e "${YELLOW}      To install missing dependencies on Linux, run:${NC}"
        echo -e "${CYAN}      brew install ${MISSING_TOOLS[*]}${NC}  (or use your system package manager)"
    fi
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
echo -e "${BOLD}${BLUE}[6/7] Installing Local User Symlinks & Launchers...${NC}"
mkdir -p "$HOME/.local/bin"

ln -sf "$SCRIPT_DIR/bin/cliamp" "$HOME/.local/bin/cliamp" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/mix-archive-manager" "$HOME/.local/bin/mix-archive-manager" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/mix-archive-manager" "$HOME/.local/bin/manager" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/launch-manager-fullscreen" "$HOME/.local/bin/launch-manager-fullscreen" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/transfer-monitor" "$HOME/.local/bin/transfer-monitor" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/chrome-upload-monitor" "$HOME/.local/bin/chrome-upload-monitor" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/update-nft-playlist" "$HOME/.local/bin/update-nft-playlist" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/watch-nft-copy-and-update.sh" "$HOME/.local/bin/watch-nft-copy-and-update.sh" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/list-midi-devices" "$HOME/.local/bin/list-midi-devices" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/Cut_Video.sh" "$HOME/.local/bin/cut-video" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$HOME/manager.sh" 2>/dev/null || true

echo -e "${GREEN}      ✓ Installed symlinks into ~/.local/bin and ~/manager.sh.${NC}"
echo ""

# 7. Desktop Integration
echo -e "${BOLD}${BLUE}[7/7] Installing Desktop Integration...${NC}"
if [ "$HOST_OS" = "macos" ]; then
    if [ -d "$HOME/Desktop" ]; then
        ln -sf "$SCRIPT_DIR/manager_macos.command" "$HOME/Desktop/Mix Archive Manager.command" 2>/dev/null || cp -p "$SCRIPT_DIR/manager_macos.command" "$HOME/Desktop/Mix Archive Manager.command"
        echo -e "${GREEN}      ✓ Created double-clickable desktop launcher: ~/Desktop/Mix Archive Manager.command${NC}"
    fi
elif [ "$HOST_OS" = "windows" ] || [ "$HOST_OS" = "wsl" ]; then
    WIN_DESKTOP=""
    if [ -d "$HOME/Desktop" ]; then
        WIN_DESKTOP="$HOME/Desktop"
    elif [ -n "${USERPROFILE:-}" ] && [ -d "$USERPROFILE/Desktop" ]; then
        WIN_DESKTOP="$USERPROFILE/Desktop"
    elif [ -d "/c/Users/$USER/Desktop" ]; then
        WIN_DESKTOP="/c/Users/$USER/Desktop"
    fi
    if [ -n "$WIN_DESKTOP" ]; then
        cp -p "$SCRIPT_DIR/manager.bat" "$WIN_DESKTOP/Mix Archive Manager.bat" 2>/dev/null || true
        echo -e "${GREEN}      ✓ Placed Windows launcher shortcut on Desktop.${NC}"
    fi
else
    # Linux Desktop Entry (.desktop)
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
fi

echo ""
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}              MIX ARCHIVE MANAGER INSTALLATION COMPLETE!              ${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}"
echo ""
echo -e "You can launch Mix Archive Manager:"
if [ "$HOST_OS" = "macos" ]; then
    echo -e "  1. Double-click:                  ${BOLD}${CYAN}~/Desktop/Mix Archive Manager.command${NC}"
    echo -e "  2. Terminal command:              ${BOLD}${CYAN}manager${NC} or ${BOLD}${CYAN}~/manager.sh${NC}"
    echo -e "  3. Launch directly from source:   ${BOLD}${CYAN}cd $SCRIPT_DIR && ./manager_macos.command${NC}"
elif [ "$HOST_OS" = "windows" ] || [ "$HOST_OS" = "wsl" ]; then
    echo -e "  1. Double-click on Windows:       ${BOLD}${CYAN}manager.bat${NC} or ${BOLD}${CYAN}manager.ps1${NC}"
    echo -e "  2. Run inside Git Bash / MSYS2:   ${BOLD}${CYAN}./Mix_Archive_Manager.sh${NC}"
    echo -e "  3. Run inside WSL2:               ${BOLD}${CYAN}./Mix_Archive_Manager.sh${NC}"
else
    echo -e "  1. Run from anywhere in terminal: ${BOLD}${CYAN}manager${NC} or ${BOLD}${CYAN}~/manager.sh${NC}"
    echo -e "  2. Launch directly from source:   ${BOLD}${CYAN}cd $SCRIPT_DIR && ./Mix_Archive_Manager.sh${NC}"
    echo -e "  3. Open from Desktop or Menu:     ${BOLD}${CYAN}Mix Archive Manager${NC}"
fi
echo ""
