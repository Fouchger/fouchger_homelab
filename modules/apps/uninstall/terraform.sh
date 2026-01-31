#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/terraform.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps uninstall module for terraform.
# Purpose: Uninstalls terraform using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/uninstall/terraform.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Uninstall Terraform

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if ! command -v terraform >/dev/null 2>&1; then
  echo "[INFO] terraform not installed"
  exit 0
fi

pkg_remove terraform
echo "[INFO] terraform removed"
