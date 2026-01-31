# Admin Node Profiles

Last updated: 2026-02-01 (Pacific/Auckland)


## Non-negotiable rule

The **admin node** performs all create, install, and configure actions for servers:
- Proxmox provisioning and lifecycle actions (Terraform and/or API)
- Configuration management (Ansible)
- Secrets handling and governance
- Standardised logging and artefact generation

Workload nodes are not used as a control plane for provisioning.

## Profile: Admin Control Plane Baseline (mandatory)

Purpose: Secure and repeatable management point for the homelab.

Recommended applications:
- openssh-server
- git
- ansible, ansible-lint
- terraform
- python3-venv, pipx
- sops with age (preferred) or Ansible Vault (choose one standard)
- curl, wget, ca-certificates, gnupg, lsb-release
- jq, yq, rsync, unzip, make

Notes:
- Keep this profile minimal and deterministic. Everything else must justify its presence.

## Profile: Admin Security Baseline (mandatory)

Purpose: Protects the most privileged node in the environment.

Recommended applications:
- ufw
- fail2ban
- unattended-upgrades
- chrony
- apparmor-utils

Optional (where it adds value):
- auditd (security event visibility)
- needrestart (helps ensure patched services restart safely)

## Profile: Admin Operational Toolkit (optional)

Purpose: Basic visibility and support tooling without bloat.

Recommended applications:
- htop, iotop, sysstat
- dnsutils, iproute2
- logrotate
- tmux
- ncdu, lsof, netcat-openbsd (optional but practical)

## Admin Capabilities (optional toggles)

These are installed only when needed:
- Proxmox tooling: (optional) proxmoxer / pvesh style tooling as agreed in codebase
- cloud-init tools: cloud-init
- qemu-guest-agent (only if admin node is itself a VM)

Client-only tooling that is acceptable on the admin node:
- kubectl, helm (clients only, no Kubernetes runtime)

## What must not be installed on the admin node

To keep the node clean and stable, avoid running these services locally:
- Docker or Podman runtimes (daemon or engine)
- Monitoring stacks (Prometheus, Grafana, Loki)
- Storage services (NFS, Samba, storage pools)
- Identity systems (Authentik, Keycloak)
- CI/CD runners
- Kubernetes components (control plane/worker runtimes)

Exception: client tools are allowed where they do not host services.

## How this maps to current local profiles

Admin-node application selection is implemented via `config/profiles.yml`.

Implemented admin profiles:
- Admin Control Plane Baseline: `admin_control_plane`
- Admin Security Baseline: `admin_security_baseline`
- Admin Operational Toolkit: `admin_operational_toolkit`
- Infrastructure Management Layer (optional): `infrastructure_management_layer`
- Kubernetes (Talos) Admin Tooling: `kubernetes_talos_admin_tooling`

Legacy convenience profiles are still available for backwards compatibility:
- `core`, `infra_core`, `network_admin`, `proxmox_admin`, `development`, `basic`

Recommendation:
Use the new admin profiles for clearer separation and to avoid accidental bloat on the admin node.

