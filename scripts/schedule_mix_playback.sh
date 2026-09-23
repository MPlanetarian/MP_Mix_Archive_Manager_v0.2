#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - DJ Mix Scheduler Launcher
# "Schedule DJ Mix or Multiple DJ Mixes to Play Loudly (Uses Default Audio Player)"
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/schedule_mix_playback.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/schedule_mix_playback.py"
fi

exec python3 "$PY_SCRIPT" "$@"
