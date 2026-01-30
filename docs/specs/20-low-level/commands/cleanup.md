# Command spec: cleanup

## Purpose
Clear caches and tidy logs with explicit confirmations.

## Entry point
- File: `commands/cleanup.sh`

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
- `state/cache/*`
- `state/logs/*`

## Outputs and artefacts
- Removes selected cache/log items
- Never removes secrets unless explicitly confirmed

## Dry run behaviour
Dry run shows what would be deleted and estimated size; does not delete.

## Step-by-step behaviour
1. Present cleanup options.
2. Confirm destructive actions.
3. Execute deletions (unless DRY_RUN).
4. Log results.

## Exit codes
0 success; 1 failure.
