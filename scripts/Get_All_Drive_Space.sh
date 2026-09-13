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

echo "=== $OS_NAME Drive Space Statistics ==="
echo "Hostname: $(hostname -s)   |   Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================================================"

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
printf "%-38s %-8s %10s %10s %10s %7s\n" "Mount Point" "Type" "Size" "Free" "Used" "%Used"
echo "----------------------------------------------------------------------------------------"

declare -A seen_devices
total_size=0
total_used=0
total_free=0

main_lines=()
media_lines=()
other_lines=()

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

else
    # Linux Implementation (supports mount points with spaces and filters pseudo filesystems)
    while read -r source fstype size_gb used_gb free_gb percent target; do
        [ "$source" = "Filesystem" ] && continue
        # Skip subvolume aliases if /var/home is present
        [[ "$target" == "/etc" ]] && continue
        [[ "$target" == "/var" && -d "/var/home" ]] && continue
        [[ -z "$target" ]] && continue

        if [ "$fstype" = "fuseblk" ]; then
            real_fs=$(lsblk -no FSTYPE "$source" 2>/dev/null | head -n1)
            [ -n "$real_fs" ] && fstype="$real_fs"
        fi

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
    
    # Color coding
    if (( $(echo "$free_gb > 1000" | bc -l 2>/dev/null || [ "$free_gb" -gt 1000 ]) )); then
        color="\033[32m"  # Green
    elif (( $(echo "$free_gb > 300" | bc -l 2>/dev/null || [ "$free_gb" -gt 300 ]) )); then
        color="\033[33m"  # Yellow
    else
        color="\033[31m"  # Red
    fi

    printf "%-38s %-8s %10s ${color}%10s\033[0m %10s %7s\n" \
        "${target:0:37}" \
        "$fstype" \
        "$(to_human "$size_gb")" \
        "$(to_human "$free_gb")" \
        "$(to_human "$used_gb")" \
        "$percent"
done

echo ""
echo "=== SUMMARY ==="

if [ "$total_size" -gt 0 ]; then
    total_size_tb=$(echo "scale=2; $total_size / 1024" | bc -l 2>/dev/null)
    total_free_tb=$(echo "scale=2; $total_free / 1024" | bc -l 2>/dev/null)
    total_used_tb=$(echo "scale=2; $total_used / 1024" | bc -l 2>/dev/null)
    pct_free=$(echo "scale=1; ($total_free * 100) / $total_size" | bc -l 2>/dev/null)

    printf "Total Size : %8.2f TB\n" "$total_size_tb"
    printf "Total Free : %8.2f TB  (%.1f%% Free)\n" "$total_free_tb" "$pct_free"
    printf "Total Used : %8.2f TB\n" "$total_used_tb"

    # Log to file
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') - $(hostname -s) ($OS_NAME) ==="
        printf "Total Size: %.2f TB | Free: %.2f TB (%.1f%%) | Used: %.2f TB\n\n" \
            "$total_size_tb" "$total_free_tb" "$pct_free" "$total_used_tb"
    } >> "$LOGFILE" 2>/dev/null
fi

echo -e "\nResults also logged to: $LOGFILE"
