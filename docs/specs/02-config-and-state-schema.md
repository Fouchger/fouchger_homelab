# Configuration and state schema

This document defines the canonical schemas for configuration and state artefacts. Treat these as contracts. If implementation deviates, update the schema and documents first, then implement.

## config/apps.yml

### Purpose
`config/apps.yml` is the authoritative catalogue of applications that can be installed or uninstalled. It is metadata only. It must not contain logic or environment-specific values.

Every app must map to module scripts under:
- `modules/apps/install/<app_id>.sh`
- `modules/apps/uninstall/<app_id>.sh` (strongly recommended, even if it becomes a no-op)

### Design principles
- Stable app IDs (treat as API; avoid renames)
- Declarative prerequisites (packages, commands, secrets)
- Safe to read during dry run and diagnostics
- No secrets or host-specific values stored in config

### Canonical schema
```yaml
apps:
  <app_id>:
    name: "<Human readable name>"
    description: "<Short description shown in UI>"
    category: "<optional grouping, e.g. core, infra, container, network>"
    install:
      module: "modules/apps/install/<app_id>.sh"
    uninstall:
      module: "modules/apps/uninstall/<app_id>.sh"

    requires:
      packages:
        - <os_package_name>
      commands:
        - <binary_expected_after_install>
      secrets:
        - <SECRET_KEY_NAME>

    conflicts:
      - <other_app_id>

    provides:
      - <capability_tag>

    default_selected: false
```

### Field definitions
| Field | Required | Description |
|---|---|---|
| `app_id` | yes | Stable, lowercase identifier. Used in profiles, selections, and replay. |
| `name` | yes | Display name in dialog UI. |
| `description` | yes | One-line UI description. |
| `category` | no | UI grouping. Future-friendly for filtering and navigation. |
| `install.module` | yes | Relative path to install module script. |
| `uninstall.module` | no | Relative path to uninstall module script. |
| `requires.packages` | no | OS packages to ensure present (optional implementation choice). |
| `requires.commands` | no | Commands expected post-install (validation and diagnostics). |
| `requires.secrets` | no | Secret keys that must exist in `state/secrets.env`. |
| `conflicts` | no | Apps that cannot be selected together; enforce at selection time. |
| `provides` | no | Capability tags, e.g. `container_runtime`, `iac`, `cm`. |
| `default_selected` | no | Pre-selected in manual app selection UI. |

### Behavioural rules
- If `install.module` does not exist, the command must fail fast with a clear remediation message.
- If required secrets are missing:
  - dry run: warn and include in plan report
  - live run: block execution before running the module
- Conflicts must be enforced during selection, not during execution.
- Execution ordering should be deterministic. Default is alphabetical by `app_id` unless explicit dependency ordering is introduced later.

### Minimal core baseline
These are the apps you can rely on across all environments because they are small, widely available, and enable the automation plumbing:

Tier 0: runtime baseline installed by `bootstrap.sh` (not app-managed)
- git
- dialog
- bash

Tier 1: core baseline profile (managed through apps and profiles)
- curl
- jq
- yq
- openssh_client

Tier 2: infrastructure baseline (only for Proxmox + Terraform + Ansible workflows)
- terraform
- ansible

### Example (as implemented in this repo)
```yaml
apps:
  curl:
    name: "Curl"
    description: "HTTP client for downloads and API calls"
    category: "core"
    install:
      module: "modules/apps/install/curl.sh"
    uninstall:
      module: "modules/apps/uninstall/curl.sh"
    requires:
      commands: ["curl"]
    provides: ["http_client"]
    default_selected: true
```

## config/profiles.yml

### Purpose
`config/profiles.yml` defines curated bundles of apps. Profiles are composition only. They reference app IDs and do not override app behaviour.

### Canonical schema
```yaml
profiles:
  <profile_id>:
    name: "<Human readable name>"
    description: "<What this profile is for>"
    apps:
      - <app_id>
      - <app_id>
    tags:
      - <optional_label>
```

### Behavioural rules
- Every app referenced in a profile must exist in `config/apps.yml`.
- Profile selection must prompt for merge semantics:
  - Replace: overwrite existing selections
  - Add: union with existing selections
- Selected profile should be recorded in:
  - `state/selections.env` (optional)
  - `state/runs/latest.env` (recommended, for replay)

### Minimal profiles to rely on
- `core`: Tier 1 baseline
- `infra_core`: Tier 1 baseline plus Terraform and Ansible

### Example (as implemented in this repo)
```yaml
profiles:
  core:
    name: "Core baseline"
    description: "Minimum tooling relied on across all environments"
    apps: ["curl", "jq", "yq", "openssh_client"]
```

## config/settings.env

### Purpose
Feature toggles and defaults.

Required keys:
- `dry_run=true|false`
- `replay_enabled=true|false`

Recommended keys:
- `ui_height`, `ui_width` (dialog sizing)
- `log_level=INFO|WARN|ERROR`

## config/validations.yml

### Purpose
Declarative validation gates. Commands must enforce relevant gates before performing mutating actions.

Minimum gates:
- proxmox_creds_present
- templates_present
- terraform_ready
- ansible_ready
- secrets_present (conditional)

## config/ui.yml

### Purpose
Defines default UI behaviour and standardises look and feel. Kept declarative to prevent command-level UI drift.

## State artefact contracts

### state/selections.env
- `SELECTED_APPS_INSTALL` (comma list)
- `SELECTED_APPS_UNINSTALL` (comma list)
- `SELECTED_PROFILE` (optional)

### state/proxmox.env
- `PROXMOX_API_URL`
- `PROXMOX_NODE`
- `PROXMOX_TOKEN_ID`
- `PROXMOX_TOKEN_SECRET` (secret)
- `PROXMOX_TLS_VERIFY` (optional)

### state/secrets.env
Key/value pairs. Must never be logged.

### state/runs/latest.env
Non-secret run contract used for replay and handoffs. Must not store token secrets.

### state/cache
- `cache/templates`: template artefacts and metadata
- `cache/terraform`: terraform working directory and provider cache
- `cache/repo`: optional clone cache

### state/logs
- One folder per RUN_ID.
- Must contain both console logs and step summary reports.
