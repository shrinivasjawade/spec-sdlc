---
name: quick-review
description: Get a fast, independent code review of the current uncommitted changes from the code-reviewer subagent. Works outside the SDLC pipeline too.
argument-hint: "[focus area, e.g. 'error handling']"
context: fork
agent: code-reviewer
background: false
allowed-tools: Bash(git *)
---

Review the current uncommitted changes in this repository.
Do not write a review file; reply with the review directly.

Extra focus requested by the user (may be empty): $ARGUMENTS

## Changed files
!`git status --short 2>/dev/null || echo "not a git repository"`

## Diff (first 400 lines)
!`(git diff HEAD 2>/dev/null || git diff 2>/dev/null) | head -n 400`

Read full files where the diff is not enough context. Return:
- Verdict: APPROVE or CHANGES REQUESTED
- Findings sorted by severity, each with `file:line`, the problem and the fix
- At most 3 Low/nit findings
