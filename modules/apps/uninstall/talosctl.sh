#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/uninstall/talosctl.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps uninstall module for talosctl.
# Purpose: Removes talosctl from /usr/local/bin.
# Usage:
#   ./modules/apps/uninstall/talosctl.sh
# Notes:
# - This only removes the binary installed by this project.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

sudo_cmd="$(pkg__sudo)"

if [[ -f /usr/local/bin/talosctl ]]; then
  ${sudo_cmd} rm -f /usr/local/bin/talosctl
  echo "[INFO] talosctl removed"
else
  echo "[INFO] talosctl not found at /usr/local/bin/talosctl"
fi
