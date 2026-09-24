#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Update System MOTD Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/manage_motd.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/manage_motd.py"
fi

exec python3 "$PY_SCRIPT" "$@"
