#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Live Weather Information Fetcher & Cacher
# Displays local meteorological conditions below the manager startup banner.
# Default Location: Swansea, UK (Configurable via config.env & settings menu)
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

# Load configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
fi

WEATHER_ENABLED="${WEATHER_ENABLED:-true}"
WEATHER_LOCATION="${WEATHER_LOCATION:-Swansea, UK}"
CACHE_FILE="$SCRIPT_DIR/assets/weather_cache.txt"
[ ! -d "$(dirname "$CACHE_FILE")" ] && CACHE_FILE="/tmp/mix_manager_weather_cache_${USER}.txt"

CACHE_TTL=1200 # 20 minutes in seconds

fetch_live_weather() {
    [ -z "$WEATHER_LOCATION" ] && return 1
    local loc_encoded
    if command -v python3 >/dev/null 2>&1; then
        loc_encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$WEATHER_LOCATION" 2>/dev/null || echo "$WEATHER_LOCATION")
    else
        loc_encoded="${WEATHER_LOCATION// /+}"
    fi

    local live_data
    live_data=$(curl -s -f -m 2.0 "wttr.in/${loc_encoded}?format=%c+%t+(%C)+•+Wind:+%w+•+Humidity:+%h" 2>/dev/null)
    
    # Filter out empty or HTML error pages
    if [ -n "$live_data" ] && [[ "$live_data" != *"<html"* ]] && [[ "$live_data" != *"Unknown location"* ]] && [[ "$live_data" != *"502"* ]]; then
        live_data=$(echo "$live_data" | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local now
        now=$(date +%s)
        echo "${now}|${live_data}" > "$CACHE_FILE" 2>/dev/null || true
        echo "$live_data"
        return 0
    fi
    return 1
}

case "${1:-get}" in
    get)
        [ "$WEATHER_ENABLED" != "true" ] && exit 0
        [ -z "$WEATHER_LOCATION" ] && exit 0

        # Check local cache
        if [ -f "$CACHE_FILE" ]; then
            IFS="|" read -r c_time c_data < "$CACHE_FILE" 2>/dev/null || true
            now=$(date +%s)
            if [ -n "$c_time" ] && [ -n "$c_data" ] && [ "$((now - c_time))" -lt "$CACHE_TTL" ]; then
                echo "$c_data"
                exit 0
            fi
        fi

        # Cache expired or absent; fetch live
        if ! fetch_live_weather; then
            # Fallback to stale cache if network failed
            if [ -f "$CACHE_FILE" ]; then
                IFS="|" read -r _ c_data < "$CACHE_FILE" 2>/dev/null || true
                [ -n "$c_data" ] && echo "$c_data"
            fi
        fi
        ;;

    refresh)
        [ "$WEATHER_ENABLED" != "true" ] && { echo "Weather display is currently disabled."; exit 0; }
        echo "Fetching fresh live weather for '$WEATHER_LOCATION'..."
        if fetch_live_weather; then
            echo "✓ Weather updated successfully."
        else
            echo "✗ Failed to fetch live weather (check network connection or location)."
        fi
        ;;

    clear)
        rm -f "$CACHE_FILE" 2>/dev/null || true
        echo "✓ Weather cache cleared."
        ;;

    status)
        echo "Weather Enabled:  $WEATHER_ENABLED"
        echo "Weather Location: $WEATHER_LOCATION"
        if [ -f "$CACHE_FILE" ]; then
            IFS="|" read -r c_time c_data < "$CACHE_FILE" 2>/dev/null || true
            echo "Cached At:        $(date -d "@$c_time" 2>/dev/null || echo "$c_time")"
            echo "Cached Data:      $c_data"
        else
            echo "Cache File:       No cache file present"
        fi
        ;;

    *)
        echo "Usage: $0 {get|refresh|clear|status}"
        exit 1
        ;;
esac
