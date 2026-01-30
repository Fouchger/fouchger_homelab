# Command spec: apps_install

## Purpose
Allow user to select apps to install and execute install modules deterministically.

## Entry point
- File: `commands/apps_install.sh`

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
- Updates `state/selections.env` (SELECTED_APPS_INSTALL)
- Updates `state/runs/latest.env` (SELECTED_APPS_INSTALL, LAST_STEP_COMPLETED)
- Writes plan/execution logs

## Dry run behaviour
When DRY_RUN=true: validate selection, modules exist, prerequisites; write plan report; do not execute modules.

## Step-by-step behaviour
1. Load catalogue.
2. Show checklist.
3. Validate IDs and conflicts.
4. Persist selection (unless DRY_RUN).
5. For each app in order:
   - validate module exists
   - validate required secrets (if declared)
   - execute module (unless DRY_RUN)
6. Update latest.env step completion.

## Exit codes
0 success; 10 validation fail; 1 module failure.
