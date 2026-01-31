#!/usr/bin/env bash
# ==============================================================================
# File: modules/apps/install/talosctl.sh
# Created: 2026-02-01
# Updated: 2026-02-01
# Description: Apps install module for talosctl.
# Purpose: Installs talosctl by downloading the official release binary.
# Usage:
#   ./modules/apps/install/talosctl.sh
# Prerequisites:
#   - curl, ca-certificates, sha256sum
# Notes:
# - Installs to /usr/local/bin/talosctl.
# ==============================================================================
# Install talosctl
#
# Contract:
#   - Must be idempotent: if already installed, exit 0.
#   - Must not prompt interactively.
#   - Must never print secrets.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/pkg.sh"

if command -v talosctl >/dev/null 2>&1; then
  echo "[INFO] talosctl already installed"
  exit 0
fi

pkg_update
pkg_install curl ca-certificates

sudo_cmd="$(pkg__sudo)"

arch="$(uname -m)"
case "${arch}" in
  x86_64) tarch="amd64" ;;
  aarch64|arm64) tarch="arm64" ;;
  *)
    echo "[ERROR] Unsupported architecture for talosctl: ${arch}" >&2
    exit 1
    ;;
esac

# Fetch latest release tag from GitHub API (no jq dependency).
tag="$(curl -fsSL https://api.github.com/repos/siderolabs/talos/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
if [[ -z "${tag}" ]]; then
  echo "[ERROR] Unable to determine latest talosctl version" >&2
  exit 1
fi

ver="${tag#v}"

bin_name="talosctl-linux-${tarch}"

# Talos releases provide checksums in sha256sum files.
base_url="https://github.com/siderolabs/talos/releases/download/${tag}"

bin_url="${base_url}/${bin_name}"
sha_url="${base_url}/sha256sum.txt"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fsSL -o "${tmpdir}/${bin_name}" "${bin_url}"
expected_sha="$(curl -fsSL "${sha_url}" | grep "${bin_name}" | awk '{print $1}' | head -n1 | tr -d ' \n\r')"
actual_sha="$(sha256sum "${tmpdir}/${bin_name}" | awk '{print $1}')"

if [[ -z "${expected_sha}" ]] || [[ "${expected_sha}" != "${actual_sha}" ]]; then
  echo "[ERROR] talosctl checksum verification failed" >&2
  echo "[INFO] Expected: ${expected_sha}" >&2
  echo "[INFO] Actual:   ${actual_sha}" >&2
  exit 1
fi

${sudo_cmd} install -m 0755 "${tmpdir}/${bin_name}" /usr/local/bin/talosctl

echo "[INFO] talosctl installed (v${ver})"
