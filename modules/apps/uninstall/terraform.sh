#!/usr/bin/env bash
# Uninstall Terraform
#
# Purpose:
#   Uninstall Terraform from the local host.
#
# Contract:
#   - Must be idempotent: if not installed, exit 0.
#   - Must not prompt interactively.
#   - Must log via stdout/stderr.
#   - Must never print secrets.
#
set -euo pipefail

echo "[INFO] terraform: uninstall stub (no-op). Replace with real uninstaller logic."
exit 0
