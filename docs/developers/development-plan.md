# Development plan and implementation roadmap

Last updated: 2026-01-30

This document defines the **sequenced development plan** for the fouchger_homelab project.
It is written to ensure incremental delivery, low rework risk, and continuous demoability.

Each phase includes:
- Scope and intent
- Explicit deliverables
- Definition of Done (DoD)
- A demo script that must work before moving on

This plan is normative for contributors.

---

## Phase 0: Repository readiness and guardrails

### Scope
Ensure documentation is authoritative and the repo is safe to work in.

### Deliverables
- Documentation index (`docs/specs/00-index.md`) is accurate
- Supported OS policy agreed (Ubuntu 22.04+, Debian 12+)
- Basic repo sanity checks exist

### Definition of Done
- All spec files referenced in the index exist
- No undocumented directories or scripts
- Repo can be cloned and explored without execution errors

### Demo script
```bash
ls docs/specs/00-index.md
tree docs/specs
```

---

## Phase 1: Shared runtime and plumbing

### Scope
Implement the shared `lib/` layer used by all commands.

### Components
- lib/runtime.sh
- lib/env.sh
- lib/logger.sh
- lib/validation.sh
- lib/ui_dialog.sh

### Deliverables
- RUN_ID generation
- Log directory creation
- summary.json and summary.md writers
- Gate execution engine
- Dialog wrappers

### Definition of Done
- A test script can initialise a run and write logs
- No secrets printed to console or logs
- summary.json matches schema

### Demo script
```bash
./bin/dev/test_runtime.sh
ls state/logs/
cat state/logs/*/summary.json
```

---

## Phase 2: Menu and diagnostics

### Scope
Prove routing, UI, logging, and validation without touching external systems.

### Components
- commands/menu.sh
- commands/diagnostics.sh

### Deliverables
- Top-level menu
- Diagnostics report of all gates
- latest.env read and display

### Definition of Done
- Menu opens and returns cleanly
- Diagnostics runs without mutation
- Logs and summaries written

### Demo script
```bash
./homelab.sh
# Select "Diagnostics"
```

---

## Phase 3: Selections, profiles, and apps pipeline

### Scope
Implement configuration-driven app selection and execution.

### Components
- commands/selections.sh
- commands/profiles.sh
- commands/apps_install.sh
- commands/apps_uninstall.sh
- Core app modules (curl, jq, yq, openssh_client)

### Deliverables
- Profile selection with replace/add
- Manual app selection
- Deterministic module execution
- DRY_RUN support

### Definition of Done
- Profile selection updates selections.env
- Dry run produces plan report only
- Live run installs core apps successfully
- Stop-on-first-failure enforced

### Demo script
```bash
./homelab.sh
# Select Profiles → core
# Select Apps → Install (dry run)
# Disable dry run and install
```

---

## Phase 4: Proxmox access and templates

### Scope
Introduce Proxmox integration safely.

### Components
- commands/proxmox_access.sh
- proxmox/setup_access.sh
- commands/templates.sh
- proxmox/download_templates.sh

### Deliverables
- proxmox.env creation
- Template cache and manifest.json

### Definition of Done
- proxmox.env written with correct permissions
- Templates cached and manifest valid
- Validation gates turn green

### Demo script
```bash
./homelab.sh
# Proxmox access (dry run)
# Templates → download both
```

---

## Phase 5: Terraform provisioning

### Scope
Provision infrastructure using Terraform.

### Components
- commands/terraform_apply.sh
- proxmox/terraform/*
- state/cache/terraform

### Deliverables
- terraform plan (dry run)
- terraform apply (live)
- outputs.json produced

### Definition of Done
- Plan runs without apply in dry run
- Apply creates outputs.json
- latest.env updated correctly

### Demo script
```bash
./homelab.sh
# Terraform → plan
# Terraform → apply
```

---

## Phase 6: Ansible configuration

### Scope
Configure provisioned hosts using Ansible.

### Components
- commands/ansible_apply.sh
- proxmox/ansible/*
- Dynamic inventory

### Deliverables
- Inventory built from outputs.json
- Playbook execution
- Ansible logs captured

### Definition of Done
- Dry run performs syntax/check only
- Live run configures hosts
- Logs and summaries written

### Demo script
```bash
./homelab.sh
# Ansible → dry run
# Ansible → apply
```

---

## Phase 7: Replay and cleanup

### Scope
Operational resilience and housekeeping.

### Components
- Replay option in menu
- commands/cleanup.sh

### Deliverables
- Replay from start
- Resume from last step
- Safe cache cleanup

### Definition of Done
- Replay works with unchanged inputs
- Resume skips completed steps
- Cleanup respects confirmations and dry run

### Demo script
```bash
./homelab.sh
# Replay last run
# Cleanup → dry run
```

---

## Phase 8: Hardening and contributor experience

### Scope
Stabilise and prepare for contributors.

### Components
- Linting (shellcheck)
- Pre-commit hooks
- Acceptance test runner
- CI pipeline

### Deliverables
- Automated checks
- Reduced regressions
- Contributor confidence

### Definition of Done
- CI passes on clean checkout
- Common errors caught early
- Documentation and code remain aligned

### Demo script
```bash
./bin/dev/run_acceptance_tests.sh
```

---

## Exit criteria
When all phases are complete:
- The system is fully reproducible
- Documentation matches behaviour
- New contributors can onboard without tribal knowledge
