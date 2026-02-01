#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: homelab.sh
# Created: 2026-01-31
# Updated: 2026-02-01
# Description: Primary entrypoint for the homelab menu and commands.
# Purpose: Routes into the menu command, which owns the runtime lifecycle.
# Usage:
#   ./homelab.sh
# Notes:
#   - The command runner in lib/command_runner.sh initialises env, logging, and
#     summary artefacts. This wrapper simply hands off to the menu.
# -----------------------------------------------------------------------------

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

main() {
  exec "${ROOT_DIR}/commands/menu.sh" "$@"
}

main "$@"