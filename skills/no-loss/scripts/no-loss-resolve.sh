#!/usr/bin/env bash
# no-loss-resolve.sh — deterministic setup + facts for the /no-loss skill.
# Resolves the target .claude dir (cwd-independent), creates .claude/no-loss/,
# self-ignores it, and emits KEY=VALUE facts on stdout. Writes NO checkpoint —
# the model does that via the schema in references/checkpoint-schema.md.
set -euo pipefail

cwd="$(pwd -P)"
[ "$cwd" = "/" ] && { echo "no-loss-resolve: refusing to run from filesystem root" >&2; exit 1; }

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
mkdir -p "$dir" || { printf 'no-loss-resolve: cannot create %s\n' "$dir" >&2; exit 1; }
printf '*\n' > "$dir/.gitignore"                       # self-ignore: cwd/repo-root independent

# --- Git facts ----------------------------------------------------------------
# git_present="no" covers BOTH "git not installed" and "not a work tree" — the
# skill degrades identically for either, so they need not be distinguished.
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_present="yes"
  branch="$(git branch --show-current 2>/dev/null)"    # empty on detached HEAD / commit-less repo
  [ -n "$branch" ] || branch="(detached-or-empty)"
else
  git_present="no"
  branch=""
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Emit facts (KEY=VALUE) ---------------------------------------------------
# %q shell-quotes path/branch values so the consumer's `eval` reconstructs them
# exactly even with spaces or special chars (and neutralises eval injection).
# GIT_PRESENT and TIMESTAMP are fixed-format tokens, so plain %s is safe.
printf 'CLAUDE_DIR=%q\n' "$claude_dir"
printf 'NO_LOSS_DIR=%q\n' "$dir"
printf 'CONTEXT_LOG=%q\n' "$claude_dir/context-log.md"
printf 'GIT_PRESENT=%s\n' "$git_present"
printf 'BRANCH=%q\n' "$branch"
printf 'TIMESTAMP=%s\n' "$ts"
