#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Filename: scripts/core/bootstrap.sh
# Created: 2026-01-18
# Description: Minimal bootstrap for Debian/Ubuntu nodes.
# Usage:
#   make bootstrap
# Developer notes:
#   - Installs only what is required to clone the repo and run Ansible.
#   - Additional tooling (Terraform/Packer) is installed via menu options.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# Consistent module loading policy:
# - Scripts anchor REPO_ROOT off their own location.
# - Scripts source lib/modules.sh, then call homelab_load_lib.
REPO_ROOT="${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
export REPO_ROOT

# shellcheck source=lib/modules.sh
source "${REPO_ROOT}/lib/modules.sh"
homelab_load_lib

run_init "bootstrap"

if ! is_debian_like; then
  warn "This bootstrap currently supports Debian/Ubuntu only."
  warn "OS detected: $(get_os_id)"
  exit 0
fi

apt_install \
  git \
  make \
  dialog


ok "Bootstrap complete. Next: make menu"