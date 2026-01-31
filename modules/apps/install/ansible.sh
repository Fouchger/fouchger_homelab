#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/ansible.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps install module for ansible.
# Purpose: Installs ansible using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/install/ansible.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Install Ansible

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v ansible-playbook >/dev/null 2>&1; then
  echo "[INFO] ansible already installed"
  exit 0
fi

pkg_update
pkg_install ansible
echo "[INFO] ansible installed"
