#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Advanced Audio File Specification & Stream Inspector
# Inspects playing or specified mix audio files: WAV, FLAC, Bit Depth, Sample Rate,
# Codec, Duration, File Size, File Path, Title, and live Audio Interface / Latency.
# ==============================================================================

set -o pipefail 2>/dev/null || true

_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")/.." >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

PY_INSPECT="$SCRIPT_DIR/scripts/inspect_playing_audio.py"
[ ! -f "$PY_INSPECT" ] && PY_INSPECT="$PWD/scripts/inspect_playing_audio.py"

if [ -f "$PY_INSPECT" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$PY_INSPECT" "$@"
else
    echo "Error: Python 3 or scripts/inspect_playing_audio.py missing."
    exit 1
fi
