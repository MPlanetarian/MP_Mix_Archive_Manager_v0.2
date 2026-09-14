#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Installation Migration & Configuration Management Suite
# Handles:
#   1. Migration of Mix Manager installation to a new directory path
#   2. Timestamped configuration backups
#   3. Portable configuration bundle export (.tar.gz with manifest & checksums)
#   4. Safe configuration bundle import with automated pre-import safety backups
#   5. Listing and restoring historical configuration snapshots
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="$HOME/.config/mix-manager/backups"
EXPORT_BASE_DIR="$HOME/.config/mix-manager/exports"
mkdir -p "$BACKUP_BASE_DIR" "$EXPORT_BASE_DIR" 2>/dev/null || true

# Detect platform
OS_TYPE="linux"
case "$(uname -s)" in
    Darwin*) OS_TYPE="macos" ;;
    CYGWIN*|MINGW*|MSYS*) OS_TYPE="windows" ;;
    FreeBSD*) OS_TYPE="freebsd" ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS_TYPE="wsl"
        else
            OS_TYPE="linux"
        fi
        ;;
esac

press_enter() {
    echo ""
    echo -e "${DIM}Press [Enter] to return to menu...${NC}"
    read -r -s -d $'\n' || true
}

compute_sha256() {
    local target="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$target" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$target" | awk '{print $1}'
    else
        python3 -c "import hashlib, sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$target"
    fi
}

# ------------------------------------------------------------------------------
# 1. MIGRATE INSTALLATION PATH
# ------------------------------------------------------------------------------
migrate_installation_path() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}           Migrate Mix Archive Manager Installation Path              ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  Current Installation Path: ${BOLD}${GREEN}${SCRIPT_DIR}${NC}"
    
    local inst_size
    inst_size=$(du -sh "$SCRIPT_DIR" 2>/dev/null | awk '{print $1}' || echo "Unknown")
    echo -e "  Codebase Disk Footprint:   ${CYAN}${inst_size}${NC}"
    echo -e "  Detected Host OS:          ${CYAN}${OS_TYPE}${NC}"
    echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
    echo -e "This wizard relocates the entire Mix Manager codebase to a new path"
    echo -e "and automatically updates all desktop shortcuts, terminal wrappers, and symlinks."
    echo ""
    echo -e "${BOLD}Choose Target Destination:${NC}"
    echo -e "  ${BOLD}${CYAN} 1)${NC} Home User Directory      ${DIM}($HOME/Mix_Archive_Manager)${NC}"
    echo -e "  ${BOLD}${CYAN} 2)${NC} External Archive Drive   ${DIM}(/run/media/$USER/WD BLACK B/MP_Mix_Manager_v0.2)${NC}"
    echo -e "  ${BOLD}${CYAN} 3)${NC} System Optional Directory ${DIM}(/opt/MP_Mix_Manager_v0.2)${NC}"
    echo -e "  ${BOLD}${CYAN} 4)${NC} Custom Directory Path..."
    echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel & Return"
    echo ""
    read -r -p "Select destination option [1-4, 0 to cancel]: " dest_opt
    
    local target_dir=""
    case "$dest_opt" in
        1) target_dir="$HOME/Mix_Archive_Manager" ;;
        2) target_dir="/run/media/$USER/WD BLACK B/MP_Mix_Manager_v0.2" ;;
        3) target_dir="/opt/MP_Mix_Manager_v0.2" ;;
        4)
            read -r -p "Enter custom absolute target directory path: " target_dir
            ;;
        0|*)
            echo -e "\n${YELLOW}Migration cancelled.${NC}"
            sleep 1
            return
            ;;
    esac
    
    target_dir="${target_dir%/}"
    if [ -z "$target_dir" ]; then
        echo -e "\n${RED}Error: Empty destination path provided.${NC}"
        press_enter
        return
    fi
    
    if [ "$target_dir" = "$SCRIPT_DIR" ]; then
        echo -e "\n${RED}Error: Target path is identical to the current installation path!${NC}"
        press_enter
        return
    fi
    
    # Verify target parent directory writable
    local target_parent
    target_parent="$(dirname "$target_dir")"
    if [ ! -d "$target_parent" ]; then
        mkdir -p "$target_parent" 2>/dev/null || {
            echo -e "\n${RED}Error: Cannot create parent directory '$target_parent'. Check permissions.${NC}"
            press_enter
            return
        }
    fi
    
    # Check free disk space at target
    local avail_kb
    avail_kb=$(df -k "$target_parent" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [ "$avail_kb" -lt 500000 ]; then # Less than 500MB
        echo -e "\n${RED}Error: Insufficient free disk space at target location! Available: ${avail_kb} KB${NC}"
        press_enter
        return
    fi
    
    echo ""
    echo -e "${BOLD}Select Migration Mode:${NC}"
    echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}Copy & Switch Active${NC} ${GREEN}(Recommended: Keeps original as safety backup)${NC}"
    echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}Relocate & Archive Old Path${NC} ${YELLOW}(Copies, repoints symlinks, renames old path to .bak)${NC}"
    echo ""
    read -r -p "Select mode [1 or 2, default 1]: " mode_opt
    mode_opt="${mode_opt:-1}"
    
    echo -e "\n${BOLD}${BLUE}Starting Codebase Transfer to ${target_dir}...${NC}"
    mkdir -p "$target_dir"
    
    # Perform rsync transfer with fallback
    if command -v rsync >/dev/null 2>&1; then
        rsync -aHAX --info=progress2 --exclude="*.log" "$SCRIPT_DIR/" "$target_dir/"
    else
        cp -a "$SCRIPT_DIR/." "$target_dir/"
    fi
    
    # Ensure executables
    chmod +x "$target_dir"/*.sh "$target_dir"/*.command "$target_dir"/bin/* 2>/dev/null || true
    if [ -d "$target_dir/scripts" ]; then
        chmod +x "$target_dir"/scripts/*.sh 2>/dev/null || true
    fi
    
    # Repoint system launchers and symlinks
    echo -e "\n${BOLD}${BLUE}Updating System Symlinks & Desktop Entries...${NC}"
    mkdir -p "$HOME/.local/bin"
    
    ln -sf "$target_dir/bin/cliamp" "$HOME/.local/bin/cliamp" 2>/dev/null || true
    ln -sf "$target_dir/bin/mix-archive-manager" "$HOME/.local/bin/mix-archive-manager" 2>/dev/null || true
    ln -sf "$target_dir/bin/mix-archive-manager" "$HOME/.local/bin/manager" 2>/dev/null || true
    ln -sf "$target_dir/bin/launch-manager-fullscreen" "$HOME/.local/bin/launch-manager-fullscreen" 2>/dev/null || true
    ln -sf "$target_dir/bin/transfer-monitor" "$HOME/.local/bin/transfer-monitor" 2>/dev/null || true
    ln -sf "$target_dir/bin/chrome-upload-monitor" "$HOME/.local/bin/chrome-upload-monitor" 2>/dev/null || true
    ln -sf "$target_dir/bin/update-nft-playlist" "$HOME/.local/bin/update-nft-playlist" 2>/dev/null || true
    ln -sf "$target_dir/bin/watch-nft-copy-and-update.sh" "$HOME/.local/bin/watch-nft-copy-and-update.sh" 2>/dev/null || true
    ln -sf "$target_dir/bin/list-midi-devices" "$HOME/.local/bin/list-midi-devices" 2>/dev/null || true
    ln -sf "$target_dir/Cut_Video.sh" "$HOME/.local/bin/cut-video" 2>/dev/null || true
    ln -sf "$target_dir/Mix_Archive_Manager.sh" "$HOME/manager.sh" 2>/dev/null || true
    
    # Desktop Shortcut Updates
    if [ "$OS_TYPE" = "macos" ]; then
        if [ -d "$HOME/Desktop" ]; then
            ln -sf "$target_dir/manager_macos.command" "$HOME/Desktop/Mix Archive Manager.command" 2>/dev/null || true
        fi
    elif [ "$OS_TYPE" = "linux" ] || [ "$OS_TYPE" = "freebsd" ]; then
        local desktop_file="$HOME/.local/share/applications/Mix_Archive_Manager.desktop"
        if [ -f "$desktop_file" ]; then
            sed -i "s|elif \[ -x \".*Mix_Archive_Manager.sh\" \]|elif [ -x \"$target_dir/Mix_Archive_Manager.sh\" ]|g" "$desktop_file" 2>/dev/null || true
        fi
        if [ -f "$HOME/Desktop/Mix_Archive_Manager.desktop" ]; then
            sed -i "s|elif \[ -x \".*Mix_Archive_Manager.sh\" \]|elif [ -x \"$target_dir/Mix_Archive_Manager.sh\" ]|g" "$HOME/Desktop/Mix_Archive_Manager.desktop" 2>/dev/null || true
        fi
        command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    if [ "$mode_opt" = "2" ]; then
        local old_bak="${SCRIPT_DIR}.archived_$(date +%Y%m%d_%H%M%S)"
        echo -e "Archiving previous location to: ${old_bak}..."
        mv "$SCRIPT_DIR" "$old_bak" 2>/dev/null || true
    fi
    
    echo ""
    echo -e "${BOLD}${GREEN}======================================================================${NC}"
    echo -e "${BOLD}${GREEN}           INSTALLATION MIGRATION COMPLETED SUCCESSFULLY!             ${NC}"
    echo -e "${BOLD}${GREEN}======================================================================${NC}"
    echo -e "  New Installation Directory: ${BOLD}${CYAN}${target_dir}${NC}"
    echo -e "  Main Executable:            ${BOLD}${CYAN}${target_dir}/Mix_Archive_Manager.sh${NC}"
    echo -e "  CLI Launchers Repointed:    ${GREEN}~/.local/bin/mix-archive-manager, ~/manager.sh${NC}"
    echo -e "  Desktop Shortcuts:          ${GREEN}Updated to target new directory${NC}"
    echo ""
    echo -e "To start the manager from its new home, run:"
    echo -e "  ${BOLD}${YELLOW}manager${NC}  or  ${BOLD}${YELLOW}${target_dir}/Mix_Archive_Manager.sh${NC}"
    press_enter
}

# ------------------------------------------------------------------------------
# 2. BACKUP CURRENT CONFIGURATION
# ------------------------------------------------------------------------------
backup_current_config() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}              Create Instant Configuration Snapshot                   ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local snap_dir="$BACKUP_BASE_DIR/backup_${timestamp}"
    mkdir -p "$snap_dir"
    
    local files_backed_up=0
    local manifest_files="[]"
    
    # 1. Backup config.env
    if [ -f "$SCRIPT_DIR/config.env" ]; then
        cp -p "$SCRIPT_DIR/config.env" "$snap_dir/config.env"
        local c_hash
        c_hash="$(compute_sha256 "$snap_dir/config.env")"
        manifest_files="$(python3 -c "import json, sys; d = json.loads(sys.argv[1]); d.append({'file': 'config.env', 'sha256': sys.argv[2]}); print(json.dumps(d))" "$manifest_files" "$c_hash")"
        files_backed_up=$((files_backed_up + 1))
    fi
    
    # 2. Backup promo_contacts.json
    if [ -f "$SCRIPT_DIR/assets/promo_contacts.json" ]; then
        cp -p "$SCRIPT_DIR/assets/promo_contacts.json" "$snap_dir/promo_contacts.json"
        local p_hash
        p_hash="$(compute_sha256 "$snap_dir/promo_contacts.json")"
        manifest_files="$(python3 -c "import json, sys; d = json.loads(sys.argv[1]); d.append({'file': 'promo_contacts.json', 'sha256': sys.argv[2]}); print(json.dumps(d))" "$manifest_files" "$p_hash")"
        files_backed_up=$((files_backed_up + 1))
    fi
    
    # 3. Backup Theme Setting
    local current_theme="classic"
    if [ -f "$HOME/.config/mix-manager/theme" ]; then
        current_theme="$(cat "$HOME/.config/mix-manager/theme" | tr -d '[:space:]')"
    fi
    echo "$current_theme" > "$snap_dir/theme.txt"
    manifest_files="$(python3 -c "import json, sys; d = json.loads(sys.argv[1]); d.append({'file': 'theme.txt', 'theme': sys.argv[2]}); print(json.dumps(d))" "$manifest_files" "$current_theme")"
    files_backed_up=$((files_backed_up + 1))
    
    # Write manifest.json
    python3 -c "
import json, sys, os, datetime
data = {
    'version': 'MP_Mix_Manager_v0.2',
    'backup_type': 'local_snapshot',
    'timestamp': '$timestamp',
    'iso_date': datetime.datetime.now().isoformat(),
    'hostname': os.uname().nodename,
    'user': os.environ.get('USER', ''),
    'os_platform': '$OS_TYPE',
    'files': json.loads(sys.argv[1])
}
with open('$snap_dir/manifest.json', 'w') as f:
    json.dump(data, f, indent=2)
" "$manifest_files"
    
    echo -e "  Snapshot Directory: ${BOLD}${GREEN}${snap_dir}${NC}"
    echo -e "  Files Preserved:    ${CYAN}${files_backed_up} files${NC} (config.env, promo_contacts.json, theme)"
    echo -e "  Manifest Created:   ${CYAN}${snap_dir}/manifest.json${NC}"
    echo ""
    echo -e "${GREEN}✓ Configuration backup successfully created!${NC}"
    press_enter
}

# ------------------------------------------------------------------------------
# 3. EXPORT CONFIGURATION BUNDLE (.tar.gz)
# ------------------------------------------------------------------------------
export_config_bundle() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}             Export Portable Configuration Bundle                     ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "This packages your active settings, promo address book, and themes"
    echo -e "into a self-contained, validated archive for transfer to USB or another machine."
    echo ""
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local default_archive="$EXPORT_BASE_DIR/mix_manager_config_${timestamp}.tar.gz"
    
    echo -e "Default Export Path: ${CYAN}${default_archive}${NC}"
    echo ""
    read -r -p "Enter custom export destination path (or press Enter for default): " user_export_path
    
    local export_file="${user_export_path:-$default_archive}"
    export_file="${export_file%/}"
    if [ -d "$export_file" ]; then
        export_file="$export_file/mix_manager_config_${timestamp}.tar.gz"
    fi
    mkdir -p "$(dirname "$export_file")"
    
    local temp_dir
    temp_dir="$(mktemp -d "/tmp/mix_config_export_XXXXXX")"
    
    # Stage files
    if [ -f "$SCRIPT_DIR/config.env" ]; then
        cp -p "$SCRIPT_DIR/config.env" "$temp_dir/config.env"
    elif [ -f "$SCRIPT_DIR/config.env.example" ]; then
        cp -p "$SCRIPT_DIR/config.env.example" "$temp_dir/config.env"
    fi
    
    if [ -f "$SCRIPT_DIR/assets/promo_contacts.json" ]; then
        cp -p "$SCRIPT_DIR/assets/promo_contacts.json" "$temp_dir/promo_contacts.json"
    fi
    
    local cur_theme="cyberpunk"
    if [ -f "$HOME/.config/mix-manager/theme" ]; then
        cur_theme="$(cat "$HOME/.config/mix-manager/theme" | tr -d '[:space:]')"
    fi
    echo "$cur_theme" > "$temp_dir/theme.txt"
    
    # Compute checksums & manifest
    local c_hash="" p_hash=""
    [ -f "$temp_dir/config.env" ] && c_hash="$(compute_sha256 "$temp_dir/config.env")"
    [ -f "$temp_dir/promo_contacts.json" ] && p_hash="$(compute_sha256 "$temp_dir/promo_contacts.json")"
    
    python3 -c "
import json, os, datetime
data = {
    'archive_type': 'mix_archive_manager_config_bundle',
    'app_version': 'MP_Mix_Manager_v0.2',
    'export_timestamp': '$timestamp',
    'iso_date': datetime.datetime.now().isoformat(),
    'hostname': os.uname().nodename,
    'user': os.environ.get('USER', ''),
    'os_platform': '$OS_TYPE',
    'files': {
        'config.env': {'sha256': '$c_hash', 'exists': os.path.exists('$temp_dir/config.env')},
        'promo_contacts.json': {'sha256': '$p_hash', 'exists': os.path.exists('$temp_dir/promo_contacts.json')},
        'theme.txt': {'theme': '$cur_theme', 'exists': True}
    }
}
with open('$temp_dir/manifest.json', 'w') as f:
    json.dump(data, f, indent=2)
"
    
    # Create tar.gz bundle
    tar -czf "$export_file" -C "$temp_dir" .
    rm -rf "$temp_dir"
    
    local bundle_hash
    bundle_hash="$(compute_sha256 "$export_file")"
    local bundle_size
    bundle_size="$(du -sh "$export_file" | awk '{print $1}')"
    
    echo ""
    echo -e "${BOLD}${GREEN}======================================================================${NC}"
    echo -e "${BOLD}${GREEN}            CONFIGURATION BUNDLE EXPORTED SUCCESSFULLY!               ${NC}"
    echo -e "${BOLD}${GREEN}======================================================================${NC}"
    echo -e "  Bundle Path:    ${BOLD}${CYAN}${export_file}${NC}"
    echo -e "  Bundle Size:    ${GREEN}${bundle_size}${NC}"
    echo -e "  SHA-256 Check:  ${YELLOW}${bundle_hash}${NC}"
    echo ""
    echo -e "${GREEN}✓ You can now safely copy this bundle to a USB drive or remote machine.${NC}"
    press_enter
}

# ------------------------------------------------------------------------------
# 4. IMPORT CONFIGURATION BUNDLE (.tar.gz)
# ------------------------------------------------------------------------------
import_config_bundle() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}             Import Configuration Bundle                              ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "Scans for available configuration archives or allows specifying a path."
    echo ""
    
    local found_bundles=()
    while IFS= read -r f; do
        [ -n "$f" ] && found_bundles+=("$f")
    done < <(find "$EXPORT_BASE_DIR" "$PWD" -maxdepth 2 -type f -name "mix_manager_config_*.tar.gz" 2>/dev/null | sort -u -r || true)
    
    if [ ${#found_bundles[@]} -gt 0 ]; then
        echo -e "${BOLD}Available Exported Bundles Found:${NC}"
        for i in "${!found_bundles[@]}"; do
            local idx=$((i + 1))
            local bfile="${found_bundles[$i]}"
            local bsize
            bsize="$(du -sh "$bfile" 2>/dev/null | awk '{print $1}')"
            printf "  ${BOLD}${CYAN}%2d)${NC} %s ${DIM}(%s) [%s]${NC}\n" "$idx" "$(basename "$bfile")" "$bsize" "$(dirname "$bfile")"
        done
        echo ""
    fi
    
    echo -e "  ${BOLD}${CYAN} C)${NC} Enter custom file path to a .tar.gz bundle"
    echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel & Return"
    echo ""
    read -r -p "Select bundle to import: " choice
    
    local target_bundle=""
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        return
    elif [ "$choice" = "C" ] || [ "$choice" = "c" ]; then
        read -r -p "Enter absolute path to .tar.gz bundle: " target_bundle
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#found_bundles[@]}" ] && [ "$choice" -ge 1 ]; then
        target_bundle="${found_bundles[$((choice - 1))]}"
    else
        echo -e "\n${RED}Invalid choice!${NC}"
        sleep 1
        return
    fi
    
    if [ ! -f "$target_bundle" ]; then
        echo -e "\n${RED}Error: File not found: '$target_bundle'${NC}"
        press_enter
        return
    fi
    
    # Validate archive integrity
    echo -e "\n${BOLD}${BLUE}Validating bundle integrity...${NC}"
    local temp_extract
    temp_extract="$(mktemp -d "/tmp/mix_config_import_XXXXXX")"
    if ! tar -tzf "$target_bundle" >/dev/null 2>&1; then
        echo -e "${RED}Error: Archive is corrupted or not a valid gzip tar file!${NC}"
        rm -rf "$temp_extract"
        press_enter
        return
    fi
    
    tar -xzf "$target_bundle" -C "$temp_extract"
    
    if [ ! -f "$temp_extract/manifest.json" ] && [ ! -f "$temp_extract/config.env" ]; then
        echo -e "${RED}Error: Archive does not contain Mix Archive Manager configuration files!${NC}"
        rm -rf "$temp_extract"
        press_enter
        return
    fi
    
    echo -e "${GREEN}✓ Archive verified.${NC}"
    if [ -f "$temp_extract/manifest.json" ]; then
        echo -e "\n${BOLD}Bundle Manifest Details:${NC}"
        python3 -c "
import json
with open('$temp_extract/manifest.json') as f:
    d = json.load(f)
    print('  App Version:   ', d.get('app_version', 'Unknown'))
    print('  Export Date:   ', d.get('iso_date', 'Unknown'))
    print('  Origin Host:   ', d.get('hostname', 'Unknown'))
    print('  Origin User:   ', d.get('user', 'Unknown'))
" 2>/dev/null || true
    fi
    
    echo ""
    read -r -p "Apply this configuration to active installation? [Y/n]: " conf_import
    if [[ "$conf_import" =~ ^[Nn] ]]; then
        echo -e "${YELLOW}Import cancelled.${NC}"
        rm -rf "$temp_extract"
        press_enter
        return
    fi
    
    # 1. Automatic Pre-Import Safety Backup
    echo -e "\n${BOLD}${BLUE}Creating automated pre-import safety backup...${NC}"
    local safety_time
    safety_time="$(date +%Y%m%d_%H%M%S)"
    local safety_dir="$BACKUP_BASE_DIR/pre_import_safety_${safety_time}"
    mkdir -p "$safety_dir"
    [ -f "$SCRIPT_DIR/config.env" ] && cp -p "$SCRIPT_DIR/config.env" "$safety_dir/"
    [ -f "$SCRIPT_DIR/assets/promo_contacts.json" ] && cp -p "$SCRIPT_DIR/assets/promo_contacts.json" "$safety_dir/"
    [ -f "$HOME/.config/mix-manager/theme" ] && cp -p "$HOME/.config/mix-manager/theme" "$safety_dir/theme.txt"
    echo -e "${GREEN}✓ Safety backup created in: ${safety_dir}${NC}"
    
    # 2. Apply Files
    if [ -f "$temp_extract/config.env" ]; then
        cp "$temp_extract/config.env" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}✓ Restored active config.env${NC}"
    fi
    
    if [ -f "$temp_extract/promo_contacts.json" ]; then
        mkdir -p "$SCRIPT_DIR/assets"
        cp "$temp_extract/promo_contacts.json" "$SCRIPT_DIR/assets/promo_contacts.json"
        echo -e "${GREEN}✓ Restored promo contacts address book${NC}"
    fi
    
    if [ -f "$temp_extract/theme.txt" ]; then
        local new_theme
        new_theme="$(cat "$temp_extract/theme.txt" | tr -d '[:space:]')"
        mkdir -p "$HOME/.config/mix-manager"
        echo "$new_theme" > "$HOME/.config/mix-manager/theme"
        echo -e "${GREEN}✓ Restored active theme: ${new_theme}${NC}"
    fi
    
    rm -rf "$temp_extract"
    echo ""
    echo -e "${BOLD}${GREEN}Configuration bundle imported successfully!${NC}"
    press_enter
}

# ------------------------------------------------------------------------------
# 5. LIST & RESTORE HISTORICAL BACKUPS
# ------------------------------------------------------------------------------
list_and_restore_backups() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}           Historical Configuration Backups & Restores                ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    
    local backups=()
    while IFS= read -r b; do
        [ -n "$b" ] && backups+=("$b")
    done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "backup_*" -o -name "pre_import_safety_*" 2>/dev/null | sort -r || true)
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}No existing configuration snapshots found in $BACKUP_BASE_DIR.${NC}"
        press_enter
        return
    fi
    
    echo -e "${BOLD}Select a backup to inspect or restore:${NC}"
    for i in "${!backups[@]}"; do
        local idx=$((i + 1))
        local bdir="${backups[$i]}"
        local bname
        bname="$(basename "$bdir")"
        local bitems
        bitems="$(find "$bdir" -maxdepth 1 -type f 2>/dev/null | wc -l)"
        printf "  ${BOLD}${CYAN}%2d)${NC} %s ${DIM}(%s files)${NC}\n" "$idx" "$bname" "$bitems"
    done
    echo ""
    echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Menu"
    echo ""
    read -r -p "Select backup [1-${#backups[@]}, 0 to return]: " rchoice
    
    if [ "$rchoice" = "0" ] || [ -z "$rchoice" ]; then
        return
    fi
    
    if ! [[ "$rchoice" =~ ^[0-9]+$ ]] || [ "$rchoice" -gt "${#backups[@]}" ] || [ "$rchoice" -lt 1 ]; then
        echo -e "\n${RED}Invalid selection!${NC}"
        sleep 1
        return
    fi
    
    local selected_snap="${backups[$((rchoice - 1))]}"
    echo ""
    echo -e "${BOLD}Contents of $(basename "$selected_snap"):${NC}"
    ls -lh "$selected_snap"
    echo ""
    read -r -p "Restore this backup over current active configuration? [y/N]: " do_res
    if [[ ! "$do_res" =~ ^[Yy] ]]; then
        echo -e "${YELLOW}Restore cancelled.${NC}"
        sleep 1
        return
    fi
    
    # Pre-restore safety backup
    local pre_time
    pre_time="$(date +%Y%m%d_%H%M%S)"
    local pre_dir="$BACKUP_BASE_DIR/pre_restore_safety_${pre_time}"
    mkdir -p "$pre_dir"
    [ -f "$SCRIPT_DIR/config.env" ] && cp -p "$SCRIPT_DIR/config.env" "$pre_dir/"
    [ -f "$SCRIPT_DIR/assets/promo_contacts.json" ] && cp -p "$SCRIPT_DIR/assets/promo_contacts.json" "$pre_dir/"
    
    # Restore
    if [ -f "$selected_snap/config.env" ]; then
        cp -p "$selected_snap/config.env" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}✓ Restored config.env${NC}"
    fi
    if [ -f "$selected_snap/promo_contacts.json" ]; then
        mkdir -p "$SCRIPT_DIR/assets"
        cp -p "$selected_snap/promo_contacts.json" "$SCRIPT_DIR/assets/promo_contacts.json"
        echo -e "${GREEN}✓ Restored promo_contacts.json${NC}"
    fi
    if [ -f "$selected_snap/theme.txt" ]; then
        local th
        th="$(cat "$selected_snap/theme.txt" | tr -d '[:space:]')"
        mkdir -p "$HOME/.config/mix-manager"
        echo "$th" > "$HOME/.config/mix-manager/theme"
        echo -e "${GREEN}✓ Restored theme: $th${NC}"
    fi
    
    echo -e "\n${BOLD}${GREEN}Backup restored successfully!${NC}"
    press_enter
}

# Handle command line arguments if provided
if [ "${1:-}" = "--backup" ]; then
    backup_current_config
    exit 0
elif [ "${1:-}" = "--export" ]; then
    export_config_bundle
    exit 0
elif [ "${1:-}" = "--import" ]; then
    import_config_bundle
    exit 0
elif [ "${1:-}" = "--list" ]; then
    list_and_restore_backups
    exit 0
fi

while true; do
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}        Installation Migration & Configuration Management Suite       ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  Active Installation Path: ${BOLD}${GREEN}${SCRIPT_DIR}${NC}"
    echo -e "  Config Backups Folder:    ${CYAN}${BACKUP_BASE_DIR}${NC}"
    echo -e "  Exported Bundles Folder:  ${CYAN}${EXPORT_BASE_DIR}${NC}"
    echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}Migrate Mix Manager Installation${NC} ${GREEN}(Relocate Path & Repoint Symlinks)${NC}"
    echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}Create Instant Configuration Snapshot${NC} ${GREEN}(Instant Local Backup)${NC}"
    echo -e "  ${BOLD}${CYAN} 3)${NC} ${BOLD}Export Configuration Bundle${NC} ${GREEN}(Portable .tar.gz with Manifest & Hashes)${NC}"
    echo -e "  ${BOLD}${CYAN} 4)${NC} ${BOLD}Import Configuration Bundle${NC} ${GREEN}(Automated Safety Backup & Restore)${NC}"
    echo -e "  ${BOLD}${CYAN} 5)${NC} ${BOLD}List & Restore Historical Backups${NC} ${GREEN}(Rollback to Any Prior Snapshot)${NC}"
    echo ""
    echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu ${DIM}(or 'q')${NC}"
    echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
    
    read -r -p "Enter choice [1-5, or 0 to return]: " opt
    case "$opt" in
        1) migrate_installation_path ;;
        2) backup_current_config ;;
        3) export_config_bundle ;;
        4) import_config_bundle ;;
        5) list_and_restore_backups ;;
        0|q|Q|exit) break ;;
        *)
            echo -e "\n${RED}Invalid option!${NC}"
            sleep 1
            ;;
    esac
done
