# Platform and version policy

Last updated: 2026-01-30

## Purpose
Define supported platforms and version expectations so developers implement predictable installers and avoid “works on my machine”.

## Supported operating systems (initial)
Target initial support:
- Ubuntu 22.04+
- Debian 12+

Secondary support (best-effort):
- Other Debian-based distributions

Not supported initially:
- RHEL family
- Arch family
- macOS

## Package manager assumptions
- `apt` must be available on supported OS.

Installer modules may detect OS and refuse with remediation if unsupported.

## Tooling version policy
### Terraform
- Minimum supported version: 1.5+
- Recommended: latest stable available via distro or vendor repo
- Version checks (optional now, recommended later): enforce in `terraform_ready`

### Ansible
- Minimum supported ansible-core: 2.14+
- Recommended: ansible 8+ packaging if available
- Where python is required:
  - require python3 on control node (local host)

### yq
- Require Mike Farah yq v4+ (behaviour differs from python yq)
- Validate `yq --version` output contains `version 4`

### jq
- Any modern jq release is acceptable; validate command exists

## Version declaration (recommended)
If you want reproducible builds later, add:
- `config/versions.yml` containing minimum versions and preferred install method.

This spec defines the behaviour; the specific version declarations can evolve without changing the contract.

## Compatibility risk notes
- Terraform providers can introduce breaking changes; pin provider versions in `proxmox/terraform/versions.tf`.
- Ansible collections and roles can drift; prefer `requirements.yml` if you start using collections.
