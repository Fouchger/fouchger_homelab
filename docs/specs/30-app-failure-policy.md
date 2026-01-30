# App install/uninstall failure policy

Last updated: 2026-01-30

## Default policy
The system uses **stop-on-first-failure** for app install and uninstall pipelines.

## Rationale
- Prevents cascading errors
- Keeps state predictable
- Simplifies replay and diagnostics
- Aligns with infrastructure-as-code principles

## Behaviour
- When a module exits non-zero:
  - stop executing further modules
  - mark run as FAILED
  - write failure details to logs and summary
  - update latest.env with FAILURE_STEP and LAST_STEP_COMPLETED

## Optional future extension (not implemented)
A best-effort mode could be added later:
- `continue_on_failure=true` in config/settings.env
- Failures logged but execution continues
- Replay semantics become more complex

Until explicitly implemented, **best-effort behaviour is not allowed**.
