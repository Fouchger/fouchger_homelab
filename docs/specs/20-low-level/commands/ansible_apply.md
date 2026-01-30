# Command spec: ansible_apply

## Purpose
Run Ansible playbooks against provisioned hosts using outputs-driven inventory.

## Entry point
- File: `commands/ansible_apply.sh`

## Required baseline includes
This command must source:
- `lib/runtime.sh`
- `lib/logger.sh`
- `lib/ui_dialog.sh`
- `lib/env.sh`
- `lib/config.sh`
- `lib/validation.sh`

## Validation gates enforced
- ansible_ready

## Inputs
- `proxmox/ansible/*`
- `state/cache/terraform/outputs.json`
- `state/runs/latest.env`

## Outputs and artefacts
- Writes ansible logs under state/logs/<RUN_ID>/
- Updates latest.env ANSIBLE_INVENTORY_PATH and LAST_STEP_COMPLETED

## Dry run behaviour
If DRY_RUN=true: syntax check and optional check mode; no changes; LAST_STEP_COMPLETED=ansible_check.

## Step-by-step behaviour
1. Validate gates.
2. Resolve inventory path.
3. Choose playbook.
4. Execute ansible-playbook with appropriate flags.
5. Update latest.env.

## Exit codes
0 success; 10 validation fail; 1 ansible failure.
