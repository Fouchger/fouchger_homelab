# Version pinning and dependency policy

Last updated: 2026-01-30

## Terraform binary
Policy decision:
- Enforce **minimum version only** initially (>= 1.5)
- Do not hard-pin Terraform binary version yet

Rationale:
- Homelab environments vary
- Terraform core is relatively stable compared to providers

## Terraform providers
Policy decision:
- Providers **must be pinned** in `proxmox/terraform/versions.tf`

Example:
```hcl
required_providers {
  proxmox {
    source  = "telmate/proxmox"
    version = "~> 2.9"
  }
}
```

Rationale:
- Provider APIs change frequently
- Pinned providers protect replay and rebuilds

## Ansible
- Do not pin ansible-core version in code
- Enforce minimum version via validation gate

## Future evolution
If reproducibility becomes critical:
- introduce `config/versions.yml`
- enforce binary versions explicitly in validation
