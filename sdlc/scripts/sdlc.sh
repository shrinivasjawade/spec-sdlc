#!/usr/bin/env bash
# SDLC state + governance helper. Hooks read the state this script writes.
#
#   start <slug>        new/resumed feature (phase = requirements); parks any active one
#   phase <phase>       move the active feature to a phase
#   status              show the active feature, phase and artifacts
#   list                list every feature and its phase (active marked *)
#   switch <slug>       make another feature the active one (parallel work)
#   ready [slug]        Definition of Ready check before design
#   trace [slug]        every spec ID must be mapped in the design's Traceability table
#   verify [slug] [--deep]   validate the traceability contract (emit trace.json); --deep greps the repo for each test
#   metrics [slug]      governance scorecard + release gate
#   deps                dependency / supply-chain scan (best-effort, advisory)
#   ci [slug]           CI gate: verify + metrics for a feature (or all); non-zero on failure
#   dashboard [slug]    (re)build the visual pipeline HTML
#   doctor              check required tooling is present
#   finish              close the active feature
#
# Phases: requirements -> design -> implement -> test -> review -> release -> maintain
set -euo pipefail
source "$(dirname "$0")/lib.sh"

PHASES="requirements design implement test review release maintain"

write_state() {  # write_state <feature> <phase>
  mkdir -p "$SDLC_DIR/$1"
  printf '{\n  "feature": "%s",\n  "phase": "%s",\n  "updated": "%s"\n}\n' \
    "$1" "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SDLC_STATE"
  printf '%s' "$2" > "$SDLC_DIR/$1/.phase"   # per-feature phase, so switch can restore it
  printf '%s  phase=%-12s (state change)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" \
    >> "$SDLC_DIR/$1/activity.log"
  gen_dashboard "$1" || true   # keep the visual dashboard current on every advance
}

require_feature() {
  if [ ! -f "$SDLC_STATE" ]; then
    echo "No feature in progress. Start one: bash sdlc/scripts/sdlc.sh start <slug>" >&2
    exit 1
  fi
}

open_questions() { awk '/^#+[[:space:]].*[Oo]pen questions/{p=1;next} /^#+[[:space:]]/{p=0} p && /^[0-9]+\./ && !/Answer:/{n++} END{print n+0}' "$1" 2>/dev/null || echo 0; }

cmd="${1:-status}"
case "$cmd" in
  start)
    raw="${2:?usage: sdlc.sh start <feature-slug>}"
    slug="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    [ -z "$slug" ] && { echo "Invalid slug: $raw" >&2; exit 1; }
    if [ -f "$SDLC_STATE" ] && [ "$(sdlc_get feature)" != "$slug" ]; then
      echo "Parking active feature '$(sdlc_get feature)' (resume with: sdlc.sh switch $(sdlc_get feature))."
    fi
    if [ -f "$SDLC_DIR/$slug/.phase" ]; then
      write_state "$slug" "$(cat "$SDLC_DIR/$slug/.phase")"
      echo "Resumed feature '$slug' at phase '$(cat "$SDLC_DIR/$slug/.phase")'."
    else
      write_state "$slug" requirements
      echo "Started feature '$slug' in phase 'requirements'. Artifacts: docs/sdlc/$slug/"
    fi
    ;;

  phase)
    require_feature
    new="${2:?usage: sdlc.sh phase <$(echo $PHASES | tr ' ' '|')>}"
    case " $PHASES " in
      *" $new "*) ;;
      *) echo "Unknown phase '$new'. Valid: $PHASES" >&2; exit 1 ;;
    esac
    feature="$(sdlc_get feature)"; old="$(sdlc_get phase)"
    write_state "$feature" "$new"
    echo "Feature '$feature': $old -> $new"
    ;;

  list)
    active="$(sdlc_get feature 2>/dev/null || true)"; found=0
    if [ -d "$SDLC_DIR" ]; then
      for d in "$SDLC_DIR"/*/; do
        [ -d "$d" ] || continue; f="$(basename "$d")"; found=1
        ph="?"; [ -f "$d/.phase" ] && ph="$(cat "$d/.phase")"
        mark="  "; [ "$f" = "$active" ] && mark="* "
        printf '%s%-30s %s\n' "$mark" "$f" "$ph"
      done
    fi
    [ "$found" -eq 0 ] && echo "No features yet. Start one: sdlc.sh start <slug>"
    ;;

  switch)
    slug="${2:?usage: sdlc.sh switch <slug>}"
    [ -d "$SDLC_DIR/$slug" ] || { echo "Unknown feature '$slug'. See: sdlc.sh list" >&2; exit 1; }
    ph="requirements"; [ -f "$SDLC_DIR/$slug/.phase" ] && ph="$(cat "$SDLC_DIR/$slug/.phase")"
    write_state "$slug" "$ph"
    echo "Active feature is now '$slug' (phase: $ph)."
    ;;

  status)
    [ -f "$SDLC_STATE" ] || { echo "No feature in progress."; exit 0; }
    feature="$(sdlc_get feature)"
    echo "Feature: $feature"
    echo "Phase:   $(sdlc_get phase)   (updated $(sdlc_get updated))"
    echo "Artifacts in docs/sdlc/$feature/:"
    ls -1 "$SDLC_DIR/$feature" 2>/dev/null | grep -v '^\.phase$' | sed 's/^/  - /' || true
    design="$SDLC_DIR/$feature/02-design.md"; spec="$SDLC_DIR/$feature/01-requirements.md"
    if [ -f "$design" ]; then
      echo "Tasks:   $(grep -c -- '- \[x\]' "$design" || true) done, $(grep -c -- '- \[ \]' "$design" || true) open"
    fi
    if [ -f "$spec" ] && [ -f "$design" ]; then
      read -r c t _ <<<"$(coverage "$spec" "$design")"
      [ "${t:-0}" -gt 0 ] && echo "Trace:   $c/$t spec requirements mapped in the design's Traceability table"
    fi
    ;;

  ready)
    # Definition of Ready: is the spec good enough to start design?
    slug="${2:-$(sdlc_get feature 2>/dev/null || true)}"
    [ -z "$slug" ] && { echo "No feature; give a slug." >&2; exit 1; }
    spec="$SDLC_DIR/$slug/01-requirements.md"
    [ -f "$spec" ] || { echo "No spec for '$slug'." >&2; exit 1; }
    ac="$(sdlc_spec_ids "$spec" | grep -c '^AC-' || true)"
    oq="$(open_questions "$spec")"; n=0
    echo "Definition of Ready — '$slug':"
    if [ "$ac" -ge 1 ]; then echo "  [ok] $ac acceptance criteria (AC-*)"; else echo "  [MISS] no acceptance criteria"; n=$((n+1)); fi
    if [ "$oq" -eq 0 ]; then echo "  [ok] no unresolved open questions"; else echo "  [MISS] $oq open question(s) unresolved"; n=$((n+1)); fi
    if grep -qiE '^#+ .*(problem|goal)' "$spec"; then echo "  [ok] problem / goal stated"; else echo "  [MISS] no Problem/Goal section"; n=$((n+1)); fi
    [ "$n" -eq 0 ] && { echo "READY for design."; } || { echo "NOT READY ($n issue(s) above)." >&2; exit 1; }
    ;;

  trace)
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    spec="$SDLC_DIR/$slug/01-requirements.md"; design="$SDLC_DIR/$slug/02-design.md"
    [ -f "$spec" ] || { echo "No spec at $spec" >&2; exit 1; }
    ids="$(sdlc_spec_ids "$spec")"
    [ -z "$ids" ] && { echo "No requirement IDs (AC-*/NFR-*) found in the spec." >&2; exit 1; }
    [ -f "$design" ] || { echo "Spec has IDs but there is no design yet ($design)." >&2; exit 1; }
    section="$(sdlc_trace_section "$design")"
    [ -z "$section" ] && { echo "No Traceability table found in $design (expected a '## ... Traceability' section)." >&2; exit 1; }
    read -r covered total rest <<<"$(coverage "$spec" "$design")"; missing="$rest"
    orphans=""
    for tid in $(printf '%s' "$section" | grep -oE '(AC-[0-9]+\.[0-9]+|NFR-[0-9]+)' | sort -u); do
      printf '%s\n' "$ids" | grep -qx -- "$tid" || orphans="$orphans $tid"
    done
    echo "Traceability for '$slug': $covered/$total spec requirements mapped in the Traceability table."
    [ -n "$orphans" ] && echo "Orphan mappings (in table but not in spec):$orphans" >&2
    if [ -n "$missing" ]; then echo "NOT mapped in the Traceability table:$missing" >&2; exit 1; fi
    echo "All spec requirements are mapped in the design's Traceability table."
    ;;

  verify)
    deep=0; slug=""
    for a in "${@:2}"; do case "$a" in --deep) deep=1 ;; *) [ -z "$slug" ] && slug="$a" ;; esac; done
    [ -z "$slug" ] && slug="$(sdlc_get feature 2>/dev/null || true)"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    spec="$SDLC_DIR/$slug/01-requirements.md"; design="$SDLC_DIR/$slug/02-design.md"
    out="$SDLC_DIR/$slug/trace.json"
    [ -f "$spec" ] && [ -f "$design" ] || { echo "Need both spec and design for '$slug'." >&2; exit 1; }
    section="$(sdlc_trace_section "$design")"
    [ -z "$section" ] && { echo "No Traceability table found in $design." >&2; exit 1; }
    ids="$(sdlc_spec_ids "$spec")"; problems=0
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    {
      printf '{\n  "feature": "%s",\n  "generated": "%s",\n  "requirements": [\n' "$slug" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      first=1
      while IFS= read -r id; do
        [ -z "$id" ] && continue
        row="$(printf '%s\n' "$section" | grep -E "^\|[[:space:]]*$id[[:space:]]*\|" | head -n1 || true)"
        tasks=""; tests=""; status="ok"
        if [ -z "$row" ]; then status="no-row"; problems=$((problems + 1))
        else
          tasks="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')"
          tests="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')"
          case "$tasks" in ""|"-"|"TBD"|"...") status="no-task"; problems=$((problems + 1)) ;; esac
          case "$tests" in ""|"-"|"TBD"|"...") status="no-test"; problems=$((problems + 1)) ;; esac
        fi
        [ $first -eq 1 ] || printf ',\n'; first=0
        printf '    { "id": "%s", "tasks": "%s", "tests": "%s", "status": "%s" }' "$id" "$(esc "$tasks")" "$(esc "$tests")" "$status"
      done <<EOF
$ids
EOF
      printf '\n  ],\n  "problems": %s\n}\n' "$problems"
    } > "$out"
    echo "Wrote contract: $(rel_path "$out")"
    if [ "$deep" -eq 1 ]; then
      echo "Deep check (grepping the repo for each referenced test):"
      while IFS= read -r id; do
        case "$id" in AC-*) ;; *) continue ;; esac
        row="$(printf '%s\n' "$section" | grep -E "^\|[[:space:]]*$id[[:space:]]*\|" | head -n1 || true)"
        tests="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')"
        token="$(printf '%s' "$tests" | grep -oE '[A-Za-z0-9_./-]+\.(test|spec)[A-Za-z0-9_.]*|[A-Za-z0-9_]+\.(py|ts|js|go|rs|java)' | head -n1 || true)"
        [ -z "$token" ] && { echo "  [warn] $id: no test file reference to check"; continue; }
        if grep -rqIl --exclude-dir=.git --exclude-dir=node_modules -- "$token" "$ROOT" 2>/dev/null; then
          echo "  [ok]   $id -> found '$token' in the repo"
        else
          echo "  [warn] $id -> '$token' not found in the repo (test may not exist yet)"
        fi
      done <<EOF
$ids
EOF
    fi
    if [ "$problems" -gt 0 ]; then
      echo "Contract INVALID: $problems requirement(s) missing a row, task, or test mapping. See $(rel_path "$out")." >&2; exit 1
    fi
    echo "Contract VALID: every spec requirement maps to a task and a test."
    ;;

  metrics)
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    dir="$SDLC_DIR/$slug"; spec="$dir/01-requirements.md"; design="$dir/02-design.md"; log="$dir/activity.log"
    [ -f "$spec" ] || { echo "No spec for '$slug'." >&2; exit 1; }
    phase="$(sdlc_get phase 2>/dev/null || echo '?')"
    read -r fc ft ac_c ac_t oq vg td to loops gate <<<"$(sdlc_scorecard "$spec" "$design" "$log")"
    fpct="$(pct "$fc" "$ft")"; apct="$(pct "$ac_c" "$ac_t")"; tpct="$(pct "$td" $((td + to)))"
    amb=$((oq + vg)); phi="1.$(( loops * 5 ))"; [ "$loops" -eq 0 ] && phi="1.0"
    echo "Governance scorecard — '$slug'  (phase: $phase)"
    echo "  Spec Fidelity        : $fc/$ft mapped in traceability   (${fpct}%)  [$( [ "$fpct" -eq 100 ] && [ "$ft" -gt 0 ] && echo PASS || echo WARN)]"
    echo "  AC Test Coverage     : $ac_c/$ac_t criteria have a test        (${apct}%)  [$( [ "$apct" -eq 100 ] && [ "$ac_t" -gt 0 ] && echo PASS || echo WARN)]"
    echo "  Ambiguity Tax        : $oq open question(s) + $vg vague term(s) = $amb  [$( [ "$amb" -eq 0 ] && echo PASS || echo WARN)]"
    echo "  Task Completion (TCI): $td/$((td + to)) tasks done                           (${tpct}%)"
    echo "  Repair multiplier φ  : implement re-entries=$loops  (φ=$phi)"
    echo "  ------------------------------------------------------------"
    echo "  RELEASE GATE         : $gate   (requires Spec Fidelity 100% and 0 open questions)"
    [ "$gate" = "PASS" ] || exit 1
    ;;

  deps)
    # Dependency / supply-chain scan — best-effort, advisory (never blocks on its own).
    cd "$ROOT" 2>/dev/null || true
    ran=0
    echo "Dependency / supply-chain scan:"
    if [ -f package.json ] && has npm; then echo "--- npm audit ---"; npm audit 2>&1 | tail -n 25 || true; ran=1; fi
    if { [ -f requirements.txt ] || [ -f pyproject.toml ]; } && has pip-audit; then echo "--- pip-audit ---"; pip-audit 2>&1 | tail -n 25 || true; ran=1; fi
    if [ -f go.mod ] && has govulncheck; then echo "--- govulncheck ---"; govulncheck ./... 2>&1 | tail -n 25 || true; ran=1; fi
    if [ -f Cargo.toml ] && has cargo-audit; then echo "--- cargo audit ---"; cargo audit 2>&1 | tail -n 25 || true; ran=1; fi
    [ "$ran" -eq 0 ] && echo "  No applicable scanner found. Install one: npm audit, pip-audit, govulncheck, or cargo-audit."
    ;;

  ci)
    # The gate a CI job runs: verify + metrics for a feature (or every feature with a spec).
    slug="${2:-$(sdlc_get feature 2>/dev/null || true)}"
    rc=0
    run_one() { echo "=== feature: $1 ==="; bash "$0" verify "$1" || rc=1; bash "$0" metrics "$1" || rc=1; }
    if [ -n "$slug" ] && [ -d "$SDLC_DIR/$slug" ]; then
      run_one "$slug"
    else
      any=0
      if [ -d "$SDLC_DIR" ]; then
        for d in "$SDLC_DIR"/*/; do [ -d "$d" ] || continue; [ -f "$d/01-requirements.md" ] || continue; run_one "$(basename "$d")"; any=1; done
      fi
      [ "$any" -eq 0 ] && { echo "No features with a spec to gate."; exit 0; }
    fi
    echo "------------------------------------------------------------"
    [ "$rc" -eq 0 ] && echo "CI gate: PASS" || echo "CI gate: FAIL"
    exit $rc
    ;;

  dashboard)
    slug="${2:-$(sdlc_get feature)}"
    [ -z "$slug" ] && { echo "No feature in progress and no slug given." >&2; exit 1; }
    [ -f "$ROOT/sdlc/dashboard/index.html" ] || { echo "No dashboard template at sdlc/dashboard/index.html" >&2; exit 1; }
    [ -d "$SDLC_DIR/$slug" ] || { echo "Unknown feature '$slug'." >&2; exit 1; }
    gen_dashboard "$slug"
    echo "Dashboard written: $(rel_path "$SDLC_DIR/$slug/dashboard.html")  — open it in a browser."
    ;;

  doctor)
    echo "SDLC environment check:"; rc=0
    if has bash; then echo "  [ok] bash"; else echo "  [MISSING] bash"; rc=1; fi
    if has jq; then echo "  [ok] jq (fast JSON)"; elif has python3 || has python; then echo "  [ok] python3/python (JSON fallback)"; else echo "  [MISSING] need jq OR python3 for the hooks"; rc=1; fi
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
    sed -n '3,19p' "$0"
    exit 1
    ;;
esac
