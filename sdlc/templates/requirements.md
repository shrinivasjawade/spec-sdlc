# Specification: <Feature name>

**Slug:** `<slug>`  **Status:** Draft | Approved  **Date:** YYYY-MM-DD

> This is the **spec** — the single source of truth for the feature. Every design
> task, test and review finding traces back to a requirement ID below (`REQ-n` /
> `AC-n.m`). If it is not in the spec, it is not built.

## 1. Problem and goal
Why are we building this? Who has the problem? What does success look like?

## 2. Requirements and acceptance criteria

Acceptance criteria use **EARS** (Easy Approach to Requirements Syntax). Pick the
pattern that fits; every criterion is one testable "SHALL" statement:

- **Ubiquitous:** The system SHALL `<response>`.
- **Event:** WHEN `<trigger>`, the system SHALL `<response>`.
- **State:** WHILE `<state>`, the system SHALL `<response>`.
- **Unwanted:** IF `<condition>`, THEN the system SHALL `<response>`.
- **Optional:** WHERE `<feature is included>`, the system SHALL `<response>`.

### REQ-1: <short title>
As a **<type of user>**, I want **<action>**, so that **<benefit>**.

Acceptance criteria:
- **AC-1.1** WHEN `<trigger>`, the system SHALL `<observable result>`.
- **AC-1.2** IF `<bad input>`, THEN the system SHALL `<handled result>`.

### REQ-2: <short title>
...

## 3. Non-functional requirements
Give each a stable ID too, so they can be traced and tested.

| ID     | Area          | Requirement (measurable)                      |
|--------|---------------|-----------------------------------------------|
| NFR-1  | Performance   | The system SHALL respond in under 300 ms (p95). |
| NFR-2  | Security      | The system SHALL allow only the owner to read their records. |
| NFR-3  | Accessibility | The UI SHALL be keyboard-navigable and meet WCAG AA contrast. |

## 4. Out of scope
- ...

## 5. Assumptions and dependencies
- ...

## 6. Open questions
1. ...  → **Answer:** (filled in after the user replies)
