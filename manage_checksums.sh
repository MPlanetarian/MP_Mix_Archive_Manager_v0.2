#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Audio File Checksum Generator & Integrity Verifier
# Generates and validates SHA-256 checksum manifests for mixes and WAVs.
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
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Resolve compute command
compute_sha256() {
    local target="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$target" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$target" | awk '{print $1}'
    elif command -v certutil.exe >/dev/null 2>&1; then
        certutil.exe -hashfile "$target" SHA256 2>/dev/null | grep -v ":" | tr -d ' \r\n'
    elif command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command "(Get-FileHash -Path '$target' -Algorithm SHA256).Hash.ToLower()" 2>/dev/null | tr -d '\r\n'
    else
        python3 -c "import hashlib; print(hashlib.sha256(open('$target', 'rb').read()).hexdigest())" 2>/dev/null
    fi
}

generate_checksums_for_dir() {
    local target_dir="$1"
    local manifest_name="${2:-checksums.sha256}"
    
    if [ ! -d "$target_dir" ]; then
        echo -e "${RED}Error: Directory '$target_dir' not found!${NC}"
        return 1
    fi

    local manifest_file="$target_dir/$manifest_name"
    mkdir -p "$target_dir"
    mkdir -p "VERIFY_LOGS"

    shopt -s nullglob nocaseglob
    local files=("$target_dir"/*.[fF][lL][aA][cC] "$target_dir"/*.[wW][aA][vV] "$target_dir"/*.[mM][pP]3 "$target_dir"/*.[mM]4[aA])
    shopt -u nullglob nocaseglob

    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No audio files found in $target_dir!${NC}"
        return 1
    fi

    echo -e "\n${BOLD}${CYAN}Generating SHA-256 checksums for ${#files[@]} file(s) in:${NC} $target_dir"
    echo -e "${DIM}Manifest: $manifest_file${NC}\n"

    local tmp_manifest
    tmp_manifest=$(mktemp)
    local count=0

    for f in "${files[@]}"; do
        local bname
        bname=$(basename "$f")
        echo -ne "  [$(($count + 1))/${#files[@]}] Hashing ${BOLD}$bname${NC}... "
        local hash
        hash=$(compute_sha256 "$f")
        if [ -n "$hash" ]; then
            echo "$hash  $bname" >> "$tmp_manifest"
            echo -e "${GREEN}✓ OK${NC}"
            ((count++))
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    done

    mv "$tmp_manifest" "$manifest_file"

    # Save backup timestamped log
    local timestamp
    timestamp=$(date "+%Y-%m-%d_%H%M%S")
    local backup_log="VERIFY_LOGS/checksums_${timestamp}.sha256"
    cp "$manifest_file" "$backup_log" 2>/dev/null || true

    echo -e "\n${BOLD}${GREEN}✓ Successfully generated $count checksums!${NC}"
    echo -e "  Manifest saved:    ${CYAN}$manifest_file${NC}"
    echo -e "  Verification copy: ${CYAN}$backup_log${NC}\n"
    return 0
}

verify_checksums_in_dir() {
    local target_dir="$1"
    local manifest_name="${2:-checksums.sha256}"
    local manifest_file="$target_dir/$manifest_name"

    if [ ! -f "$manifest_file" ]; then
        echo -e "${RED}Error: Manifest '$manifest_file' does not exist!${NC}"
        echo -e "${YELLOW}Please generate checksums first before verifying.${NC}\n"
        return 1
    fi

    echo -e "\n${BOLD}${CYAN}Verifying audio integrity against manifest:${NC} $manifest_file\n"

    mkdir -p "VERIFY_LOGS"
    local timestamp
    timestamp=$(date "+%Y-%m-%d_%H%M%S")
    local report_file="VERIFY_LOGS/verify_report_${timestamp}.log"
    : > "$report_file"

    local total=0
    local passed=0
    local failed=0
    local missing=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [ -z "$(echo "$line" | tr -d ' ')" ] && continue

        local expected_hash file_name
        expected_hash=$(echo "$line" | awk '{print $1}')
        file_name=$(echo "$line" | sed 's/^[^ ]*[ ]*//')

        local full_path="$target_dir/$file_name"
        ((total++))

        if [ ! -f "$full_path" ]; then
            echo -e "  ${BOLD}${YELLOW}[ MISSING ]${NC} $file_name"
            echo "MISSING: $file_name" >> "$report_file"
            ((missing++))
            continue
        fi

        echo -ne "  Verifying $file_name... "
        local actual_hash
        actual_hash=$(compute_sha256 "$full_path")

        if [ "$expected_hash" = "$actual_hash" ]; then
            echo -e "${BOLD}${GREEN}[ OK ]${NC}"
            echo "OK: $file_name ($actual_hash)" >> "$report_file"
            ((passed++))
        else
            echo -e "${BOLD}${RED}[ CORRUPT / MODIFIED ]${NC}"
            echo "FAILED: $file_name (Expected: $expected_hash, Got: $actual_hash)" >> "$report_file"
            ((failed++))
        fi
    done < "$manifest_file"

    echo -e "\n${BOLD}${MAGENTA}==================================================${NC}"
    echo -e "${BOLD}${MAGENTA}          INTEGRITY VERIFICATION SUMMARY          ${NC}"
    echo -e "${BOLD}${MAGENTA}==================================================${NC}"
    echo -e "  Total Files Audited: ${BOLD}$total${NC}"
    echo -e "  Intact & Valid:      ${BOLD}${GREEN}$passed${NC}"
    if [ "$failed" -gt 0 ]; then
        echo -e "  Corrupted/Modified:  ${BOLD}${RED}$failed${NC}"
    else
        echo -e "  Corrupted/Modified:  ${GREEN}0${NC}"
    fi
    if [ "$missing" -gt 0 ]; then
        echo -e "  Missing Files:       ${BOLD}${YELLOW}$missing${NC}"
    fi
    echo -e "  Detailed Log:        ${CYAN}$report_file${NC}"
    echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"

    if [ "$failed" -eq 0 ] && [ "$missing" -eq 0 ]; then
        echo -e "${BOLD}${GREEN}✓ Perfect! All audio files match bit-exact master checksums.${NC}\n"
        return 0
    else
        echo -e "${BOLD}${RED}⚠️ Integrity warnings found! Please check log for details.${NC}\n"
        return 1
    fi
}

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}          AUDIO FILE CHECKSUM CREATOR & INTEGRITY VERIFIER            ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

echo -e "${BOLD}Select Checksum Operation:${NC}"
echo -e "  ${BOLD}${BLUE}── [ GENERATE CHECKSUMS (SHA-256) ] ──────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN} 1)${NC} Generate Checksums for All FLAC Mixes (FLAC_CONVERTED_OUTPUTS)"
echo -e "  ${BOLD}${CYAN} 2)${NC} Generate Checksums for Converted WAV Archive (CONVERTED_WAV_FILES)"
echo -e "  ${BOLD}${CYAN} 3)${NC} Generate Checksums for WAVs in Staging / Current Directory"
echo -e "  ${BOLD}${CYAN} 4)${NC} Generate Checksum for a Single Audio File"
echo -e "  ${BOLD}${BLUE}── [ VERIFY AUDIO INTEGRITY ] ────────────────────────────────${NC}"
echo -e "  ${BOLD}${CYAN} 5)${NC} Verify FLAC Mixes (FLAC_CONVERTED_OUTPUTS/checksums.sha256)"
echo -e "  ${BOLD}${CYAN} 6)${NC} Verify Converted WAV Files (CONVERTED_WAV_FILES/checksums.sha256)"
echo -e "  ${BOLD}${CYAN} 7)${NC} Verify Custom Manifest File"
echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
echo ""

read -r -p "Enter choice [1-7]: " c_choice

case "$c_choice" in
    1)
        target="FLAC_CONVERTED_OUTPUTS"
        [ ! -d "$target" ] && [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" ] && target="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"
        generate_checksums_for_dir "$target" "checksums.sha256"
        ;;
    2)
        target="CONVERTED_WAV_FILES"
        [ ! -d "$target" ] && [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" ] && target="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES"
        generate_checksums_for_dir "$target" "checksums.sha256"
        ;;
    3)
        generate_checksums_for_dir "." "checksums.sha256"
        ;;
    4)
        read -r -e -p "Enter path to audio file: " single_f
        single_f=$(echo "$single_f" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        if [ -f "$single_f" ]; then
            echo -e "\nComputing SHA-256 for $(basename "$single_f")... Please wait..."
            h=$(compute_sha256 "$single_f")
            sz=$(ls -lh "$single_f" 2>/dev/null | awk '{print $5}')
            echo -e "\n  File:    ${BOLD}${CYAN}$(basename "$single_f")${NC} (${sz})"
            echo -e "  Path:    $single_f"
            echo -e "  SHA-256: ${BOLD}${GREEN}$h${NC}\n"
        else
            echo -e "${RED}File not found!${NC}"
        fi
        ;;
    5)
        target="FLAC_CONVERTED_OUTPUTS"
        [ ! -d "$target" ] && [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" ] && target="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"
        verify_checksums_in_dir "$target" "checksums.sha256"
        ;;
    6)
        target="CONVERTED_WAV_FILES"
        [ ! -d "$target" ] && [ -d "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" ] && target="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES"
        verify_checksums_in_dir "$target" "checksums.sha256"
        ;;
    7)
        read -r -e -p "Enter directory containing checksums.sha256 (or path to manifest): " cust_m
        cust_m=$(echo "$cust_m" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        if [ -d "$cust_m" ]; then
            verify_checksums_in_dir "$cust_m" "checksums.sha256"
        elif [ -f "$cust_m" ]; then
            verify_checksums_in_dir "$(dirname "$cust_m")" "$(basename "$cust_m")"
        else
            echo -e "${RED}Target does not exist!${NC}"
        fi
        ;;
    0|q|Q)
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice!${NC}"
        exit 1
        ;;
esac
