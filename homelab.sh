#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: homelab.sh
# Created: 2026-01-31
# Updated: 2026-02-01
# Description: Primary entrypoint for the homelab menu and commands.
# Purpose: Routes into the menu command, which owns the runtime lifecycle.
# Usage:
#   ./homelab.sh
# Notes:
#   - The command runner in lib/command_runner.sh initialises env, logging, and
#     summary artefacts. This wrapper simply hands off to the menu.
# -----------------------------------------------------------------------------

#!/usr/bin/env bash
set -euo pipefail

#------------------------------------------
# Find the repository root by locating the directory that contains ".root_marker"
find_repo_root() {
  local dir="${1:-$PWD}"

  while :; do
    if [[ -e "$dir/.root_marker" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi

    [[ "$dir" == "/" ]] && return 1
    dir="$(dirname -- "$dir")"
  done
}

# Prefer script location as the starting point (works even if invoked from elsewhere)
script_path="${BASH_SOURCE[0]:-$0}"
start_dir="$(cd -- "$(dirname -- "$script_path")" 2>/dev/null && pwd -P || pwd -P)"

# If REPO_ROOT is unset (or incorrect), discover it
if [[ -z "${REPO_ROOT:-}" || ! -e "${REPO_ROOT}/.root_marker" ]]; then
  if REPO_ROOT="$(find_repo_root "$start_dir")"; then
    export REPO_ROOT
  else
    echo "ERROR: Could not locate repo root (.root_marker not found starting from: $start_dir)" >&2
    exit 1
  fi
fi

echo "Root Dir = $REPO_ROOT"
#------------------------------------------

# Load core libs
source "$ROOT_DIR/commands/menu/lib/env.sh"
source "$ROOT_DIR/commands/menu/lib/ui.sh"
source "$ROOT_DIR/commands/menu/lib/logger.sh"
source "$ROOT_DIR/commands/menu/lib/menu_runner.sh"

detect_environment

# Default entry menu
run_menu "$ROOT_DIR/commands/menu/menus/main.menu.sh"