#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Mix Publishing Calendar & Scheduler Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/publish_calendar_scheduler.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/publish_calendar_scheduler.py"
fi

exec python3 "$PY_SCRIPT" "$@"
