#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/profile.sh
# Created: 29/01/2026
# Updated: 29/01/2026
# Description: App Manager profiles (named bundles of apps from app_catalogue.sh).
#
# Notes
#   - Profiles provide a fast way to set selections. Users can still adjust via checklist.
#   - Profile keys should be stable because they can be stored in state.
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

declare -gA PROFILES=(
  ["baseline"]="Bare minimum workstation essentials (Dev + NetAdmin + Proxmox Admin)"
  ["dev"]="Developer-focused tooling (adds build tools and runtimes)"
  ["netadmin"]="Network admin tooling (adds deeper diagnostics)"
  ["proxmox"]="Proxmox and storage admin tooling (adds guestfs and storage tooling)"
  ["platform"]="Platform engineering tooling (Docker, IaC, Kubernetes CLIs)"
)

declare -gA PROFILE_APPS=(
  ["baseline"]="sudo ca_certs gnupg curl wget zip unzip rsync openssh_client bash_completion less tmux htop chrony logrotate iproute2 dnsutils git jq"
  ["dev"]="build_essential make cmake git_lfs python openjdk golang gh nodejs"
  ["netadmin"]="traceroute mtr nettools tcpdump nmap ethtool iperf3 socat whois arp_scan"
  ["proxmox"]="pve_client libguestfs virt_what lvm2 thin_prov nfs_common cifs_utils smartmontools parted xfsprogs zfsutils"
  ["platform"]="docker_engine podman_cli ansible terraform packer vault helm kubectl yq sops"
)

profile_list_keys() { for k in "${!PROFILES[@]}"; do printf '%s\n' "$k"; done | sort; }
profile_get_description() { local key="$1"; printf '%s' "${PROFILES[$key]:-}"; }
profile_get_apps() { local key="$1"; printf '%s' "${PROFILE_APPS[$key]:-}"; }
