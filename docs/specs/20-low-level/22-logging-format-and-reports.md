# Logging format and report templates

Last updated: 2026-01-30

## Purpose
Define mandatory log structure and report content so troubleshooting and replay are deterministic.

## Directory structure
Each run creates a directory:
- `state/logs/<RUN_ID>/`

Mandatory files:
- `state/logs/<RUN_ID>/console.log` (combined stdout/stderr capture)
- `state/logs/<RUN_ID>/summary.json` (structured summary)
- `state/logs/<RUN_ID>/summary.md` (human readable)

Optional per-tool files (recommended):
- `terraform.plan.txt`
- `terraform.apply.txt`
- `terraform.outputs.json` (copy or link to working dir outputs)
- `ansible.log`
- `validation.report.json`

## Naming conventions
- RUN_ID format: `YYYYMMDD-HHMMSS-<4hex>` (example: `20260130-214455-a3f2`)
- All reports must include RUN_ID in content as well as path.

## summary.json schema (mandatory)
```json
{
  "run_id": "20260130-214455-a3f2",
  "timestamp": "2026-01-30T21:44:55+13:00",
  "command": "terraform_apply",
  "dry_run": false,
  "state": "COMPLETED",
  "steps": [
    {
      "name": "validating",
      "status": "PASS",
      "gates": ["proxmox_creds_present", "templates_present", "terraform_ready"]
    },
    {
      "name": "terraform_apply",
      "status": "PASS",
      "artefacts": {
        "terraform_workdir": "state/cache/terraform",
        "outputs_json": "state/cache/terraform/outputs.json"
      }
    }
  ],
  "warnings": [],
  "errors": []
}
```

## summary.md template (mandatory)
The markdown summary must include:
1. Run metadata (RUN_ID, timestamp, command, DRY_RUN)
2. Gate results
3. Actions taken (or would take, in dry run)
4. Artefacts produced (paths)
5. Outcome and next suggested action

## Log event format in console.log
Every log line emitted by commands and modules should follow:
`[LEVEL] <component>: <message>`

Examples:
- `[INFO] runtime: initialising run`
- `[WARN] validation: missing optional secret FOO_API_KEY`
- `[ERROR] terraform: apply failed (exit=1)`

## Mandatory logging behaviours
- Start-of-run banner written to console.log
- Validation results written before execution
- End-of-run banner with status code written at end
- On failure:
  - log the remediation hint
  - include pointers to relevant tool outputs

## UI integration rule
After every command completes, UI must show a message containing:
- Outcome (success/failure)
- RUN_ID
- Log path `state/logs/<RUN_ID>/`

This keeps the operator loop tight and reduces support overhead.
