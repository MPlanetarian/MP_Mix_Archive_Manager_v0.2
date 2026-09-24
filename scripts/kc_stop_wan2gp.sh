#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Stop WAN2GP AI Video Server
# Mix Archive Manager -> Menu 56 -> Option 3:
# (3) Stop Running WAN2GP Server
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"

# Resolve codebase directory
CODEBASE_DIR="/var/home/mplanetarian/MP_Mix_Manager_v0.3"
if [ ! -f "$CODEBASE_DIR/wan2gp.sh" ]; then
    for _c in \
        "$HOME/MP_Mix_Manager_v0.3" \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.1" \
        "$HOME/MP_Mix_Manager_v0.1" \
        "$HOME/Documents/BASH_SCRIPTS"; do
        if [ -f "$_c/wan2gp.sh" ]; then
            CODEBASE_DIR="$_c"
            break
        fi
    done
fi
WAN2GP_SCRIPT="$CODEBASE_DIR/wan2gp.sh"

# Check if WAN2GP is running
wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
if [ -z "$wgp_pids" ]; then
    notify-send -a "KDE Connect" -i "dialog-information" "WAN2GP Server" "WAN2GP is not currently running." 2>/dev/null || true
    exit 0
fi

notify-send -a "KDE Connect" -i "dialog-warning" "WAN2GP Server" "Stopping WAN2GP Server (PID: ${wgp_pids% })..." 2>/dev/null || true

bash "$WAN2GP_SCRIPT" stop

sleep 1

# Verify stopped
if ! pgrep -f "python.*wgp\.py" >/dev/null 2>&1; then
    notify-send -a "KDE Connect" -i "dialog-ok" "WAN2GP Server" "✓ WAN2GP Server stopped successfully." 2>/dev/null || true
else
    pkill -9 -f "python.*wgp\.py" 2>/dev/null || true
    sleep 0.5
    notify-send -a "KDE Connect" -i "dialog-ok" "WAN2GP Server" "✓ WAN2GP Server force terminated." 2>/dev/null || true
fi
