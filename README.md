# fouchger_homelab

## Quick start (recommended)

Run the remote installer:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Fouchger/fouchger_homelab/rewrite/install.sh)"
```

This will:
- install minimum dependencies (git, dialog) on Debian/Ubuntu/Proxmox
- clone or update the repo into `~/fouchger_homelab`
- hand off to `./homelab.sh`

## Local run

From the repo root:

```bash
./homelab.sh
```

## What works now
- Menu-driven navigation (dialog with safe fallbacks)
- Profiles and manual selections persisted to state/selections.env
- Apps install/uninstall pipeline (Debian/Ubuntu), preferring nala with apt-get fallback
- Diagnostics view (gates, environment, latest.env)

## Demo scripts

### Runtime demo (Sprint 1)

```bash
./bin/dev/test_runtime.sh
```

### Profiles + apps pipeline demo (Sprint 3)
```bash
./homelab.sh
# Profiles -> development
# Apps install (set DRY_RUN=true, then unset)
```

See `docs/developers/sprint-plan.md` and `docs/developers/architecture.md` for the long-term design.
