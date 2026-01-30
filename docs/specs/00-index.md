# fouchger_homelab – Complete Project Specification

## Scope
This specification defines every functional feature of the **fouchger_homelab** automation suite, including UI behaviour, state contracts, validation gates, and integration points across Proxmox, Terraform, and Ansible.

This pack is documentation-only. It is written so implementation across `bootstrap.sh`, `homelab.sh`, `commands/`, `lib/`, and backends fits together without ambiguity.

## Document map
### Developer references
- [docs/developers/architecture.md](/fouchger_homelab/docs/developers/architecture.md)
- [docs/developers/runtime.md](/fouchger_homelab/docs/developers/runtime.md)
- [docs/developers/validation-and-errors.md](/fouchger_homelab/docs/developers/validation-and-errors.md)
- [docs/developers/extending.md](/fouchger_homelab/docs/developers/extending.md)

### Specifications
- [docs/specs/01-functional-overview.md](/fouchger_homelab/docs/specs/01-functional-overview.md)
- [docs/specs/02-config-and-state-schema.md](/fouchger_homelab/docs/specs/02-config-and-state-schema.md)
- [docs/specs/03-ui-and-navigation-spec.md](/fouchger_homelab/docs/specs/03-ui-and-navigation-spec.md)
- [docs/specs/04-bootstrap-spec.md](/fouchger_homelab/docs/specs/04-bootstrap-spec.md)
- [docs/specs/05-menu-and-command-contracts.md](/fouchger_homelab/docs/specs/05-menu-and-command-contracts.md)
- [docs/specs/06-apps-pipeline-spec.md](/fouchger_homelab/docs/specs/06-apps-pipeline-spec.md)
- [docs/specs/07-proxmox-access-spec.md](/fouchger_homelab/docs/specs/07-proxmox-access-spec.md)
- [docs/specs/08-templates-spec.md](/fouchger_homelab/docs/specs/08-templates-spec.md)
- [docs/specs/09-terraform-spec.md](/fouchger_homelab/docs/specs/09-terraform-spec.md)
- [docs/specs/10-ansible-spec.md](/fouchger_homelab/docs/specs/10-ansible-spec.md)
- [docs/specs/11-diagnostics-and-cleanup-spec.md](/fouchger_homelab/docs/specs/11-diagnostics-and-cleanup-spec.md)
- [docs/specs/12-dry-run-and-replay-spec.md](/fouchger_homelab/docs/specs/12-dry-run-and-replay-spec.md)
- [docs/specs/13-logging-observability-spec.md](/fouchger_homelab/docs/specs/13-logging-observability-spec.md)
- [docs/specs/14-validation-gates-spec.md](/fouchger_homelab/docs/specs/14-validation-gates-spec.md)
- [docs/specs/15-security-and-secrets-spec.md](/fouchger_homelab/docs/specs/15-security-and-secrets-spec.md)
- [docs/specs/16-acceptance-tests.md](/fouchger_homelab/docs/specs/16-acceptance-tests.md)

### ADR placeholders
- [docs/ADRs/0001-architecture-and-state-contract.md](/fouchger_homelab/docs/ADRs/0001-architecture-and-state-contract.md)
- [docs/ADRs/0002-dry-run-and-replay.md](/fouchger_homelab/docs/ADRs/0002-dry-run-and-replay.md)
- [docs/ADRs/0003-validation-gates.md](/fouchger_homelab/docs/ADRs/0003-validation-gates.md)

Last updated: 2026-01-29

### Low-level specifications
- docs/specs/20-low-level/README.md

## Examples
- docs/examples/

## Quality and delivery
- docs/specs/28-definition-of-done.md
- docs/specs/29-version-pinning-policy.md
- docs/specs/30-app-failure-policy.md
