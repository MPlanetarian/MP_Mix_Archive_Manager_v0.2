#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - Local Launcher
# ==============================================================================
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
if [ ! -f "$SCRIPT_DIR/Mix_Archive_Manager.sh" ]; then
    for _c in \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.2" \
        "$HOME/MP_Mix_Manager_v0.2" \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.1" \
        "$HOME/MP_Mix_Manager_v0.1"; do
        if [ -f "$_c/Mix_Archive_Manager.sh" ]; then
            SCRIPT_DIR="$_c"
            break
        fi
    done
fi
unset _RESOLVED_SRC _RESOLVED_DIR _c
exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
