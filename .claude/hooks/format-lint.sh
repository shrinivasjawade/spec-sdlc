#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): formats the changed file and lints it.
# Lint errors are fed back to Claude (exit 2) so it fixes them immediately.
# Tools are used only if they are installed in the project; nothing is installed.
source "$(dirname "$0")/lib.sh"

INPUT="$(cat)"
FILE="$(json_field "$INPUT" tool_input.file_path)"
# Nothing to do if there is no file path or the file no longer exists.
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then exit 0; fi
cd "$ROOT" || exit 0
REL="$(rel_path "$FILE")"

# Optional override in .claude/settings.json -> "env": { "SDLC_LINT_CMD": "..." }
# The file path is appended to the command.
if [ -n "${SDLC_LINT_CMD:-}" ]; then
  if ! OUT="$(bash -c "$SDLC_LINT_CMD \"\$1\"" _ "$FILE" 2>&1)"; then
    block "Lint failed for $REL. Fix these before moving on:
$(printf '%s\n' "$OUT" | head -n 40)"
  fi
  exit 0
fi

lint() {  # lint <command...> : run a linter, feed failures back to Claude
  local out
  if ! out="$("$@" 2>&1)"; then
    block "Lint failed for $REL. Fix these before moving on:
$(printf '%s\n' "$out" | head -n 40)"
  fi
}

BIN="node_modules/.bin"
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte)
    [ -x "$BIN/prettier" ] && "$BIN/prettier" --write "$FILE" >/dev/null 2>&1
    [ -x "$BIN/eslint" ] && lint "$BIN/eslint" --no-warn-ignored "$FILE"
    ;;
  *.json|*.css|*.scss|*.html|*.yml|*.yaml)
    [ -x "$BIN/prettier" ] && "$BIN/prettier" --write "$FILE" >/dev/null 2>&1
    ;;
  *.py)
    if has ruff; then
      ruff format -q "$FILE" >/dev/null 2>&1
      lint ruff check -q "$FILE"
    elif has black; then
      black -q "$FILE" >/dev/null 2>&1
      has flake8 && lint flake8 "$FILE"
    fi
    ;;
  *.go)
    has gofmt && gofmt -w "$FILE" 2>/dev/null
    ;;
  *.rs)
    has rustfmt && rustfmt --edition 2021 "$FILE" 2>/dev/null
    ;;
  # Java, C#, PHP, etc.: set SDLC_LINT_CMD (e.g. a checkstyle or spotless command).
esac

exit 0
