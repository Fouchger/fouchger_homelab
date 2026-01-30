# Extending – adding apps, commands, and infrastructure steps

## Purpose
This document explains how to extend the system safely without breaking consistency, traceability, or replayability.

## Design rules
- Every menu option must map to exactly one script in `commands/`.
- Every command must source the shared runtime baseline:
  - lib/runtime.sh
  - lib/logger.sh
  - lib/ui_dialog.sh
  - lib/env.sh
  - lib/config.sh
  - lib/validation.sh
- No command may silently skip validation gates.
- No secrets may be written to logs or state/runs/latest.env.
- All new behaviour must be expressible in dry run mode.

## Add a new app
1. Add an entry to `config/apps.yml`.
2. Create module scripts:
   - modules/apps/install/<app>.sh
   - modules/apps/uninstall/<app>.sh
3. Ensure idempotency and non-interactive execution.
4. Ensure logging via lib/logger.sh, with no secrets.

## Add a new profile
1. Update config/profiles.yml with id, label, apps.
2. Ensure merge/replace behaviour remains consistent in commands/profiles.sh.

## Add a new menu option (command)
1. Create a new file under commands/.
2. Add routing from commands/menu.sh.
3. Declare and enforce validation gates.
4. Implement DRY_RUN preview + report path.
5. Publish outputs to state/runs/latest.env (non-secret).

## Add a new infrastructure step
1. Create backend implementation.
2. Create orchestrator command.
3. Define and document handoffs in latest.env and logs.
4. Update validation matrix and diagrams where the pipeline changes.
