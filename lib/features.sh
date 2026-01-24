#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: lib/features.sh
# Created:  2026-01-24
# Description: Feature flag helpers backed by state.env
#
# Purpose
#   Provide simple on/off capability toggles that can be changed per host
#   without changing code. Flags are stored in the state file (state.env).
#
# Convention
#   FEATURE_<NAME>=1 enables a capability
#   FEATURE_<NAME>=0 (or missing) disables it
#
# Examples
#   state_set FEATURE_PROXMOX 1
#   state_set FEATURE_MIKROTIK 0
#
# Notes
#   - This file expects lib/state.sh and lib/ui.sh to be loaded before use.
# -----------------------------------------------------------------------------
echo "lib/features.sh"
set -Eeuo pipefail
IFS=$'\n\t'

feature_key() {
  # Normalise to FEATURE_SOMETHING
  local name="${1:-}"
  name="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9' '_')"
  printf 'FEATURE_%s' "$name"
}

feature_enabled() {
  # Returns 0 (true) if enabled, 1 (false) otherwise
  local name="${1:-}"
  local key val

  key="$(feature_key "$name")"
  val="$(state_get "$key" "0")"

  case "$val" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

feature_require() {
  # Usage:
  #   feature_require PROXMOX "Message to show if disabled" && do_the_thing
  local name="$1"
  local msg="${2:-This feature is not enabled on this host.}"

  if feature_enabled "$name"; then
    return 0
  fi

  ui_msgbox "Not enabled" "$msg"
  return 1
}
