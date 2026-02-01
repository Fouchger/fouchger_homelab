#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load core libs
source "$BASE_DIR/lib/env.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/logger.sh"
source "$BASE_DIR/lib/menu_runner.sh"
source "$BASE_DIR/lib/dialogrc.sh"
source "$BASE_DIR/lib/dialog_api.sh"

detect_environment

# Default entry menu
run_menu "$BASE_DIR/menus/main.menu.sh"
