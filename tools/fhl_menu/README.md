# Fouchger HomeLab Menu

Production-ready terminal menu for Ubuntu 22.04/24.04 and Debian 12, designed for Proxmox LXC/VM and bare metal.

Features
- Textual TUI with CLI fallback (same options in both modes)
- Rotating file logging (always-on)
- TOML settings stored per user
- Doctor report for terminal/env diagnostics
- Log level editable via menu and persisted

Run
- Installer (self-healing):
  - `bash install.sh`
- Manual run:
  - `cd tools/fhl_menu`
  - `python -m venv .venv && source .venv/bin/activate`
  - `pip install -r ../../requirements.txt`
  - `python -m fhl_menu`

Overrides (optional)
- `FHL_REPO_BRANCH=dev`
- `FHL_APP_DISPLAY_NAME="Fouchger HomeLab"`
- `FHL_APP_SLUG="fouchger-homelab"`

install
```bash
bash -c 'curl -fsSL https://raw.githubusercontent.com/Fouchger/fouchger_homelab/refs/heads/20250205/install.sh | bash'
```