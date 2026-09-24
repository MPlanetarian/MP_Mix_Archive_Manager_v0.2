#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Cross-Platform Automated Installer
# Supports Linux (Bazzite / SteamOS / Fedora / Ubuntu), macOS, and Windows
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}        Mix Archive Manager Installer (MP_Mix_Manager_v0.3)           ${NC}"
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
    FreeBSD*)
        HOST_OS="freebsd"
        echo -e "      Platform:     ${GREEN}FreeBSD${NC} ($(uname -r), $(uname -m))"
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
    chmod +x "$SCRIPT_DIR"/scripts/*.sh "$SCRIPT_DIR"/scripts/*.py 2>/dev/null || true
fi
chmod +x "$SCRIPT_DIR"/bin/cliamp 2>/dev/null || true
echo -e "${GREEN}      ✓ Executable permissions granted across all scripts and tools.${NC}"
echo ""

# 3. Create Scaffold Working Directories
echo -e "${BOLD}${BLUE}[3/7] Setting Up Archive Directory Structure...${NC}"
mkdir -p "$SCRIPT_DIR"/{FLAC_CONVERTED_OUTPUTS,MP3_CONVERTED_OUTPUTS,WAV_CONVERTED_OUTPUTS,MP4_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,SPEK_OUTPUTS,BACKUP_LOGS,VERIFY_LOGS,IMPORT_LOGS,COVERS,config_backups,exported_configs}
touch "$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/MP3_CONVERTED_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/WAV_CONVERTED_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/MP4_CONVERTED_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/CONVERTED_WAV_FILES/.gitkeep"
touch "$SCRIPT_DIR/SPEK_OUTPUTS/.gitkeep"
touch "$SCRIPT_DIR/BACKUP_LOGS/.gitkeep"
touch "$SCRIPT_DIR/VERIFY_LOGS/.gitkeep"
touch "$SCRIPT_DIR/IMPORT_LOGS/.gitkeep"
touch "$SCRIPT_DIR/COVERS/.gitkeep"
touch "$SCRIPT_DIR/config_backups/.gitkeep"
touch "$SCRIPT_DIR/exported_configs/.gitkeep"
echo -e "${GREEN}      ✓ Archive, output, and log directories ready.${NC}"
echo ""

# 4. Check & Report Dependencies
echo -e "${BOLD}${BLUE}[4/7] Checking System Dependencies...${NC}"
TOOLS_LIST=(
    "ffmpeg:Audio/video conversion, encoding, and integrity verification"
    "ffprobe:Audio stream duration and codec inspection"
    "sox:Spectrogram and high-resolution signal processing"
    "flac:Native lossless audio encoding and decoding"
    "rclone:Automated Google Drive and cloud synchronisation"
    "jq:JSON parser for cliamp and system inspection"
)

MISSING_TOOLS=()
for item in "${TOOLS_LIST[@]}"; do
    tool="${item%%:*}"
    desc="${item#*:}"
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "      [${GREEN}FOUND${NC}] $tool"
    else
        echo -e "      [${RED}MISSING${NC}] ${BOLD}$tool${NC} ($desc)"
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
    elif [ "$HOST_OS" = "freebsd" ]; then
        echo -e "${YELLOW}      To install missing dependencies on FreeBSD using pkg, run:${NC}"
        echo -e "${CYAN}      pkg install -y ${MISSING_TOOLS[*]} spek btop${NC}"
        echo -e "${DIM}      Optional GUI apps: pkg install -y vlc audacity spek gimp reaper${NC}"
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
ln -sf "$SCRIPT_DIR/scripts/view_tracklist_console.sh" "$HOME/.local/bin/view-tracklist" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/inspect_playing_audio.sh" "$HOME/.local/bin/view-mix-specs" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/bin/traktor-monitor" "$HOME/.local/bin/traktor-monitor" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/traktor_monitor.sh" "$HOME/.local/bin/traktor_monitor.sh" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/Cut_Video.sh" "$HOME/.local/bin/cut-video" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/Split_FLAC_File.sh" "$HOME/.local/bin/split-flac" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/Split_Video_File.sh" "$HOME/.local/bin/split-video" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/kc_start_wan2gp_profile45.sh" "$HOME/.local/bin/wan2gp-start-profile45" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/kc_stop_wan2gp.sh" "$HOME/.local/bin/wan2gp-stop" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/kc_run_ollama_serve.sh" "$HOME/.local/bin/ollama-serve" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/kc_stop_ollama.sh" "$HOME/.local/bin/ollama-stop" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/manage_ollama.sh" "$HOME/.local/bin/manage-ollama" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/kc_launch_beszel_hub_and_agent.sh" "$HOME/.local/bin/beszel-hub-and-agent" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/beszel.sh" "$HOME/.local/bin/beszel" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/dsh_mobile.sh" "$HOME/.local/bin/dsh-mobile" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/dsh_mobile.sh" "$HOME/.local/bin/manage-dsh-mobile" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/scripts/kc_run_aider_qwen.sh" "$HOME/.local/bin/aider-qwen" 2>/dev/null || true
ln -sf "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$HOME/manager.sh" 2>/dev/null || true

echo -e "${GREEN}      ✓ Installed symlinks into ~/.local/bin and ~/manager.sh.${NC}"

# Register KWin Borderless Window Rule on Bazzite / KDE Plasma
if [ "$HOST_OS" = "linux" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "
import configparser, os, uuid, subprocess

rc_path = os.path.expanduser('~/.config/kwinrulesrc')
if not os.path.exists(rc_path):
    os.makedirs(os.path.dirname(rc_path), exist_ok=True)
    with open(rc_path, 'w') as f:
        f.write('[General]\ncount=0\nrules=\n')

cp = configparser.ConfigParser()
cp.read(rc_path)

rule_desc = 'Mix Tracklist Viewer (Borderless)'
found = False
for sec in cp.sections():
    if cp.has_option(sec, 'description') and cp.get(sec, 'description') == rule_desc:
        found = True
        break

if not found:
    new_uuid = str(uuid.uuid4())
    cp.add_section(new_uuid)
    cp.set(new_uuid, 'description', rule_desc)
    cp.set(new_uuid, 'wmclass', 'konsole')
    cp.set(new_uuid, 'wmclassmatch', '1')
    cp.set(new_uuid, 'title', 'Mix Tracklist Viewer')
    cp.set(new_uuid, 'titlematch', '1')
    cp.set(new_uuid, 'types', '1')
    cp.set(new_uuid, 'noborder', 'true')
    cp.set(new_uuid, 'noborderrule', '2')

    if not cp.has_section('General'):
        cp.add_section('General')
    count = int(cp.get('General', 'count', fallback='0')) + 1
    cp.set('General', 'count', str(count))
    existing_rules = cp.get('General', 'rules', fallback='')
    rules_list = [r.strip() for r in existing_rules.split(',') if r.strip()]
    rules_list.append(new_uuid)
    cp.set('General', 'rules', ','.join(rules_list))

    with open(rc_path, 'w') as f:
        cp.write(f)

    if os.path.exists('/usr/bin/qdbus'):
        subprocess.run(['/usr/bin/qdbus', 'org.kde.KWin', '/KWin', 'reconfigure'], capture_output=True)
" 2>/dev/null || true
    echo -e "${GREEN}      ✓ Configured KWin borderless console window rule for Bazzite / KDE.${NC}"
fi
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
    # Linux Desktop Entries (.desktop)
    mkdir -p "$HOME/.local/share/applications"
    for _dentry in "Mix_Archive_Manager.desktop" "wan2gp-start-profile45.desktop" "wan2gp-stop.desktop" "ollama-serve.desktop" "ollama-stop.desktop" "beszel-hub-and-agent.desktop" "dsh-mobile.desktop"; do
        if [ -f "$SCRIPT_DIR/desktop/$_dentry" ]; then
            cp -p "$SCRIPT_DIR/desktop/$_dentry" "$HOME/.local/share/applications/$_dentry"
            if [ -d "$HOME/Desktop" ]; then
                cp -p "$SCRIPT_DIR/desktop/$_dentry" "$HOME/Desktop/$_dentry"
                chmod +x "$HOME/Desktop/$_dentry" 2>/dev/null || true
            fi
        fi
    done
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    echo -e "${GREEN}      ✓ Application, WAN2GP, Ollama, Beszel, and dsh-mobile shortcuts installed.${NC}"

    # Sync KDE Connect command scripts if directory exists
    if [ -d "$HOME/KDE_CONNECT_CMDS" ]; then
        cp -p "$SCRIPT_DIR/scripts/kc_start_wan2gp_profile45.sh" "$HOME/KDE_CONNECT_CMDS/kc_start_wan2gp_profile45.sh" 2>/dev/null || true
        cp -p "$SCRIPT_DIR/scripts/kc_stop_wan2gp.sh" "$HOME/KDE_CONNECT_CMDS/kc_stop_wan2gp.sh" 2>/dev/null || true
        cp -p "$SCRIPT_DIR/scripts/kc_run_ollama_serve.sh" "$HOME/KDE_CONNECT_CMDS/kc_run_ollama_serve.sh" 2>/dev/null || true
        cp -p "$SCRIPT_DIR/scripts/kc_stop_ollama.sh" "$HOME/KDE_CONNECT_CMDS/kc_stop_ollama.sh" 2>/dev/null || true
        cp -p "$SCRIPT_DIR/scripts/kc_launch_beszel_hub_and_agent.sh" "$HOME/KDE_CONNECT_CMDS/kc_launch_beszel_hub_and_agent.sh" 2>/dev/null || true
        cp -p "$SCRIPT_DIR/scripts/kc_launch_dsh_mobile.sh" "$HOME/KDE_CONNECT_CMDS/kc_launch_dsh_mobile.sh" 2>/dev/null || true
        chmod +x "$HOME/KDE_CONNECT_CMDS/kc_start_wan2gp_profile45.sh" "$HOME/KDE_CONNECT_CMDS/kc_stop_wan2gp.sh" "$HOME/KDE_CONNECT_CMDS/kc_run_ollama_serve.sh" "$HOME/KDE_CONNECT_CMDS/kc_stop_ollama.sh" "$HOME/KDE_CONNECT_CMDS/kc_launch_beszel_hub_and_agent.sh" "$HOME/KDE_CONNECT_CMDS/kc_launch_dsh_mobile.sh" 2>/dev/null || true
        echo -e "${GREEN}      ✓ Synced KDE Connect scripts to ~/KDE_CONNECT_CMDS.${NC}"
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
