#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Traktor Pro Live Monitor & Audio Recorder Control
# Cross-platform: macOS, Windows 10 & 11, and Linux
# Supports:
#   • CPU % & RSS RAM memory tracking for Traktor processes
#   • Loaded / playing track detection across decks (file handles & history)
#   • Real-time recording file status & file-size growth detector
#   • Audio interface hardware query (sample rate, latency, buffer size)
#   • Live recording control: start, stop, toggle (menu automation & shortcuts)
#   • Interactive hotkeys: [s] Start, [x] Stop, [t] Toggle, [r] Refresh, [q] Quit
# ==============================================================================

set -eo pipefail 2>/dev/null || true

_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

# Locate python3 executable
PYTHON_CMD="python3"
if ! command -v python3 >/dev/null 2>&1; then
    if command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    elif [ -x "/usr/bin/python3" ]; then
        PYTHON_CMD="/usr/bin/python3"
    elif [ -x "/usr/local/bin/python3" ]; then
        PYTHON_CMD="/usr/local/bin/python3"
    else
        echo "Error: Python 3 is required but was not found in PATH." >&2
        exit 1
    fi
fi

# Locate traktor_monitor.py
MONITOR_PY="$SCRIPT_DIR/traktor_monitor.py"
if [ ! -f "$MONITOR_PY" ]; then
    if [ -f "$SCRIPT_DIR/scripts/traktor_monitor.py" ]; then
        MONITOR_PY="$SCRIPT_DIR/scripts/traktor_monitor.py"
    elif [ -f "$PWD/scripts/traktor_monitor.py" ]; then
        MONITOR_PY="$PWD/scripts/traktor_monitor.py"
    elif [ -f "$PWD/traktor_monitor.py" ]; then
        MONITOR_PY="$PWD/traktor_monitor.py"
    else
        echo "Error: traktor_monitor.py not found in $SCRIPT_DIR or subdirectories." >&2
        exit 1
    fi
fi

exec "$PYTHON_CMD" "$MONITOR_PY" "$@"
