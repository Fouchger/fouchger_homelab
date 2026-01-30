# Command spec: templates

## Purpose
Download and cache Ubuntu and Talos templates, writing a manifest for Terraform consumption.

## Entry point
- File: `commands/templates.sh`

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

## Inputs
- `state/proxmox.env`
- `proxmox/download_templates.sh`

## Outputs and artefacts
- Writes template files under `state/cache/templates/`
- Writes `state/cache/templates/manifest.json`
- Updates latest.env TEMPLATE_* and LAST_STEP_COMPLETED=templates
- Logs

## Dry run behaviour
Dry run lists intended downloads and expected output paths; does not download.

## Step-by-step behaviour
1. Show cache status.
2. Choose action (ubuntu/talos/both/clear).
3. Validate creds gate.
4. Execute downloader.
5. Write manifest and update latest.env.

## Exit codes
0 success; 10 validation fail; 1 download failure.
