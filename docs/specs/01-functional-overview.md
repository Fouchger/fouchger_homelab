# Functional overview

## Product goal
Provide a single interactive, menu-driven homelab automation experience that can install/uninstall apps, set up Proxmox access, download templates, provision via Terraform, configure via Ansible, and support dry run and replay.

## Key design principles
- Single look and feel via dialog wrappers.
- Declarative configuration for apps, profiles, UI, and validations.
- Idempotency and explicit state handoffs.
