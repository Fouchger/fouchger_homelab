#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/modules.sh
# Created: 2026-01-23
# Description: Module loading for fouchger_homelab.
# Usage:
#       source "${REPO_ROOT}/lib/modules.sh"
# Developer notes:
#   -   Keep this file dependency-free so every script can source it early.
#   -   Loading functions are idempotent.
#   -   Load core lib first, then modules.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Ensure REPO_ROOT is defined even when caller didn't set it.
# We anchor off this file's location: <repo>/lib/modules.sh -> <repo>
# -----------------------------------------------------------------------------
if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

source_if_exists() {
  local f="$1"
  [[ -f "${f}" ]] && source "${f}"
}

# -----------------------------------------------------------------------------
# load lib all at once
# -----------------------------------------------------------------------------
homelab_load_lib() {
    # Optional: source feature menus / workflows (best-effort)
    # If a file is missing, we skip it without failing.
    # Core libs
    # shellcheck source=lib/paths.sh
    source "${REPO_ROOT}/lib/paths.sh"
    # shellcheck source=lib/logging.sh
    source "${REPO_ROOT}/lib/logging.sh"
    # shellcheck source=lib/core.sh
    source "${REPO_ROOT}/lib/core.sh"
    # shellcheck source=lib/run.sh
    source "${REPO_ROOT}/lib/run.sh"
    # shellcheck source=lib/state.sh
    source "${REPO_ROOT}/lib/state.sh"

    # UI + framework
    # shellcheck source=lib/ui.sh
    source "${REPO_ROOT}/lib/ui.sh"
    # shellcheck source=lib/actions.sh
    source "${REPO_ROOT}/lib/actions.sh"
    # shellcheck source=lib/menu.sh
    source "${REPO_ROOT}/lib/menu.sh"
}

# -----------------------------------------------------------------------------
# load modules all at once
# -----------------------------------------------------------------------------
homelab_load_modules() {
  # Optional: source feature menus / workflows (best-effort)
  # If a file is missing, we skip it without failing.
  echo "lib/modules.sh - function homelab_load_modules - no modules exist yet"
  # source_if_exists "${REPO_ROOT}/scripts/core/questionnaires.sh"
  # source_if_exists "${REPO_ROOT}/scripts/proxmox/templates.sh"
  # source_if_exists "${REPO_ROOT}/scripts/mikrotik/menu.sh"
  # source_if_exists "${REPO_ROOT}/scripts/dns/menu.sh"
  # source_if_exists "${REPO_ROOT}/scripts/core/app_manager.sh"
}

