#!/usr/bin/env bash
# Unit tests for no-loss-resolve.sh — proves the two P0 guards and the degrade paths.
# Plain bash, no bats. Each case runs the script in a subshell (so cwd changes are
# contained) but eval's its KEY=VALUE output into THIS shell, so assertions update
# the parent's fail counter.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/no-loss-resolve.sh"
fails=0

assert_eq() { # actual expected label
  if [ "$1" = "$2" ]; then echo "ok: $3"; else echo "FAIL: $3 (got '$1', want '$2')"; fails=$((fails+1)); fi
}
assert_true() { # cmd... label(last arg)
  local label="${@: -1}"; set -- "${@:1:$#-1}"
  if "$@"; then echo "ok: $label"; else echo "FAIL: $label"; fails=$((fails+1)); fi
}
run() { ( cd "$1" && bash "$SCRIPT" ); }   # prints KEY=VALUE lines

# --- Case A: basename==.claude → target IS cwd, no nested .claude/.claude ----
t="$(cd "$(mktemp -d)" && pwd -P)"; mkdir -p "$t/proj/.claude"
eval "$(run "$t/proj/.claude")"
assert_eq "$CLAUDE_DIR" "$t/proj/.claude" "A: basename==.claude resolves to cwd"
assert_true [ -d "$t/proj/.claude/no-loss" ] "A: no-loss dir created"
assert_true [ ! -d "$t/proj/.claude/.claude" ] "A: no nested .claude/.claude"

# --- Case B: monorepo subdir, .claude at repo root, self-ignore holds --------
t="$(cd "$(mktemp -d)" && pwd -P)"; ( cd "$t" && git init -q ); mkdir -p "$t/.claude" "$t/sub"
eval "$(run "$t/sub")"
assert_eq "$CLAUDE_DIR" "$t/.claude" "B: walk-up from subdir finds root .claude"
echo "secret" > "$NO_LOSS_DIR/probe.md"
assert_true git -C "$t" check-ignore -q "$NO_LOSS_DIR/probe.md" "B: checkpoint file is gitignored"

# --- Case C: walk-up picks the NEAREST .claude ------------------------------
t="$(cd "$(mktemp -d)" && pwd -P)"; mkdir -p "$t/.claude" "$t/a/.claude" "$t/a/b"
eval "$(run "$t/a/b")"
assert_eq "$CLAUDE_DIR" "$t/a/.claude" "C: nearest .claude wins over higher one"

# --- Case D: non-git, no .claude anywhere → create at cwd, GIT_PRESENT=no ----
t="$(cd "$(mktemp -d)" && pwd -P)"; mkdir -p "$t/plain"
eval "$(run "$t/plain")"
assert_eq "$CLAUDE_DIR" "$t/plain/.claude" "D: no .claude + no git → cwd/.claude"
assert_eq "$GIT_PRESENT" "no" "D: git absence reported"

# --- Case E: git repo, no .claude → create at git toplevel ------------------
t="$(cd "$(mktemp -d)" && pwd -P)"; ( cd "$t" && git init -q ); mkdir -p "$t/deep/er"
eval "$(run "$t/deep/er")"
assert_eq "$CLAUDE_DIR" "$t/.claude" "E: git root chosen when no .claude exists"
assert_eq "$GIT_PRESENT" "yes" "E: git presence reported"

# --- Case F: idempotent rerun (mkdir + gitignore overwrite-safe) -------------
eval "$(run "$t/deep/er")"
assert_eq "$(cat "$NO_LOSS_DIR/.gitignore")" "*" "F: self-ignore content is '*' after rerun"

echo "----"
if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi
