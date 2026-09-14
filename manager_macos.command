#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - macOS Double-Clickable Launcher
# Double-click this script in Finder to run Mix Archive Manager in Terminal.app
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Ensure Homebrew and local tools are available in PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$PATH"

exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
