# fouchger_homelab

bash -c "$(curl -fsSL https://raw.githubusercontent.com/Fouchger/fouchger_homelab/main/install.sh)"

## Repo-local state

This project writes all runtime state (settings, secrets, logs and output
artifacts) under:

`$ROOT_DIR/state`

This folder is excluded by `.gitignore` and should never be committed.

If your repo path is read-only (some LXC/VM patterns), you can override the
state root by exporting `HOMELAB_STATE_DIR` to a writable location.
