#!/usr/bin/env bash
# WorktreeRemove hook: tears down the worktree created by worktree-create.sh.
# For fake (copy-based) worktrees, marked with .claude-fake-worktree, we
# rm -rf the directory. For real git worktrees we call `git worktree remove`.
#
# Contract: exit code is advisory (WorktreeRemove cannot block).

set -euo pipefail

input=$(cat)
worktree_path=$(printf '%s' "$input" | jq -r '.worktree_path // empty')

if [[ -z "$worktree_path" || ! -e "$worktree_path" ]]; then
  exit 0
fi

# Sanity: only operate under the known fallback root or a git-managed worktree.
root="${CLAUDE_WORKTREE_FALLBACK_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-worktrees}"

if [[ -f "$worktree_path/.claude-fake-worktree" ]]; then
  case "$worktree_path" in
    "$root"/*) rm -rf -- "$worktree_path" ;;
    *) echo "worktree-remove: refusing to rm outside $root ($worktree_path)" >&2 ;;
  esac
  exit 0
fi

if git -C "$worktree_path" rev-parse --git-common-dir >/dev/null 2>&1; then
  common=$(git -C "$worktree_path" rev-parse --git-common-dir)
  case "$common" in /*) ;; *) common="$worktree_path/$common" ;; esac
  main_repo=$(dirname "$common")
  git -C "$main_repo" worktree remove --force "$worktree_path" >&2 || rm -rf -- "$worktree_path"
else
  case "$worktree_path" in
    "$root"/*) rm -rf -- "$worktree_path" ;;
  esac
fi
exit 0
