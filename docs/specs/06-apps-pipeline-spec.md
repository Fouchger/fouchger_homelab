# Apps pipeline specification

Last updated: 2026-01-31

This specification describes how fouchger_homelab selects, installs, and uninstalls local applications.

## Design principles
- Catalogue-driven: apps are defined in config/apps.yml and profiles in config/profiles.yml.
- Non-interactive installers: all modules under modules/apps must run without prompts.
- Prefer nala, fallback to apt-get: packaging wrapper lives in lib/pkg.sh.
- Observable by default: all module output is captured in the run log.
- Non-secret handoff: selections are persisted to state/selections.env and mirrored into state/runs/latest.env.

## Key files
- config/apps.yml: app catalogue (name, description, install/uninstall module paths)
- config/profiles.yml: profiles -> list of app ids
- commands/profiles.sh: pick a profile, update selections
- commands/selections.sh: manually set install/uninstall lists
- commands/apps_install.sh: install selected apps
- commands/apps_uninstall.sh: uninstall selected apps
- lib/pkg.sh: Debian/Ubuntu package wrapper (nala -> apt-get)
- modules/apps/install/*.sh and modules/apps/uninstall/*.sh: app installers/removers

## State contract
state/selections.env (persisted across runs)
- SELECTED_PROFILE
- SELECTED_APPS_INSTALL (comma separated)
- SELECTED_APPS_UNINSTALL (comma separated)

state/runs/latest.env (handoff per run)
- RUN_ID, RUN_DIR, LOG_FILE, RUN_STARTED_AT, RUN_TIMESTAMP, DRY_RUN
- SELECTED_PROFILE
- SELECTED_APPS_INSTALL
- SELECTED_APPS_UNINSTALL
- LAST_STEP_COMPLETED

## Execution model
1) Profile selection (optional)
- profiles.sh reads config/profiles.yml and writes the selected app ids into SELECTED_APPS_INSTALL.
- Mode
  - replace: overwrite install selections
  - add: merge profile apps into existing install selections

2) Manual selection (optional)
- selections.sh updates both install and uninstall selections.
- Dialog mode uses checklists.
- Text mode falls back to comma-separated input boxes.

3) Install pipeline
- apps_install.sh
  - Selection precedence: --apps arg -> state/selections.env -> prompt (dialog only)
  - DRY_RUN=true: validates module existence and displays the plan, without executing modules
  - DRY_RUN=false: executes each install module in the order listed, and reports failures

4) Uninstall pipeline
- apps_uninstall.sh mirrors install behaviour for uninstall modules.

## Module contract
Every module under modules/apps/install and modules/apps/uninstall must
- Be idempotent
- Be non-interactive
- Exit 0 on success, non-zero on failure
- Avoid printing secrets

Baseline modules in this repo currently target Debian/Ubuntu packaging (nala or apt-get). Future sprints can introduce distro-specific strategies.

## Known gaps and planned hardening
Planned Sprint 4 improvements
- Dependency ordering and conflict enforcement using apps.yml metadata
- Vendor repository support for apps that are not available via default apt repositories (for example terraform, tailscale)
- A consistent failure policy (stop-on-first-failure vs continue) with a config switch
