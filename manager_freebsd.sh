#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - FreeBSD Launcher
# Sets up FreeBSD environment, paths, and launches Mix Archive Manager
# ==============================================================================
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR
cd "$SCRIPT_DIR" || exit 1

# Ensure standard FreeBSD and local tool paths are in PATH
export PATH="/usr/local/bin:/usr/local/sbin:$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$HOME/bin:$PATH"

exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
