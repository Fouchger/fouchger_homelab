# Install and uninstall model

Last updated: 2026-02-01 (Pacific/Auckland)

This document defines how profile-driven installation and removal works in the current implementation, and how it will extend to server role profiles.

## Current implementation (local applications)

Scope
- Installs and uninstalls **applications on the admin node** only.
- Profiles are defined in `config/profiles.yml`.
- Applications are defined in `config/apps.yml` and mapped to install and uninstall modules.

Behaviour
- Selecting a profile produces a list of app IDs to install (stored in `state/selections.env`).
- Manual selection can add or remove app IDs from the install or uninstall sets.
- Install and uninstall actions run module scripts under `modules/apps/install/` and `modules/apps/uninstall/`.
- Package operations prefer `nala` with an `apt-get` fallback (as implemented in `lib/pkg.sh`).

Safety expectations
- Uninstall is never run implicitly. It must be explicitly selected.
- Install modules must be non-interactive and idempotent.
- All outputs must be captured in the run log for auditability.

## Target extension (server role profiles)

Principle
- The admin node remains the single orchestration point for creating, installing, and configuring servers.
- Server role profiles describe **desired state on workload nodes**, applied via Terraform and Ansible, not via local `apt` installs on the admin node.

Implementation direction (future)
- Role profile selection produces a desired role for a workload node (or group of nodes).
- Terraform provisions nodes, and Ansible applies role playbooks to targets.
- Kubernetes uses Talos Linux and includes MetalLB plus an Ingress controller as standard add-ons.

Documentation reference
- [docs/profiles/role-catalogue.md](/fouchger_homelab/docs/profiles/role-catalogue.md)
- [docs/platform/kubernetes-talos.md](/fouchger_homelab/docs/platform/kubernetes-talos.md)
