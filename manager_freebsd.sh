#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - FreeBSD Launcher
# Sets up FreeBSD environment, paths, and launches Mix Archive Manager
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Ensure standard FreeBSD and local tool paths are in PATH
export PATH="/usr/local/bin:/usr/local/sbin:$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$HOME/bin:$PATH"

exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
