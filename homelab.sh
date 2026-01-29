#!/usr/bin/env bash
# ==========================================================
# homelab.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Purpose: Repo entry point. Ensures perms then launches menu.
# ==========================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${ROOT_DIR}/bin/lib/log.sh"
# shellcheck source=/dev/null
source "${ROOT_DIR}/bin/lib/perms.sh"

init_logging "${ROOT_DIR}/state/logs/homelab.log"

ensure_executables "${ROOT_DIR}"

exec "${ROOT_DIR}/bin/menu.sh"
