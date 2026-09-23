#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Traktor Pro History Playlist Generator
# Exclusively supported on macOS.
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
    elif [ -x "/opt/homebrew/bin/python3" ]; then
        PYTHON_CMD="/opt/homebrew/bin/python3"
    else
        echo "Error: Python 3 is required but was not found in PATH." >&2
        exit 1
    fi
fi

# Locate generate_traktor_playlist_from_history.py
GEN_PY="$SCRIPT_DIR/generate_traktor_playlist_from_history.py"
if [ ! -f "$GEN_PY" ]; then
    if [ -f "$SCRIPT_DIR/scripts/generate_traktor_playlist_from_history.py" ]; then
        GEN_PY="$SCRIPT_DIR/scripts/generate_traktor_playlist_from_history.py"
    elif [ -f "$PWD/scripts/generate_traktor_playlist_from_history.py" ]; then
        GEN_PY="$PWD/scripts/generate_traktor_playlist_from_history.py"
    elif [ -f "$PWD/generate_traktor_playlist_from_history.py" ]; then
        GEN_PY="$PWD/generate_traktor_playlist_from_history.py"
    else
        echo "Error: generate_traktor_playlist_from_history.py not found in $SCRIPT_DIR or subdirectories." >&2
        exit 1
    fi
fi

exec "$PYTHON_CMD" "$GEN_PY" "$@"
