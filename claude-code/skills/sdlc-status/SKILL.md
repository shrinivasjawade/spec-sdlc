---
name: sdlc-status
description: Show which feature is in progress, its current SDLC phase, which artifacts exist and what the next step is. Use when the user asks where a feature stands.
allowed-tools: Bash(bash .claude/scripts/sdlc.sh *) Read
---

# SDLC status

!`bash .claude/scripts/sdlc.sh status 2>/dev/null || true`

Recent activity:
!`tail -n 15 docs/sdlc/*/activity.log 2>/dev/null || echo "(no activity yet)"`

Using the information above (read the artifact files if you need detail), tell
the user in five lines or fewer:
1. Feature and current phase
2. What is done (artifacts present, tasks ticked in 02-design.md)
3. Any blocking issues (failing tests, Critical/High findings)
4. The next command to run, for example `/sdlc` to resume or
   `/sdlc-phase review`
