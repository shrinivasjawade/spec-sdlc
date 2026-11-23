# Project instructions

## SDLC workflow
This project builds features through an agent-driven SDLC pipeline:

requirements -> design -> implement -> test -> review -> release

- Start a feature: `/sdlc <feature description>`. Resume: `/sdlc`.
- One phase only: `/sdlc-phase <phase>`. Status: `/sdlc-status`.
- Quick review of the current diff: `/quick-review`.
- Each phase has a specialist subagent in `.claude/agents/`.
- Artifacts for every feature live in `docs/sdlc/<feature-slug>/`.
- The current feature and phase are in `docs/sdlc/current.json`; change them only
  through `bash .claude/scripts/sdlc.sh`.
- Standards and the Definition of Done: `.claude/skills/sdlc-standards/SKILL.md`.

## Guard rails enforced by hooks (see .claude/settings.json)
- Source code is locked during the requirements and design phases.
- `.env` files, private keys and lockfiles cannot be edited by the agent.
- Force pushes, pushes to main, deploys, publishes and destructive SQL are blocked.
- Changed files are formatted and linted after every edit.
- During implement and test, Claude cannot finish while tests fail.

For small fixes that do not need the full pipeline, work normally: without a
feature in progress, the phase gate and quality gate are inactive.

## Project specifics (fill these in)
- Tech stack:
- How to run locally:
- Test command:
- Lint command:
