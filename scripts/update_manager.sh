#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.2 - System Updater
# Purpose: Check for and install latest version of Mix Archive Manager
# Usage:
#   mix-archive-manager update          (Checks and installs latest version)
#   mix-archive-manager update --check  (Checks for updates without installing)
#   mix-archive-manager --version       (Displays current version)
# ==============================================================================

set -euo pipefail

# ANSI Styling
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Resolve codebase directory
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
_SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
if [ "$(basename "$_SCRIPT_DIR")" = "scripts" ]; then
    CODEBASE_DIR="$(cd -P "$_SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
else
    CODEBASE_DIR="$_SCRIPT_DIR"
fi
unset _RESOLVED_SRC _RESOLVED_DIR _SCRIPT_DIR

get_current_version() {
    if [ -f "$CODEBASE_DIR/VERSION" ]; then
        head -n 1 "$CODEBASE_DIR/VERSION" | tr -d ' \t\r\n'
    elif [ -f "$CODEBASE_DIR/CHANGELOG.md" ]; then
        grep -E '^## \[[0-9]+\.[0-9]+' "$CODEBASE_DIR/CHANGELOG.md" | head -1 | sed -E 's/.*\[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/'
    else
        echo "0.2.1"
    fi
}

CURRENT_VER="$(get_current_version)"

# ------------------------------------------------------------------------------
# 1. Version Flag Check (--version, -v, version)
# ------------------------------------------------------------------------------
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ] || [ "${1:-}" = "version" ]; then
    COMMIT_HASH="unknown"
    COMMIT_DATE=""
    if [ -d "$CODEBASE_DIR/.git" ] && command -v git >/dev/null 2>&1; then
        COMMIT_HASH=$(git -C "$CODEBASE_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
        COMMIT_DATE=$(git -C "$CODEBASE_DIR" log -1 --format=%cd --date=short 2>/dev/null || echo "")
    fi
    if [ -n "$COMMIT_DATE" ]; then
        echo -e "Mix Archive Manager ${BOLD}v${CURRENT_VER}${NC} (${CYAN}${COMMIT_HASH}${NC}, ${COMMIT_DATE})"
    else
        echo -e "Mix Archive Manager ${BOLD}v${CURRENT_VER}${NC} (${CYAN}${COMMIT_HASH}${NC})"
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. Help Flag
# ------------------------------------------------------------------------------
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    echo -e "${BOLD}Mix Archive Manager - System Updater${NC}"
    echo -e "Usage:"
    echo -e "  mix-archive-manager update           Check for and install the latest version"
    echo -e "  mix-archive-manager update --check   Check for available updates without installing"
    echo -e "  mix-archive-manager update --force   Force re-pull/update from remote"
    echo -e "  mix-archive-manager --version        Display current installed version"
    exit 0
fi

CHECK_ONLY=0
FORCE_UPDATE=0

for arg in "$@"; do
    case "$arg" in
        --check|-c) CHECK_ONLY=1 ;;
        --force|-f) FORCE_UPDATE=1 ;;
    esac
done

# ------------------------------------------------------------------------------
# 3. Banner
# ------------------------------------------------------------------------------
echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}                 Mix Archive Manager - System Updater                 ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "  Current Installed Version: ${BOLD}${GREEN}v${CURRENT_VER}${NC}"
echo -e "  Codebase Directory:        ${CYAN}${CODEBASE_DIR}${NC}"

# Check git availability
if ! command -v git >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: 'git' command not found. Cannot verify remote repository updates.${NC}"
    echo -e "Mix Archive Manager is running version: ${BOLD}${GREEN}v${CURRENT_VER}${NC}"
    exit 0
fi

if [ ! -d "$CODEBASE_DIR/.git" ] && ! git -C "$CODEBASE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${YELLOW}Notice: ${CODEBASE_DIR} is not a git repository.${NC}"
    echo -e "Mix Archive Manager is running version: ${BOLD}${GREEN}v${CURRENT_VER}${NC}"
    exit 0
fi

cd "$CODEBASE_DIR"

CURRENT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'main')"
echo -e "  Active Branch:             ${CYAN}${CURRENT_BRANCH}${NC} (${DIM}commit: ${CURRENT_COMMIT}${NC})"
echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"

# ------------------------------------------------------------------------------
# 4. Fetch Updates from Remote
# ------------------------------------------------------------------------------
echo -e "Checking for updates from remote repository (${DIM}origin/${CURRENT_BRANCH}${NC})..."

FETCH_OK=1
if ! git fetch origin "$CURRENT_BRANCH" --quiet 2>/dev/null; then
    if ! git fetch origin "$CURRENT_BRANCH" 2>&1; then
        FETCH_OK=0
    fi
fi

if [ "$FETCH_OK" -eq 0 ]; then
    echo -e "\n${YELLOW}Notice: Unable to connect to remote repository (offline or remote unreachable).${NC}"
    echo -e "Mix Archive Manager is running version: ${BOLD}${GREEN}v${CURRENT_VER}${NC}"
    exit 0
fi

# Determine upstream commit
UPSTREAM="origin/$CURRENT_BRANCH"
if ! git rev-parse "$UPSTREAM" >/dev/null 2>&1; then
    UPSTREAM="origin/main"
fi

if ! git rev-parse "$UPSTREAM" >/dev/null 2>&1; then
    echo -e "\n${YELLOW}Notice: No remote tracking branch found for origin.${NC}"
    echo -e "Mix Archive Manager is running version: ${BOLD}${GREEN}v${CURRENT_VER}${NC}"
    exit 0
fi

BEHIND_COUNT=$(git rev-list --count HEAD.."$UPSTREAM" 2>/dev/null || echo 0)
AHEAD_COUNT=$(git rev-list --count "$UPSTREAM"..HEAD 2>/dev/null || echo 0)

# Check remote version string if available
REMOTE_VER=""
if git cat-file -e "${UPSTREAM}:VERSION" 2>/dev/null; then
    REMOTE_VER="$(git show "${UPSTREAM}:VERSION" 2>/dev/null | head -n 1 | tr -d ' \t\r\n')"
fi
if [ -z "$REMOTE_VER" ] && git cat-file -e "${UPSTREAM}:CHANGELOG.md" 2>/dev/null; then
    REMOTE_VER="$(git show "${UPSTREAM}:CHANGELOG.md" 2>/dev/null | grep -E '^## \[[0-9]+\.[0-9]+' | head -1 | sed -E 's/.*\[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/' || true)"
fi

# ------------------------------------------------------------------------------
# 5. Up To Date Condition
# ------------------------------------------------------------------------------
if [ "$BEHIND_COUNT" -eq 0 ] && [ "$FORCE_UPDATE" -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}✓ Mix Archive Manager is running the latest version: v${CURRENT_VER}${NC}"
    if [ "$AHEAD_COUNT" -gt 0 ]; then
        echo -e "  ${DIM}(Local development branch is ahead of remote by ${AHEAD_COUNT} commit(s))${NC}"
    fi
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    exit 0
fi

# ------------------------------------------------------------------------------
# 6. Update Available
# ------------------------------------------------------------------------------
TARGET_VER="${REMOTE_VER:-latest}"
echo -e "\n${BOLD}${CYAN}★ A new version of Mix Archive Manager is available: v${TARGET_VER}${NC}"
echo -e "  Remote commits available: ${BOLD}${YELLOW}${BEHIND_COUNT}${NC}"
echo -e "\n${DIM}Incoming commits:${NC}"
git log --oneline -n "$BEHIND_COUNT" "$UPSTREAM"

if [ "$CHECK_ONLY" -eq 1 ]; then
    echo -e "\nRun '${BOLD}${GREEN}mix-archive-manager update${NC}' or '${BOLD}${GREEN}manager update${NC}' to install."
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    exit 0
fi

# ------------------------------------------------------------------------------
# 7. Install Update
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}Installing the latest version...${NC}"

# Handle uncommitted local modifications safely
STASH_NEEDED=0
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo -e "  ${DIM}Temporarily stashing local modifications...${NC}"
    git stash push -m "Auto-stashed before update on $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1 || true
    STASH_NEEDED=1
fi

UPDATE_SUCCESS=1
if git pull origin "$CURRENT_BRANCH" 2>&1; then
    echo -e "  ${GREEN}✓ Pulled latest changes from origin/${CURRENT_BRANCH}.${NC}"
else
    echo -e "  ${YELLOW}Fast-forward pull not possible; attempting rebase integration...${NC}"
    if git pull --rebase origin "$CURRENT_BRANCH" 2>&1; then
        echo -e "  ${GREEN}✓ Rebased cleanly onto origin/${CURRENT_BRANCH}.${NC}"
    else
        echo -e "\n${RED}Error: Git pull/rebase encountered merge conflicts.${NC}"
        echo -e "${YELLOW}Please inspect 'git status' in ${CODEBASE_DIR} and resolve conflicts.${NC}"
        UPDATE_SUCCESS=0
    fi
fi

if [ "$STASH_NEEDED" -eq 1 ]; then
    echo -e "  ${DIM}Restoring stashed local modifications...${NC}"
    git stash pop >/dev/null 2>&1 || true
fi

if [ "$UPDATE_SUCCESS" -eq 0 ]; then
    exit 1
fi

# Ensure executable permissions across all executables and scripts
chmod +x "$CODEBASE_DIR/Mix_Archive_Manager.sh" 2>/dev/null || true
chmod +x "$CODEBASE_DIR/bin/"* 2>/dev/null || true
chmod +x "$CODEBASE_DIR/scripts/"*.sh "$CODEBASE_DIR/scripts/"*.py 2>/dev/null || true

# Refresh user symlinks in ~/.local/bin and ~/manager.sh
mkdir -p "$HOME/.local/bin" 2>/dev/null || true
ln -sf "$CODEBASE_DIR/bin/mix-archive-manager" "$HOME/.local/bin/mix-archive-manager" 2>/dev/null || true
ln -sf "$CODEBASE_DIR/bin/mix-archive-manager" "$HOME/.local/bin/manager" 2>/dev/null || true
ln -sf "$CODEBASE_DIR/bin/launch-manager-fullscreen" "$HOME/.local/bin/launch-manager-fullscreen" 2>/dev/null || true
ln -sf "$CODEBASE_DIR/Mix_Archive_Manager.sh" "$HOME/manager.sh" 2>/dev/null || true

# Refresh dynamic MOTD banner
if [ -x "$CODEBASE_DIR/scripts/update_system_motd.sh" ]; then
    "$CODEBASE_DIR/scripts/update_system_motd.sh" --apply >/dev/null 2>&1 || true
elif [ -f "$CODEBASE_DIR/scripts/manage_motd.py" ]; then
    python3 "$CODEBASE_DIR/scripts/manage_motd.py" --apply >/dev/null 2>&1 || true
fi

NEW_VER="$(get_current_version)"
NEW_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}✓ Mix Archive Manager successfully updated to v${NEW_VER}!${NC}"
echo -e "  Installed Commit: ${CYAN}${NEW_COMMIT}${NC} (${DIM}$(git log -1 --format=%cd --date=short 2>/dev/null || echo '')${NC})"
echo -e "${GREEN}======================================================================${NC}"
