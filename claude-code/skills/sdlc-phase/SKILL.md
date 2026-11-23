---
name: sdlc-phase
description: Run or re-run a single SDLC phase (requirements, design, implement, test, review, release) for the current feature, without running the whole pipeline.
argument-hint: "<phase> [extra instructions]"
disable-model-invocation: true
arguments: [phase]
allowed-tools: Bash(bash .claude/scripts/sdlc.sh *) Read Glob Grep
---

# Run one SDLC phase

Requested phase: $phase
Full arguments: $ARGUMENTS

Current state:
!`bash .claude/scripts/sdlc.sh status 2>/dev/null || true`

If no feature is in progress, tell the user to start one with `/sdlc <description>`
and stop.

## Phase to subagent map

| Phase        | Subagent(s)                          | Output file                                  |
|--------------|--------------------------------------|----------------------------------------------|
| requirements | requirements-analyst                 | 01-requirements.md                           |
| design       | architect                            | 02-design.md                                 |
| implement    | developer                            | source code + ticked tasks in 02-design.md   |
| test         | qa-engineer                          | 03-test-report.md                            |
| review       | code-reviewer + security-auditor (in parallel) | 04-code-review.md, 05-security-review.md |
| release      | release-manager                      | 06-release-notes.md, CHANGELOG.md            |
| maintain     | incident handling (diagnose read-only)         | 07-incident.md, sdlc/lessons.md              |

## Steps
1. Validate that the requested phase is one of the six above.
2. Run `bash .claude/scripts/sdlc.sh phase <phase>`.
3. Delegate to the mapped subagent(s). Include the feature slug, the file paths
   in `docs/sdlc/<slug>/`, and any extra instructions the user gave after the
   phase name.
4. Summarise the result in a few lines. If the phase was `requirements` or
   `design`, ask the user to approve before anyone moves to the next phase.
