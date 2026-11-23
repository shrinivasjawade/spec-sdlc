#!/usr/bin/env bash
# SubagentStop (async): appends an audit line to docs/sdlc/<feature>/activity.log
# every time a subagent finishes, so you can see who did what in which phase.
source "$(dirname "$0")/lib.sh"

INPUT="$(cat)"
[ -f "$SDLC_STATE" ] || exit 0
FEATURE="$(sdlc_get feature)"
PHASE="$(sdlc_get phase)"
[ -z "$FEATURE" ] && exit 0
AGENT="$(json_field "$INPUT" agent_type)"

mkdir -p "$SDLC_DIR/$FEATURE"
printf '%s  phase=%-12s agent=%s finished\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PHASE" "${AGENT:-unknown}" \
  >> "$SDLC_DIR/$FEATURE/activity.log"
exit 0
