# Configuration and state schema

## config/apps.yml
Defines apps with id, name, description, install/uninstall module paths, and optional requirements (packages, commands, secrets).

### Purpose

Defines the authoritative list of applications that can be installed or uninstalled by the system.
This file is pure metadata. It must not contain logic.

Every app defined here must map to:
- one install module
- one uninstall module (optional but strongly recommended)

### Design principles

- Stable app IDs (never rename casually)
- Declarative dependencies and requirements
- No environment-specific values
- Safe to read during dry run and diagnostics

### Schema (canonical)
```yml
apps:
  <app_id>:
    name: "<Human readable name>"
    description: "<Short description shown in UI>"
    category: "<optional grouping, e.g. container, monitoring, network>"
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
| Field               | Required | Description                                       |
| ------------------- | -------- | ------------------------------------------------- |
| `app_id`            | yes      | Stable, lowercase identifier. Used everywhere.    |
| `name`              | yes      | Display name in dialog UI.                        |
| `description`       | yes      | One-line description shown in selection lists.    |
| `category`          | no       | Used for grouping or filtering in UI later.       |
| `install.module`    | yes      | Relative path to install script.                  |
| `uninstall.module`  | no       | Relative path to uninstall script.                |
| `requires.packages` | no       | OS packages expected to exist or be installable.  |
| `requires.commands` | no       | Commands expected post-install (validation only). |
| `requires.secrets`  | no       | Keys that must exist in `state/secrets.env`.      |
| `conflicts`         | no       | Apps that cannot be installed together.           |
| `provides`          | no       | Capability tags (e.g. `container_runtime`).       |
| `default_selected`  | no       | Pre-selected in manual install UI.                |
| `version`           | optional | Version to install erse latest.                   |


### Behavioural rules

- If install.module does not exist → hard failure.
- If a required secret is missing:
    - dry run → warn + plan report
    - live run → block execution
- conflicts are enforced at selection time, not execution time.
- Ordering is alphabetical by app_id unless dependency ordering is introduced later.

### Example

```yml
apps:
  docker:
    name: Docker Engine
    description: Container runtime for local workloads
    category: container
    install:
      module: modules/apps/install/docker.sh
    uninstall:
      module: modules/apps/uninstall/docker.sh
    requires:
      packages:
        - ca-certificates
        - curl
      commands:
        - docker
    provides:
      - container_runtime
    default_selected: true

  portainer:
    name: Portainer
    description: Web UI for Docker management
    category: container
    install:
      module: modules/apps/install/portainer.sh
    uninstall:
      module: modules/apps/uninstall/portainer.sh
    requires:
      commands:
        - docker
    conflicts: []
```

## config/profiles.yml
Defines profiles with id, name, description, and app lists. Supports Replace and Add semantics.

### Purpose

Defines curated bundles of apps that represent common use cases.
Profiles are composition only. They do not override app behaviour.

### Design principles

- Profiles never define logic
- Profiles reference apps by ID only
- Profiles must be safe to replay
- Profiles do not store environment-specific data

### Schema (canonical)

```yml
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

### Field definitions
| Field         | Required | Description                                 |
| ------------- | -------- | ------------------------------------------- |
| `profile_id`  | yes      | Stable identifier used in state and replay. |
| `name`        | yes      | Display name in UI.                         |
| `description` | yes      | Shown in profile selection screen.          |
| `apps`        | yes      | List of app IDs (must exist in apps.yml).   |
| `tags`        | no       | Informational only (e.g. `infra`, `dev`).   |

### Behavioural rules

- All apps must exist in config/apps.yml.
- Profile selection triggers a merge or replace decision:
    - Replace → overwrite state/selections.env
    - Add → union with existing selections
- Profiles do not bypass conflicts or validations.
- Selected profile ID is recorded in state/runs/latest.env.

### Example

```yml
profiles:
  basic:
    name: Basic homelab
    description: Minimal tools for a fresh homelab
    apps:
      - docker
      - portainer
    tags:
      - baseline

  development:
    name: Development workstation
    description: Tools for local development and testing
    apps:
      - docker
      - portainer
      - kind
    tags:
      - dev

  proxmox_admin:
    name: Proxmox administrator
    description: Tooling for managing Proxmox and workloads
    apps:
      - docker
      - terraform
      - ansible
    tags:
      - infra
```

### Cross-file guarantees (important)

These definitions are deliberately aligned with:
- `commands/profiles.sh`
Only merges and persists app IDs, never logic.
- `commands/apps_install.sh` / `apps_uninstall.sh`
Consume app IDs and resolve module paths via `apps.yml`.
- `config/validations.yml`
Enforces secrets and prerequisites declared in `apps.yml`.
- `state/runs/latest.env`
Records selected profile and resolved app lists for replay.

No other file should need to “guess” behaviour.

## config/settings.env
Defines dry_run and replay_enabled.

## state/runs/latest.env
Non-secret run contract used for replay and handoffs.
