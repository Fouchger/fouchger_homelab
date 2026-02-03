#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/config.sh
# Created: 2026-02-01
# Updated: 2026-02-03
# Description:
#   System + user configuration loader and writer.
#
#   Config files are plain bash (KEY=VALUE) so they can be sourced.
#
# Precedence (lowest to highest):
#   1) Repo defaults:   $ROOT_DIR/config/homelab.conf.defaults
#   2) Repo state:      $HOMELAB_STATE_CONFIG_FILE (default: $ROOT_DIR/state/config/homelab.conf)
#   3) System config:   /etc/fouchger_homelab_back_to_basic.conf (legacy/back-compat)
#   4) User config:     $XDG_CONFIG_HOME/fouchger/homelab-back_to_basic.conf (legacy/back-compat)
#   5) Explicit config: $HOMELAB_CONFIG_FILE (if set)
#   6) Environment vars always win (because they are already set)
#
# Notes:
#   - Writer updates a single KEY=VALUE line, preserving other content.
#   - By default, user changes are written into repo-local state
#     ($ROOT_DIR/state/config/homelab.conf), so the tool can run consistently
#     on LXC/VM hosts where user home directories vary.
# -----------------------------------------------------------------------------

# Guardrail: prevent double-sourcing.
if [[ -n "${_HOMELAB_CONFIG_SOURCED:-}" ]]; then
  return 0
fi
readonly _HOMELAB_CONFIG_SOURCED="1"

homelab_config__sys_path() {
  echo "/etc/fouchger_homelab_back_to_basic.conf"
}

homelab_config__user_path() {
  local base="${XDG_CONFIG_HOME:-$HOME/.config}"
  echo "${base%/}/fouchger/homelab-back_to_basic.conf"
}

homelab_config__defaults_path() {
  # ROOT_DIR should be available when sourcing from repo scripts.
  echo "${ROOT_DIR%/}/config/homelab.conf.defaults"
}

homelab_config__state_path() {
  # Preferred, repo-local state config. lib/paths.sh initialises
  # HOMELAB_STATE_CONFIG_FILE, but we also provide a safe fallback.
  if [[ -n "${HOMELAB_STATE_CONFIG_FILE:-}" ]]; then
    echo "$HOMELAB_STATE_CONFIG_FILE"
  else
    echo "${ROOT_DIR%/}/state/config/homelab.conf"
  fi
}

homelab_config_effective_write_path() {
  # If the user explicitly set a config path, respect it.
  if [[ -n "${HOMELAB_CONFIG_FILE:-}" ]]; then
    echo "$HOMELAB_CONFIG_FILE"
    return 0
  fi

  # Default: repo-local state config.
  echo "$(homelab_config__state_path)"
}

homelab_config_ensure_file() {
  local file="$1"
  local dir
  dir="$(dirname -- "$file")"
  mkdir -p "$dir"

  if [[ -f "$file" ]]; then
    return 0
  fi

  cat >"$file" <<'EOF'
# -----------------------------------------------------------------------------
# fouchger_homelab-back_to_basic configuration
#
# This file is sourced by bash. Keep it to simple KEY=VALUE pairs.
#
# Tips
#   - Values are case-insensitive unless noted.
#   - You can override any setting per-run by exporting the env var.
# -----------------------------------------------------------------------------

# --- UI / theme --------------------------------------------------------------
# One of: LATTE | FRAPPE | MACCHIATO | MOCHA
CATPPUCCIN_FLAVOUR="MOCHA"

# Force UI mode (leave empty for auto-detect)
# Options: "" | dialog | text | noninteractive
FORCE_UI_MODE=""

# --- Logging -----------------------------------------------------------------
# Options: DEBUG | INFO | WARN | ERROR
LOG_LEVEL="INFO"

# Optional: write a combined log file for suppressed command output.
# Leave empty to default to XDG_STATE_HOME (or /tmp).
HOMELAB_LOG_FILE=""

# --- Repo/root override ------------------------------------------------------
# If you run wrappers from outside the repo, set this to the repo path.
# Takes effect on next run.
HOMELAB_REPO_ROOT=""

# --- Dialog defaults ---------------------------------------------------------
# You can set per-widget defaults, e.g.
#   DIALOG_DEFAULT_MENU_H=20
#   DIALOG_DEFAULT_MENU_W=90
#   DIALOG_DEFAULT_MENU_LISTH=15
#
# See: commands/menu/lib/dialog_api.sh for supported widgets.
EOF
}

homelab_config__safe_source() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # shellcheck disable=SC1090
  source "$file"
}

homelab_config_load() {
  # Load defaults first.
  local defaults state sys user explicit
  defaults="$(homelab_config__defaults_path)"
  state="$(homelab_config__state_path)"
  sys="$(homelab_config__sys_path)"
  user="$(homelab_config__user_path)"
  explicit="${HOMELAB_CONFIG_FILE:-}"

  homelab_config__safe_source "$defaults"
  homelab_config__safe_source "$state"
  homelab_config__safe_source "$sys"
  homelab_config__safe_source "$user"
  if [[ -n "$explicit" ]]; then
    homelab_config__safe_source "$explicit"
  fi

  # Normalise a couple of commonly-used vars.
  if [[ -n "${CATPPUCCIN_FLAVOUR:-}" ]]; then
    CATPPUCCIN_FLAVOUR="${CATPPUCCIN_FLAVOUR^^}"
    [[ "$CATPPUCCIN_FLAVOUR" == "FRAPPÉ" ]] && CATPPUCCIN_FLAVOUR="FRAPPE"
  fi

  if [[ -n "${LOG_LEVEL:-}" ]]; then
    LOG_LEVEL="${LOG_LEVEL^^}"
  fi
}

homelab_config_set_kv() {
  # Usage: homelab_config_set_kv KEY VALUE [file]
  local key="$1"
  local value="$2"
  local file="${3:-$(homelab_config_effective_write_path)}"

  homelab_config_ensure_file "$file"

  local tmp
  tmp="${file}.tmp.$$"

  # Ensure we write a bash-safe value.
  # Using %q yields a shell-escaped representation.
  local q
  q="$(printf '%q' "$value")"

  awk -v k="$key" -v v="$q" '
    BEGIN{found=0}
    $0 ~ "^[[:space:]]*"k"[[:space:]]*=" {
      print k "=" v
      found=1
      next
    }
    {print}
    END{ if(!found) print k "=" v }
  ' "$file" >"$tmp" && mv "$tmp" "$file"
}

homelab_config_effective_source_summary() {
  # Human-readable summary of where config came from.
  local defaults state sys user explicit
  defaults="$(homelab_config__defaults_path)"
  state="$(homelab_config__state_path)"
  sys="$(homelab_config__sys_path)"
  user="$(homelab_config__user_path)"
  explicit="${HOMELAB_CONFIG_FILE:-}"

  echo "Defaults:  ${defaults}"
  echo "State:     ${state} $( [[ -f "$state" ]] && echo '(loaded)' || echo '(missing)' )"
  echo "System:    ${sys} $( [[ -f "$sys" ]] && echo '(loaded)' || echo '(missing)' )"
  echo "User:      ${user} $( [[ -f "$user" ]] && echo '(loaded)' || echo '(missing)' )"
  if [[ -n "$explicit" ]]; then
    echo "Explicit:  ${explicit} $( [[ -f "$explicit" ]] && echo '(loaded)' || echo '(missing)' )"
  fi
  echo "Write to:  $(homelab_config_effective_write_path)"
}
