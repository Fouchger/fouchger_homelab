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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# Load core libs
source "$ROOT_DIR/commands/menu/lib/env.sh"
source "$ROOT_DIR/commands/menu/lib/ui.sh"
source "$ROOT_DIR/commands/menu/lib/logger.sh"
source "$ROOT_DIR/commands/menu/lib/menu_runner.sh"

detect_environment

# Default entry menu
run_menu "$ROOT_DIR/commands/menu/menus/main.menu.sh"