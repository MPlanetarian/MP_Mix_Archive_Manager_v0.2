#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Run Aider with Qwen2.5 7B Instruct
# Command: aider --model ollama_chat/qwen2.5:7b-instruct
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"
export OLLAMA_API_BASE="http://127.0.0.1:11434"

# 1. Ensure Ollama server dependency is running
if ! curl -s --connect-timeout 2 http://127.0.0.1:11434/ >/dev/null 2>&1 && ! pgrep -f "ollama serve" >/dev/null 2>&1; then
    notify-send -a "KDE Connect" -i "utilities-system-monitor" "Aider" "Starting Ollama server dependency in background..." 2>/dev/null || true
    if ! podman ps --filter "name=ollama-container" --format "{{.Names}}" 2>/dev/null | grep -q "^ollama-container$"; then
        podman start ollama-container >/dev/null 2>&1 || true
    fi
    nohup distrobox enter -T ollama-container -- ollama serve >/tmp/ollama-serve.log 2>&1 &
    for _ in {1..20}; do
        if curl -s --connect-timeout 1 http://127.0.0.1:11434/ >/dev/null 2>&1; then
            break
        fi
        sleep 0.5
    done
fi

# 2. Determine target workspace
WORKDIR="${AIDER_DIR:-/var/home/mplanetarian/MP_Mix_Manager_v0.2}"
[ ! -d "$WORKDIR" ] && WORKDIR="$HOME"

notify-send -a "KDE Connect" -i "utilities-terminal" "Aider AI" "Opening Aider (Qwen2.5 7B) in Konsole..." 2>/dev/null || true

TITLE="Aider (Qwen2.5:7B-Instruct)"
AIDER_CMD="aider --model ollama_chat/qwen2.5:7b-instruct; exec bash"

# 3. Launch in terminal
if command -v konsole >/dev/null 2>&1; then
    konsole --new-tab -p tabtitle="$TITLE" --workdir "$WORKDIR" -e bash -c "$AIDER_CMD" &
elif command -v xdg-terminal-exec >/dev/null 2>&1; then
    nohup xdg-terminal-exec bash -c "$AIDER_CMD" >/dev/null 2>&1 &
elif command -v gnome-terminal >/dev/null 2>&1; then
    nohup gnome-terminal --title="$TITLE" --working-directory="$WORKDIR" -- bash -c "$AIDER_CMD" >/dev/null 2>&1 &
elif command -v xterm >/dev/null 2>&1; then
    nohup xterm -T "$TITLE" -e bash -c "cd \"$WORKDIR\" && $AIDER_CMD" >/dev/null 2>&1 &
fi
