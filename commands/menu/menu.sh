#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: commands/menu/menu.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description:
#   Menu runtime entrypoint. Detects environment (dialog/text/noninteractive),
#   loads the UI theming (Catppuccin), and starts the main menu.
#
# Notes:
#   - ROOT_DIR is resolved via lib/paths.sh.
#   - Theme is driven by CATPPUCCIN_FLAVOUR (LATTE|FRAPPE|MACCHIATO|MOCHA).
# -----------------------------------------------------------------------------

set -euo pipefail

# Resolve repository root.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd -P)/lib/paths.sh"

# Load system + user settings early (theme, log level, dialog defaults etc).
source "${ROOT_DIR}/lib/config.sh"
homelab_config_load

# Initialise logging early.
source "${ROOT_DIR}/lib/logging.sh"
homelab_log_init

# Load core libs
source "$ROOT_DIR/commands/menu/lib/dialog_api.sh"
source "$ROOT_DIR/commands/menu/lib/dialogrc.sh"
source "$ROOT_DIR/commands/menu/lib/env.sh"
source "$ROOT_DIR/commands/menu/lib/logger.sh"
source "$ROOT_DIR/commands/menu/lib/settings_ui.sh"
source "$ROOT_DIR/commands/menu/lib/menu_runner.sh"
source "$ROOT_DIR/commands/menu/lib/ui.sh"

MENU_DIR="$ROOT_DIR/commands/menu/menus"
export MENU_DIR

detect_environment

# Default entry menu
run_menu "$MENU_DIR/main.menu.sh"
