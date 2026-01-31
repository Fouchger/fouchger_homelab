#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/terraform.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Apps install module for terraform.
# Purpose: Installs terraform using pkg wrapper with nala/apt-get fallback.
# Usage:
#   ./modules/apps/install/terraform.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# Install Terraform

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v terraform >/dev/null 2>&1; then
  echo "[INFO] terraform already installed"
  exit 0
fi

if ! apt-cache show terraform >/dev/null 2>&1; then
  echo "[ERROR] terraform package not available via configured apt repositories"
  echo "[INFO] Consider adding the HashiCorp apt repository, then re-run"
  exit 1
fi

pkg_update
pkg_install terraform
echo "[INFO] terraform installed"
