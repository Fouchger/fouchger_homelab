#!/usr/bin/env bash
# Install Curl
#
# Purpose:
#   Install Curl on the local host.
#
# Contract:
#   - Must be idempotent: if already installed, exit 0.
#   - Must not prompt interactively (UI prompts happen in commands/ via dialog).
#   - Must log via stdout/stderr (logger wrapper will capture output).
#   - Must never print secrets.
#
# Notes for developers:
#   This repository is currently in a documentation-first phase.
#   Replace this stub with real installation logic (apt/dnf/pacman or vendor installer).
#
set -euo pipefail

echo "[INFO] curl: install stub (no-op). Replace with real installer logic."
exit 0
