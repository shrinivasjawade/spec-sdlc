#!/usr/bin/env bash
# Shim. The canonical state + governance helper lives in the tool-neutral core
# at sdlc/scripts/sdlc.sh, so Claude Code and every other tool share one copy.
DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
exec bash "$DIR/sdlc/scripts/sdlc.sh" "$@"
