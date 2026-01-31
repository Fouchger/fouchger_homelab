# Menu and command contracts

## Purpose
Each command in `commands/` implements one discrete menu action. The contract
ensures every command behaves consistently across interactive runs, dialog UI,
and automated or replayable execution.



## UI helper API status
The UI helper API is standardised in `lib/ui_dialog.sh` and supports an auto-selected UI mode:
- dialog (when /dev/tty is usable and dialog is installed)
- text (interactive stdin fallback)
- console (headless default selection via HOMELAB_DEFAULT_CHOICE)

## Required behaviour for every command
1. Initialise the run lifecycle (RUN_ID, run directories, log file)
2. Write all logs to `state/logs/` and a per-run summary to `state/runs/<RUN_ID>/`
3. Apply validation gates (including "no secrets leaked")
4. Use the shared UI wrapper so the look and feel remains consistent
5. Exit with a meaningful return code

## Command runner contract
Commands must use the standard runner:
- Library: `lib/command_runner.sh`
- API: `command_run "<command_name>" <implementation_fn> "$@"`

The runner is responsible for:
- `ui_init`
- `runtime_init`
- section logging and summary line defaults
- ensuring `runtime_finish` runs exactly once via the EXIT trap

Commands should not call `runtime_finish` directly.

## Minimal command template
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# shellcheck disable=SC1091
source "${ROOT_DIR}/lib/command_runner.sh"

my_command_impl() {
  # do work
  return 0
}

main() {
  command_run "my_command" my_command_impl "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

## Secrets handling
- Secrets must never be sourced from `config/`.
- Secrets are loaded explicitly from `state/secrets.env` using `lib/secrets.sh`.
- Any command that needs secrets must:
  - call `secrets_load`
  - call `secrets_require VAR1 VAR2 ...` and fail safely if missing
  - avoid echoing secret values (logger will redact, but this is a guardrail, not a licence)
