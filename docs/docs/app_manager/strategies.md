# App Manager Strategies

## Purpose
The App Manager catalogue uses a `strategy` field to describe how an app should be installed and uninstalled. Strategies exist so we can keep the questionnaire simple while making installer behaviour consistent, supportable, and easy to extend.

## Design principles
1. Idempotent by default: running install twice should not break the system.
2. Use vendor-supported install paths where practical (repos for long-lived tooling, pinned binaries where version control matters).
3. Prefer `/etc/apt/keyrings` + signed-by for third-party APT repositories.
4. Uninstall should be as clean as possible without being destructive (avoid deleting user data unless explicitly requested).

## Catalogue fields the strategies use
Each `APP|...` record provides:
- `key`: internal identifier
- `packages_csv`: comma-separated package list (may be blank for non-APT strategies)
- `strategy`: one of the strategies defined below
- `version_var`: optional env var used to pin a version (primarily for binary strategies)

---

# Strategy: apt

## When to use
Anything installable via Ubuntu repositories with a straight APT workflow.

## Inputs
- `packages_csv` (required)

## Install behaviour
- `apt-get update`
- `apt-get install -y <packages...>`

## Uninstall behaviour
- `apt-get remove -y <packages...>`
- Optional: `apt-get purge -y <packages...>` (only if you want to remove config)
- Optional: `apt-get autoremove -y`

## Notes
Use this for core tooling: ssh client/server, git, jq, nmap, lvm2, nfs-common, etc.

---

# Strategy: github_cli_repo

## When to use
GitHub CLI (`gh`) via GitHub’s supported APT repository approach.

## Inputs
- `packages_csv` (usually `gh`)

## Install behaviour
1. Ensure prerequisites: `ca-certificates`, `curl`, `gnupg`
2. Add repository key into `/etc/apt/keyrings/`
3. Add repo file under `/etc/apt/sources.list.d/`
4. `apt-get update`
5. `apt-get install -y gh`

## Uninstall behaviour
- `apt-get remove -y gh`
- Remove repo file and keyring if nothing else uses them:
  - `/etc/apt/sources.list.d/github-cli.list` (name can be standardised)
  - `/etc/apt/keyrings/githubcli-archive-keyring.gpg` (name can be standardised)

## Notes
GitHub documentation points users to the GitHub CLI repository for installation options. :contentReference[oaicite:0]{index=0}

---

# Strategy: hashicorp_repo

## When to use
HashiCorp tooling via HashiCorp’s APT repository (Terraform, Packer, Vault).

## Inputs
- `packages_csv` (e.g. `terraform` or `packer` or `vault`)
- Optional `version_var` if you later implement pinning by version (APT pinning)

## Install behaviour
1. Ensure prerequisites: `gpg`, `wget`
2. Add HashiCorp keyring:
   - `/usr/share/keyrings/hashicorp-archive-keyring.gpg`
3. Add repo:
   - `/etc/apt/sources.list.d/hashicorp.list`
4. `apt-get update`
5. `apt-get install -y <package>`

## Uninstall behaviour
- `apt-get remove -y <package>`
- Optional cleanup:
  - `/etc/apt/sources.list.d/hashicorp.list`
  - `/usr/share/keyrings/hashicorp-archive-keyring.gpg`

## Notes
HashiCorp provides explicit Ubuntu/Debian repository steps for Terraform (same repo pattern applies across their tools). :contentReference[oaicite:1]{index=1}

---

# Strategy: docker_apt_repo

## When to use
Docker Engine installed via Docker’s official APT repository, with Compose v2 and Buildx plugins.

## Inputs
- `packages_csv` typically:
  - `docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin`

## Install behaviour
1. Remove conflicting/unofficial packages if present (as per Docker guidance)
2. Add Docker APT keyring into `/etc/apt/keyrings/`
3. Add Docker repo in `/etc/apt/sources.list.d/docker.list`
4. `apt-get update`
5. `apt-get install -y <packages...>`

## Uninstall behaviour
- `apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
- Optional: remove repo file and keyring
- Optional (explicitly user-approved): remove `/var/lib/docker` and `/var/lib/containerd` to wipe data

## Notes
Docker documents multiple installation methods and includes official steps for Ubuntu via their APT repo, as well as package conflict guidance. :contentReference[oaicite:2]{index=2}

---

# Strategy: grafana_repo

## When to use
Grafana Alloy installed via Grafana’s APT repository.

## Inputs
- `packages_csv` typically: `alloy`

## Install behaviour
1. Ensure prerequisites: `gpg` (Grafana notes some Debian-based VMs lack it)
2. Add Grafana keyring into `/etc/apt/keyrings/`
3. Add Grafana repo in `/etc/apt/sources.list.d/grafana.list`
4. `apt-get update`
5. `apt-get install -y alloy`

## Uninstall behaviour
- `apt-get remove -y alloy`
- Optional: remove repo file and keyring

## Notes
Grafana provides repo-based installation steps for Alloy on Linux. :contentReference[oaicite:3]{index=3}

---

# Strategy: mongodb_repo

## When to use
MongoDB Community Edition installed via MongoDB’s official APT repository (using `mongodb-org` meta-package).

## Inputs
- `packages_csv` typically: `mongodb-org`
- `version_var` typically: `MONGODB_SERIES` (used to choose repo line series)

## Install behaviour
1. Import MongoDB GPG key
2. Add MongoDB repo under `/etc/apt/sources.list.d/`
3. `apt-get update`
4. `apt-get install -y mongodb-org`

## Uninstall behaviour
- `apt-get remove -y mongodb-org`
- Optional: remove repo file and keyring
- Optional (explicitly user-approved): remove MongoDB data directories

## Notes
MongoDB documents installing MongoDB Community Edition on Ubuntu using APT and the `mongodb-org` package set. :contentReference[oaicite:4]{index=4}

---

# Strategy: binary

## When to use
Tools where the upstream provides official binaries and you want deterministic version pinning (good for kubectl and Helm).

## Inputs
- `version_var` (recommended)
- `key` used to determine binary name and download URL logic
- `packages_csv` is blank

## Install behaviour (generic)
1. Determine OS/ARCH
2. Resolve version:
   - if `version_var` set, use that
   - else default to vendor “latest stable” path (where available)
3. Download binary to a temp path
4. Verify integrity where vendor provides a straightforward mechanism (checksums/signatures)
5. Install to `/usr/local/bin/<name>` and `chmod +x`
6. Validate: `<name> version --client` or equivalent

## Uninstall behaviour
- Remove `/usr/local/bin/<name>`

## Notes
- Kubernetes documents installing `kubectl` via direct binary download (including how to pick latest or a specific version). :contentReference[oaicite:5]{index=5}
- Helm documents official binary release installation methods and provides a supported install approach. :contentReference[oaicite:6]{index=6}

---

# Strategy: yq_binary

## When to use
`yq` is commonly installed as a single, dependency-free binary from upstream releases.

## Inputs
- `version_var` (recommended): `YQ_VERSION`

## Install behaviour
- Download the correct `yq` binary for OS/ARCH
- Install to `/usr/local/bin/yq`, `chmod +x`
- Validate: `yq --version`

## Uninstall behaviour
- Remove `/usr/local/bin/yq`

## Notes
The yq project explicitly supports downloading a dependency-free binary for your platform. :contentReference[oaicite:7]{index=7}

---

# Strategy: sops_binary

## When to use
`sops` is commonly installed via pre-built binaries from GitHub releases, with optional integrity verification.

## Inputs
- `version_var` (recommended): `SOPS_VERSION`

## Install behaviour
- Download `sops-<version>.<platform>` from releases
- Optional: verify checksums/signature where implemented
- Install to `/usr/local/bin/sops`, `chmod +x`
- Validate: `sops --version`

## Uninstall behaviour
- Remove `/usr/local/bin/sops`

## Notes
The sops project publishes pre-built binaries in GitHub releases and provides guidance for verifying release artefacts. :contentReference[oaicite:8]{index=8}

---

# Strategy: python

## When to use
Python runtime/tooling where base packages may be APT, but you also want consistent tooling via `pipx` (and potentially pinned Python versions later).

## Inputs
- `packages_csv` typically includes: `python3,python3-venv,python3-pip,pipx`
- Optional `version_var`: `PYTHON_TARGET` (only relevant if you later implement a version manager workflow)

## Install behaviour (baseline)
- Install APT packages
- Ensure pipx path is configured (system-wide guidance varies; align to your project standard)
- Optionally install a curated set of pipx tools (future enhancement)

## Uninstall behaviour
- Remove APT packages (note: removing python3 on Ubuntu can be disruptive; consider only removing pipx + extras)
- Optional: remove pipx-installed tools

## Notes
Keep this strategy conservative to avoid breaking the base OS.

---

# Strategy: nvm

## When to use
Node.js via NVM (per-user), where installing node system-wide is not desired.

## Inputs
- Optional env var: `NVM_NODE_VERSION` (e.g. `lts/*` or `v22.x.y`)
- `packages_csv` blank

## Install behaviour
1. Ensure prerequisites: `curl` or `wget`
2. Install NVM into the target user’s home directory
3. Load NVM in the user’s shell profile
4. Install Node version:
   - if `NVM_NODE_VERSION` set, use it
   - else install `lts/*`
5. Optionally set default alias: `nvm alias default <version>`

## Uninstall behaviour
- Remove NVM directory (usually `~/.nvm`)
- Remove NVM init lines from shell profile files (carefully, only what we added)

## Notes
NVM is a bash-based version manager designed to install and manage Node per user. :contentReference[oaicite:9]{index=9}

---

## Strategy naming conventions
- Prefer `*_repo` for vendor-managed APT repositories.
- Prefer `*_binary` for GitHub-release-driven binary downloads.
- Keep `apt` reserved for pure Ubuntu repo installs.

## Recommended implementation interface (for your bash functions)
Each strategy handler should accept:
- `app_key`
- `packages_csv`
- `version_var_name` and resolved `version_value`
- `mode`: `install` or `uninstall`

And it should return:
- `0` success
- non-zero failure with a clear message suitable for `dialog` display
