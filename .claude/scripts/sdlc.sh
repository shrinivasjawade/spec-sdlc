#!/usr/bin/env bash
# SDLC state helper. The hooks read the state this script writes.
#
#   bash .claude/scripts/sdlc.sh start <feature-slug>   new feature, phase = requirements
#   bash .claude/scripts/sdlc.sh phase <phase>          move the current feature to a phase
#   bash .claude/scripts/sdlc.sh status                 show feature, phase and artifacts
#   bash .claude/scripts/sdlc.sh trace [slug]           check every spec ID is covered in the design
#   bash .claude/scripts/sdlc.sh doctor                 check required tooling is present
#   bash .claude/scripts/sdlc.sh finish                 close the current feature
#
# Phases: requirements -> design -> implement -> test -> review -> release
set -euo pipefail
source "$(dirname "$0")/../hooks/lib.sh"

PHASES="requirements design implement test review release"

write_state() {  # write_state <feature> <phase>
  mkdir -p "$SDLC_DIR/$1"
  printf '{\n  "feature": "%s",\n  "phase": "%s",\n  "updated": "%s"\n}\n' \
    "$1" "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SDLC_STATE"
  printf '%s  phase=%-12s (state change)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" \
    >> "$SDLC_DIR/$1/activity.log"
}

require_feature() {
  if [ ! -f "$SDLC_STATE" ]; then
    echo "No feature in progress. Start one: bash .claude/scripts/sdlc.sh start <slug>" >&2
    exit 1
  fi
}

cmd="${1:-status}"
case "$cmd" in
  start)
    raw="${2:?usage: sdlc.sh start <feature-slug>}"
    slug="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    [ -z "$slug" ] && { echo "Invalid slug: $raw" >&2; exit 1; }
    if [ -f "$SDLC_STATE" ]; then
      echo "Feature '$(sdlc_get feature)' is still in progress (phase: $(sdlc_get phase)). Run 'finish' first." >&2
      exit 1
    fi
    write_state "$slug" requirements
    echo "Started feature '$slug' in phase 'requirements'. Artifacts: docs/sdlc/$slug/"
    ;;

  phase)
    require_feature
    new="${2:?usage: sdlc.sh phase <$(echo $PHASES | tr ' ' '|')>}"
    case " $PHASES " in
      *" $new "*) ;;
      *) echo "Unknown phase '$new'. Valid: $PHASES" >&2; exit 1 ;;
    esac
    feature="$(sdlc_get feature)"
    old="$(sdlc_get phase)"
    write_state "$feature" "$new"
    echo "Feature '$feature': $old -> $new"
    ;;

  status)
    if [ ! -f "$SDLC_STATE" ]; then
      echo "No feature in progress."
      exit 0
    fi
    feature="$(sdlc_get feature)"
    echo "Feature: $feature"
    echo "Phase:   $(sdlc_get phase)   (updated $(sdlc_get updated))"
    echo "Artifacts in docs/sdlc/$feature/:"
    ls -1 "$SDLC_DIR/$feature" 2>/dev/null | sed 's/^/  - /' || true
    design="$SDLC_DIR/$feature/02-design.md"
    spec="$SDLC_DIR/$feature/01-requirements.md"
    if [ -f "$design" ]; then
      done_n="$(grep -c -- '- \[x\]' "$design" || true)"
      todo_n="$(grep -c -- '- \[ \]' "$design" || true)"
      echo "Tasks:   $done_n done, $todo_n open"
    fi
    if [ -f "$spec" ] && [ -f "$design" ]; then
      ids="$(grep -oE '(AC-[0-9]+\.[0-9]+|NFR-[0-9]+)' "$spec" | sort -u)"
      if [ -n "$ids" ]; then
        t=0; c=0
        while IFS= read -r id; do
          t=$((t + 1)); grep -q -- "$id" "$design" && c=$((c + 1))
        done <<EOF
$ids
EOF
        echo "Trace:   $c/$t spec requirements covered in the design"
      fi
    fi
    ;;

  trace)
    # Every AC-*/NFR-* in the spec must appear in the design. Reports gaps.
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    spec="$SDLC_DIR/$slug/01-requirements.md"
    design="$SDLC_DIR/$slug/02-design.md"
    [ -f "$spec" ] || { echo "No spec at $spec" >&2; exit 1; }
    ids="$(grep -oE '(AC-[0-9]+\.[0-9]+|NFR-[0-9]+)' "$spec" | sort -u)"
    [ -z "$ids" ] && { echo "No requirement IDs (AC-*/NFR-*) found in the spec." >&2; exit 1; }
    if [ ! -f "$design" ]; then
      echo "Spec has IDs but there is no design yet ($design). Nothing to trace against." >&2
      exit 1
    fi
    missing=""; covered=0; total=0
    while IFS= read -r id; do
      total=$((total + 1))
      if grep -q -- "$id" "$design"; then covered=$((covered + 1)); else missing="$missing $id"; fi
    done <<EOF
$ids
EOF
    echo "Traceability for '$slug': $covered/$total requirement IDs covered in the design."
    if [ -n "$missing" ]; then
      echo "NOT covered by any design task:$missing" >&2
      exit 1
    fi
    echo "All spec requirements are traced to the design."
    ;;

  doctor)
    echo "SDLC environment check:"
    ok=0
    if has bash; then echo "  [ok] bash"; else echo "  [MISSING] bash"; ok=1; fi
    if has jq; then echo "  [ok] jq (fast JSON)"; elif has python3 || has python; then
      echo "  [ok] python3/python (JSON fallback)"; else
      echo "  [MISSING] need jq OR python3 for the hooks"; ok=1; fi
    has git && echo "  [ok] git" || echo "  [warn] git not found (review/release phases need it)"
    exit $ok
    ;;

  finish)
    require_feature
    feature="$(sdlc_get feature)"
    printf '%s  feature finished\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SDLC_DIR/$feature/activity.log"
    rm -f "$SDLC_STATE"
    echo "Feature '$feature' finished. Artifacts kept in docs/sdlc/$feature/"
    ;;

  *)
    sed -n '2,9p' "$0"
    exit 1
    ;;
esac
