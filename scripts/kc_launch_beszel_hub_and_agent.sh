#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Launch Beszel Hub & Agent
# Starts or ensures both beszel (hub:8090) and beszel-agent containers are running
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"

BESZEL_DIR="/var/home/mplanetarian/beszel-hub"

hub_running=false
agent_running=false

if podman ps --filter "name=beszel" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel$"; then
    hub_running=true
fi
if podman ps --filter "name=beszel-agent" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel-agent$"; then
    agent_running=true
fi

if [ "$hub_running" = "true" ] && [ "$agent_running" = "true" ]; then
    notify-send -a "KDE Connect" -i "dialog-information" "Beszel Monitoring" "Beszel Hub & Agent are already running (http://192.168.1.11:8090)." 2>/dev/null || true
    exit 0
fi

notify-send -a "KDE Connect" -i "utilities-system-monitor" "Beszel Monitoring" "Launching Beszel Hub and Agent..." 2>/dev/null || true

# 1. Start or launch Beszel Hub
if [ "$hub_running" = "false" ]; then
    if podman ps -a --filter "name=beszel" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel$"; then
        podman start beszel >/dev/null 2>&1 || true
        sleep 1
    fi
    if ! podman ps --filter "name=beszel" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel$"; then
        if [ -f "$BESZEL_DIR/launch_beszel_hub_replace.sh" ]; then
            (cd "$BESZEL_DIR" && bash ./launch_beszel_hub_replace.sh >/dev/null 2>&1 || true)
        fi
    fi
fi

# 2. Start or launch Beszel Agent
if [ "$agent_running" = "false" ]; then
    if podman ps -a --filter "name=beszel-agent" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel-agent$"; then
        podman start beszel-agent >/dev/null 2>&1 || true
        sleep 1
    fi
    if ! podman ps --filter "name=beszel-agent" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel-agent$"; then
        if [ -f "$BESZEL_DIR/launch_beszel_agent_replace.sh" ]; then
            (cd "$BESZEL_DIR" && bash ./launch_beszel_agent_replace.sh >/dev/null 2>&1 || true)
        fi
    fi
fi

sleep 1.5

# 3. Verify status and notify
if podman ps --filter "name=beszel" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel$" && \
   podman ps --filter "name=beszel-agent" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel-agent$"; then
    notify-send -a "KDE Connect" -i "dialog-ok" "Beszel Monitoring" "✓ Beszel Hub & Agent are running (http://192.168.1.11:8090)" 2>/dev/null || true
else
    notify-send -a "KDE Connect" -i "dialog-warning" "Beszel Monitoring" "Beszel launched (check podman ps for container status)." 2>/dev/null || true
fi
