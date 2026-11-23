#!/usr/bin/env bash
# SessionStart: tells Claude where the current feature stands, so a new or
# resumed session picks up the SDLC state without the user re-explaining it.
# For SessionStart, plain stdout is added to Claude's context.
source "$(dirname "$0")/lib.sh"
cat >/dev/null   # input not needed

if [ ! -f "$SDLC_STATE" ]; then
  echo "SDLC: no feature is in progress. A new feature starts with /sdlc <description>."
  exit 0
fi

FEATURE="$(sdlc_get feature)"
PHASE="$(sdlc_get phase)"
ARTIFACTS="$(cd "$SDLC_DIR/$FEATURE" 2>/dev/null && ls -1 2>/dev/null | tr '\n' ' ')"

echo "SDLC status: feature '$FEATURE' is in the '$PHASE' phase."
echo "Artifacts in docs/sdlc/$FEATURE/: ${ARTIFACTS:-none yet}"
case "$PHASE" in
  requirements|design) echo "Source-code edits are locked by the phase gate until the design is approved." ;;
  implement|test)      echo "A quality gate runs the test suite when Claude or the developer subagent tries to finish." ;;
esac
echo "/sdlc resumes the pipeline; /sdlc-status shows details."
exit 0
