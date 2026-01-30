# Functional overview

## Product goal
Provide a single interactive, menu-driven homelab automation experience that can:
1. Install or uninstall local applications by profile or manual selection.
2. Set up Proxmox access (user, role, token).
3. Download and cache LXC/VM templates (Ubuntu 22+ and latest Talos).
4. Provision LXC/VM workloads via Terraform.
5. Configure workloads via Ansible.
6. Support safe experimentation through dry run and operational resilience through replay.

## Minimal baseline you can rely on
To keep installs lightweight while still dependable, baseline tooling is tiered:

Tier 0: runtime baseline installed by `bootstrap.sh`
- git, dialog, bash

Tier 1: core baseline profile (safe across all environments)
- curl, jq, yq, openssh_client

Tier 2: infrastructure baseline (only for Proxmox + Terraform + Ansible workflows)
- terraform, ansible

## Key design principles
- Single look and feel via dialog wrappers.
- Declarative configuration for apps, profiles, UI, and validations.
- Idempotent modules and deterministic execution.
- Explicit state handoffs via `state/runs/latest.env`.
- Secrets are confined to `state/proxmox.env` and `state/secrets.env`.
