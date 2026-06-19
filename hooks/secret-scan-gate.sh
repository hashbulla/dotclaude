#!/usr/bin/env bash
# secret-scan-gate.sh — PreToolUse/Bash hook (AI-177 locked gate).
# Requires: jq, git.
#
# HARD-blocks a `git commit` whose staged diff (and, with -a/--all, tracked
# unstaged changes) contains a secret, by returning permissionDecision:deny.
# Secrets in git history are the canonical cheap-to-detect + irreversible case —
# the one check that earns a hard block rather than the soft-inject pattern used
# by pdf-design-gate.sh / voice-check.
#
# Contract:
#   - Acts ONLY on `git commit`; every other Bash call exits 0 silently (loop-safe).
#   - On a secret match -> emit deny JSON, exit 0 (the decision rides in the JSON).
#   - FAIL-OPEN: missing jq, not a git repo, or a git error -> exit 0 + stderr warn.
#     A missing dependency must never block commits (matches the house posture).
#   - Override: ALLOW_SECRET_COMMIT=1 bypasses the gate (legitimate fixtures).
#   - NEVER prints the secret value — only the matched pattern name / filename.
#
# Detection is regex-based (baseline). Layering in `gitleaks` when present is a
# planned follow-up (kept out here: no test covers it yet — see hooks/tests/).
set -euo pipefail

warn() { printf 'secret-scan-gate: %s\n' "$1" >&2; }

# jq parses stdin and emits safe JSON; without it we cannot do either -> fail-open.
command -v jq >/dev/null 2>&1 || { warn "jq not found — skipping secret scan (fail-open)"; exit 0; }

INPUT="$(cat)"
# Fail-open on malformed/empty stdin: jq's non-zero exit must not leak through set -e.
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$CMD" ] && exit 0

# Only a `git commit` is in scope. Over-matching (e.g. "git log --grep commit")
# only causes a harmless extra scan that allows when clean.
case "$CMD" in
  *git*commit*) : ;;
  *) exit 0 ;;
esac

# Intentional override for legitimate secret-looking content (test fixtures, docs).
[ "${ALLOW_SECRET_COMMIT:-}" = "1" ] && exit 0

# Must be inside a work tree to diff anything — else fail-open.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { warn "not a git repository — skipping (fail-open)"; exit 0; }

STAGED="$(git diff --cached 2>/dev/null)" \
  || { warn "git diff --cached failed — skipping (fail-open)"; exit 0; }
NAMES="$(git diff --cached --name-only 2>/dev/null || true)"
CONTENT="$STAGED"

# -a / -am / --all also commits tracked-but-unstaged changes — scan those too.
if [[ "$CMD" =~ (^|[[:space:]])-[A-Za-z]*a[A-Za-z]* ]] || [[ "$CMD" == *--all* ]]; then
  CONTENT="${CONTENT}"$'\n'"$(git diff 2>/dev/null || true)"
  NAMES="${NAMES}"$'\n'"$(git diff --name-only 2>/dev/null || true)"
fi

# High-signal, conservative secret patterns (low false-positive by construction).
SECRET_RE='AKIA[0-9A-Z]{16}'
SECRET_RE+='|-----BEGIN [A-Z ]*PRIVATE KEY-----'
SECRET_RE+='|xox[baprs]-[0-9A-Za-z-]{10,}'
SECRET_RE+='|ghp_[0-9A-Za-z]{36}'
SECRET_RE+='|github_pat_[0-9A-Za-z_]{20,}'
SECRET_RE+='|sk-ant-[0-9A-Za-z-]{20,}'
SECRET_RE+='|sk-[A-Za-z0-9]{32,}'

FOUND=""

# Filename rule: a committed .env / .env.* (but not *.example) is itself a leak.
ENV_HIT="$(printf '%s\n' "$NAMES" | grep -E '(^|/)\.env($|\.)' | grep -vE '\.example$' | head -n1 || true)"
[ -n "$ENV_HIT" ] && FOUND="dotenv file (${ENV_HIT})"

# Lines carrying an inline allow pragma are exempt (detect-secrets / gitleaks
# convention) — lets the gate coexist with deliberate fixtures and docs.
SCAN="$(printf '%s' "$CONTENT" | grep -vE 'pragma: allowlist secret' || true)"
if [ -z "$FOUND" ] && printf '%s' "$SCAN" | grep -qE "$SECRET_RE"; then
  FOUND="a hardcoded secret pattern"
fi

[ -z "$FOUND" ] && exit 0   # clean -> allow silently

REASON="secret-scan-gate blocked this commit: ${FOUND} detected in the diff to be committed. "
REASON+="Remove it (and rotate the credential if it was ever real), or set ALLOW_SECRET_COMMIT=1 to override intentionally."

jq -n --arg r "$REASON" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'

exit 0
