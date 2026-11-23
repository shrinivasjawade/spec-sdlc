---
name: sdlc-standards
description: Team engineering standards, artifact locations and the Definition of Done for every SDLC phase. Loaded automatically into the SDLC subagents; also applies whenever writing or reviewing code in this project.
user-invocable: false
---

# Engineering standards (edit this file to match your team)

## Where things live
- Phase artifacts: `docs/sdlc/<feature-slug>/`
  - `01-requirements.md`, `02-design.md`, `03-test-report.md`,
    `04-code-review.md`, `05-security-review.md`, `06-release-notes.md`,
    `activity.log` (written by hooks)
- Current feature and phase: `docs/sdlc/current.json`
  (change it only through `bash .claude/scripts/sdlc.sh`)
- Templates: `sdlc/templates/`  (canonical, tool-neutral)

## Coding standards
- Follow the existing style of the file you are editing; consistency beats preference.
- Functions do one thing; aim for under 40 lines.
- Names describe intent: `calculateInvoiceTotal`, not `doCalc`.
- Validate all external input at the boundary (HTTP handlers, CLI args, file reads).
- Handle errors explicitly; never swallow an exception silently.
- No secrets in code or logs. Configuration comes from environment variables.
- No new dependency without a reason written in `02-design.md`.

## Spec-driven rules (the spec is the source of truth)
- `01-requirements.md` is the **spec**. Nothing gets designed, built or tested that
  is not traceable to a requirement ID in it.
- Acceptance criteria are written in **EARS** form (WHEN/IF/WHILE/WHERE ... the
  system SHALL ...) and carry stable IDs (`AC-1.1`); non-functional requirements
  carry `NFR-*` IDs. IDs are never reused or renumbered once approved.
- The design's traceability table must cover every `AC-*` and `NFR-*`. Tests are
  named so their AC-* is identifiable. Changing behaviour means changing the spec
  first, then the design, then the code.
- Change control: a material change to an approved spec re-opens Gate 1; a change to
  an approved design re-opens Gate 2. Re-run `verify`/`trace` after any such edit.
- Verification is independent: the agent that wrote the code does not sign off its
  own correctness — the verifier (fresh context) and the reviewers do.

## Testing standards
- Every acceptance criterion (`AC-*`) has at least one automated test.
- Tests are independent, deterministic and named after the behaviour they check:
  `returns 401 when token is expired`.
- Bug fixes start with a failing test that reproduces the bug.

## Definition of Done per phase
| Phase        | Done when                                                                 |
|--------------|---------------------------------------------------------------------------|
| requirements | Spec with REQ/AC/NFR IDs, EARS acceptance criteria, open questions answered, user approved |
| design       | Change plan + ordered task checklist + traceability covering every AC/NFR, user approved |
| implement    | All tasks ticked, full test suite green, lint clean                       |
| test         | Test matrix covered, report says PASS, no open Critical/High bugs          |
| review       | No open Critical/High findings in code or security review                 |
| release      | CHANGELOG updated, release notes + PR description + rollback plan written |

## Commit message format (Conventional Commits)
`feat(scope): summary`, `fix(scope): summary`, `test: ...`, `docs: ...`, `refactor: ...`
