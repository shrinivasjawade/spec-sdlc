#!/usr/bin/env bash
# SDLC state + governance helper. Hooks read the state this script writes.
#
#   bash sdlc/scripts/sdlc.sh start <feature-slug>   new feature, phase = requirements
#   bash sdlc/scripts/sdlc.sh phase <phase>          move the current feature to a phase
#   bash sdlc/scripts/sdlc.sh status                 show feature, phase and artifacts
#   bash sdlc/scripts/sdlc.sh trace [slug]           every spec ID must be mapped in the design's Traceability table
#   bash sdlc/scripts/sdlc.sh verify [slug]          validate the traceability contract; emit trace.json
#   bash sdlc/scripts/sdlc.sh metrics [slug]         governance scorecard + release gate
#   bash sdlc/scripts/sdlc.sh doctor                 check required tooling is present
#   bash sdlc/scripts/sdlc.sh finish                 close the current feature
#
# Phases: requirements -> design -> implement -> test -> review -> release
set -euo pipefail
source "$(dirname "$0")/lib.sh"

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
    echo "No feature in progress. Start one: bash sdlc/scripts/sdlc.sh start <slug>" >&2
    exit 1
  fi
}

# coverage <spec> <design>  ->  echoes "covered total missing..." using the
# Traceability table only. Returns 0 always; caller inspects the numbers.
coverage() {
  local spec="$1" design="$2" section ids id covered=0 total=0 missing=""
  ids="$(sdlc_spec_ids "$spec")"
  section="$(sdlc_trace_section "$design")"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    total=$((total + 1))
    if printf '%s' "$section" | grep -q -- "$id"; then
      covered=$((covered + 1))
    else
      missing="$missing $id"
    fi
  done <<EOF
$ids
EOF
  echo "$covered $total$missing"
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
      read -r c t _ <<<"$(coverage "$spec" "$design")"
      [ "${t:-0}" -gt 0 ] && echo "Trace:   $c/$t spec requirements mapped in the design's Traceability table"
    fi
    ;;

  trace)
    # Every AC-*/NFR-* in the spec must be mapped in the design's Traceability table.
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    spec="$SDLC_DIR/$slug/01-requirements.md"
    design="$SDLC_DIR/$slug/02-design.md"
    [ -f "$spec" ] || { echo "No spec at $spec" >&2; exit 1; }
    ids="$(sdlc_spec_ids "$spec")"
    [ -z "$ids" ] && { echo "No requirement IDs (AC-*/NFR-*) found in the spec." >&2; exit 1; }
    [ -f "$design" ] || { echo "Spec has IDs but there is no design yet ($design)." >&2; exit 1; }
    section="$(sdlc_trace_section "$design")"
    [ -z "$section" ] && { echo "No Traceability table found in $design (expected a '## ... Traceability' section)." >&2; exit 1; }
    read -r covered total rest <<<"$(coverage "$spec" "$design")"
    missing="$rest"
    # Orphans: ids mapped in the table that are not (any longer) in the spec.
    orphans=""
    for tid in $(printf '%s' "$section" | grep -oE '(AC-[0-9]+\.[0-9]+|NFR-[0-9]+)' | sort -u); do
      printf '%s\n' "$ids" | grep -qx -- "$tid" || orphans="$orphans $tid"
    done
    echo "Traceability for '$slug': $covered/$total spec requirements mapped in the Traceability table."
    [ -n "$orphans" ] && echo "Orphan mappings (in table but not in spec):$orphans" >&2
    if [ -n "$missing" ]; then
      echo "NOT mapped in the Traceability table:$missing" >&2
      exit 1
    fi
    echo "All spec requirements are mapped in the design's Traceability table."
    ;;

  verify)
    # Validate the traceability contract: every spec ID has a row with BOTH a task
    # cell and a test cell filled, and emit a machine-readable trace.json.
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    spec="$SDLC_DIR/$slug/01-requirements.md"
    design="$SDLC_DIR/$slug/02-design.md"
    out="$SDLC_DIR/$slug/trace.json"
    [ -f "$spec" ] && [ -f "$design" ] || { echo "Need both spec and design for '$slug'." >&2; exit 1; }
    section="$(sdlc_trace_section "$design")"
    [ -z "$section" ] && { echo "No Traceability table found in $design." >&2; exit 1; }
    ids="$(sdlc_spec_ids "$spec")"
    problems=0
    {
      printf '{\n  "feature": "%s",\n  "generated": "%s",\n  "requirements": [\n' \
        "$slug" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      first=1
      while IFS= read -r id; do
        [ -z "$id" ] && continue
        # the table row for this id: | id | tasks | tests |
        row="$(printf '%s\n' "$section" | grep -E "^\|[[:space:]]*$id[[:space:]]*\|" | head -n1 || true)"
        tasks=""; tests=""; status="ok"
        if [ -z "$row" ]; then
          status="no-row"; problems=$((problems + 1))
        else
          tasks="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
          tests="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')"
          case "$tasks" in ""|"-"|"TBD"|"...") status="no-task"; problems=$((problems + 1)) ;; esac
          case "$tests" in ""|"-"|"TBD"|"...") status="no-test"; problems=$((problems + 1)) ;; esac
        fi
        [ $first -eq 1 ] || printf ',\n'; first=0
        esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
        printf '    { "id": "%s", "tasks": "%s", "tests": "%s", "status": "%s" }' \
          "$id" "$(esc "$tasks")" "$(esc "$tests")" "$status"
      done <<EOF
$ids
EOF
      printf '\n  ],\n  "problems": %s\n}\n' "$problems"
    } > "$out"
    echo "Wrote contract: $(rel_path "$out")"
    if [ "$problems" -gt 0 ]; then
      echo "Contract INVALID: $problems requirement(s) missing a row, task, or test mapping. See $(rel_path "$out")." >&2
      exit 1
    fi
    echo "Contract VALID: every spec requirement maps to a task and a test."
    ;;

  metrics)
    # Governance scorecard (SDAD-style) + release gate.
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    dir="$SDLC_DIR/$slug"
    spec="$dir/01-requirements.md"; design="$dir/02-design.md"; log="$dir/activity.log"
    [ -f "$spec" ] || { echo "No spec for '$slug'." >&2; exit 1; }
    phase="$(sdlc_get phase 2>/dev/null || echo '?')"

    # Spec Fidelity: AC/NFR mapped in traceability / total.
    fidelity_c=0; fidelity_t=0
    if [ -f "$design" ]; then
      read -r fidelity_c fidelity_t _ <<<"$(coverage "$spec" "$design")"
    fi
    pct() { [ "${2:-0}" -gt 0 ] && echo $(( $1 * 100 / $2 )) || echo 0; }
    fidelity_pct="$(pct "$fidelity_c" "$fidelity_t")"

    # AC test coverage: AC rows in the table whose test cell is filled / total AC.
    ac_total="$(printf '%s\n' "$(sdlc_spec_ids "$spec")" | grep -c '^AC-' || true)"
    ac_tested=0
    if [ -f "$design" ]; then
      section="$(sdlc_trace_section "$design")"
      while IFS= read -r id; do
        case "$id" in AC-*) ;; *) continue ;; esac
        row="$(printf '%s\n' "$section" | grep -E "^\|[[:space:]]*$id[[:space:]]*\|" | head -n1 || true)"
        tcell="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')"
        case "$tcell" in ""|"-"|"TBD"|"...") ;; *) ac_tested=$((ac_tested + 1)) ;; esac
      done <<EOF
$(sdlc_spec_ids "$spec")
EOF
    fi
    ac_pct="$(pct "$ac_tested" "$ac_total")"

    # Ambiguity Tax: unanswered open questions + vague terms lacking numbers.
    open_q="$(awk '/^#+[[:space:]].*[Oo]pen questions/{p=1;next} /^#+[[:space:]]/{p=0} p && /^[0-9]+\./ && !/Answer:/{n++} END{print n+0}' "$spec")"
    vague="$( { grep -oiE '\b(fast|quick|easy|robust|scalable|secure|user-friendly|efficient|appropriate|as needed|etc\.|TBD|\?\?\?)\b' "$spec" || true; } | wc -l | tr -d ' ')"
    ambiguity=$((open_q + vague))

    # Task Completion Index + repair multiplier phi (implement re-entries).
    tdone=0; topen=0
    if [ -f "$design" ]; then
      tdone="$(grep -c -- '- \[x\]' "$design" || true)"
      topen="$(grep -c -- '- \[ \]' "$design" || true)"
    fi
    ttot=$((tdone + topen)); tci_pct="$(pct "$tdone" "$ttot")"
    impl_entries=0
    [ -f "$log" ] && impl_entries="$(grep -c 'phase=implement' "$log" || true)"
    loops=$((impl_entries > 0 ? impl_entries - 1 : 0))
    phi="1.$(( loops * 5 ))"; [ "$loops" -eq 0 ] && phi="1.0"

    verdict() { [ "$1" = "1" ] && echo "PASS" || echo "WARN"; }
    gate="PASS"
    [ "$fidelity_pct" -eq 100 ] && [ "$fidelity_t" -gt 0 ] || gate="FAIL"
    [ "$open_q" -eq 0 ] || gate="FAIL"

    echo "Governance scorecard — '$slug'  (phase: $phase)"
    echo "  Spec Fidelity        : $fidelity_c/$fidelity_t mapped in traceability   (${fidelity_pct}%)  [$( [ "$fidelity_pct" -eq 100 ] && [ "$fidelity_t" -gt 0 ] && echo PASS || echo WARN)]"
    echo "  AC Test Coverage     : $ac_tested/$ac_total criteria have a test        (${ac_pct}%)  [$( [ "$ac_pct" -eq 100 ] && [ "$ac_total" -gt 0 ] && echo PASS || echo WARN)]"
    echo "  Ambiguity Tax        : $open_q open question(s) + $vague vague term(s) = $ambiguity  [$( [ "$ambiguity" -eq 0 ] && echo PASS || echo WARN)]"
    echo "  Task Completion (TCI): $tdone/$ttot tasks done                           (${tci_pct}%)"
    echo "  Repair multiplier φ  : implement re-entries=$loops  (φ=$phi)"
    echo "  ------------------------------------------------------------"
    echo "  RELEASE GATE         : $gate   (requires Spec Fidelity 100% and 0 open questions)"
    [ "$gate" = "PASS" ] || exit 1
    ;;

  doctor)
    echo "SDLC environment check:"
    rc=0
    if has bash; then echo "  [ok] bash"; else echo "  [MISSING] bash"; rc=1; fi
    if has jq; then echo "  [ok] jq (fast JSON)"; elif has python3 || has python; then
      echo "  [ok] python3/python (JSON fallback)"; else
      echo "  [MISSING] need jq OR python3 for the hooks"; rc=1; fi
    has git && echo "  [ok] git" || echo "  [warn] git not found (review/release phases need it)"
    exit $rc
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
