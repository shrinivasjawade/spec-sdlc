---
trigger: always_on
---

# Spec-driven SDLC (Windsurf)

Follow `sdlc/PROCESS.md` for every feature.

- **Spec first:** `docs/sdlc/<slug>/01-requirements.md` with stable IDs (`REQ-1`,
  `AC-1.1`, `NFR-1`) and EARS acceptance criteria. Human approves. **(Gate 1)**
- **Design:** `docs/sdlc/<slug>/02-design.md` with an ordered task list and a
  traceability table covering every `AC-*`/`NFR-*`. Human approves. **(Gate 2)**
- **Implement** TDD (tests named after their `AC-*`) → **test → review**.
- **Release:** notes only — never push, deploy or publish. **(Gate 3)**

Templates: `sdlc/templates/`. State: `bash sdlc/scripts/sdlc.sh status`.

## Hard rules
- Never edit `.env*`, keys, or lockfiles; never commit secrets.
- Never force-push, push to main/master, deploy, or publish.
- No destructive SQL from the agent.
- Change the spec before changing behaviour.

Stack: {{STACK}} · Tests: {{TEST_CMD}} · Lint: {{LINT_CMD}}
