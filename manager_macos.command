#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - macOS Double-Clickable Launcher
# Double-click this script in Finder to run Mix Archive Manager in Terminal.app
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

# Ensure Homebrew and local tools are available in PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$PATH"

if [ -x "/opt/homebrew/bin/bash" ]; then
    exec /opt/homebrew/bin/bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
elif [ -x "/usr/local/bin/bash" ]; then
    exec /usr/local/bin/bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
elif command -v bash >/dev/null 2>&1; then
    exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
fi
