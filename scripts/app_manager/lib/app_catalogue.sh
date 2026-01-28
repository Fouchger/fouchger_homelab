#!/usr/bin/env bash
# =============================================================================
# Filename: scripts/app_manager/lib/app_catalogue.sh
# Created: 28/01/2026
# Updated: 28/01/2026
# Description: Application catalogue for workstation (Dev + NetAdmin + Proxmox Admin)
#
# Notes
#   - Catalogue feeds the questionnaire for install/uninstall selection.
#   - Strategy indicates the installer workflow required:
#       apt               : install via apt-get install <packages> -y
#       github_cli_repo    : add GitHub CLI apt repo, then apt install gh
#       hashicorp_repo     : add HashiCorp apt repo, then apt install <tool> (Terraform/Packer/Vault)
#       docker_apt_repo    : add Docker apt repo, then apt install docker engine + plugins
#       grafana_repo       : add Grafana apt repo, then apt install alloy
#       mongodb_repo       : add MongoDB apt repo, then apt install mongodb-org
#       binary             : download official binary release and install to /usr/local/bin (version var supported)
#       yq_binary          : download mikefarah/yq binary release (version var supported)
#       sops_binary        : download getsops/sops binary release (version var supported)
#       python             : manage Python toolchain and pipx tools (target var supported)
#       nvm                : install Node.js via NVM (per-user)
# =============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi

# =============================================================================
# Application catalogue
# Format (TYPE|...):
#   HEADING|<text>
#   BLANK|<text>
#   APP|<key>|<label>|<default:ON/OFF>|<packages_csv>|<description>|<strategy>|<version_var>
# Notes
#   - packages are CSV (comma-separated), not space-separated
# =============================================================================
APP_CATALOGUE=(

  "HEADING|1. Absolute Baseline (Core workstation essentials)"
  "APP|sudo|[Core] sudo + coreutils|ON|sudo,coreutils|Privilege escalation and base utilities|apt|"
  "APP|ca_certs|[Core] ca-certificates|ON|ca-certificates|TLS trust store for HTTPS|apt|"
  "APP|gnupg|[Core] gnupg|ON|gnupg|GPG for repo keys, signing and verification|apt|"
  "APP|curl|[Core] curl|ON|curl|HTTP client|apt|"
  "APP|wget|[Core] wget|ON|wget|Downloader|apt|"
  "APP|zip|[Core] zip|ON|zip|Zip archive support|apt|"
  "APP|unzip|[Core] unzip|ON|unzip|Unzip archive support|apt|"
  "APP|rsync|[Core] rsync|ON|rsync|File synchronisation|apt|"
  "APP|openssh_client|[Core] OpenSSH client|ON|openssh-client|Outbound SSH access|apt|"
  "APP|openssh_server|[Core] OpenSSH server|OFF|openssh-server|Inbound SSH access to this workstation|apt|"
  "APP|bash_completion|[Core] bash-completion|ON|bash-completion|Shell completion|apt|"
  "APP|less|[Core] less|ON|less|Pager for logs and output|apt|"
  "APP|tree|[Core] tree|OFF|tree|Directory tree viewer|apt|"
  "APP|tmux|[Core] tmux|ON|tmux|Terminal multiplexer|apt|"
  "APP|htop|[Core] htop|ON|htop|Process viewer|apt|"
  "APP|btop|[Core] btop (alternative)|OFF|btop|Modern process viewer|apt|"
  "APP|fzf|[Core] fzf|OFF|fzf|Fuzzy finder|apt|"
  "APP|chrony|[Core] chrony|ON|chrony|Time synchronisation|apt|"
  "APP|logrotate|[Core] logrotate|ON|logrotate|Log rotation|apt|"

  "BLANK| "
  "HEADING|2. Proxmox and Virtualisation Admin Essentials"
  "APP|pve_client|[Proxmox] pve-client|OFF|pve-client|Proxmox API client tooling|apt|"
  "APP|libguestfs|[Proxmox] libguestfs-tools|OFF|libguestfs-tools|Inspect and repair VM disk images|apt|"
  "APP|virt_what|[Proxmox] virt-what|OFF|virt-what|Detect virtualisation environment|apt|"

  "BLANK| "
  "HEADING|3. Storage and Filesystem Operations"
  "APP|lvm2|[Storage] lvm2|OFF|lvm2|LVM management|apt|"
  "APP|thin_prov|[Storage] thin-provisioning-tools|OFF|thin-provisioning-tools|Thin pool tooling for LVM|apt|"
  "APP|nfs_common|[Storage] nfs-common|OFF|nfs-common|NFS client utilities|apt|"
  "APP|cifs_utils|[Storage] cifs-utils|OFF|cifs-utils|SMB/CIFS client utilities|apt|"
  "APP|smartmontools|[Storage] smartmontools|OFF|smartmontools|Disk health tooling (where applicable)|apt|"
  "APP|parted|[Storage] parted|OFF|parted|Partitioning tool|apt|"
  "APP|xfsprogs|[Storage] xfsprogs|OFF|xfsprogs|XFS filesystem tools|apt|"
  "APP|zfsutils|[Storage] zfsutils-linux|OFF|zfsutils-linux|ZFS tooling (context-dependent)|apt|"

  "BLANK| "
  "HEADING|4. Networking and Diagnostics"
  "APP|iproute2|[Net] iproute2|ON|iproute2|Modern networking tools|apt|"
  "APP|dnsutils|[Net] dnsutils|ON|dnsutils|dig, nslookup for DNS troubleshooting|apt|"
  "APP|traceroute|[Net] traceroute|OFF|traceroute|Route path troubleshooting|apt|"
  "APP|mtr|[Net] mtr|OFF|mtr|Traceroute + ping combined|apt|"
  "APP|nettools|[Net] net-tools (legacy)|OFF|net-tools|Legacy networking tools|apt|"
  "APP|tcpdump|[Net] tcpdump|OFF|tcpdump|Packet capture|apt|"
  "APP|nmap|[Net] nmap|OFF|nmap|Port scanning and service discovery|apt|"
  "APP|ethtool|[Net] ethtool|OFF|ethtool|NIC diagnostics and offload checks|apt|"
  "APP|iperf3|[Net] iperf3|OFF|iperf3|Network throughput testing|apt|"
  "APP|socat|[Net] socat|OFF|socat|Socket relay and quick TCP/UDP tests|apt|"
  "APP|whois|[Net] whois|OFF|whois|Domain and IP registration lookup|apt|"
  "APP|arp_scan|[Net] arp-scan|OFF|arp-scan|Layer-2 discovery on LANs|apt|"

  "BLANK| "
  "HEADING|5. Developer Baseline (Language-agnostic)"
  "APP|build_essential|[Dev] build-essential|OFF|build-essential|Compiler toolchain|apt|"
  "APP|make|[Dev] make|OFF|make|Build automation|apt|"
  "APP|cmake|[Dev] cmake|OFF|cmake|Modern build system|apt|"
  "APP|git|[Dev] git|ON|git|Source control|apt|"
  "APP|git_lfs|[Dev] git-lfs|OFF|git-lfs|Large File Storage for Git|apt|"
  "APP|gh|[Dev] gh (GitHub CLI)|OFF|gh|GitHub CLI via official apt repo|github_cli_repo|"
  "APP|python|[Dev] Python tooling (versioned)|OFF|python3,python3-venv,python3-pip,pipx|Python runtime and tooling|python|PYTHON_TARGET"
  "APP|openjdk|[Dev] OpenJDK 17|OFF|openjdk-17-jdk|Java runtime|apt|"
  "APP|golang|[Dev] Go|OFF|golang-go|Go language toolchain|apt|"

  # Node.js via NVM (per-user) is intentionally not apt-based.
  "APP|nodejs|[Dev] Node.js (NVM)|OFF||Node.js runtime installed via NVM (per-user)|nvm|"

  "BLANK| "
  "HEADING|6. Containers and Platform Engineering (CLI)"
  "APP|docker_engine|[Containers] Docker Engine (apt repo)|OFF|docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin|Docker Engine + Buildx + Compose v2 via Docker apt repo|docker_apt_repo|"
  "APP|podman_cli|[Containers] Podman|OFF|podman|Rootless container tooling|apt|"

  "BLANK| "
  "HEADING|7. Infrastructure as Code and Automation"
  "APP|ansible|[IaC] Ansible|OFF|ansible|Configuration management|apt|"
  "APP|terraform|[IaC] Terraform|OFF|terraform|Infrastructure as code via HashiCorp apt repo|hashicorp_repo|TERRAFORM_VERSION"
  "APP|packer|[IaC] Packer|OFF|packer|Image automation via HashiCorp apt repo|hashicorp_repo|PACKER_VERSION"
  "APP|vault|[IaC] Vault CLI|OFF|vault|Secrets tooling via HashiCorp apt repo|hashicorp_repo|VAULT_VERSION"
  "APP|helm|[IaC] Helm (official binary)|OFF||Kubernetes package manager (official binary release)|binary|HELM_VERSION"
  "APP|kubectl|[IaC] kubectl (official binary)|OFF||Kubernetes CLI (official binary release)|binary|KUBECTL_VERSION"
  "APP|jq|[IaC] jq|ON|jq|JSON processor|apt|"
  "APP|yq|[IaC] yq (mikefarah, binary)|OFF||YAML processor (GitHub release binary)|yq_binary|YQ_VERSION"

  "BLANK| "
  "HEADING|8. Observability and Debugging"
  "APP|lsof|[Obs] lsof|OFF|lsof|List open files and sockets|apt|"
  "APP|strace|[Obs] strace|OFF|strace|Syscall tracing|apt|"
  "APP|sysstat|[Obs] sysstat|OFF|sysstat|Performance tooling (sar, iostat)|apt|"
  "APP|grafana_alloy|[Obs] Grafana Alloy|OFF|alloy|OpenTelemetry collector distro via Grafana apt repo|grafana_repo|"

  "BLANK| "
  "HEADING|9. Security and Access Tooling"
  "APP|pass|[Sec] pass|OFF|pass|Password store|apt|"
  "APP|age|[Sec] age|OFF|age|Modern encryption|apt|"
  "APP|sops|[Sec] sops (binary)|OFF||Secrets operations (GitHub release binary)|sops_binary|SOPS_VERSION"
  "APP|ufw|[Sec] ufw|OFF|ufw|Host firewall tooling|apt|"
  "APP|fail2ban|[Sec] fail2ban|OFF|fail2ban|Brute-force mitigation (jump boxes)|apt|"

  "BLANK| "
  "HEADING|10. Optional Data Services (for local dev or labs)"
  "APP|postgres|[Data] PostgreSQL|OFF|postgresql|Relational database|apt|"
  "APP|mysql|[Data] MySQL|OFF|mysql-server|Relational database|apt|"
  "APP|mariadb|[Data] MariaDB|OFF|mariadb-server|MySQL-compatible database|apt|"
  "APP|redis|[Data] Redis|OFF|redis-server|In-memory datastore|apt|"
  "APP|mongodb|[Data] MongoDB Community (mongodb-org)|OFF|mongodb-org|MongoDB via official MongoDB apt repo|mongodb_repo|MONGODB_SERIES"
)
