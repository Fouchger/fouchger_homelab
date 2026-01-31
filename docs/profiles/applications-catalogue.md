# Applications catalogue

Last updated: 2026-02-01 (Pacific/Auckland)

This catalogue defines the **application IDs** used by profile selection and manual install/uninstall. The source of truth is `config/apps.yml`.

## Implemented application IDs (current code)

Core
- `curl`, `wget`, `ca_certificates`, `gnupg`, `lsb_release`
- `jq`, `yq`, `git`
- `openssh_client`, `openssh_server`
- `python3`, `python3_venv`, `pipx`

Infrastructure
- `terraform`, `ansible`, `ansible_lint`

Secrets and security tooling
- `sops`, `age`
- `ufw`, `fail2ban`, `unattended_upgrades`, `chrony`, `apparmor_utils`

Operational toolkit
- `htop`, `iotop`, `sysstat`
- `dnsutils`, `iproute2`, `logrotate`, `tmux`

Optional admin capabilities
- `cloud_init`, `qemu_guest_agent`

Containers and networking
- `docker`, `tailscale`

Kubernetes and Talos admin tooling (client-side)
- `kubectl`, `helm`, `talosctl`

## Profile mapping (current code)

Profiles are defined in `config/profiles.yml` and reference the application IDs above.

Admin node profiles (recommended)
- `admin_control_plane`
- `admin_security_baseline`
- `admin_operational_toolkit`
- `infrastructure_management_layer` (optional)
- `kubernetes_talos_admin_tooling` (optional)

Legacy and convenience profiles (kept for backwards compatibility)
- `core`, `infra_core`, `basic`, `development`, `network_admin`, `proxmox_admin`

## Notes and boundaries

- Install/uninstall actions in Sprint 3 apply to the **local host** (the admin node in the intended operating model).
- Workload server role profiles are defined in documentation and will be provisioned using Terraform and Ansible in later sprints.
