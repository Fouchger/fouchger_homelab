# Dialog UX specification (screen-by-screen)

Last updated: 2026-01-30

## Purpose
Define predictable, consistent UI flows using `dialog`. This removes ambiguity and prevents “UI drift” across commands.

## Global UX rules
- All screens use wrappers from `lib/ui_dialog.sh`.
- Default buttons:
  - OK = proceed
  - Cancel = abort current action and return to menu
  - Back = return to previous screen (only where multi-step flows exist)
- Every completed action ends with a result message including RUN_ID and log path.
- On validation failure, show:
  - what failed
  - why it matters
  - exact remediation steps

## Top-level menu (commands/menu.sh)
Options (order fixed):
1. Profiles
2. Apps
3. Proxmox access
4. Templates
5. Terraform provision
6. Ansible configure
7. Diagnostics
8. Replay last run (only if replay_enabled=true)
9. Exit

Selection behaviour:
- on selection, create RUN_ID and write latest.env INIT state
- call the corresponding command
- return to menu afterwards

## Profiles flow (commands/profiles.sh)
Screen 1: Profile selector (radiolist)
- Show name + short description.

Screen 2: Merge semantics
- Choices: Replace existing selections, Add to existing selections

Screen 3: Confirmation
- Show resulting app list (sorted)
- OK proceeds to persist selections
- Cancel returns to menu without changes

Success screen:
- “Profile applied” + selected profile + log path

Failure cases:
- Profile references unknown app IDs: show list and remediation (“update apps.yml or profile”)

## Apps flow (commands/apps_install.sh / apps_uninstall.sh)
Screen 1: Choose Install vs Uninstall
- Two buttons or a menu entry branching.

Screen 2: App checklist
- List apps with description.
- Pre-select apps where `default_selected=true` (install screen only).

Screen 3: Conflict check results
- If conflicts exist, show conflict pairs and block until resolved.

Screen 4: Summary
- Show selected apps
- Show DRY_RUN mode if enabled
- OK executes, Cancel returns

Execution progress:
- Use an infobox or gauge that updates per app if feasible.
- Always write per-app output to logs.

Result screen:
- Success/failure summary + RUN_ID + log path
- On failure, show the failing app and the last 10 lines hint (optional)

## Proxmox access flow (commands/proxmox_access.sh)
Screen 1: Current status
- Show whether proxmox.env exists (without secret)
- Show API URL and token ID if present

Screen 2: Data entry (if missing)
- API URL
- Node
- Token ID
- Token secret (password box)
- TLS verify toggle

Screen 3: Confirmation of actions
- Describe what will be created or validated

Result screen:
- Success/failure + remediation pointers

## Templates flow (commands/templates.sh)
Screen 1: Cache status
- Show whether manifest exists
- Show ubuntu/talos filenames and timestamps if available

Screen 2: Action menu
- Download/refresh Ubuntu
- Download/refresh Talos
- Download/refresh both
- Clear cache (confirmation required)

Result screen:
- Success/failure + updated manifest path

## Terraform flow (commands/terraform_apply.sh)
Screen 1: Readiness summary
- Gate results: proxmox_creds_present, templates_present, terraform_ready

Screen 2: Action choice
- Plan
- Apply (disabled or hidden when DRY_RUN=true)

Screen 3: Confirmation
- Show workdir and what will happen

Result screen:
- Success/failure + outputs.json path if produced

## Ansible flow (commands/ansible_apply.sh)
Screen 1: Inventory summary
- Show inventory path selected
- Show hosts/groups count if you can

Screen 2: Playbook selection
- site.yml
- base.yml only
- k8s_talos.yml (if present)

Screen 3: Confirmation
- Show DRY_RUN behaviour (syntax/check vs apply)

Result screen:
- Success/failure + ansible.log path

## Diagnostics flow (commands/diagnostics.sh)
Screen 1: Gate report
- Show all gates pass/fail with remediation hints
- Show last run summary from latest.env

Options:
- View latest logs (tail console.log)
- Export diagnostics report (writes into logs)

## Replay flow
Screen 1: Show last run
- profile, apps, DRY_RUN, last step, run timestamp

Screen 2: Choose mode
- Replay from start
- Resume from last step

Screen 3: Confirmation
- Show which steps will run

Result screen:
- Success/failure + RUN_ID + log path

This UX spec ensures a single “house style” and reduces operator errors.
