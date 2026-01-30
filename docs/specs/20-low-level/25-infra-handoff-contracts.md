# Infrastructure handoff contracts

Last updated: 2026-01-30

## Purpose
Define the produced and consumed data between:
Proxmox access → Templates → Terraform → Ansible.

This is the low-level “API” between tools. Implementers must follow these keys and file paths to keep replay and diagnostics reliable.

## Handoff artefacts
| Artefact | Producer | Consumer | Path |
|---|---|---|---|
| Proxmox credentials | proxmox_access | templates, terraform, ansible dynamic inventory | state/proxmox.env |
| Template manifest | templates | terraform | state/cache/templates/manifest.json |
| Terraform state/workdir | terraform_apply | diagnostics, replay | state/cache/terraform/ |
| Terraform outputs JSON | terraform_apply | ansible | state/cache/terraform/outputs.json |
| Latest run context | all commands | replay/resume, diagnostics | state/runs/latest.env |

## state/proxmox.env required keys
- PROXMOX_API_URL
- PROXMOX_NODE
- PROXMOX_TOKEN_ID
- PROXMOX_TOKEN_SECRET (secret, never copied to latest.env)
Optional:
- PROXMOX_TLS_VERIFY (true|false)

## Template manifest contract
File: `state/cache/templates/manifest.json`

Minimum schema:
```json
{
  "generated_at": "2026-01-30T22:00:00+13:00",
  "ubuntu": {
    "type": "lxc|vm",
    "source": "url-or-repo",
    "filename": "ubuntu-22.04-template.img",
    "path": "state/cache/templates/ubuntu-22.04-template.img",
    "proxmox_template_id": "optional"
  },
  "talos": {
    "type": "iso|img|qcow2",
    "source": "url-or-repo",
    "filename": "talos-latest.iso",
    "path": "state/cache/templates/talos-latest.iso",
    "proxmox_template_id": "optional"
  }
}
```

Terraform must treat the manifest as source of truth for which template artefacts exist.

## Terraform outputs contract
File: `state/cache/terraform/outputs.json`

Minimum keys required for Ansible:
```json
{
  "nodes": [
    {
      "name": "lab-01",
      "ipv4": "192.168.1.10",
      "ssh_user": "ubuntu",
      "ssh_port": 22,
      "groups": ["base", "docker"]
    }
  ]
}
```

Notes:
- `groups` are mapped to Ansible inventory groups.
- Any secrets (private keys, tokens) must not be written here.

## Ansible inventory consumption rules
Preferred approach:
- `proxmox/ansible/inventory/proxmox_dynamic.yml` reads `outputs.json` and produces inventory.

Minimum inventory variables per host:
- ansible_host
- ansible_user
- ansible_port (optional, default 22)

If you use static inventory (`hosts.yml`), document how it is generated/updated from outputs.json.

## latest.env keys used for infra handoffs
latest.env must include:
- RUN_ID
- RUN_TIMESTAMP
- DRY_RUN
- PROXMOX_API_URL
- PROXMOX_NODE
- PROXMOX_TOKEN_ID
- TEMPLATE_UBUNTU_IMAGE (path)
- TEMPLATE_TALOS_IMAGE (path)
- TERRAFORM_WORKDIR
- TERRAFORM_OUTPUT_JSON
- ANSIBLE_INVENTORY_PATH
- LAST_STEP_COMPLETED

latest.env must never include:
- PROXMOX_TOKEN_SECRET
- any app secrets

## Failure behaviour
- If terraform succeeds but ansible fails:
  - latest.env LAST_STEP_COMPLETED must remain terraform_apply
  - resume should start at ansible_* after re-validation

- If templates are missing:
  - terraform must refuse with templates_present remediation

This contract underpins replay and diagnostics, so deviations must be treated as breaking changes.
