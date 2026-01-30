# Command spec: profiles

## Purpose
Apply a profile (replace or add) to app selections.

## Entry point
- File: `commands/profiles.sh`

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
- `config/profiles.yml`
- `config/apps.yml`
- `state/selections.env` (existing, optional)

## Outputs and artefacts
- Updates `state/selections.env`
- Updates `state/runs/latest.env` (SELECTED_PROFILE, selected apps, LAST_STEP_COMPLETED=profiles)
- Writes logs under `state/logs/<RUN_ID>/`

## Dry run behaviour
Dry run previews the resulting selection set and writes a plan report; it must not write selections.env.

## Step-by-step behaviour
1. Load profiles.
2. Let user select profile.
3. Validate all referenced apps exist.
4. Prompt Replace vs Add.
5. Compute resulting set.
6. If DRY_RUN=true: write plan report only.
7. Else persist selections.env and update latest.env.

## Exit codes
0 success; 10 validation fail (unknown app id); 1 runtime failure.
