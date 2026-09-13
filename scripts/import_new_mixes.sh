#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/import_new_mixes.py"
if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/import_new_mixes.py"
fi
if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="/run/media/$USER/WD BLACK B/MIX_ARCHIVE/import_new_mixes.py"
fi

exec python3 "$PY_SCRIPT" "$@"
