#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Procedural PPM Cover Art Generator Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/generate_ppm_cover.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/generate_ppm_cover.py"
fi

exec python3 "$PY_SCRIPT" "$@"
