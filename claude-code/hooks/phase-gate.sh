#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit):
#  1. Always protects secrets and generated lockfiles.
#  2. Enforces the SDLC phase: no source-code edits until the design is approved.
source "$(dirname "$0")/lib.sh"

INPUT="$(cat)"
FILE="$(json_field "$INPUT" tool_input.file_path)"
[ -z "$FILE" ] && FILE="$(json_field "$INPUT" tool_input.notebook_path)"
[ -z "$FILE" ] && exit 0
REL="$(rel_path "$FILE")"
NAME="$(basename "$REL")"

# --- 1. Always-on file protection --------------------------------------------
case "$NAME" in
  .env.example|.env.sample|.env.template) ;;   # templates are fine
  .env|.env.*)
    block "BLOCKED: $REL holds secrets and must not be edited by the agent. Update .env.example instead and tell the user which variables to set." ;;
  *.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*)
    block "BLOCKED: $REL looks like a private key or certificate." ;;
  package-lock.json|yarn.lock|pnpm-lock.yaml|poetry.lock|Pipfile.lock|Cargo.lock|go.sum|composer.lock)
    block "BLOCKED: $REL is generated. Run the package manager (e.g. npm install <pkg>) instead of editing it by hand." ;;
esac

# --- 2. Phase gate -------------------------------------------------------------
[ -f "$SDLC_STATE" ] || exit 0          # no feature in progress: no gate
PHASE="$(sdlc_get phase)"
FEATURE="$(sdlc_get feature)"

case "$PHASE" in
  requirements|design)
    case "$REL" in
      docs/*|.claude/*|*.md) exit 0 ;;   # documentation is the job in these phases
      *)
        block "BLOCKED by phase gate: feature '$FEATURE' is in the '$PHASE' phase, so source code is locked. Finish docs/sdlc/$FEATURE/ and get the user's approval first. After approval the orchestrator runs: bash .claude/scripts/sdlc.sh phase implement" ;;
    esac ;;
esac

exit 0
