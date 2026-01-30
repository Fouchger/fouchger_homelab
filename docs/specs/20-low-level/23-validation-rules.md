# Validation rules and gate checks

Last updated: 2026-01-30

## Purpose
Make `config/validations.yml` gates unambiguous by defining exact checks, required keys, and remediation guidance.

Implementers must ensure `lib/validation.sh` enforces these checks consistently and returns standard exit codes.

## Standard check types
- file_exists(path)
- dir_exists(path)
- dir_writable(path)
- command_exists(name)
- env_file_has_keys(path, keys[])
- file_nonempty(path)
- yaml_key_exists(path, keypath)
- json_key_exists(path, keypath)

## Gate definitions (normative)

### Gate: proxmox_creds_present
**Intent**: Prevent Proxmox-dependent steps running without credentials.

Checks:
1. file_exists(`state/proxmox.env`)
2. env_file_has_keys(`state/proxmox.env`, [
   `PROXMOX_API_URL`, `PROXMOX_NODE`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET`
])

Remediation text:
- “Run ‘Proxmox access’ first to create and store API credentials.”

Failure class: Recoverable

### Gate: secrets_present (conditional)
**Intent**: Ensure required secrets for selected apps exist.

Checks:
1. If any selected app declares `requires.secrets`, then:
   - file_exists(`state/secrets.env`)
   - env_file_has_keys(`state/secrets.env`, required_secret_keys)

Remediation text:
- “Create `state/secrets.env` (from config/secrets.env.example) and set required keys.”

Failure class: Recoverable

### Gate: templates_present
**Intent**: Prevent Terraform from building VMs/LXCs without required templates.

Checks:
1. dir_exists(`state/cache/templates`)
2. file_nonempty(`state/cache/templates/manifest.json`) OR file_nonempty(`state/cache/templates/manifest.yml`)
3. manifest contains:
   - ubuntu template reference (id or path)
   - talos template reference (id or path)
4. referenced template files exist in templates dir

Remediation text:
- “Run ‘Templates’ to download and cache Ubuntu and Talos templates.”

Failure class: Recoverable

### Gate: terraform_ready
**Intent**: Ensure terraform can run with correct project structure.

Checks:
1. dir_exists(`proxmox/terraform`)
2. file_exists(`proxmox/terraform/main.tf`)
3. dir_writable(`state/cache/terraform`)
4. command_exists(`terraform`)
5. If `config/settings.env` sets a required version policy later, validate it here.

Remediation text:
- “Install terraform (Apps → infra_core) and ensure state/cache/terraform is writable.”

Failure class: Recoverable

### Gate: ansible_ready
**Intent**: Ensure Ansible can run and inventories exist.

Checks:
1. dir_exists(`proxmox/ansible`)
2. file_exists(`proxmox/ansible/ansible.cfg`)
3. dir_exists(`proxmox/ansible/inventory`)
4. file_exists(`proxmox/ansible/playbooks/site.yml`)
5. command_exists(`ansible-playbook`)

Remediation text:
- “Install ansible (Apps → infra_core) and ensure proxmox/ansible is present.”

Failure class: Recoverable

## Gate execution behaviour
- Commands must call gates before any mutating action.
- Diagnostics must run gates in report mode (never blocks).
- Gate failures must produce:
  - UI dialog with remediation
  - log entry in console.log
  - summary.json entry under steps.validating

## Standard exit codes
- 0: pass
- 10: recoverable validation failure
- 20: fatal validation failure (reserved)
