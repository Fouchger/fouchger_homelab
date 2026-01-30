# Command spec: apps_uninstall

## Purpose
Allow user to select apps to uninstall and execute uninstall modules deterministically.

## Entry point
- File: `commands/apps_uninstall.sh`

## Required baseline includes
This command must source:
- `lib/runtime.sh`
- `lib/logger.sh`
- `lib/ui_dialog.sh`
- `lib/env.sh`
- `lib/config.sh`
- `lib/validation.sh`

## Validation gates enforced
- secrets_present (conditional)

## Inputs
- `config/apps.yml`
- `state/selections.env`
- optional `state/secrets.env`

## Outputs and artefacts
- Updates `state/selections.env` (SELECTED_APPS_UNINSTALL)
- Updates `state/runs/latest.env`
- Writes logs

## Dry run behaviour
Dry run validates and writes a plan report; does not execute modules or mutate selections.

## Step-by-step behaviour
Same as apps_install, using uninstall modules and LAST_STEP_COMPLETED=apps_uninstall.

## Exit codes
0 success; 10 validation fail; 1 module failure.
