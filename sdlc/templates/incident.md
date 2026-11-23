# Incident: <title>

**Slug:** `<slug>`  **Severity:** Sev1 | Sev2 | Sev3  **Date:** YYYY-MM-DD  **Phase:** maintain

> The maintain phase closes the loop: a production problem becomes a recorded
> incident, a spec/test change so it can't recur, and a lesson. Agents may diagnose
> read-only and propose a fix PR; a human approves and ships.

## 1. What happened
Impact, who/what was affected, and the time window.

## 2. Detection
How it was found (alert, user report, scan). Tiered response taken:
- **1σ** — logged and watched
- **2σ** — diagnosed read-only
- **3σ** — proposed a fix PR or ran a pre-approved runbook

## 3. Root cause
The real cause, not just the symptom.

## 4. Fix
Link the spec change, design change, and PR. Behaviour changed only after the spec
changed (see change control).

## 5. Prevention (so it can't recur)
- New/changed acceptance criterion: `AC-…`
- New test / eval case: `…`
- New pattern or CLAUDE.md note, if the class of mistake is general.

## 6. Lesson
One line for `sdlc/lessons.md`.
