#!/usr/bin/env bash
# Uninstall yq
#
# Purpose:
#   Uninstall yq from the local host.
#
# Contract:
#   - Must be idempotent: if not installed, exit 0.
#   - Must not prompt interactively.
#   - Must log via stdout/stderr.
#   - Must never print secrets.
#
set -euo pipefail

echo "[INFO] yq: uninstall stub (no-op). Replace with real uninstaller logic."
exit 0
