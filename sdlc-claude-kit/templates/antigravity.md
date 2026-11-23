# Spec-driven SDLC (Google Antigravity)

Antigravity reads `AGENTS.md` at the repo root — that is the primary adapter and it
already carries this workflow. This file is the Antigravity-specific rule entry; keep
it in sync with `AGENTS.md`.

Follow `sdlc/PROCESS.md` for every feature:

1. **Spec first** → `docs/sdlc/<slug>/01-requirements.md` with stable IDs (`REQ-1`,
   `AC-1.1`, `NFR-1`) and EARS acceptance criteria. Human approval. **(Gate 1)**
2. **Design** → `docs/sdlc/<slug>/02-design.md` with an ordered task list and a
   traceability table covering every `AC-*`/`NFR-*`. Human approval. **(Gate 2)**
3. **Implement** with TDD (tests named after their `AC-*`) → **test → review**.
4. **Release** notes only — never push, deploy or publish. **(Gate 3)**

Antigravity's agent/artifact workflow maps naturally: treat the spec and design docs
as the Implementation Plan it must get approved before writing code, and keep its
task list in sync with the checklist in `02-design.md`.

## Hard rules
- Never edit `.env*`, keys, or lockfiles; never commit secrets.
- Never force-push, push to main/master, deploy, or publish.
- No destructive SQL from the agent. Change the spec before changing behaviour.

Stack: {{STACK}} · Tests: {{TEST_CMD}} · Lint: {{LINT_CMD}}
