#!/usr/bin/env bash
# ==============================================================================
# File: archieve/bin/menu.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Archived legacy script retained for reference.
# Purpose: Retained for historical context; not part of current execution path.
# Usage:
#   ./archieve/bin/menu.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# ==========================================================
# bin/menu.sh
# Purpose: Main dialog menu controller for homelab workflows.
# ==========================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/bin/lib/ui.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/bin/lib/log.sh"

STATE_DIR="${ROOT_DIR}/state"
SELECTIONS_FILE="${STATE_DIR}/selections.env"

ensure_state() {
  mkdir -p "${STATE_DIR}/logs"
  touch "$SELECTIONS_FILE"
}

load_selections() {
  # stored as: APPS="docker tailscale terraform"
  # shellcheck disable=SC1090
  source "$SELECTIONS_FILE" 2>/dev/null || true
  APPS="${APPS:-}"
}

save_selections() {
  printf 'APPS="%s"\n' "$APPS" > "$SELECTIONS_FILE"
}

main_menu() {
  ui_init
  ensure_state
  load_selections

  while true; do
    local choice
    choice="$(ui_menu "Main Menu" "Choose an option" \
      1 "Profiles" \
      2 "Apps" \
      3 "Proxmox access" \
      4 "Templates" \
      5 "Provisioning (Terraform)" \
      6 "Configuration (Ansible)" \
      7 "Extend" \
      0 "Exit")" || true

    case "${choice:-0}" in
      1) profiles_menu ;;
      2) apps_menu ;;
      3) proxmox_access_menu ;;
      4) templates_menu ;;
      5) terraform_menu ;;
      6) ansible_menu ;;
      7) extend_menu ;;
      0) break ;;
    esac
  done
}

profiles_menu() {
  ui_msg "Profiles" "Coming next: profile selection (replace vs add), driven from config/profiles.yml."
}

apps_menu() {
  ui_msg "Apps" "Coming next: manual select install/uninstall, driven from config/apps.yml."
}

proxmox_access_menu() {
  ui_msg "Proxmox access" "Coming next: create role/user/token and persist non-secret config."
}

templates_menu() {
  ui_msg "Templates" "Coming next: download Ubuntu 22.04+ LXC templates and latest Talos image."
}

terraform_menu() {
  ui_msg "Terraform" "Coming next: plan/apply/destroy using modules/proxmox/terraform."
}

ansible_menu() {
  ui_msg "Ansible" "Coming next: run playbooks in modules/proxmox/ansible against provisioned nodes."
}

extend_menu() {
  ui_msg "Extend" "Add new menu entries by dropping scripts into modules/ and registering here."
}

main_menu
