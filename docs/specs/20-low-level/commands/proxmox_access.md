# Command spec: proxmox_access

## Purpose
Collect Proxmox connection details and create/validate access token, writing credentials to state.

## Entry point
- File: `commands/proxmox_access.sh`

## Required baseline includes
This command must source:
- `lib/runtime.sh`
- `lib/logger.sh`
- `lib/ui_dialog.sh`
- `lib/env.sh`
- `lib/config.sh`
- `lib/validation.sh`

## Validation gates enforced
- None

## Inputs
- `config/proxmox.env.example` (template)
- User inputs via dialog
- `proxmox/setup_access.sh`

## Outputs and artefacts
- Writes `state/proxmox.env` (chmod 600)
- Updates latest.env with non-secret identifiers
- Logs

## Dry run behaviour
Dry run performs syntactic validation only and writes a report; it must not call Proxmox APIs.

## Step-by-step behaviour
1. Check existing proxmox.env (non-secret fields only shown).
2. Prompt for missing fields.
3. Confirm.
4. If DRY_RUN=false run setup_access.sh.
5. Write proxmox.env and latest.env.

## Exit codes
0 success; 10 validation fail; 1 runtime/API failure.
