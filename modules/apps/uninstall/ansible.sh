#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/ansible.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps uninstall module for ansible.
# Purpose: Uninstalls ansible using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/ansible.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall Ansible

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "[INFO] ansible not installed"
  exit 0
fi

pkg_remove ansible
echo "[INFO] ansible removed"
