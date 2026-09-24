#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Synchronized Video Companion & Multi-Player Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/sync_video_companion.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/sync_video_companion.py"
fi

exec python3 "$PY_SCRIPT" "$@"
