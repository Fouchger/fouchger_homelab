#!/usr/bin/env bash
set -euo pipefail

#------------------------------------------
# Find the repository root by locating the directory that contains ".root_marker"
find_ROOT_DIR() {
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

# If ROOT_DIR is unset (or incorrect), discover it
if [[ -z "${ROOT_DIR:-}" || ! -e "${ROOT_DIR}/.root_marker" ]]; then
  if ROOT_DIR="$(find_ROOT_DIR "$start_dir")"; then
    export ROOT_DIR
  else
    echo "ERROR: Could not locate repo root (.root_marker not found starting from: $start_dir)" >&2
    exit 1
  fi
fi
echo ""
echo "---------------------------------------"
echo "REPO ROOT: $ROOT_DIR"
echo "---------------------------------------"
echo ""
export ROOT_DIR
#------------------------------------------

# Load core libs
source "$ROOT_DIR/commands/menu/lib/dialog_api.sh"
source "$ROOT_DIR/commands/menu/lib/dialogrc.sh"
source "$ROOT_DIR/commands/menu/lib/env.sh"
source "$ROOT_DIR/commands/menu/lib/logger.sh"
source "$ROOT_DIR/commands/menu/lib/menu_runner.sh"
source "$ROOT_DIR/commands/menu/lib/ui.sh"
source "$ROOT_DIR/commands/menu/menus/main.menu.sh"
source "$ROOT_DIR/commands/menu/menus/system.menu.sh"

detect_environment

# Default entry menu
run_menu "$ROOT_DIR/commands/menu/menus/main.menu.sh"
