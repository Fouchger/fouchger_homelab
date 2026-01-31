#!/usr/bin/env bash
# ==========================================================
# Filename: homelab.sh
# Created:  2026-01-31
# Updated:  2026-01-31
# Description:
#   Primary entrypoint for the fouchger_homelab menu runtime.
# Purpose:
#   - Initialise environment, runtime lifecycle, logging, validation, and UI plumbing.
#   - Hand off to menu flow (implemented in later sprints).
# Usage:
#   ./homelab.sh
# Prerequisites:
#   - Project bootstrapped (see bootstrap.sh)
#   - bash, git (for some flows), dialog (recommended for UI)
# Notes:
#   - Sprint 1 provides runtime foundation only; menu flows arrive in later sprints.
# ==========================================================
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load runtime plumbing
# shellcheck source=lib/runtime.sh
source "$ROOT_DIR/lib/runtime.sh"
# shellcheck source=lib/ui_dialog.sh
source "$ROOT_DIR/lib/ui_dialog.sh"

main() {
  runtime_init
  ui_info "Homelab runtime is initialised ✅"
  ui_info "Menu is not yet implemented (Sprint 1). Run: ./bin/dev/test_runtime.sh"

  runtime_summary_line "homelab.sh exited before menu handoff (Sprint 1 placeholder)"
  runtime_finish 0
}

main "$@"
