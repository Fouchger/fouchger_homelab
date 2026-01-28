# Module and Paths Policy

## Purpose

Keep the codebase predictable and maintainable by standardising how scripts:

1. Locate the repository.
2. Load shared libraries and optional modules.
3. Read and write operational artefacts (logs, state, caches, UI temp files).

## Module loading policy

### For executable scripts

Executable scripts (anything you run directly from the shell or from the menu) must:

1. Anchor `REPO_ROOT` off the script location.
2. Source `lib/modules.sh`.
3. Call `homelab_load_lib`.
4. Call `homelab_load_modules` only if the script needs module entrypoints.

This avoids duplicated `source` statements and ensures a consistent library order.

Reference pattern:

```bash
REPO_ROOT="${REPO_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
export REPO_ROOT
source "${REPO_ROOT}/lib/modules.sh"
homelab_load_lib
```

### For library files under `lib/`

Library files should not usually source other libraries. The exception is defensive
sourcing where a library can be used standalone (for example `lib/run.sh`).

When defensive sourcing is used:

1. Guard it with `declare -F` checks or variable checks.
2. Prefer `lib/paths.sh` and `lib/logging.sh` only.

## Paths policy

### Single source of truth

All operational folders must be:

1. Defined in `lib/paths.sh`.
2. Created by `ensure_dirs()`.

Examples of operational folders include:

- State (`STATE_DIR_DEFAULT`, `STATE_DIR`, `MARKER_DIR`)
- Logs (`LOG_DIR_DEFAULT`)
- UI runtime files (`UI_DIR`)
- App Manager state/backups (`APPM_DIR`, `ENV_BACKUP_DIR`)

### No hard-coded output paths

Do not hard-code paths such as:

- `~/.config/...`
- `/tmp/...`
- relative `./logs` inside the repo

Always use variables from `lib/paths.sh` so the tool behaves consistently across:

- interactive terminal runs
- `dialog` menu runs
- headless/automation (CI/cron)

### Log files

Per-run logs are owned by `run_init` in `lib/run.sh` and are written to `LOG_DIR_DEFAULT`.
Scripts should not invent their own run log locations.
