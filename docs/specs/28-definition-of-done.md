# Developer Definition of Done (DoD)

Last updated: 2026-01-30

This checklist applies to every command and module before it is considered complete.

## Global requirements (all commands)
- Validation gates enforced as per spec
- DRY_RUN=true produces:
  - no mutation
  - a clear plan report in logs
- Logs written to `state/logs/<RUN_ID>/`
- `summary.json` and `summary.md` produced
- `state/runs/latest.env` updated correctly (no secrets)
- Clear UI result screen with RUN_ID and log path

## Replay requirements (where applicable)
- Command records sufficient data in latest.env to replay
- Replay from start works
- Resume from LAST_STEP_COMPLETED works (if command participates in pipeline)

## Apps install/uninstall commands
- Conflicts enforced at selection time
- Deterministic execution order
- Stop-on-first-failure unless policy explicitly states otherwise
- Module exit codes handled correctly

## Infra commands (templates / terraform / ansible)
- Required gates block execution if unmet
- Artefacts written to documented paths
- Partial failures leave repo in resumable state

## Module scripts
- Idempotent
- Non-interactive
- Honour DRY_RUN
- Do not leak secrets
- Use standard log format

A command or module that does not meet this checklist must not be merged.
