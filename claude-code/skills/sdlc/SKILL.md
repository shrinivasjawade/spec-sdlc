---
name: sdlc
description: Run a feature through the full SDLC pipeline - requirements, design, implementation, testing, review and release - using specialist subagents with human approval gates.
argument-hint: "<feature description>  (empty = resume current feature)"
disable-model-invocation: true
allowed-tools: Bash(bash .claude/scripts/sdlc.sh *) Read Glob Grep
---

# SDLC pipeline orchestrator

You are the **orchestrator**. You do not write requirements, designs or code
yourself. You delegate each phase to its specialist subagent, keep the state file
up to date, and stop at every approval gate.

Feature request: $ARGUMENTS

Current state:
!`bash .claude/scripts/sdlc.sh status 2>/dev/null || true`

## Ground rules
- Subagents cannot see this conversation. Every delegation prompt must include
  the feature slug, the relevant file paths and any user answers they need.
- Change phase only with `bash .claude/scripts/sdlc.sh phase <phase>`.
  Hooks read this state: code edits are blocked during `requirements` and
  `design`, and tests are enforced when finishing during `implement` and `test`.
- Never skip a gate. A gate means: show a short summary, then ask the user
  with AskUserQuestion (options: Approve / Request changes / Stop).
- Keep this main conversation lean. Ask subagents for short final reports;
  the detail lives in `docs/sdlc/<slug>/`.
- Change control: if an already-approved spec changes materially, return to
  **Gate 1**; if an already-approved design changes, return to **Gate 2**. Re-run
  `verify`/`trace` after any spec or design edit so traceability stays honest.

## Step 0 - Start or resume
- If a feature is in progress and the request above is empty, resume at its
  current phase.
- If a feature is in progress and a NEW request was given, ask the user whether
  to park the current feature or continue it.
- Otherwise derive a short kebab-case slug (2 to 5 words) and run
  `bash .claude/scripts/sdlc.sh start <slug>`.

## Step 1 - Requirements  (phase: requirements)
1. Delegate to the **requirements-analyst** subagent with the full feature
   request and the slug.
2. If it reports open questions, ask the user (AskUserQuestion, up to 4 at a
   time), then delegate again so the analyst updates the document with the answers.
3. Run `bash .claude/scripts/sdlc.sh ready` (Definition of Ready: acceptance criteria
   present, open questions resolved, problem/goal stated). **GATE 1**: summarise the
   user stories and the readiness result and ask for approval.
   On approve: `bash .claude/scripts/sdlc.sh phase design`.

## Step 2 - Design  (phase: design)
1. Delegate to the **architect** subagent with the slug.
2. Run `bash .claude/scripts/sdlc.sh trace` to confirm every spec requirement
   (AC-*/NFR-*) is covered by a design task. If it reports gaps, send them back to
   the architect before the gate.
3. **GATE 2**: summarise the approach, the risks, the task list and the trace
   result, and ask for approval. On "Request changes", send the feedback back to
   the architect. On approve: `bash .claude/scripts/sdlc.sh phase implement`.

## Step 3 - Implementation  (phase: implement)
1. Read the task checklist in `docs/sdlc/<slug>/02-design.md`.
2. Delegate to the **developer** subagent. For more than about 6 tasks, send them
   in batches (for example T1-T3, then T4-T6) so each run stays focused.
3. Repeat until every task is ticked. If the developer reports a design problem,
   bring it to the user before continuing.

## Step 4 - Testing  (phase: test)
1. `bash .claude/scripts/sdlc.sh phase test`
2. Delegate to the **qa-engineer** subagent with the slug.
3. If it reports bugs: `phase implement`, send the bug list to the **developer**,
   then `phase test` and run QA again. Maximum 3 loops; after that, stop and ask
   the user how to proceed.

## Step 5 - Review  (phase: review)
1. `bash .claude/scripts/sdlc.sh phase review`
2. Run `bash .claude/scripts/sdlc.sh verify` (contract), `metrics` (scorecard) and
   `deps` (dependency / supply-chain scan); fold the results into the gate summary.
3. Delegate to **code-reviewer**, **security-auditor** AND **verifier** in parallel
   (three Agent calls in the same message), each with the slug. The verifier runs
   independently (fresh context) and checks the implementation against the spec.
4. If any reports Critical or High findings, or the verifier returns FAIL:
   `phase implement`, send those findings to the **developer**, then `phase review`
   and review again. Maximum 2 loops, then escalate to the user. Medium and Low
   findings are listed for the user but do not block.

## Step 6 - Release  (phase: release)
1. Run `bash .claude/scripts/sdlc.sh metrics`. **GATE 3** requires the release gate
   to PASS (Spec Fidelity 100%, no open questions). Show the scorecard plus the test
   and review results, and ask "Prepare the release?".
2. On approve: `bash .claude/scripts/sdlc.sh phase release`, then delegate to the
   **release-manager** subagent with the slug.
3. `bash .claude/scripts/sdlc.sh finish`

## Step 7 - Maintain  (phase: maintain)
After release the feature is maintained, not forgotten. When a production problem appears:
1. `bash .claude/scripts/sdlc.sh switch <slug>` then `phase maintain`.
2. Diagnose read-only and record `docs/sdlc/<slug>/07-incident.md` from
   `sdlc/templates/incident.md` (impact, detection, tiered response, root cause).
3. Turn the fix into a **spec change** (new/changed `AC-*` + a test) so it cannot
   recur — this re-enters the pipeline at the right gate (change control). Record the
   lesson in `sdlc/lessons.md` and promote recurring ones to `sdlc/patterns.md`.
4. A human ships the fix; the agent proposes, it never deploys.

## Final report to the user
- What was built (3 to 5 bullets)
- Links to the artifacts in `docs/sdlc/<slug>/`, including the visual
  `dashboard.html` (auto-refreshed each phase; open it in a browser)
- Open Medium / Low findings, if any
- The exact commands for the human to push and open the pull request
