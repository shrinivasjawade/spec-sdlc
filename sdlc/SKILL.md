---
name: spec-driven-sdlc
description: Vendor-neutral spec-driven SDLC. Build every feature as spec -> design -> implement -> test -> review -> release, with stable requirement IDs, EARS acceptance criteria, end-to-end traceability, independent verification, governance metrics, and three human approval gates. Works with any AI coding tool.
---

# Spec-driven SDLC (tool-neutral skill)

This skill defines **how features are built here**, independent of tool. The full
process and guard rails are in [`PROCESS.md`](./PROCESS.md); this is the operating
summary any agent must follow.

## The six phases and three gates
`spec → design → implement → test → review → release`

1. **Spec** → `docs/sdlc/<slug>/01-requirements.md`. Requirements with stable IDs
   (`REQ-1`, `AC-1.1`, `NFR-1`) and acceptance criteria in **EARS** ("WHEN … the
   system SHALL …"). **Gate 1:** a human approves before any design.
2. **Design** → `docs/sdlc/<slug>/02-design.md`. Change plan, ordered task list,
   and a traceability table covering **every** `AC-*`/`NFR-*`. Validate with
   `bash sdlc/scripts/sdlc.sh verify <slug>`. **Gate 2:** a human approves.
3. **Implement** task by task with TDD; name each test after the `AC-*` it covers.
4. **Test** → `03-test-report.md`. Edge cases; every `AC-*` has a real test.
5. **Review** → code review + security audit + an **independent verifier** (a fresh
   context that did not write the code) checking the implementation against the spec.
6. **Release** → `06-release-notes.md`, changelog, PR text, rollback. **Gate 3:** a
   human approves. **Never push, deploy, or publish autonomously — a human does.**

## Non-negotiable rules
- Nothing is designed, built, or tested that does not trace to a requirement ID.
- To change behaviour: change the spec first, then the design, then the code. A
  material change to an approved spec re-opens Gate 1; to an approved design, Gate 2.
- Never edit `.env*`, keys, or lockfiles; never commit secrets.
- Never force-push, push to `main`/`master`, deploy, or publish from an agent.
- No destructive SQL (`DROP`, `TRUNCATE`) from an agent.

## Governance (make quality measurable)
- `bash sdlc/scripts/sdlc.sh trace <slug>`   — every spec ID mapped in the design.
- `bash sdlc/scripts/sdlc.sh verify <slug>`  — every ID maps to a task AND a test; emits `trace.json`.
- `bash sdlc/scripts/sdlc.sh metrics <slug>` — Spec Fidelity, AC test coverage,
  Ambiguity Tax, Task Completion Index + repair multiplier φ, and the release gate.
- Provenance: each subagent run is recorded in `provenance.jsonl` (agent, phase,
  session, spec version), and each PR carries the spec, design, diff, tests, and review.

## Patterns
Consult [`patterns.md`](./patterns.md) for the project's required patterns, and flag
any change that violates one during review.
