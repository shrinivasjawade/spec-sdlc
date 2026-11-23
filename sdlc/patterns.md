# Patterns registry

The architectural and coding patterns this project requires. The **design** phase
must conform to these, and **review** (code-reviewer + verifier) checks adherence
and flags any deviation. Each pattern has a stable ID so findings can cite it
(`PAT-1`), the same way requirements use `AC-*`.

> Fill these in for your project. The rows below are examples — replace them.

| ID    | Pattern | Rule (what adherence looks like) | Applies to |
|-------|---------|----------------------------------|------------|
| PAT-1 | Input validation at the boundary | All external input (HTTP, CLI, file, queue) is validated and typed before it reaches domain logic. | handlers, controllers |
| PAT-2 | Errors are explicit | No silent catch; errors are returned/raised with context and logged once at the boundary. | everywhere |
| PAT-3 | Config from environment | No secrets or environment-specific values in code; read from env/config. | everywhere |
| PAT-4 | Layering | UI → service → repository → store. No layer skips (e.g. no SQL in a controller). | architecture |
| PAT-5 | Dependency justification | A new dependency is introduced only with a reason recorded in `02-design.md`. | design |

## How patterns are enforced
- **Design time:** the architect states which patterns the change touches and how it
  conforms (or an explicit, approved exception).
- **Review time:** every deviation is a finding citing the `PAT-*` ID, rated
  Important or Nit (cap nits at five), with a suggested fix.
- **Context:** agents read this file (and `CLAUDE.md` where present) before designing
  or reviewing, so the project's conventions travel with the task.

## Adding a pattern
When the same correction is made twice in review, write it here as a new `PAT-*`
row rather than re-explaining it each time. Keep each rule testable and specific.
