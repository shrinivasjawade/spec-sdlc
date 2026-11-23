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
