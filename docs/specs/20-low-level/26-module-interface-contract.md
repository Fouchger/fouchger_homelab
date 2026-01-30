# Module interface contract (apps)

Last updated: 2026-01-30

## Purpose
Define the exact interface between `commands/apps_install.sh` / `apps_uninstall.sh` and the module scripts under `modules/apps/`.

This prevents modules from becoming bespoke snowflakes and keeps logging, dry run, and error handling consistent.

## Invocation contract
Modules are executed by commands. Commands provide context via environment variables.

### Environment variables provided to modules
Mandatory:
- RUN_ID: current run identifier
- DRY_RUN: `true|false`
- LOG_DIR: absolute or repo-relative path, e.g. `state/logs/<RUN_ID>`
- APP_ID: the module app identifier

Optional (future-ready):
- OS_FAMILY: `debian` etc.
- PACKAGE_MANAGER: `apt`

Modules must not depend on variables not listed here unless added to this spec.

## Behavioural requirements
1. Idempotency
- Install: if already installed, exit 0 and log INFO.
- Uninstall: if not installed, exit 0 and log INFO.

2. Non-interactive
- Modules must not prompt the user. All prompting happens in dialog UI.

3. Output and logging
- Modules write logs to stdout/stderr.
- Logs must follow: `[LEVEL] <app_id>: <message>`

4. Secrets handling
- Modules must never echo secrets.
- Modules may read required secrets from environment (if the command chooses to export them), but this must be explicitly documented per app and masked in logs.

5. Exit codes
- 0: success (including no-op)
- 1: actionable failure (install/uninstall failed)
- 2: unsupported platform
- 3: missing prerequisite (package manager, command, permission)

Commands must treat any non-zero as a module failure and stop further module execution unless explicitly configured to continue.

## DRY_RUN behaviour
Modules must not mutate when DRY_RUN=true.
Acceptable dry run patterns:
- Return 0 and log planned actions.
- Validate prerequisites and log warnings.

Modules must not:
- install packages
- write files outside LOG_DIR
- enable services
- change system configuration

## Required module header
Every module must include at top:
- title
- purpose
- contract
- idempotency note
- non-interactive note
- secrets note

This is to keep contribution quality consistent.

## Developer checklist
Before merging a new module:
- it is idempotent
- it honours DRY_RUN
- it uses standard log format
- it does not prompt
- it does not leak secrets
