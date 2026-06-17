#!/usr/bin/env bash
# no-loss-resolve.sh — deterministic setup + facts for the /no-loss skill.
# Resolves the target .claude dir (cwd-independent), creates .claude/no-loss/,
# self-ignores it, and emits KEY=VALUE facts on stdout. Writes NO checkpoint —
# the model does that via the schema in references/checkpoint-schema.md.
set -euo pipefail

cwd="$(pwd -P)"

# --- Resolve CLAUDE_DIR -------------------------------------------------------
claude_dir=""
if [ "$(basename "$cwd")" = ".claude" ]; then
  claude_dir="$cwd"                                    # already inside a .claude
else
  d="$cwd"                                             # walk up to nearest existing .claude/
  while [ "$d" != "/" ]; do
    if [ -d "$d/.claude" ]; then claude_dir="$d/.claude"; break; fi
    d="$(dirname "$d")"
  done
fi
if [ -z "$claude_dir" ]; then                          # none found → git toplevel, else cwd
  if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    claude_dir="$root/.claude"
  else
    claude_dir="$cwd/.claude"
  fi
fi

dir="$claude_dir/no-loss"
mkdir -p "$dir"
printf '*\n' > "$dir/.gitignore"                       # self-ignore: cwd/repo-root independent

# --- Git facts ----------------------------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_present="yes"
  branch="$(git branch --show-current 2>/dev/null || echo "(detached)")"
else
  git_present="no"
  branch=""
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Emit facts (KEY=VALUE, eval-friendly) ------------------------------------
printf 'CLAUDE_DIR=%s\n' "$claude_dir"
printf 'NO_LOSS_DIR=%s\n' "$dir"
printf 'CONTEXT_LOG=%s\n' "$claude_dir/context-log.md"
printf 'GIT_PRESENT=%s\n' "$git_present"
printf 'BRANCH=%s\n' "$branch"
printf 'TIMESTAMP=%s\n' "$ts"
