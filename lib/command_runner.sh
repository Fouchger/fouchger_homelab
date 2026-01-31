#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/command_runner.sh
# Created: 2026-01-31
# Updated: 2026-01-31
#
# Description:
#   Standard runner for command scripts under ./commands.
#
# Purpose:
#   - Provide a consistent wrapper that initialises UI and runtime.
#   - Execute a command implementation function.
#   - Append a high-level summary line for traceability.
#   - Exit with the implementation's return code (runtime_finish runs via trap).
#
# Usage:
#   source "${ROOT_DIR}/lib/command_runner.sh"
#   command_run "menu" command_impl "$@"
#
# Prerequisites:
#   - bash >= 4
#   - ROOT_DIR exported or derivable from the calling script
#   - lib/runtime.sh and lib/ui_dialog.sh available
#
# Notes:
#   - Commands should never call runtime_finish directly.
#   - Commands that require secrets must call secrets_load + secrets_require.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

command_run() {
  local command_name impl rc
  command_name="${1:-command}"; shift || true
  impl="${1:-}"; shift || true

  if [[ -z "${impl}" ]]; then
    echo "❌ command_run requires an implementation function name" >&2
    return 2
  fi

  : "${ROOT_DIR:=""}"
  if [[ -z "${ROOT_DIR}" ]]; then
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    export ROOT_DIR
  fi

  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/runtime.sh"
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/lib/ui_dialog.sh"

  # Initialise runtime first so configuration and logging are available before UI.
  runtime_init
  ui_init

  log_section "Command: ${command_name}"

  set +o errexit
  "${impl}" "$@"
  rc=$?
  set -o errexit

  if [[ ${rc} -eq 0 ]]; then
    runtime_summary_line "${command_name}: success"
  else
    runtime_summary_line "${command_name}: failed (rc=${rc})"
  fi

  return "${rc}"
}
