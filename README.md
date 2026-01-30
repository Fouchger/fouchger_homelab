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

## Sprint 1 demo

```bash
./bin/dev/test_runtime.sh
```

See `docs/developers/sprint-plan.md` and `docs/developers/architecture.md` for the long-term design.
