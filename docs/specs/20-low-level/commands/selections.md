# Command spec: selections

## Purpose
Read and write selection state for install/uninstall pipelines.

## Entry point
- File: `commands/selections.sh`

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
- `state/selections.env`

## Outputs and artefacts
- Updated `state/selections.env`

## Dry run behaviour
Selections helper must honour DRY_RUN by not writing when DRY_RUN=true.

## Step-by-step behaviour
1. Parse selections.env.
2. Merge or replace keys.
3. Write back with safe permissions.

## Exit codes
0 success; 1 failure to write.
