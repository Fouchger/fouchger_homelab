# Command spec: terraform_apply

## Purpose
Run terraform init/plan/apply for Proxmox provisioning and publish outputs for Ansible.

## Entry point
- File: `commands/terraform_apply.sh`

## Required baseline includes
This command must source:
- `lib/runtime.sh`
- `lib/logger.sh`
- `lib/ui_dialog.sh`
- `lib/env.sh`
- `lib/config.sh`
- `lib/validation.sh`

## Validation gates enforced
- proxmox_creds_present
- templates_present
- terraform_ready

## Inputs
- `state/proxmox.env`
- `state/cache/templates/manifest.json`
- `proxmox/terraform/*`
- `config/settings.env`

## Outputs and artefacts
- Writes working data under `state/cache/terraform/`
- Writes `state/cache/terraform/outputs.json`
- Updates latest.env (TERRAFORM_WORKDIR, TERRAFORM_OUTPUT_JSON, LAST_STEP_COMPLETED)
- Logs

## Dry run behaviour
If DRY_RUN=true: terraform plan only; no apply; write plan output and LAST_STEP_COMPLETED=terraform_plan.

## Step-by-step behaviour
1. Validate gates.
2. terraform init in workdir.
3. terraform plan.
4. If DRY_RUN=false: terraform apply.
5. Generate outputs.json.
6. Update latest.env.

## Exit codes
0 success; 10 validation fail; 1 terraform failure.
