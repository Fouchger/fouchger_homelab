# Development standards

Last updated: 2026-01-30

This document sets the development standards for the **fouchger_homelab** repo. It is the reference for how we write, structure, and review changes so the project stays predictable, safe, and easy to extend.

## Outcomes we are optimising for
- Consistent user experience across all menu flows (single look and feel)
- Repeatable automation (dry run, replay, validation gates)
- Supportable operations (clear logs, easy diagnostics, safe state management)
- Low-friction contribution (small changes, clear contracts, strong defaults)

## Non-negotiables
1. **Docs first**: update or add specs before behaviour changes.
2. **No secrets in git**: never commit tokens, passwords, private keys, or real endpoints.
3. **Every file has a developer header**: use the templates below and keep them current.
4. **Single source of truth**: config lives in `config/`, runtime state lives in `state/`.
5. **UI consistency**: all dialog UX goes through the shared UI helper library.
6. **Idempotent where practical**: safe to re-run without unintended side effects.
7. **Fail fast with a helpful message**: validation before execution, clear remediation hints.

## File header standards

### Shell scripts (`*.sh`)
Place this at the very top of the file, before logic:

```bash
#!/usr/bin/env bash
# ==============================================================================
# File: <relative/path/to/file.sh>
# Created: YYYY-MM-DD
# Updated: YYYY-MM-DD
# Description: <one paragraph overview of what this file contains>
# Purpose: <why this exists and what outcome it delivers>
# Usage: <common invocations and examples>
# Prerequisites: <packages, environment variables, required files, permissions>
# Notes:
# - <operational notes, safety warnings, assumptions>
# - <interfaces/contract references, e.g. docs/specs/05-menu-and-command-contracts.md>
# ==============================================================================
```

Guidance:
- **Updated** must change whenever behaviour changes.
- Keep **Usage** actionable and copy-paste friendly.
- **Prerequisites** should include minimum OS support when relevant.

### Markdown (`*.md`)
Add a front-matter style header under the title:

```markdown
# <Title>

Last updated: YYYY-MM-DD

## Purpose
<why this document exists>

## Audience
<who should read it>

## Scope
<what is and is not covered>
```

### YAML (`*.yml`, `*.yaml`)
YAML has no native comments in all tooling contexts, but in our repo we will use a short comment header at the top:

```yaml
# ==============================================================================
# File: <relative/path/to/file.yml>
# Created: YYYY-MM-DD
# Updated: YYYY-MM-DD
# Description: <what the config expresses>
# Purpose: <why it exists>
# Usage: <where it is read from>
# Prerequisites: <dependencies, required keys, validation rules>
# ==============================================================================
```

## Shell coding standards

### Baseline practices
- Use `#!/usr/bin/env bash` and target Bash 4+ features only when required.
- Prefer `set -euo pipefail` for command-style scripts. For menu flows, be deliberate: avoid surprising exits that break dialog; trap and handle errors through the shared error pathway.
- Quote variables unless you explicitly want word splitting.
- Use `readonly` for constants.
- Prefer arrays over string concatenation for command building.
- Use functions with clear inputs and outputs. Keep functions small.

### Naming
- Functions: `snake_case` (example: `init_logging`, `ui_confirm`).
- Constants: `UPPER_SNAKE_CASE`.
- Local variables: `lower_snake_case`.
- Avoid ambiguous names like `tmp`, `data`, `value` unless the scope is tiny.

### Error handling and exit codes
- Validate inputs early, return a non-zero exit code for failure, and write a user-friendly message.
- Map failures to a small set of predictable exit codes where it helps operations.
- If a command is invoked from dialog, ensure errors are shown in a way that the user can action (and logged).

### Logging, colour, and emojis
- All user-facing output must go through the logging helpers (so it remains consistent whether launched from terminal or via dialog).
- Use emojis and colour sparingly to increase scan-ability, not to decorate.
- Colour must degrade gracefully:
  - Disable colour when not running in a TTY.
  - Provide a no-colour mode for logs captured by dialog.
- Never rely on colour alone to convey meaning (include text labels).

### Dialog and UX standards
- All dialog widgets and theming must be via `bin/lib/ui.sh` (no direct `dialog` calls in command scripts).
- Keep prompts short and plain English, with NZ spelling.
- Provide defaults and safe options.
- Where destructive actions exist (uninstall, cleanup, state reset), require explicit confirmation.

### Config and state
- Treat `config/` as declarative inputs.
- Treat `state/` as runtime outputs (logs, selections, caches, exports).
- Command scripts must never silently mutate config without user consent.
- If you write to state, do it atomically where practical (write temp then move).

### Security
- Prefer tokens and secrets via environment variables or local state files excluded by `.gitignore`.
- Avoid echoing secrets into logs, dialog text, or command history.
- If a secret must be written to disk, set restrictive permissions (0600).

## Documentation and specs standards
- Specs are normative. Implementation must match specs or update the spec.
- When adding a new command:
  - Add or update the relevant spec in `docs/specs/`.
  - Update `docs/specs/00-index.md` if you add a new spec.
  - Add acceptance criteria and a demo script step.

## Quality gates
- Run `shellcheck` on changed shell files where feasible.
- Keep changes small and testable per sprint. If a change cannot be demoed, it is not done.
- Ensure dry run and replay behaviour remains intact when adding new execution steps.

## Innovation lane
We encourage practical innovation when it improves user outcomes:
- Add “smart defaults” driven by lightweight host discovery (while keeping a manual override).
- Offer “plan view” previews before execution (especially for Terraform and Proxmox changes).
- Consider an “export runbook” feature that turns a successful run into a short operations runbook (inputs, outputs, versions, key decisions).

---
If this standard conflicts with an approved ADR, the ADR takes precedence. If it conflicts with a spec, update the spec or raise a new ADR.
