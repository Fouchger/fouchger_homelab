#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/markers.sh
# Purpose : Marker tracking (conservative removals).
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

ensure_state_dirs() { as_root mkdir -p "${STATE_DIR}" "${MARKER_DIR}"; }
marker_path() { printf '%s/%s.installed_by_app_manager' "${MARKER_DIR}" "$1"; }
is_marked_installed() { [[ -f "$(marker_path "$1")" ]]; }
unmark_installed() { as_root rm -f -- "$(marker_path "$1")" >/dev/null 2>&1 || true; }

mark_installed() {
  local key="$1" strategy="${2:-}" packages_csv="${3:-}"
  ensure_state_dirs
  as_root bash -c "cat > \"$(marker_path \"${key}\")\" << EOF
installed_at=$(date -Is)
strategy=${strategy}
packages_csv=${packages_csv}
EOF"
}

marker_get_field() {
  local key="$1" field="$2"
  [[ -f "$(marker_path "$1")" ]] || return 1
  awk -F= -v f="${field}" '$1==f {sub(/^[^=]+=/,""); print; exit}' "$(marker_path "$1")"
}

marker_get_packages_compat_csv() {
  local key="$1" v
  v="$(marker_get_field "${key}" "packages_csv" 2>/dev/null || true)"
  if [[ -n "${v}" ]]; then
    printf '%s\n' "${v}"
    return 0
  fi
  v="$(marker_get_field "${key}" "packages" 2>/dev/null || true)"
  printf '%s\n' "${v}" | tr ' ' ',' | tr -s ','
}
