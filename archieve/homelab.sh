#!/usr/bin/env bash
# ==============================================================================
# File: archieve/homelab.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Archived legacy script retained for reference.
# Purpose: Retained for historical context; not part of current execution path.
# Usage:
#   ./archieve/homelab.sh
# Prerequisites:
#   - Bash
#   - See docs/developers/development-standards.md
# Notes:
# - Follow repo command/UI contracts.
# - Update 'Updated' when behaviour changes.
# ==============================================================================
# ==========================================================
# homelab.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Purpose: Repo entry point. Ensures perms then launches menu.
# ==========================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export LOG_LEVEL="INFO"   # TRACE | DEBUG | INFO | WARN | ERROR | FATAL


# shellcheck source=/dev/null
source "${ROOT_DIR}/bin/lib/log.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/bin/lib/perms.sh"

init_logging "${ROOT_DIR}/state/logs"

ensure_executables "${ROOT_DIR}"

exec "${ROOT_DIR}/bin/menu.sh"
