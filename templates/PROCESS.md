# Spec-driven SDLC — the process (tool-neutral)

This is the **single source of truth for how features get built here**, independent
of which AI tool you use (Claude Code, Codex, Gemini, Cursor, Windsurf, Antigravity,
or by hand). Each tool has a thin adapter (`AGENTS.md`, `.cursor/rules/…`, `.claude/`,
etc.) that simply points back to this file.

## The pipeline

```
spec ─► design ─► implement ─► test ─► review ─► release
(gate 1)  (gate 2)    ▲ quality   │        │ code+security   (gate 3)
                      └── gate ◄───┴────────┘  fix loops
```

| Phase        | You produce                                   | Artifact                                   |
|--------------|-----------------------------------------------|--------------------------------------------|
| requirements | The **spec**: REQ/AC/NFR with EARS criteria   | `docs/sdlc/<slug>/01-requirements.md`       |
| design       | Change plan + ordered tasks + traceability    | `docs/sdlc/<slug>/02-design.md`             |
| implement    | Code, TDD, tasks ticked off                   | source + ticked tasks                       |
| test         | Edge-case tests + report                      | `docs/sdlc/<slug>/03-test-report.md`        |
| review       | Code review + security review                 | `04-code-review.md`, `05-security-review.md`|
| release      | Changelog, release notes, PR text, rollback   | `06-release-notes.md`, `CHANGELOG.md`       |

Templates for each artifact are in `sdlc/templates/`.

## The spec is the source of truth

- `01-requirements.md` is the **spec**. Nothing is designed, built or tested that
  does not trace to a requirement ID in it.
- Requirements get stable IDs: `REQ-1`, acceptance criteria `AC-1.1`, non-functional
  `NFR-1`. IDs are never reused or renumbered once approved.
- Acceptance criteria are written in **EARS**:
  - Ubiquitous — The system SHALL `<response>`.
  - Event — WHEN `<trigger>`, the system SHALL `<response>`.
  - State — WHILE `<state>`, the system SHALL `<response>`.
  - Unwanted — IF `<condition>`, THEN the system SHALL `<response>`.
  - Optional — WHERE `<feature included>`, the system SHALL `<response>`.
- The design's **traceability table** must cover every `AC-*` and `NFR-*`. Tests are
  named so their `AC-*` is identifiable.
- To change behaviour: change the spec first, then the design, then the code.

## The three human gates — never skip

1. **Gate 1 (after spec):** the human approves the requirements before any design.
2. **Gate 2 (after design):** the human approves the design + task list. Every
   `AC-*`/`NFR-*` must be covered in traceability (`bash .claude/scripts/sdlc.sh trace`).
3. **Gate 3 (before release):** the human approves, then release artifacts are
   prepared. **The agent never pushes, deploys or publishes** — a human does.

## State

The current feature and phase live in `docs/sdlc/current.json`. Change it only through
the helper script (works from any tool that has a shell):

```
bash .claude/scripts/sdlc.sh start <slug>     # begin a feature
bash .claude/scripts/sdlc.sh phase <phase>    # advance phase
bash .claude/scripts/sdlc.sh status           # where things stand + trace summary
bash .claude/scripts/sdlc.sh trace            # verify every spec ID is covered
bash .claude/scripts/sdlc.sh doctor           # check tooling (bash + jq/python3)
bash .claude/scripts/sdlc.sh finish           # close the feature
```

## What enforcement you get per tool

- **Claude Code** is the only layer that *enforces* the rules automatically, via
  hooks: source code is locked during spec/design, secrets and lockfiles are
  protected, dangerous commands are blocked, and it cannot finish while tests fail.
- **Every other tool** (Codex, Gemini, Cursor, Windsurf, Antigravity, …) *follows*
  this process because its adapter file tells it to, and the human gates still apply.
  The guard rails are guidance there, not hard blocks — so review diffs before you run
  anything, and keep a human on the three gates.

## Guard rails (always, in every phase)

- Never edit `.env`, private keys, or lockfiles; never commit secrets.
- Never force-push, push to main/master, deploy, or publish.
- No destructive SQL (`DROP`, `TRUNCATE`) from the agent.
- Match the existing code style; add a dependency only with a reason in the design.
