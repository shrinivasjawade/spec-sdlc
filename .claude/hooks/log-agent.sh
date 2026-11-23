#!/usr/bin/env bash
# SubagentStop (async): appends to the human-readable activity.log AND a
# machine-readable provenance ledger (provenance.jsonl), so every artifact is
# traceable to the agent, phase, session and spec version that produced it.
source "$(dirname "$0")/lib.sh"

INPUT="$(cat)"
[ -f "$SDLC_STATE" ] || exit 0
FEATURE="$(sdlc_get feature)"
PHASE="$(sdlc_get phase)"
[ -z "$FEATURE" ] && exit 0
AGENT="$(json_field "$INPUT" agent_type)"
SESSION="$(json_field "$INPUT" session_id)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
dir="$SDLC_DIR/$FEATURE"
mkdir -p "$dir"

# Spec version: short git hash of the spec file when under git (auditable provenance).
SPEC="$dir/01-requirements.md"
SPEC_REV="-"
if [ -f "$SPEC" ] && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  SPEC_REV="$(git -C "$ROOT" log -1 --format=%h -- "$SPEC" 2>/dev/null || echo -)"
fi

printf '%s  phase=%-12s agent=%s finished\n' "$TS" "$PHASE" "${AGENT:-unknown}" \
  >> "$dir/activity.log"
printf '{"ts":"%s","phase":"%s","agent":"%s","session":"%s","spec_rev":"%s"}\n' \
  "$TS" "$PHASE" "${AGENT:-unknown}" "${SESSION:-}" "$SPEC_REV" \
  >> "$dir/provenance.jsonl"
exit 0
