#!/bin/bash
# Script to terminate open desktop applications and close windows gracefully,
# while preserving any active Mix Archive Manager window.

echo "Closing all open application windows..."

# Find Mix Archive Manager PIDs and their parent terminal PIDs to protect them
PROTECTED_PIDS=()
for mpid in $(pgrep -f "Mix_Archive_Manager.sh" 2>/dev/null); do
    p=$mpid
    while [ "$p" -gt 1 ]; do
        PROTECTED_PIDS+=("$p")
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        [ -z "$p" ] && break
    done
done

# 1. Gracefully request all application windows to close via wmctrl
if command -v wmctrl >/dev/null 2>&1; then
    wmctrl -lp | while read -r win_id desktop_num win_pid host win_title; do
        # Skip system desktop panels (-1) and plasmashell
        if [ "$desktop_num" -lt 0 ] || [[ "$win_title" == *"plasmashell"* ]]; then
            continue
        fi

        # Protect any window belonging to Mix Archive Manager
        is_protected=false
        for pp in "${PROTECTED_PIDS[@]}"; do
            if [ "$win_pid" = "$pp" ]; then
                is_protected=true
                break
            fi
        done
        if [ "$is_protected" = true ] || [[ "$win_title" == *"Mix Archive Manager"* ]]; then
            echo "Skipping protected Manager window: $win_title"
            continue
        fi

        wmctrl -c "$win_id"
    done
fi

sleep 1

# 2. Terminate background desktop app processes (preserving konsole/bash so Manager stays open)
GUI_APPS=(
    "cpu-x"
    "GPUViewer"
    "btop"
    "dolphin"
    "vlc"
    "mpv"
    "strawberry"
    "cliamp"
    "steam"
    "steamwebhelper"
)

for app in "${GUI_APPS[@]}"; do
    pkill -f "$app" 2>/dev/null || true
done

echo "All desktop application windows closed (Mix Archive Manager preserved)."
