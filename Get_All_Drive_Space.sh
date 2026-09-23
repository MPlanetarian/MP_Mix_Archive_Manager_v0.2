#!/bin/bash

LOGFILE="$HOME/drive_space_log.txt"
OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Darwin" ]; then
    OS_NAME="macOS"
elif [ "$OS_TYPE" = "Linux" ]; then
    OS_NAME="Linux"
else
    OS_NAME="$OS_TYPE"
fi

# ANSI Color Codes
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_MAGENTA="\033[1;35m"
C_CYAN="\033[1;36m"
C_WHITE="\033[1;37m"
C_BORDER="\033[0;34m"

echo -e "${C_CYAN}=== $OS_NAME Drive Space Statistics ===${C_RESET}"
echo -e "Hostname: ${C_WHITE}$(hostname -s)${C_RESET}   |   Date: ${C_DIM}$(date '+%Y-%m-%d %H:%M:%S')${C_RESET}"
echo -e "${C_BORDER}========================================================================================${C_RESET}"

# Human readable conversion function (GB to TB/GB)
to_human() {
    local val="$1"
    if (( $(echo "$val >= 1024" | bc -l 2>/dev/null || [ "$val" -ge 1024 ]) )); then
        printf "%.2f TB" "$(echo "scale=2; $val / 1024" | bc -l 2>/dev/null)"
    else
        printf "%.1f GB" "$val"
    fi
}

# Determine the main drive / mount point containing user HOME / root
main_mount=$(df -P "$HOME" 2>/dev/null | awk 'NR==2 {print $6}')
[ -z "$main_mount" ] && main_mount="/"

# Table Header
printf "${C_WHITE}%-38s %-8s %10s %10s %10s %7s${C_RESET}\n" "Mount Point" "FS Type" "Size" "Free" "Used" "%Used"
echo -e "${C_BORDER}----------------------------------------------------------------------------------------${C_RESET}"

declare -A seen_devices
total_size=0
total_used=0
total_free=0

main_lines=()
media_lines=()
other_lines=()
unmounted_rows=()

if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS Implementation
    while read -r line; do
        source=$(echo "$line" | awk '{print $1}')
        mount=$(echo "$line" | awk '{print $9}')
        size_gb=$(echo "$line" | awk '{print $2}')
        used_gb=$(echo "$line" | awk '{print $3}')
        free_gb=$(echo "$line" | awk '{print $4}')
        percent=$(echo "$line" | awk '{print $5}')
        
        if [[ "$mount" == /private/tmp/* ]] || [[ "$mount" =~ /System/Volumes/.*Data$ && "$mount" != "$main_mount" ]] || [[ -z "$mount" ]]; then
            continue
        fi
        
        fstype=$(mount | grep "^$source on " | awk -F'[(),]' '{print $2}' | awk '{print $1}')
        [ -z "$fstype" ] && fstype="apfs"
        fstype=$(echo "$fstype" | tr '[:lower:]' '[:upper:]')
        case "$fstype" in
            NTFS*|*NTFS*) fstype="NTFS" ;;
        esac

        row="$mount|$fstype|$size_gb|$free_gb|$used_gb|$percent"

        if [ "$mount" = "$main_mount" ] || [ "$mount" = "/" ]; then
            main_lines+=("$row")
        elif [[ "$mount" == /Volumes/* ]]; then
            media_lines+=("$row")
        else
            other_lines+=("$row")
        fi

        total_size=$((total_size + size_gb))
        total_used=$((total_used + used_gb))
        total_free=$((total_free + free_gb))
    done < <(df -g | grep -E '^/dev/(disk|apfs)')

    # macOS unmounted storage detection via diskutil
    if command -v diskutil >/dev/null 2>&1; then
        while read -r disk_id; do
            [ -z "$disk_id" ] && continue
            dev_path="/dev/$disk_id"
            if ! mount | grep -q "^$dev_path on "; then
                info=$(diskutil info "$disk_id" 2>/dev/null)
                is_mounted=$(echo "$info" | awk -F': *' '/Mounted:/ {print $2}')
                [ "$is_mounted" = "Yes" ] && continue
                media_name=$(echo "$info" | awk -F': *' '/Device \/ Media Name:/ {print $2}' | xargs 2>/dev/null)
                vol_name=$(echo "$info" | awk -F': *' '/Volume Name:/ {print $2}' | xargs 2>/dev/null)
                fs=$(echo "$info" | awk -F': *' '/Type \(Bundle\):/ {print $2}' | xargs 2>/dev/null)
                [ -z "$fs" ] && fs=$(echo "$info" | awk -F': *' '/File System Personality:/ {print $2}' | xargs 2>/dev/null)
                bytes=$(echo "$info" | awk -F': *' '/Disk Size:/ {print $2}' | awk -F'[(B]' '{print $2}' | tr -d ' ')
                if [ -n "$bytes" ] && [ "$bytes" -gt 1073741824 ] 2>/dev/null; then
                    size_gb=$(echo "scale=2; $bytes / 1073741824" | bc -l 2>/dev/null || echo "$(( bytes / 1073741824 ))")
                    desc="$media_name"
                    [ -n "$vol_name" ] && desc="$desc ($vol_name)"
                    [ -z "$desc" ] && desc="Disk Device"
                    [ -z "$fs" ] && fs="-"
                    fs=$(echo "$fs" | tr '[:lower:]' '[:upper:]')
                    case "$fs" in
                        NTFS*|*NTFS*) fs="NTFS" ;;
                    esac
                    unmounted_rows+=("$dev_path|$desc|$fs|$(to_human "$size_gb")")
                fi
            fi
        done < <(diskutil list 2>/dev/null | awk '/^\/dev\/disk/ {print $1}' | sed 's|/dev/||')
    fi

else
    # Linux Implementation (supports mount points with spaces and filters pseudo filesystems)
    while read -r source fstype size_gb used_gb free_gb percent target; do
        [ "$source" = "Filesystem" ] && continue
        # Skip subvolume aliases if /var/home is present
        [[ "$target" == "/etc" ]] && continue
        [[ "$target" == "/var" && -d "/var/home" ]] && continue
        [[ -z "$target" ]] && continue

        if [ "$fstype" = "fuseblk" ] || [ -z "$fstype" ]; then
            real_fs=$(lsblk -no FSTYPE "$source" 2>/dev/null | head -n1)
            if [ -z "$real_fs" ]; then
                real_fs=$(udevadm info -q property -n "$source" 2>/dev/null | grep '^ID_FS_TYPE=' | cut -d= -f2)
            fi
            if [ -z "$real_fs" ]; then
                real_fs=$(blkid -s TYPE -o value "$source" 2>/dev/null)
            fi
            [ -n "$real_fs" ] && fstype="$real_fs"
        fi

        fstype=$(echo "$fstype" | tr '[:lower:]' '[:upper:]')
        case "$fstype" in
            NTFS*|*NTFS*) fstype="NTFS" ;;
        esac

        row="$target|$fstype|$size_gb|$free_gb|$used_gb|$percent"

        # Prioritize main OS / Home drive first
        if [ "$target" = "$main_mount" ] || [ "$target" = "/" ]; then
            main_lines+=("$row")
        elif [[ "$target" == /run/media/$USER/* || "$target" == /media/$USER/* || "$target" == /Volumes/* ]]; then
            media_lines+=("$row")
        else
            other_lines+=("$row")
        fi

        # Deduplicate physical devices for accurate total summary
        if [ -z "${seen_devices[$source]}" ]; then
            seen_devices[$source]=1
            total_size=$((total_size + size_gb))
            total_used=$((total_used + used_gb))
            total_free=$((total_free + free_gb))
        fi
    done < <(df -B1G -x tmpfs -x devtmpfs -x efivarfs -x composefs -x squashfs -x overlay --output=source,fstype,size,used,avail,pcent,target | grep '^/dev/')

    # Linux unmounted storage detection via lsblk
    if command -v lsblk >/dev/null 2>&1; then
        _SAVED_PATH="$PATH"
        declare -A parent_model parent_vendor has_children dev_type dev_size dev_fstype dev_label dev_pkname dev_mp

        while IFS= read -r line; do
            unset DEV_PATH TYPE SIZE FSTYPE LABEL MODEL VENDOR MOUNTPOINT PKNAME
            eval "$line"
            dev_name="${DEV_PATH#/dev/}"
            [[ "$dev_name" == loop* || "$dev_name" == zram* ]] && continue

            dev_type["$DEV_PATH"]="$TYPE"
            dev_size["$DEV_PATH"]="$SIZE"
            dev_fstype["$DEV_PATH"]="$FSTYPE"
            dev_label["$DEV_PATH"]="$LABEL"
            dev_pkname["$DEV_PATH"]="$PKNAME"
            dev_mp["$DEV_PATH"]="$MOUNTPOINT"

            if [ -n "$PKNAME" ]; then
                has_children["/dev/$PKNAME"]=1
            fi
            if [ "$TYPE" = "disk" ]; then
                parent_model["/dev/$dev_name"]="$MODEL"
                parent_vendor["/dev/$dev_name"]="$VENDOR"
            fi
        done < <(lsblk -b --pairs -o PATH,TYPE,SIZE,FSTYPE,LABEL,MODEL,VENDOR,MOUNTPOINT,PKNAME 2>/dev/null | sed 's/^PATH=/DEV_PATH=/')

        export PATH="$_SAVED_PATH"

        for p in "${!dev_type[@]}"; do
            mp="${dev_mp[$p]}"
            [ -n "$mp" ] && continue
            type="${dev_type[$p]}"
            fstype="${dev_fstype[$p]}"
            size="${dev_size[$p]}"
            label="${dev_label[$p]}"
            pk="${dev_pkname[$p]}"

            [[ "$fstype" == *raid* || "$fstype" == "swap" ]] && continue
            [ "$size" -le 0 ] 2>/dev/null && continue

            # Skip device containers that have child partitions
            [ -n "${has_children[$p]}" ] && continue

            # If it is a partition, skip tiny system partitions (MSR, EFI, Recovery < 1GB)
            if [ "$type" = "part" ]; then
                if [ "$size" -lt 1073741824 ] 2>/dev/null; then
                    [[ -z "$fstype" || "$label" =~ ^(Recovery|EFI.*)$ || "$fstype" == "vfat" ]] && continue
                fi
            fi

            if [ "$type" = "disk" ]; then
                m="${parent_model[$p]}"
                v="${parent_vendor[$p]}"
            else
                m="${parent_model[/dev/$pk]}"
                v="${parent_vendor[/dev/$pk]}"
            fi

            # Clean and combine vendor + model
            v=$(echo "$v" | xargs 2>/dev/null)
            m=$(echo "$m" | xargs 2>/dev/null)
            [[ "$v" =~ ^(ATA|NVMe)$ ]] && v=""
            m_lower=$(echo "$m" | tr '[:upper:]' '[:lower:]')
            v_lower=$(echo "$v" | tr '[:upper:]' '[:lower:]')
            if [ -n "$v" ] && [[ "$m_lower" != *"$v_lower"* ]]; then
                full_name="$v $m"
            else
                full_name="$m"
            fi
            if [ -n "$label" ]; then
                full_name="$full_name ($label)"
            fi
            [ -z "$full_name" ] && full_name="Disk Device"

            # Normalize filesystem
            [ -z "$fstype" ] && fstype="-"
            fstype=$(echo "$fstype" | tr '[:lower:]' '[:upper:]')
            case "$fstype" in
                NTFS*|*NTFS*) fstype="NTFS" ;;
            esac

            size_gb=$(echo "scale=2; $size / 1073741824" | bc -l 2>/dev/null || echo "$(( size / 1073741824 ))")
            unmounted_rows+=("$p|$full_name|$fstype|$(to_human "$size_gb")")
        done
    fi
fi

# Build ordered row list: Main drive first, then user media drives, then other drives
sorted_rows=()
for r in "${main_lines[@]}"; do
    sorted_rows+=("$r")
done

if [ ${#media_lines[@]} -gt 0 ]; then
    readarray -t sorted_media < <(printf "%s\n" "${media_lines[@]}" | sort)
    for r in "${sorted_media[@]}"; do
        sorted_rows+=("$r")
    done
fi

if [ ${#other_lines[@]} -gt 0 ]; then
    readarray -t sorted_other < <(printf "%s\n" "${other_lines[@]}" | sort)
    for r in "${sorted_other[@]}"; do
        sorted_rows+=("$r")
    done
fi

# Print table rows
for item in "${sorted_rows[@]}"; do
    IFS="|" read -r target fstype size_gb free_gb used_gb percent <<< "$item"
    
    # Color coding for Free space
    if (( $(echo "$free_gb > 1000" | bc -l 2>/dev/null || [ "$free_gb" -gt 1000 ]) )); then
        color="${C_GREEN}"   # Green
    elif (( $(echo "$free_gb > 300" | bc -l 2>/dev/null || [ "$free_gb" -gt 300 ]) )); then
        color="${C_YELLOW}"  # Yellow
    else
        color="${C_RED}"     # Red
    fi

    # Color coding for %Used
    p_num="${percent%%%}"
    if [ "$p_num" -ge 90 ] 2>/dev/null; then
        p_color="${C_RED}"
    elif [ "$p_num" -ge 75 ] 2>/dev/null; then
        p_color="${C_YELLOW}"
    else
        p_color="${C_RESET}"
    fi

    printf "${C_CYAN}%-38s${C_RESET} ${C_MAGENTA}%-8s${C_RESET} %10s ${color}%10s${C_RESET} %10s ${p_color}%7s${C_RESET}\n" \
        "${target:0:37}" \
        "$fstype" \
        "$(to_human "$size_gb")" \
        "$(to_human "$free_gb")" \
        "$(to_human "$used_gb")" \
        "$percent"
done

# Print unmounted storage devices if any are detected
if [ ${#unmounted_rows[@]} -gt 0 ]; then
    echo ""
    echo -e "${C_MAGENTA}=== UNMOUNTED STORAGE DEVICES ===${C_RESET}"
    printf "${C_WHITE}%-16s %-38s %-8s %10s %11s${C_RESET}\n" "Device" "Model / Label" "FS Type" "Size" "Status"
    echo -e "${C_BORDER}----------------------------------------------------------------------------------------${C_RESET}"
    sorted_unmounted=()
    while IFS= read -r r; do
        [ -n "$r" ] && sorted_unmounted+=("$r")
    done < <(printf "%s\n" "${unmounted_rows[@]}" | sort)

    for uitem in "${sorted_unmounted[@]}"; do
        IFS="|" read -r udev udesc ufstype usize <<< "$uitem"
        printf "${C_CYAN}%-16s${C_RESET} %-38s ${C_MAGENTA}%-8s${C_RESET} %10s   ${C_YELLOW}%s${C_RESET}\n" \
            "${udev:0:15}" \
            "${udesc:0:37}" \
            "$ufstype" \
            "$usize" \
            "Unmounted"
    done
fi

echo ""
echo -e "${C_CYAN}=== SUMMARY ===${C_RESET}"

if [ "$total_size" -gt 0 ]; then
    total_size_tb=$(echo "scale=2; $total_size / 1024" | bc -l 2>/dev/null)
    total_free_tb=$(echo "scale=2; $total_free / 1024" | bc -l 2>/dev/null)
    total_used_tb=$(echo "scale=2; $total_used / 1024" | bc -l 2>/dev/null)
    pct_free=$(echo "scale=1; ($total_free * 100) / $total_size" | bc -l 2>/dev/null)

    # Color code Total Free (Red if total amount of space left is <= 20%)
    if (( $(echo "$pct_free <= 20" | bc -l 2>/dev/null || [ "${pct_free%.*}" -le 20 ]) )); then
        total_free_color="${C_RED}"
    elif (( $(echo "$pct_free <= 35" | bc -l 2>/dev/null || [ "${pct_free%.*}" -le 35 ]) )); then
        total_free_color="${C_YELLOW}"
    else
        total_free_color="${C_GREEN}"
    fi

    printf "Total Size : ${C_WHITE}%8.2f TB${C_RESET}\n" "$total_size_tb"
    printf "Total Free : ${total_free_color}%8.2f TB  (%.1f%% Free)${C_RESET}\n" "$total_free_tb" "$pct_free"
    printf "Total Used : ${C_WHITE}%8.2f TB${C_RESET}\n" "$total_used_tb"

    if (( $(echo "$pct_free <= 20" | bc -l 2>/dev/null || [ "${pct_free%.*}" -le 20 ]) )); then
        echo -e "${C_RED}⚠️  Warning: Total free space across mounted drives is critically low (<= 20%)!${C_RESET}"
    fi

    # Log to file (plain text)
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') - $(hostname -s) ($OS_NAME) ==="
        printf "Total Size: %.2f TB | Free: %.2f TB (%.1f%%) | Used: %.2f TB\n\n" \
            "$total_size_tb" "$total_free_tb" "$pct_free" "$total_used_tb"
    } >> "$LOGFILE" 2>/dev/null
fi

echo -e "\n${C_DIM}Results also logged to:${C_RESET} ${C_CYAN}$LOGFILE${C_RESET}"
