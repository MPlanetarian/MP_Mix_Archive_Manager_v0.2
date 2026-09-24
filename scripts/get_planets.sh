#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Live Planets Above Horizon Fetcher
# Displays which major planets are currently above the horizon for the observer's location.
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

# Load configuration if present
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
fi

PLANETS_ENABLED="${PLANETS_ENABLED:-true}"
WEATHER_LOCATION="${WEATHER_LOCATION:-Swansea, UK}"

[ "$PLANETS_ENABLED" != "true" ] && exit 0

PY_SCRIPT="$SCRIPT_DIR/scripts/get_planets.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$PWD/scripts/get_planets.py"

if [ -f "$PY_SCRIPT" ] && command -v python3 >/dev/null 2>&1; then
    exec python3 "$PY_SCRIPT" --location "$WEATHER_LOCATION" "$@"
fi

exit 0
