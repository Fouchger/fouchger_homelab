# Command spec: diagnostics

## Purpose
Report gate readiness, last run summary, and provide log viewing/export without mutation.

## Entry point
- File: `commands/diagnostics.sh`

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
- `config/validations.yml`
- `state/runs/latest.env` (optional)
- `state/logs/`

## Outputs and artefacts
- Writes optional diagnostics report under current RUN_ID logs
- Does not change infra/app state

## Dry run behaviour
Dry run not applicable; diagnostics is non-mutating.

## Step-by-step behaviour
1. Report gates.
2. Show latest.env summary.
3. Offer view logs/export report.

## Exit codes
0 success; 1 UI failure.
