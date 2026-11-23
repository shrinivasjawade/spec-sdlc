#!/usr/bin/env bash
# Shim. The shared hook/script helpers live in the tool-neutral core at
# sdlc/scripts/lib.sh (single source of truth). This file is sourced, not run.
source "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/sdlc/scripts/lib.sh"
