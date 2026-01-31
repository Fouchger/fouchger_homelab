# UI and navigation specification

## Top-level menu
Profiles, Apps, Proxmox access, Templates, Terraform, Ansible, Diagnostics, Replay (if enabled), Exit.

## UI requirements
All interactive screens must use the wrappers in `lib/ui_dialog.sh` to keep behaviour consistent across Proxmox LXC/VM environments.

Decision tree (must be followed consistently):
1. If `/dev/tty` is usable, `TERM` is set and not `dumb`, and `dialog` exists: use `dialog` bound to `/dev/tty`.
2. Else if the shell is interactive (`-t 0`): use simple text prompts.
3. Else: run non-interactively using defaults and flags, and log clearly (no blocking reads).

Key expectations:
- Commands must remain safe in headless runs (no hangs waiting for input).
- `ui_menu` returns an empty selection on cancel; callers must treat empty as “back/exit”.
- For automation, `HOMELAB_DEFAULT_CHOICE` may be used to preselect a menu option.
