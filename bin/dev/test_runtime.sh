#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: bin/dev/test_runtime.sh
# Created: 2026-01-30
# Updated: 2026-01-30
# Description: Sprint 1 demo harness for runtime foundation.
# Purpose: Prove RUN_ID creation, logging + summary generation, and no secret leak.
# Usage:
#   ./bin/dev/test_runtime.sh
# Prerequisites:
#   - bash >= 4
#   - dialog (optional; script will fallback if absent)
# Notes:
#   - This script intentionally sets a dummy secret and validates redaction.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export HOMELAB_LOG_LEVEL=DEBUG
export ROOT_DIR

# Seed a dummy secret in env to validate redaction.
export HOMELAB_TEST_TOKEN="tok_test_1234567890"

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/runtime.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/ui_dialog.sh"

ui_init
runtime_init

ui_msg "Sprint 1 runtime demo" "RUN_ID: ${RUN_ID}\nLog: ${LOG_FILE}"

log_debug "🐛 Debug line (may be hidden depending on log level)" "token=${HOMELAB_TEST_TOKEN}"
log_info "ℹ️ Info line" "hello=world"
log_warn "⚠️ Warn line" "something=minor"

# Demonstrate command capture.
log_cmd "List repo root" ls -la "${ROOT_DIR}" >/dev/null

# Explicit secret leak check in demo (runtime_finish also checks on exit trap).
if validate_no_secrets_leaked "${LOG_FILE}"; then
  ui_msg "✅ Demo validation passed" "No secrets detected in logs."
else
  ui_msg "🛑 Demo validation failed" "Potential secret leak detected."
  exit 2
fi
