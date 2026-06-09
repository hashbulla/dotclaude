#!/usr/bin/env bash
# audit-config.sh — executable invariants for the dotclaude config.
#
# Drift gate: the doctrine (best-practice/claude-memory.md) states a 200-line
# CLAUDE.md ceiling, but a number nothing checks is a wish. This is the check.
# HARD violations exit 1 (block the commit); warnings print but pass unless
# --strict. Wire into .git/hooks/pre-commit (see README) — drift enters via
# commits, so gate there.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$HOME/.claude}"
cd "$ROOT"

strict=0
[[ "${1:-}" == "--strict" ]] && strict=1

fail=0
warn=0
hard() { printf 'FAIL: %s\n' "$1" >&2; fail=1; }
soft() { printf 'WARN: %s\n' "$1" >&2; warn=1; }

# 1. CLAUDE.md <= 200 lines (hard); warn approaching the ceiling.
claude_lines=$(wc -l < CLAUDE.md)
if (( claude_lines > 200 )); then
  hard "CLAUDE.md is ${claude_lines} lines (ceiling 200). Relocate domain depth to rules/ or playbooks/."
elif (( claude_lines > 180 )); then
  soft "CLAUDE.md is ${claude_lines} lines (>180, approaching the 200 ceiling)."
fi

# 2. Each rules/*.md <= 100 lines (hard).
for f in rules/*.md; do
  n=$(wc -l < "$f")
  (( n > 100 )) && hard "${f} is ${n} lines (rules ceiling 100). Split, or move depth to best-practice/."
done

# 3. No verbose tails inlined in CLAUDE.md (hard) — those belong in a playbook.
if grep -qE 'Tool-call cheat sheet|^\*\*Pitfalls' CLAUDE.md; then
  hard "CLAUDE.md contains a cheat-sheet/pitfalls block. Move it to the domain's playbook; leave a one-line pointer."
fi

# 4. No doc asserts CLAUDE.md *is* N lines (warn) — asserted counts rot; ceiling refs ("<200 lines") are fine.
if grep -rnE 'CLAUDE\.md[^.]{0,24}is ~?[0-9]+ lines' best-practice/ 2>/dev/null; then
  soft "A doc hand-asserts CLAUDE.md's line count. Numbers drift from reality; reference audit-config.sh instead."
fi

# 5. best-practice/*.md soft ceiling ~120 (warn).
for f in best-practice/*.md; do
  n=$(wc -l < "$f")
  (( n > 120 )) && soft "${f} is ${n} lines (best-practice soft ceiling ~100-120; consider splitting)."
done

# Summary / exit.
if (( fail )); then
  printf '\naudit-config: HARD invariant(s) violated — fix before committing.\n' >&2
  exit 1
fi
if (( warn && strict )); then
  printf '\naudit-config: warnings present and --strict set.\n' >&2
  exit 1
fi
printf 'audit-config: OK (CLAUDE.md %s lines).\n' "$claude_lines"
