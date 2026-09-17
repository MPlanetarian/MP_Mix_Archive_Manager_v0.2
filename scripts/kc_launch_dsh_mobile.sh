#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Launch dsh-mobile (DeepSeek Harness)
# Boots the DeepSeek Harness web profile with LAN mobile trust (http://192.168.1.11:3080)
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"

DSH_DIR="/var/home/mplanetarian/beszel-hub/deepseek-harness"

# Check if DeepSeek Harness is already listening on port 3080 or process active
if ss -tuln 2>/dev/null | grep -q ':3080 ' || pgrep -f "dsh web" >/dev/null 2>&1; then
    notify-send -a "KDE Connect" -i "dialog-information" "DeepSeek Harness" "dsh-mobile is already running (http://192.168.1.11:3080)." 2>/dev/null || true
    exit 0
fi

if [ ! -d "$DSH_DIR" ]; then
    notify-send -a "KDE Connect" -i "dialog-error" "DeepSeek Harness" "Error: DeepSeek Harness directory not found at $DSH_DIR" 2>/dev/null || true
    exit 1
fi

notify-send -a "KDE Connect" -i "utilities-terminal" "DeepSeek Harness" "Launching dsh-mobile on http://192.168.1.11:3080..." 2>/dev/null || true

TITLE="DeepSeek Harness (dsh-mobile)"
CMD="cd \"$DSH_DIR\" && pnpm dsh web --trusted-host 192.168.1.11:3080 --trusted-host 192.168.1.11 --no-open; echo ''; echo 'dsh web finished. Press [Enter] to close...'; read -r"

if command -v konsole >/dev/null 2>&1; then
    konsole --new-tab -p tabtitle="$TITLE" --workdir "$DSH_DIR" -e bash -c "$CMD" &
elif command -v xdg-terminal-exec >/dev/null 2>&1; then
    nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
elif command -v gnome-terminal >/dev/null 2>&1; then
    nohup gnome-terminal --title="$TITLE" -- bash -c "$CMD" >/dev/null 2>&1 &
elif command -v xterm >/dev/null 2>&1; then
    nohup xterm -T "$TITLE" -e bash -c "$CMD" >/dev/null 2>&1 &
else
    (cd "$DSH_DIR" && nohup pnpm dsh web --trusted-host 192.168.1.11:3080 --trusted-host 192.168.1.11 --no-open >/tmp/dsh-mobile.log 2>&1 &)
fi
