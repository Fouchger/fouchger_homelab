# Sprint plan (documentation-first delivery)

Last updated: 2026-01-30

This sprint plan translates the development roadmap into **2-week, demo-driven sprints**.
Each sprint must end with a runnable demo aligned to the Development Plan.

## Sprint 1: Runtime foundation
**Goals**
- Establish run lifecycle, logging, validation, and UI plumbing.

**Scope**
- lib/runtime.sh
- lib/env.sh
- lib/logger.sh
- lib/validation.sh
- lib/ui_dialog.sh

**Demo**
```bash
./bin/dev/test_runtime.sh
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- RUN_ID created
- logs + summary written
- no secrets leaked
- controlled UI error permitted and expected (UI helper API is not yet standardised in Sprint 1)

---

## Sprint 2: Menu and diagnostics
**Goals**
- Prove routing, visibility, and navigation without mutation.
- Formalise the UI helper API and remove the known Sprint 1 UI error.
- Demonstrate safe traversal between menu and diagnostics with full runtime observability.

**Scope**
UI layer (new, explicit)
- lib/ui_dialog.sh
    - Define and stabilise the public UI helper API:
        - ui_init
        - ui_info
        - ui_warn
        - ui_error
        - ui_menu (or equivalent selector wrapper)
    - Ensure graceful fallback between:
        - dialog mode
        - non-interactive / stdout mode
    - Ensure all UI helpers:
        - are safe to call multiple times
        - do not terminate the runtime
        - optionally log via logger if available

This closes the Sprint 1 known limitation.

**Menu and routing**
- commands/menu.sh
    - Main menu loop
    - Routes to diagnostics
    - Clean return paths
    - No state mutation

**Diagnostics**
- commands/diagnostics.sh
    - Read-only visibility into:
        - runtime state
        - state/runs/latest.env
        - environment detection
        - gate status
    - No configuration changes
    - No secrets required

**Demo**
```bash
./homelab.sh
# Navigate menu
# Enter diagnostics
# Return to menu
# Exit cleanly
```



**Known limitation**
- No infrastructure changes (no installs, no Proxmox calls).
- Menu and diagnostics are strictly read-only.
- Secrets loading is not required or exercised in Sprint 2.

The Sprint 1 UI helper missing-function error is resolved in Sprint 2 by formalising the UI API.

**Acceptance**
- Menu renders using UI helper API (dialog or fallback).
- Gates are visible in diagnostics.
- `state/runs/latest.env` is read and displayed safely.
- Diagnostics returns cleanly to menu.
- Exiting menu completes runtime without errors.
- Logs and summary reflect menu navigation and diagnostics execution.

---

## Sprint 3: Profiles and selections
**Goals**
- Deterministic config-driven selection.

**Scope**
- commands/profiles.sh
- commands/selections.sh

**Demo**
```bash
./homelab.sh
# Profiles → core
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- selections.env updated
- dry run safe
- conflicts blocked

---

## Sprint 4: Apps pipeline
**Goals**
- Local app install/uninstall pipeline.

**Scope**
- commands/apps_install.sh
- commands/apps_uninstall.sh
- core app modules

**Demo**
```bash
./homelab.sh
# Apps → Install (dry run then live)
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- DRY_RUN produces plan
- live run installs core apps
- stop-on-first-failure enforced

---

## Sprint 5: Proxmox access and templates
**Goals**
- External integration with safety.

**Scope**
- commands/proxmox_access.sh
- commands/templates.sh

**Demo**
```bash
./homelab.sh
# Proxmox access (dry run)
# Templates
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- proxmox.env written correctly
- template manifest valid

---

## Sprint 6: Terraform provisioning
**Goals**
- IaC provisioning with replayable outputs.

**Scope**
- commands/terraform_apply.sh
- proxmox/terraform

**Demo**
```bash
./homelab.sh
# Terraform → plan/apply
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- outputs.json produced
- latest.env updated

---

## Sprint 7: Ansible configuration
**Goals**
- Host configuration and convergence.

**Scope**
- commands/ansible_apply.sh
- dynamic inventory

**Demo**
```bash
./homelab.sh
# Ansible → dry run/apply
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- inventory resolved
- logs captured

---

## Sprint 8: Replay, cleanup, hardening
**Goals**
- Operational resilience and contributor readiness.

**Scope**
- Replay
- cleanup
- linting
- CI

**Demo**
```bash
./homelab.sh
# Replay last run
```



**Known limitation**
Sprint 1 intentionally delivers UI plumbing only. The high-level UI helper API is standardised in Sprint 2, so a controlled UI helper missing-function error may be observed while still meeting Sprint 1 acceptance (runtime completes with logs, summary, and validation).

**Acceptance**
- replay/resume works
- cleanup safe
- CI green
