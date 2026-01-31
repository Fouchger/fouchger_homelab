#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/kubectl.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for kubectl.
# Purpose: Installs kubectl (Kubernetes CLI) by downloading the official binary.
# Usage:
#   ./modules/apps/install/kubectl.sh
# Prerequisites:
#   - curl, ca-certificates, sha256sum
# Notes:
# - Installs to /usr/local/bin/kubectl.
# - Prefers a stable release from dl.k8s.io.
# ==============================================================================
# Install kubectl
#
# Contract:
#   - Must be idempotent: if already installed, exit 0.
#   - Must not prompt interactively.
#   - Must never print secrets.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v kubectl >/dev/null 2>&1; then
  echo "[INFO] kubectl already installed"
  exit 0
fi

# Ensure core prerequisites exist.
pkg_update
pkg_install curl ca-certificates

sudo_cmd="$(pkg__sudo)"

arch="$(uname -m)"
case "${arch}" in
  x86_64) karch="amd64" ;;
  aarch64|arm64) karch="arm64" ;;
  *)
    echo "[ERROR] Unsupported architecture for kubectl: ${arch}" >&2
    exit 1
    ;;
esac

ver="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
if [[ -z "${ver}" ]]; then
  echo "[ERROR] Unable to determine latest stable kubectl version" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

bin_url="https://dl.k8s.io/release/${ver}/bin/linux/${karch}/kubectl"
sha_url="https://dl.k8s.io/${ver}/bin/linux/${karch}/kubectl.sha256"

curl -fsSL -o "${tmpdir}/kubectl" "${bin_url}"
expected_sha="$(curl -fsSL "${sha_url}" | tr -d ' \n\r')"
actual_sha="$(sha256sum "${tmpdir}/kubectl" | awk '{print $1}')"

if [[ -z "${expected_sha}" ]] || [[ "${expected_sha}" != "${actual_sha}" ]]; then
  echo "[ERROR] kubectl checksum verification failed" >&2
  echo "[INFO] Expected: ${expected_sha}" >&2
  echo "[INFO] Actual:   ${actual_sha}" >&2
  exit 1
fi

${sudo_cmd} install -m 0755 "${tmpdir}/kubectl" /usr/local/bin/kubectl

echo "[INFO] kubectl installed (${ver})"
