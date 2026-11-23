# Release notes: <Feature name>

**Slug:** `<slug>`  **Readiness:** READY | BLOCKED  **Date:** YYYY-MM-DD
**Proposed version bump:** major | minor | patch — <reason>

## Readiness checklist
- [ ] All tasks in 02-design.md ticked
- [ ] 03-test-report.md: PASS
- [ ] No open Critical/High in 04-code-review.md
- [ ] No open Critical/High in 05-security-review.md
- [ ] Final test run + build green: `<command>`
- [ ] CHANGELOG.md updated

## What changed (user-facing)
- ...

## Deployment notes
Migrations, new environment variables, feature flags, order of steps.

## Rollback plan
How to undo this release safely (revert commit, down-migration, flag off).

## Pull request
**Title:** `feat(<scope>): <summary>`

**Description:**
```
## What
## Why
## How to test
## Links
- Requirements: docs/sdlc/<slug>/01-requirements.md
- Design: docs/sdlc/<slug>/02-design.md
```

## Commands for the human to run
```bash
git checkout -b feat/<slug>
git add -A && git commit -m "feat(<scope>): <summary>"
git push -u origin feat/<slug>
gh pr create --fill
```
