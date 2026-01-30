# Security and secrets specification

## Principles
- Secrets must never be committed to git.
- Secrets must never be printed to the console, written to logs, or persisted in
  convenience pointers such as `state/runs/latest.env`.
- Secret handling must be explicit: a command must opt in to loading secrets.

## Authoritative locations
- `state/secrets.env` is the single authoritative secrets file used by runtime
  code. It is gitignored and should be `chmod 600`.
- `state/proxmox.env` stores Proxmox connection settings. It may contain secrets
  depending on the auth mode used; treat it with the same permissions.
- `config/secrets.env.example` and `config/proxmox.env.example` are templates
  only and must not be sourced.

## Loading rules
- The runtime must not automatically source any secrets.
- Non-secret settings are loaded from `config/settings.env` and optional
  `config/local.env` only.
- Secrets are loaded only by calling `secrets_load` from `lib/secrets.sh`, which
  sources `state/secrets.env`.

## Command responsibilities
Any command requiring secrets must:
1. Call `secrets_load` before using secret variables.
2. Validate presence with `secrets_require VAR1 VAR2 ...`.
3. Fail safely if missing (clear message, no value output).
4. Never echo secret values (logger redaction is an additional safeguard, not a
   primary control).

## Log redaction and leak detection
- The logger redacts common secret patterns and registered literal values.
- `secrets_load` registers secret-like env values with the logger’s redaction
  list.
- Validation includes a post-run scan that checks the log for any secret values
  sourced from the environment or `state/secrets.env`.

## Permissions
- `state/` should be user-only readable and writable where practical.
- `state/secrets.env` and `state/proxmox.env` should be `chmod 600`.

## Future hardening (planned)
- Support prompting for secrets via dialog when missing, with secure in-memory
  handling.
- Support external secret managers (1Password CLI, Bitwarden, Vault) behind the
  same `lib/secrets.sh` interface.
