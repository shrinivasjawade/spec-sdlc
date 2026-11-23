#!/usr/bin/env bash
# PreToolUse (Bash): blocks destructive, secret-leaking or deploy commands.
# Exit 2 = block the command and tell Claude why. Exit 0 = allow.
source "$(dirname "$0")/lib.sh"

INPUT="$(cat)"
CMD="$(json_field "$INPUT" tool_input.command)"
[ -z "$CMD" ] && exit 0

deny() { block "BLOCKED by SDLC guard: $1. Command was: $CMD"; }
matches() { printf '%s' "$CMD" | grep -Eiq -- "$1"; }

S='[[:space:]]'

# 1. Destructive file operations
matches "rm$S+(-[a-z]*r[a-z]*f?|-[a-z]*f[a-z]*r|--recursive)$S+(--?[a-z-]+$S+)*(/|~|\\\$HOME|\\*|\\.)($S|/?$|;|&)" \
  && deny "recursive delete of /, ~, \$HOME, * or . is not allowed"
matches "chmod$S+(-R$S+)?777" && deny "chmod 777 is not allowed"
matches "(^|$S|;|&)(mkfs|dd$S+if=)" && deny "disk-level commands are not allowed"

# 2. Git history and branch protection
matches "git$S+push.*(--force([^-]|$)|$S-f($S|$))" && deny "force push is not allowed (use --force-with-lease on your own branch, by hand)"
matches "git$S+push($S+[^ ]+)*$S+(origin$S+)?(main|master)($S|$)" && deny "pushing directly to main/master is not allowed; open a pull request"
if matches "git$S+push"; then
  BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  case "$BRANCH" in main|master) deny "you are on '$BRANCH'; create a feature branch and open a pull request instead of pushing" ;; esac
fi
matches "git$S+reset$S+--hard" && deny "git reset --hard discards work; ask the user to run it themselves"
matches "git$S+clean$S+-[a-z]*f" && deny "git clean -f deletes untracked files; ask the user first"
matches "--no-verify" && deny "skipping git hooks with --no-verify is not allowed"

# 3. Deploy / publish: humans only
matches "(^|$S|;|&)(npm|pnpm|yarn)$S+publish" && deny "publishing packages is a human-only step"
matches "docker$S+push|terraform$S+(apply|destroy)|kubectl$S+(apply|delete)|helm$S+(install|upgrade|uninstall)" \
  && deny "deploy commands are a human-only step (release phase prepares, humans ship)"

# 4. Databases
matches "drop$S+(table|database|schema)|truncate$S+table" && deny "destructive SQL is not allowed from the agent"

# 5. Remote code execution and secrets
matches "(curl|wget)[^|]*\\|$S*(sudo$S+)?(ba|z)?sh" && deny "piping a download into a shell is not allowed"
matches "(cat|less|more|head|tail|bat|grep|source|\\.)$S+[^|;&]*\\.env($S|$|\\.(local|prod|production|development))" \
  && deny "reading .env files is not allowed; use .env.example for variable names"
matches "(^|$S)(printenv|env)($S*$|$S*\\|)" && deny "dumping all environment variables can leak secrets"

exit 0
