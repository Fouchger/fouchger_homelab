# Command spec: menu

## Purpose
Render the top-level dialog menu and route user choices to one command per action.

## Entry point
- File: `commands/menu.sh`

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
- Reads `config/settings.env` to decide whether to show Replay.
- Reads VERSION (optional) for title.

## Outputs and artefacts
- No state mutation except creating a RUN_ID when dispatching an action.
- Must not modify selections.

## Dry run behaviour
Menu itself is non-mutating; dry_run only affects downstream commands.

## Step-by-step behaviour
1. Load settings.
2. Render menu.
3. On selection: create RUN_ID, init latest.env, open log dir.
4. Dispatch to command.
5. Return to menu.

## Exit codes
0 on normal loop; 1 only on unrecoverable UI failure.
