# Contribution workflow

Last updated: 2026-01-30

## Branching
- main: stable
- feature/*: one feature or command per branch

## Development rules
- Docs first: update specs before behaviour
- Every changed file follows the developer header standard (see `development-standards.md`)
- One command or module per PR
- Follow Definition of Done strictly

## Pull request checklist
- [ ] Specs updated (if behaviour changed)
- [ ] DoD satisfied
- [ ] Demo script executed
- [ ] No secrets committed
- [ ] Logs and summaries verified

## Review expectations
- Behaviour matches specs
- No UI drift
- Replay and dry run unaffected
