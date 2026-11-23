#!/usr/bin/env bash
# Shared helpers for the SDLC hooks and scripts. This file is sourced, not run.

# Project root: Claude Code sets CLAUDE_PROJECT_DIR for hooks. When this file is
# sourced from elsewhere (e.g. the Bash tool), fall back to two levels above it.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  ROOT="$CLAUDE_PROJECT_DIR"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
SDLC_DIR="$ROOT/docs/sdlc"
SDLC_STATE="$SDLC_DIR/current.json"

has() { command -v "$1" >/dev/null 2>&1; }

# json_field <json-string> <dotted.path>
# Prints the value at the path, or nothing if missing. Uses jq, falls back to Python.
json_field() {
  local json="$1" path="$2" py
  if has jq; then
    printf '%s' "$json" | jq -r --arg p "$path" \
      'getpath($p | split(".")) | if . == null then empty else (if type == "object" or type == "array" then tojson else tostring end) end' 2>/dev/null
    return 0
  fi
  py="$(command -v python3 || command -v python || true)"
  [ -z "$py" ] && return 0
  printf '%s' "$json" | "$py" -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
if d is None:
    sys.exit(0)
if isinstance(d, bool):
    print(str(d).lower())
elif isinstance(d, (dict, list)):
    print(json.dumps(d))
else:
    print(d)
' "$path" 2>/dev/null
}

# sdlc_get <field>  ->  value from docs/sdlc/current.json (feature | phase | updated)
sdlc_get() {
  [ -f "$SDLC_STATE" ] || return 0
  json_field "$(cat "$SDLC_STATE")" "$1"
}

# block <reason>  ->  exit code 2 = blocking; stderr is fed back to Claude.
block() {
  echo "$1" >&2
  exit 2
}

# rel_path <absolute-path>  ->  path relative to the project root
rel_path() {
  local p="$1"
  case "$p" in
    "$ROOT"/*) printf '%s' "${p#"$ROOT"/}" ;;
    *) printf '%s' "$p" ;;
  esac
}

# sdlc_trace_section <design-file>  ->  prints ONLY the Traceability table section,
# i.e. the lines from a "## ... Traceability" heading up to the next heading. This
# is what makes trace/verify check mappings, not stray mentions elsewhere.
sdlc_trace_section() {
  awk 'BEGIN{p=0}
       /^#+[[:space:]].*[Tt]raceability/{p=1; next}
       /^#+[[:space:]]/{ if(p) exit }
       p{print}' "$1" 2>/dev/null || true
}

# sdlc_spec_ids <spec-file>  ->  sorted unique AC-*/NFR-* ids found in the spec.
sdlc_spec_ids() {
  grep -oE '(AC-[0-9]+\.[0-9]+|NFR-[0-9]+)' "$1" 2>/dev/null | sort -u || true
}

# pct <n> <d>  ->  integer percentage (0 when d==0).
pct() { if [ "${2:-0}" -gt 0 ]; then echo $(( $1 * 100 / $2 )); else echo 0; fi; }

# coverage <spec> <design>  ->  "covered total missing..." using the Traceability table.
coverage() {
  local spec="$1" design="$2" section ids id covered=0 total=0 missing=""
  ids="$(sdlc_spec_ids "$spec")"
  section="$(sdlc_trace_section "$design")"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    total=$((total + 1))
    if printf '%s' "$section" | grep -q -- "$id"; then covered=$((covered + 1)); else missing="$missing $id"; fi
  done <<EOF
$ids
EOF
  echo "$covered $total$missing"
}

# sdlc_scorecard <spec> <design> <log>  ->  one line of raw numbers:
#   fidelity_covered fidelity_total ac_tested ac_total open_q vague tasks_done tasks_open loops gate
sdlc_scorecard() {
  local spec="$1" design="$2" log="$3"
  local fc=0 ft=0 ac_t=0 ac_c=0 oq=0 vg=0 td=0 to=0 loops=0 gate=FAIL section ids id row tcell impl=0
  [ -f "$spec" ] || { echo "0 0 0 0 0 0 0 0 0 FAIL"; return 0; }
  if [ -f "$design" ]; then read -r fc ft _ <<<"$(coverage "$spec" "$design")"; fi
  ids="$(sdlc_spec_ids "$spec")"
  ac_t="$(printf '%s\n' "$ids" | grep -c '^AC-' || true)"
  section="$(sdlc_trace_section "$design")"
  while IFS= read -r id; do
    case "$id" in AC-*) ;; *) continue ;; esac
    row="$(printf '%s\n' "$section" | grep -E "^\|[[:space:]]*$id[[:space:]]*\|" | head -n1 || true)"
    tcell="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/,"",$4); print $4}')"
    case "$tcell" in ""|"-"|"TBD"|"...") ;; *) ac_c=$((ac_c + 1)) ;; esac
  done <<EOF
$ids
EOF
  oq="$(awk '/^#+[[:space:]].*[Oo]pen questions/{p=1;next} /^#+[[:space:]]/{p=0} p && /^[0-9]+\./ && !/Answer:/{n++} END{print n+0}' "$spec" 2>/dev/null || echo 0)"
  vg="$( { grep -oiE '\b(fast|quick|easy|robust|scalable|secure|user-friendly|efficient|appropriate|as needed|etc\.|TBD|\?\?\?)\b' "$spec" 2>/dev/null || true; } | wc -l | tr -d ' ')"
  if [ -f "$design" ]; then td="$(grep -c -- '- \[x\]' "$design" || true)"; to="$(grep -c -- '- \[ \]' "$design" || true)"; fi
  [ -f "$log" ] && impl="$(grep -c 'phase=implement' "$log" || true)"
  loops=$(( impl > 0 ? impl - 1 : 0 ))
  if [ "$ft" -gt 0 ] && [ "$fc" -eq "$ft" ] && [ "$oq" -eq 0 ]; then gate=PASS; fi
  echo "$fc $ft $ac_c $ac_t $oq $vg $td $to $loops $gate"
}

# gen_dashboard <feature>  ->  writes docs/sdlc/<feature>/dashboard.html from the
# template with the live snapshot injected. Best-effort; no-op without the template.
gen_dashboard() {
  local feature="$1"
  local tpl="$ROOT/sdlc/dashboard/index.html"
  local dir="$SDLC_DIR/$feature"
  [ -f "$tpl" ] || return 0
  local spec="$dir/01-requirements.md" design="$dir/02-design.md" log="$dir/activity.log"
  local phase; phase="$(sdlc_get phase 2>/dev/null)"; [ -z "$phase" ] && phase="requirements"
  local fc ft ac_c ac_t oq vg td to loops gate
  read -r fc ft ac_c ac_t oq vg td to loops gate <<<"$(sdlc_scorecard "$spec" "$design" "$log")"
  local fpct apct tpct ts json
  fpct="$(pct "$fc" "$ft")"; apct="$(pct "$ac_c" "$ac_t")"; tpct="$(pct "$td" $((td + to)))"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  json="$(printf '{"feature":"%s","phase":"%s","generated":"%s","blocked":false,"tasks":{"done":%s,"open":%s},"trace":{"covered":%s,"total":%s},"metrics":{"fidelity_pct":%s,"ac_pct":%s,"tci_pct":%s,"ambiguity":%s,"gate":"%s"}}' \
    "$feature" "$phase" "$ts" "$td" "$to" "$fc" "$ft" "$fpct" "$apct" "$tpct" "$((oq + vg))" "$gate")"
  mkdir -p "$dir"
  awk -v j="window.SDLC_STATE = $json;" '
    /\/\*__SDLC_STATE__\*\// { print j " /*__SDLC_STATE__*/"; next } { print }' \
    "$tpl" > "$dir/dashboard.html" 2>/dev/null || true
}
