#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/pkg_mgr.sh
# Purpose : Package manager abstraction (prefers nala; falls back to apt-get).
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

PKG_MGR="apt-get"

detect_pkg_mgr() {
  if need_cmd_quiet nala; then
    PKG_MGR="nala"
  else
    PKG_MGR="apt-get"
  fi
}

ensure_pkg_mgr() {
  detect_pkg_mgr
  if [[ "${PKG_MGR}" == "nala" ]]; then
    return 0
  fi

  log_line "nala not found; bootstrapping via apt-get"
  as_root apt-get update
  as_root apt-get install -y --no-install-recommends nala || true

  detect_pkg_mgr
}

pkg_update_once() {
  if [[ "${PKG_MGR}" == "nala" ]]; then
    as_root nala update
  else
    as_root apt-get update
  fi
}

pkg_install_pkgs() {
  (("$#")) || return 0
  if [[ "${PKG_MGR}" == "nala" ]]; then
    as_root nala install -y --no-install-recommends "$@"
  else
    as_root apt-get install -y --no-install-recommends "$@"
  fi
}

pkg_remove_pkgs() {
  (("$#")) || return 0
  if [[ "${PKG_MGR}" == "nala" ]]; then
    as_root nala remove -y "$@" >/dev/null 2>&1 || true
  else
    as_root apt-get remove -y "$@" >/dev/null 2>&1 || true
  fi
}

pkg_autoremove() {
  if [[ "${PKG_MGR}" == "nala" ]]; then
    as_root nala autoremove -y
  else
    as_root apt-get autoremove -y
  fi
}
