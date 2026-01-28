#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/pkg_utils.sh
# Purpose : APT helpers, CSV helpers, and package selection utilities.
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Apt candidate checks (prevents one missing package from killing the run)
# -----------------------------------------------------------------------------
apt_pkg_has_candidate() {
  local pkg="$1"
  apt-cache policy "${pkg}" 2>/dev/null | awk -F': ' '
    $1=="Candidate" { cand=$2 }
    END {
      if (cand=="" || cand=="(none)") exit 1
      exit 0
    }
  '
}

filter_installable_apt_pkgs() {
  local in_name="$1" out_name="$2" missing_name="$3"
  local -a installable=() missing=()
  local p

  eval "for p in \"\${${in_name}[@]}\"; do
    if apt_pkg_has_candidate \"\$p\"; then
      installable+=(\"\$p\")
    else
      missing+=(\"\$p\")
    fi
  done"

  eval "${out_name}=(\"\${installable[@]}\")"
  eval "${missing_name}=(\"\${missing[@]}\")"
}

# -----------------------------------------------------------------------------
# CSV helpers
# -----------------------------------------------------------------------------
pkgs_csv_to_array() {
  local csv="$1" out_name="$2"
  eval "${out_name}=()"
  [[ -n "${csv}" ]] || return 0

  local -a tmp=()
  local IFS=','

  # shellcheck disable=SC2206
  tmp=(${csv})

  local -a cleaned=()
  local x
  for x in "${tmp[@]}"; do
    x="${x#"${x%%[![:space:]]*}"}"
    x="${x%"${x##*[![:space:]]}"}"
    [[ -n "${x}" ]] && cleaned+=("${x}")
  done

  eval "${out_name}=(\"\${cleaned[@]}\")"
}

unique_pkgs() {
  local in_name="$1" out_name="$2"
  local -a out=()

  mapfile -t out < <(
    eval "printf '%s\n' \"\${${in_name}[@]}\"" \
      | awk 'NF' \
      | sort -u
  )

  eval "${out_name}=(\"\${out[@]}\")"
}

# -----------------------------------------------------------------------------
# Install state checks
# -----------------------------------------------------------------------------
is_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

verify_pkgs_installed() {
  local pkgs_csv="$1"
  local -a pkgs_arr=()
  pkgs_csv_to_array "${pkgs_csv}" pkgs_arr
  local p
  for p in "${pkgs_arr[@]}"; do
    is_pkg_installed "${p}" || return 1
  done
  return 0
}
