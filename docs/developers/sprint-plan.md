# Sprint plan (demo-driven delivery)

Last updated: 2026-01-31

This sprint plan translates the development roadmap into 2-week, demo-driven sprints. Each sprint ends with a runnable demo aligned to the Development Plan, and leaves the repo in a production-ready documentation state.

## Sprint 1: Runtime foundation
Goals
- Establish run lifecycle, logging, validation, and UI plumbing.

Scope
- lib/runtime.sh
- lib/env.sh
- lib/logger.sh
- lib/validation.sh
- lib/ui_dialog.sh

Demo
```bash
./bin/dev/test_runtime.sh
```

Acceptance
- RUN_ID created
- logs and summary written
- no secrets leaked

## Sprint 2: Menu and diagnostics
Goals
- Prove routing, visibility, and navigation without mutation.
- Formalise the UI helper API and remove the Sprint 1 UI gaps.

Scope
- commands/menu.sh (read-only navigation)
- commands/diagnostics.sh (read-only visibility)

Demo
```bash
./homelab.sh
# Navigate menu
# Open diagnostics
# Return to menu
# Exit cleanly
```

Acceptance
- Menu renders using UI helper API (dialog or graceful fallback)
- Diagnostics reads and displays state/runs/latest.env safely
- Exiting menu completes runtime without errors
- Logs and summary reflect navigation

## Sprint 3: Profiles, selections, and apps pipeline baseline
Goals
- Config-driven selection via profiles.yml and apps.yml.
- Persist selections safely for repeatable installs.
- Deliver a baseline apps install/uninstall pipeline using a Debian/Ubuntu package manager wrapper that prefers nala and falls back to apt-get.

Scope
- commands/profiles.sh
- commands/selections.sh
- commands/apps_install.sh
- commands/apps_uninstall.sh
- lib/state.sh
- lib/yaml.sh
- lib/pkg.sh
- modules/apps/install/* (baseline Debian/Ubuntu installers)
- modules/apps/uninstall/* (baseline Debian/Ubuntu removers)

Demo
```bash
./homelab.sh
# Profiles -> development
# Apps install (try DRY_RUN=true, then DRY_RUN=false)
# Diagnostics (confirm latest.env keys)
```

Known limitations
- No dependency graph or conflict enforcement yet (planned Sprint 4).
- Some apps may not be available via default apt repos (terraform, tailscale) unless vendor repos are added.

Acceptance
- state/selections.env updated
- state/runs/latest.env updated with SELECTED_PROFILE, SELECTED_APPS_INSTALL, SELECTED_APPS_UNINSTALL, LAST_STEP_COMPLETED
- DRY_RUN produces a plan and validates module presence
- Live run executes modules in deterministic order and captures logs

## Sprint 4: Apps pipeline hardening
Goals
- Conflict detection, dependency ordering, and improved installer strategies.

Scope
- Conflict enforcement using apps.yml metadata
- Optional vendor repo enablement for terraform, docker, tailscale
- Stop-on-first-failure vs continue-on-failure policy (make configurable)
- Better text-mode selection experience where dialog is unavailable

Demo
```bash
DRY_RUN=true ./homelab.sh
# Apps install -> plan output includes conflicts and remediation
```

Acceptance
- Conflicts blocked with actionable messaging
- Installer strategies documented and predictable
- Failure policy documented and implemented

## Sprint 5: Proxmox access and templates
Goals
- External integration with safety gates.

Scope
- commands/proxmox_access.sh
- commands/templates.sh

Demo
```bash
./homelab.sh
# Proxmox access (dry run)
# Templates (dry run)
```

Acceptance
- proxmox.env written correctly (no secrets in latest.env)
- template manifest valid

## Sprint 6: Terraform provisioning
Goals
- IaC provisioning with replayable outputs.

Scope
- commands/terraform_apply.sh
- proxmox/terraform

Demo
```bash
./homelab.sh
# Terraform -> plan/apply
```

Acceptance
- outputs.json produced
- latest.env updated with output paths

## Sprint 7: Ansible configuration
Goals
- Host configuration and convergence.

Scope
- commands/ansible_apply.sh
- dynamic inventory

Demo
```bash
./homelab.sh
# Ansible -> dry run/apply
```

Acceptance
- inventory resolved
- logs captured

## Sprint 8: Replay, cleanup, hardening
Goals
- Operational resilience and contributor readiness.

Scope
- Replay/resume
- cleanup
- linting
- CI

Demo
```bash
./homelab.sh
# Replay last run
```

Acceptance
- replay/resume works
- cleanup safe
- CI green
