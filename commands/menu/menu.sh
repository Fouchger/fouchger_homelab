#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# Load core libs
source "$ROOT_DIR/commands/menu/lib/env.sh"
source "$ROOT_DIR/commands/menu/lib/ui.sh"
source "$ROOT_DIR/commands/menu/lib/logger.sh"
source "$ROOT_DIR/commands/menu/lib/menu_runner.sh"
source "$ROOT_DIR/commands/menu/lib/dialogrc.sh"
source "$ROOT_DIR/commands/menu/lib/dialog_api.sh"

detect_environment

# Default entry menu
run_menu "$ROOT_DIR/commands/menu/menus/main.menu.sh"
