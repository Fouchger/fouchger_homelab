#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/dev-auth.sh
# Created: 2026-01-21
# Description: Configure global Git identity and authenticate GitHub CLI (gh).
# Usage:
#   scripts/core/dev-auth.sh [git|gh|all|help]
#
# Notes:
#   - Safe-by-default: only sets git user.name/user.email if currently unset.
#   - Supports interactive and non-interactive usage.
#   - In non-interactive mode, provide inputs via environment variables.
#   - Token is passed via stdin; GitHub CLI will store auth for future use.
#
# Environment:
#   NONINTERACTIVE   1 disables prompts and requires env vars (default: 0)
#   GIT_USER_NAME    Git global user.name
#   GIT_USER_EMAIL   Git global user.email
#   GITHUB_TOKEN     GitHub token for gh auth login (PAT or fine-grained token)
#   GH_HOST          GitHub hostname (default: github.com; supports GHES)
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# source modules
# shellcheck source=lib/modules.sh
source "${REPO_ROOT}/lib/modules.sh"
homelab_load_lib
homelab_load_modules

run_init "dev-auth"

: "${NONINTERACTIVE:=0}"
: "${GIT_USER_NAME:=}"
: "${GIT_USER_EMAIL:=}"
: "${GITHUB_TOKEN:=}"
: "${GH_HOST:=github.com}"

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

usage() {
  cat <<EOF
Developer authentication helper

Usage:
  ${SCRIPT_NAME} [git|gh|all|help]

Subcommands:
  git   Configure global Git identity (user.name, user.email) if not already set
  gh    Authenticate GitHub CLI (gh) via token or interactive login
  all   Run both steps (default)

Environment (optional):
  NONINTERACTIVE   If 1, never prompt; require env vars (default: 0)
  GIT_USER_NAME    Preseed for Git user.name
  GIT_USER_EMAIL   Preseed for Git user.email
  GITHUB_TOKEN     Preseed for gh auth (only used when not already authenticated)
  GH_HOST          GitHub hostname (default: github.com)

Examples:
  ${SCRIPT_NAME} all
  NONINTERACTIVE=1 GIT_USER_NAME="Jane" GIT_USER_EMAIL="jane@ex.com" ${SCRIPT_NAME} git
  GITHUB_TOKEN="..." ${SCRIPT_NAME} gh
EOF
}

is_tty() { [[ -t 0 && -t 1 ]]; }

ensure_tool() {
  local bin="$1" pkg="${2:-$1}"
  if have_cmd "$bin"; then
    return 0
  fi

  if is_debian_like; then
    warn "'${bin}' not found. Installing '${pkg}' via apt."
    apt_install "$pkg"
    return 0
  fi

  warn "'${bin}' not found and this host is not Debian-like. Install '${pkg}' manually."
  return 1
}

already_has_git_identity() {
  git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1
}

configure_git_identity() {
  ensure_tool git git || return 1

  if already_has_git_identity; then
    local name email
    name="$(git config --global user.name || true)"
    email="$(git config --global user.email || true)"
    info "Git identity already configured: ${name:-<unset>} <${email:-unset}>"
    return 0
  fi

  local name="${GIT_USER_NAME}" email="${GIT_USER_EMAIL}"

  if [[ "${NONINTERACTIVE}" -eq 1 || ! -t 0 ]]; then
    if [[ -z "${name}" || -z "${email}" ]]; then
      error "NONINTERACTIVE=1 but GIT_USER_NAME/GIT_USER_EMAIL not provided."
      return 1
    fi
  else
    if [[ -z "${name}" ]]; then
      read -r -p "Enter Git user.name: " name
    fi
    if [[ -z "${email}" ]]; then
      read -r -p "Enter Git user.email: " email
    fi
  fi

  if [[ -z "${name}" || -z "${email}" ]]; then
    error "Git identity not set (name or email empty)."
    return 1
  fi

  info "Configuring global Git identity"
  git config --global user.name "${name}"
  git config --global user.email "${email}"
  ok "Git identity set to: ${name} <${email}>"
}

is_gh_authenticated() {
  have_cmd gh && gh auth status -h "${GH_HOST}" >/dev/null 2>&1
}

authenticate_gh() {
  ensure_tool gh gh || {
    error "GitHub CLI (gh) not installed or not on PATH."
    return 1
  }

  if is_gh_authenticated; then
    # Attempt to extract account from status output (best-effort).
    local acct
    acct="$(
      gh auth status -h "${GH_HOST}" 2>/dev/null \
        | awk -F 'account ' '/Logged in to/ {print $2}' \
        | awk '{print $1}'
    )"
    if [[ -n "${acct:-}" ]]; then
      info "Already logged in to ${GH_HOST} (account: ${acct})."
    else
      info "Already logged in to ${GH_HOST}."
    fi
    return 0
  fi

  info "GitHub CLI is not authenticated for ${GH_HOST}."

  # Prefer token-based auth first.
  local token="${GITHUB_TOKEN}"
  if [[ -z "${token}" && -z "${CI:-}" && is_tty ]]; then
    read -rsp "Paste your GitHub token (input hidden) or press Enter to skip: " token || true
    echo
  fi

  if [[ -n "${token}" ]]; then
    if (( ${#token} < 20 )); then
      warn "Token looks unusually short; double-check if login fails."
    fi

    if printf '%s' "${token}" | gh auth login \
      --hostname "${GH_HOST}" \
      --git-protocol https \
      --with-token >/dev/null; then
      token="" # clear
      gh auth setup-git --hostname "${GH_HOST}" >/dev/null 2>&1 || true
      if is_gh_authenticated; then
        ok "GitHub CLI authentication successful (token)."
        return 0
      fi
    else
      warn "Token-based login failed."
    fi
  else
    info "No token provided; will try manual login if possible."
  fi

  # Fallback: interactive wizard if possible.
  if is_tty && [[ -z "${CI:-}" ]]; then
    info "Starting interactive 'gh auth login' wizard"
    if gh auth login --hostname "${GH_HOST}" --git-protocol https; then
      gh auth setup-git --hostname "${GH_HOST}" >/dev/null 2>&1 || true
      if is_gh_authenticated; then
        ok "GitHub CLI authentication successful (manual)."
        return 0
      fi
    fi
    error "Interactive login did not complete successfully."
    return 1
  fi

  error "Cannot start manual login in a non-interactive environment."
  info "Provide a token in GITHUB_TOKEN or run locally with a TTY."
  return 1
}

main() {
  local cmd="${1:-all}"
  case "${cmd}" in
    git) configure_git_identity ;;
    gh) authenticate_gh ;;
    all) configure_git_identity; authenticate_gh ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      error "Unknown subcommand: ${cmd}"
      echo
      usage
      exit 2
      ;;
  esac
}

main "$@"
