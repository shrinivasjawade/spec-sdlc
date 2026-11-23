# AGENTS.md

Guidance for any AI coding agent working in this repository (OpenAI Codex, Gemini
CLI, Google Antigravity, Jules, and most agentic tools read this file automatically).

## How we build features here: spec-driven SDLC

**Read [`sdlc/PROCESS.md`](sdlc/PROCESS.md) and follow it.** It is the single source
of truth for the workflow. In short:

1. **Spec first.** Write `docs/sdlc/<slug>/01-requirements.md` — requirements with
   stable IDs (`REQ-1`, `AC-1.1`, `NFR-1`) and acceptance criteria in EARS form
   ("WHEN … the system SHALL …"). Stop and let the human approve it. **(Gate 1)**
2. **Design.** Write `docs/sdlc/<slug>/02-design.md` — a change plan, an ordered task
   checklist, and a traceability table covering **every** `AC-*`/`NFR-*`. Let the
   human approve it. **(Gate 2)**
3. **Implement** task by task with TDD; name tests after their `AC-*`.
4. **Test** → **review** (correctness + security) → fix loops.
5. **Release:** prepare changelog/notes/PR text. **Never push, deploy or publish —
   a human does that. (Gate 3)**

Use the templates in `sdlc/templates/`. Track state with:
`bash .claude/scripts/sdlc.sh status` (and `start` / `phase` / `trace` / `finish`).

## Hard rules (do not violate)

- Do not edit `.env*`, private keys/certs, or lockfiles. Never put secrets in code.
- Do not force-push, push to `main`/`master`, deploy, or publish.
- No destructive SQL (`DROP`, `TRUNCATE`) from the agent.
- Do not change behaviour without updating the spec first.
- Match the existing code style; justify any new dependency in the design doc.

## This project

- **Stack:** {{STACK}}
- **Install:** {{INSTALL_CMD}}
- **Run tests:** {{TEST_CMD}}
- **Lint:** {{LINT_CMD}}
