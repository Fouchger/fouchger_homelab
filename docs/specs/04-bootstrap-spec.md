# bootstrap and install specification

## Purpose

Provide a simple, reliable first-run experience that installs only what is required to fetch the repo and start the menu runtime.

## Canonical entrypoints

- **install.sh**: remote installer intended to be run via curl. It only installs the prerequisites required to fetch the repository (git, curl, ca-certificates), clones/updates the repo, then **delegates to `bootstrap.sh`**.
- **bootstrap.sh**: single source of truth for bootstrapping once the repo exists locally. It installs runtime dependencies, applies permissions, and hands off to `homelab.sh`.

## Behaviour

### install.sh
- Installs only `git`, `curl`, and `ca-certificates` (Debian/Ubuntu/Proxmox via apt)
- Clones or updates the repo into `$HOME/fouchger_homelab` by default
- Executes `./bootstrap.sh` in the repo with `SKIP_CLONE=1` so bootstrapping logic remains centralised

### bootstrap.sh
- Installs runtime dependencies (at least `git` and `dialog`; also `curl` and `ca-certificates` for ongoing operations)
- Ensures executables (`chmod +x` all `*.sh` plus any files listed in `config/executables.list`)
- Explicitly skips `archieve/` when applying executable bits (legacy reference only)
- Hands off to `./homelab.sh`
