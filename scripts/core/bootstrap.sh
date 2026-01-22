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

# shellcheck source=lib/paths.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)/lib/paths.sh"
# shellcheck source=lib/logging.sh
source "${REPO_ROOT}/lib/logging.sh"
# shellcheck source=lib/core.sh
source "${REPO_ROOT}/lib/core.sh"
# shellcheck source=lib/run.sh
source "${REPO_ROOT}/lib/run.sh"

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