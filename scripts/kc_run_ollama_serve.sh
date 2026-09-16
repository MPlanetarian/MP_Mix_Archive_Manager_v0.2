#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Run Ollama Server
# Starts ollama serve inside distrobox container: ollama-container
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"

# Check if Ollama is already listening on port 11434 or process is active
if curl -s --connect-timeout 2 http://127.0.0.1:11434/ >/dev/null 2>&1 || pgrep -f "ollama serve" >/dev/null 2>&1; then
    notify-send -a "KDE Connect" -i "dialog-information" "Ollama Server" "Ollama server is already running (http://127.0.0.1:11434)." 2>/dev/null || true
    exit 0
fi

notify-send -a "KDE Connect" -i "utilities-terminal" "Ollama Server" "Starting Ollama Server in distrobox (ollama-container)..." 2>/dev/null || true

# Ensure container is started if stopped
if ! podman ps --filter "name=ollama-container" --format "{{.Names}}" 2>/dev/null | grep -q "^ollama-container$"; then
    podman start ollama-container >/dev/null 2>&1 || true
fi

TITLE="Ollama Server (ollama-container)"
CMD="distrobox enter ollama-container -- ollama serve; echo ''; echo 'Ollama server exited. Press [Enter] to close...'; read -r"

if command -v konsole >/dev/null 2>&1; then
    konsole --new-tab -p tabtitle="$TITLE" -e bash -c "$CMD" &
elif command -v xdg-terminal-exec >/dev/null 2>&1; then
    nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
elif command -v gnome-terminal >/dev/null 2>&1; then
    nohup gnome-terminal --title="$TITLE" -- bash -c "$CMD" >/dev/null 2>&1 &
elif command -v xterm >/dev/null 2>&1; then
    nohup xterm -T "$TITLE" -e bash -c "$CMD" >/dev/null 2>&1 &
else
    nohup distrobox enter -T ollama-container -- ollama serve >/tmp/ollama-serve.log 2>&1 &
fi
