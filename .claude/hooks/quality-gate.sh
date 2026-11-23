#!/usr/bin/env bash
# Stop / SubagentStop: during the implement and test phases, Claude (or the
# developer subagent) may not finish while the test suite is failing.
# Exit 2 = "keep working", and stderr tells Claude what failed.
source "$(dirname "$0")/lib.sh"

INPUT="$(cat)"
[ -f "$SDLC_STATE" ] || exit 0
PHASE="$(sdlc_get phase)"
case "$PHASE" in implement|test) ;; *) exit 0 ;; esac

cd "$ROOT" || exit 0

# Nothing changed since the last commit? Then there is nothing to verify.
if git rev-parse --git-dir >/dev/null 2>&1; then
  [ -z "$(git status --porcelain -- . ':(exclude)docs/sdlc' 2>/dev/null)" ] && exit 0
fi

# Loop protection: block at most 3 times per session, then let the human decide.
SESSION="$(json_field "$INPUT" session_id)"
COUNTER="${TMPDIR:-/tmp}/sdlc-quality-gate-${SESSION:-nosession}"
ATTEMPTS="$(cat "$COUNTER" 2>/dev/null || echo 0)"

detect_test_cmd() {
  if [ -n "${SDLC_TEST_CMD:-}" ]; then echo "$SDLC_TEST_CMD"; return; fi
  if [ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json \
     && ! grep -q 'no test specified' package.json; then echo "npm test --silent"; return; fi
  if [ -f go.mod ]; then echo "go test ./..."; return; fi
  if [ -f Cargo.toml ]; then echo "cargo test --quiet"; return; fi
  if [ -x ./mvnw ]; then echo "./mvnw -q test"; return; fi
  if [ -f pom.xml ] && has mvn; then echo "mvn -q test"; return; fi
  if [ -x ./gradlew ]; then echo "./gradlew test -q"; return; fi
  if has pytest && { [ -f pytest.ini ] || [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -d tests ]; }; then
    echo "pytest -q"; return
  fi
}

TEST_CMD="$(detect_test_cmd)"
[ -z "$TEST_CMD" ] && exit 0   # no test runner found: nothing to enforce

if OUT="$(bash -c "$TEST_CMD" 2>&1)"; then
  rm -f "$COUNTER"
  exit 0
fi

if [ "$ATTEMPTS" -ge 3 ]; then
  rm -f "$COUNTER"
  echo "Quality gate: tests still failing after 3 attempts; handing back to the user." >&2
  exit 0   # stop blocking; the failure is visible in the transcript
fi
echo $((ATTEMPTS + 1)) > "$COUNTER"

block "Quality gate (phase: $PHASE): the test suite is failing, so you cannot finish yet.
Command: $TEST_CMD
Fix the code (do not delete or skip tests). Last 40 lines of output:
$(printf '%s\n' "$OUT" | tail -n 40)"
