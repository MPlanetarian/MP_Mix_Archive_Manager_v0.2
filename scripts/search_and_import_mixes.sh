#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.1 - Universal Mix Search & Importer Shell Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/search_and_import_mixes.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/search_and_import_mixes.py"
fi

if [ ! -f "$PY_SCRIPT" ]; then
    echo "Error: search_and_import_mixes.py not found in $SCRIPT_DIR!" >&2
    exit 1
fi

exec python3 "$PY_SCRIPT" "$@"
