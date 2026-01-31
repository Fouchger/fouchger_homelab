# Profiles Overview

Last updated: 2026-02-01 (Pacific/Auckland)


## Two-tier profile strategy

### 1) Admin Node Profiles (control plane only)

The Admin Node is responsible for orchestration, provisioning, and platform governance. It should not run general application services.

Admin Node profiles are layered so you can rebuild quickly and keep the node predictable:
- Admin Control Plane Baseline (mandatory)
- Admin Security Baseline (mandatory)
- Admin Operational Toolkit (optional)
- Admin Capabilities (optional toggles, not full profiles)

### 2) Server Role Profiles (workload nodes)

Every workload node must have:
- Workload Baseline (mandatory)

Plus:
- Exactly one role profile (DNS, Storage, Observability, Kubernetes Worker, etc.)

Optional add-ons may be attached when appropriate (for example, log shipper choice).

## Principles

- Keep the admin node boring, stable, and rebuildable.
- Keep workload nodes tightly scoped to their purpose.
- Prefer automation over manual configuration.
- Favour enterprise patterns: least privilege, change control, observability by default.

## Current implementation status

Today, profiles are used to manage **local applications on the admin node** (see `config/profiles.yml`).

The two-tier model in this folder is the **target operating model**. Until server role profiles are implemented in code, treat the role catalogue as documentation of intended workload-node states, with the admin node remaining the single orchestration point.
