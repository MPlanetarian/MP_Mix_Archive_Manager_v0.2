#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.1 - Local Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
