#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Custom Playlists Creator & Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/manage_playlists.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/manage_playlists.py"
fi

exec python3 "$PY_SCRIPT" "$@"
