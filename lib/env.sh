#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/env.sh
# Created: 2026-01-30
# Updated: 2026-01-30
# Description: Environment and path bootstrap for fouchger_homelab runtime.
# Purpose: Provide consistent directory paths, safe defaults, and OS/TTY context.
# Usage:
#   source "${ROOT_DIR}/lib/env.sh"
#   env_init
# Prerequisites:
#   - bash >= 4
#   - coreutils (date, mkdir, chmod)
# Notes:
#   - This file intentionally avoids sourcing other project libs to prevent cycles.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# Shellcheck hints (project uses bash)
# shellcheck shell=bash

env_detect_root_dir() {
  # Resolve ROOT_DIR as the repository root.
  # Works when sourced from anywhere inside the repo.
  local src
  src="${BASH_SOURCE[0]}"
  # lib/env.sh -> repo root
  ROOT_DIR="$(cd "$(dirname "$src")/.." && pwd)"
  export ROOT_DIR
}

env_is_tty() {
  [[ -t 1 ]] && [[ -t 2 ]]
}

env_init() {
  : "${ROOT_DIR:=""}"
  if [[ -z "${ROOT_DIR}" ]]; then
    env_detect_root_dir
  fi

  # Core directories
  CONFIG_DIR="${ROOT_DIR}/config"
  STATE_DIR="${ROOT_DIR}/state"
  LOG_DIR="${STATE_DIR}/logs"
  RUNS_DIR="${STATE_DIR}/runs"
  CACHE_DIR="${STATE_DIR}/cache"

  STATE_LOGS_DIR="${LOG_DIR}"
  STATE_RUNS_DIR="${RUNS_DIR}"
  export CONFIG_DIR STATE_DIR LOG_DIR RUNS_DIR CACHE_DIR STATE_LOGS_DIR STATE_RUNS_DIR

  # Context flags
  if env_is_tty; then
    IS_TTY=1
  else
    IS_TTY=0
  fi
  export IS_TTY

  # Create required directories (idempotent)
  mkdir -p "${CONFIG_DIR}" "${STATE_DIR}" "${LOG_DIR}" "${RUNS_DIR}" "${CACHE_DIR}"

  # Standard permissions: readable by user; avoid world-writable state.
  chmod 700 "${STATE_DIR}" "${RUNS_DIR}" "${CACHE_DIR}" 2>/dev/null || true
  chmod 700 "${LOG_DIR}" 2>/dev/null || true

  # Default settings (can be overridden by config/settings.env later)
  : "${HOMELAB_LOG_LEVEL:=INFO}"
  : "${HOMELAB_UI_MODE:=auto}" # auto|dialog|plain

  export HOMELAB_LOG_LEVEL HOMELAB_UI_MODE
}
