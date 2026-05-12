#!/usr/bin/env bash
# WorktreeCreate hook: uses `git worktree add` when base_path is inside a git
# repo, otherwise falls back to an rsync/cp copy under a cache directory so
# worktree-isolated agents can run in non-git working directories too.
#
# Contract (per Claude Code hooks docs):
#   stdin  : JSON with base_path, worktree_name, target_branch, cwd, ...
#   stdout : single line with absolute path to the prepared worktree
#   stderr : informational only
#   exit   : 0 on success, non-zero to fail worktree creation

set -euo pipefail

input=$(cat)
base_path=$(printf '%s' "$input" | jq -r '.base_path // .cwd // empty')
worktree_name=$(printf '%s' "$input" | jq -r '.worktree_name // empty')
target_branch=$(printf '%s' "$input" | jq -r '.target_branch // empty')

if [[ -z "$base_path" ]]; then
  echo "worktree-create: no base_path or cwd in hook input" >&2
  exit 1
fi

if [[ -z "$worktree_name" ]]; then
  worktree_name="agent-$(date +%s)-$$"
fi
worktree_name=$(printf '%s' "$worktree_name" | tr -c 'A-Za-z0-9._-' '_')

root="${CLAUDE_WORKTREE_FALLBACK_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-worktrees}"
mkdir -p "$root"
worktree_path="$root/${worktree_name}-$$-$(date +%s)"

if git -C "$base_path" rev-parse --git-dir >/dev/null 2>&1; then
  if [[ -n "$target_branch" ]] && git -C "$base_path" show-ref --verify --quiet "refs/heads/$target_branch"; then
    git -C "$base_path" worktree add --detach "$worktree_path" "$target_branch" >&2
  elif [[ -n "$target_branch" ]]; then
    git -C "$base_path" worktree add -b "$target_branch" "$worktree_path" HEAD >&2
  else
    git -C "$base_path" worktree add --detach "$worktree_path" HEAD >&2
  fi
  printf '%s\n' "$worktree_path"
  exit 0
fi

# Non-git fallback: rsync/cp a filtered copy and mark it with a sentinel
# so the remove hook knows to rm -rf instead of calling git.
if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='.venv/' \
    --exclude='__pycache__/' \
    --exclude='.mypy_cache/' \
    --exclude='.pytest_cache/' \
    --exclude='.ruff_cache/' \
    --exclude='target/' \
    --exclude='dist/' \
    --exclude='build/' \
    --exclude='.next/' \
    --exclude='.turbo/' \
    "$base_path"/ "$worktree_path"/ >&2
else
  mkdir -p "$worktree_path"
  cp -a "$base_path/." "$worktree_path/" >&2
fi

touch "$worktree_path/.claude-fake-worktree"
printf '%s\n' "$worktree_path"
