#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/app_manager.sh
# Created : 2026-01-26
# Description: Ubuntu LXC App Manager (dialog UI) for fouchger_homelab.
#
# Purpose
#   Interactive selection + install/uninstall manager for Ubuntu 24.04+ LXC
#   containers (Proxmox-friendly). Uses the project-standard UI helpers from
#   lib/ui.sh and persists selections + version pins to an env file.
#
# Entry points
#   - app_manager_menu   (preferred): opens the main menu.
#   - apm_ui_main_menu   (internal):  menu implementation.
#
# Design notes
#   - No direct dialog calls: uses ui_menu/ui_checklist/ui_input/ui_confirm/
#     ui_msgbox/ui_textbox when present.
#   - Safe-by-default removals: removes only apps installed by this manager
#     (marker based).
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Bootstrapping
#
# This module is typically sourced by bin/homelab (after lib/modules.sh has
# loaded lib/ui.sh, lib/logging.sh, lib/paths.sh, etc.).
#
# However operators also run it directly during development and troubleshooting.
# In that scenario, we self-bootstrap the project libraries so functions like
# ui_msgbox and variables like APPM_DIR exist.
# -----------------------------------------------------------------------------

_apm_repo_root() {
  # scripts/app_manager/app_manager.sh -> <repo>
  local d
  d="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
  printf '%s' "$d"
}

_apm_bootstrap_project_libs() {
  # If UI helpers are missing, we are almost certainly being run standalone.
  if ! declare -F ui_msgbox >/dev/null 2>&1; then
    local root
    root="${REPO_ROOT:-$(_apm_repo_root)}"
    export REPO_ROOT="$root"

    # shellcheck disable=SC1091
    source "${REPO_ROOT}/lib/modules.sh"
    homelab_load_lib
  fi
}

_apm_bootstrap_project_libs

_apm_this_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

_apm_load_modules() {
  local base
  base="$(_apm_this_dir)"

  # These modules expect the project to have already loaded:
  # - lib/ui.sh (ui_menu, ui_checklist, ui_input, ui_confirm, ui_msgbox, ...)
  # - lib/logging.sh (info, warn, ok, logging_rotate_file, logging_set_layer1_file)
  # - lib/paths.sh (APPM_DIR, ENV_BACKUP_DIR, STATE_DIR, MARKER_DIR, BIN_DIR)

  # Core modules
  # shellcheck disable=SC1091
  source "${base}/lib/constants.sh"
  source "${base}/lib/catalogue.sh"
  source "${base}/lib/profiles.sh"
  source "${base}/lib/env.sh"
  source "${base}/lib/pins.sh"

  # Runtime / install modules
  source "${base}/lib/markers.sh"
  source "${base}/lib/pkg_utils.sh"
  source "${base}/lib/pkg_mgr.sh"
  source "${base}/lib/installers.sh"
  source "${base}/lib/audit.sh"
  source "${base}/lib/apply.sh"

  # UI
  source "${base}/lib/ui_flows.sh"
}

_apm_load_modules

# Compatibility with historical menu wiring (bin/homelab expected this name).
app_manager_menu() { apm_ui_main_menu; }

# If executed directly, open the menu.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  app_manager_menu
fi
