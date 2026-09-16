#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Stop Ollama Server
# Stops running ollama serve instance inside distrobox container: ollama-container
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"

if ! pgrep -f "ollama serve" >/dev/null 2>&1 && ! curl -s --connect-timeout 2 http://127.0.0.1:11434/ >/dev/null 2>&1; then
    notify-send -a "KDE Connect" -i "dialog-information" "Ollama Server" "Ollama server is not currently running." 2>/dev/null || true
    exit 0
fi

notify-send -a "KDE Connect" -i "dialog-warning" "Ollama Server" "Stopping Ollama Server..." 2>/dev/null || true

# Signal termination to ollama inside container and on host
distrobox enter -T ollama-container -- pkill -TERM -f "ollama serve" 2>/dev/null || true
pkill -TERM -f "ollama serve" 2>/dev/null || true

sleep 1.5

if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
    notify-send -a "KDE Connect" -i "dialog-ok" "Ollama Server" "✓ Ollama Server stopped successfully." 2>/dev/null || true
else
    distrobox enter -T ollama-container -- pkill -9 -f "ollama serve" 2>/dev/null || true
    pkill -9 -f "ollama serve" 2>/dev/null || true
    notify-send -a "KDE Connect" -i "dialog-ok" "Ollama Server" "✓ Ollama Server force terminated." 2>/dev/null || true
fi
