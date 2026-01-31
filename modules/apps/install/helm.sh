#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/helm.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for Helm.
# Purpose: Installs Helm by downloading the official release binary.
# Usage:
#   ./modules/apps/install/helm.sh
# Prerequisites:
#   - curl, ca-certificates, tar, sha256sum
# Notes:
# - Installs to /usr/local/bin/helm.
# ==============================================================================
# Install Helm
#
# Contract:
#   - Must be idempotent: if already installed, exit 0.
#   - Must not prompt interactively.
#   - Must never print secrets.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v helm >/dev/null 2>&1; then
  echo "[INFO] helm already installed"
  exit 0
fi

pkg_update
pkg_install curl ca-certificates tar

sudo_cmd="$(pkg__sudo)"

arch="$(uname -m)"
case "${arch}" in
  x86_64) harch="amd64" ;;
  aarch64|arm64) harch="arm64" ;;
  *)
    echo "[ERROR] Unsupported architecture for helm: ${arch}" >&2
    exit 1
    ;;
esac

# Fetch latest release tag from GitHub API (no jq dependency).
tag="$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
if [[ -z "${tag}" ]]; then
  echo "[ERROR] Unable to determine latest helm version" >&2
  exit 1
fi

ver="${tag#v}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

base="helm-v${ver}-linux-${harch}"
tgz_url="https://get.helm.sh/${base}.tar.gz"
sha_url="https://get.helm.sh/${base}.tar.gz.sha256sum"

curl -fsSL -o "${tmpdir}/helm.tgz" "${tgz_url}"
expected_sha="$(curl -fsSL "${sha_url}" | awk '{print $1}' | tr -d ' \n\r')"
actual_sha="$(sha256sum "${tmpdir}/helm.tgz" | awk '{print $1}')"

if [[ -z "${expected_sha}" ]] || [[ "${expected_sha}" != "${actual_sha}" ]]; then
  echo "[ERROR] Helm checksum verification failed" >&2
  echo "[INFO] Expected: ${expected_sha}" >&2
  echo "[INFO] Actual:   ${actual_sha}" >&2
  exit 1
fi

tar -xzf "${tmpdir}/helm.tgz" -C "${tmpdir}"
${sudo_cmd} install -m 0755 "${tmpdir}/linux-${harch}/helm" /usr/local/bin/helm

echo "[INFO] helm installed (v${ver})"
