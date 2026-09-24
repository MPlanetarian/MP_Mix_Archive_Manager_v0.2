#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Audio Studio & Hardware Inspector Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/inspect_audio_studio.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/inspect_audio_studio.py"
fi

exec python3 "$PY_SCRIPT" "$@"
