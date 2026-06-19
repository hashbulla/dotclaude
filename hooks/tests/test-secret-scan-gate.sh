#!/usr/bin/env bash
# test-secret-scan-gate.sh — TDD harness for hooks/secret-scan-gate.sh (AI-177).
#
# Test runner: intentionally uses `set -uo pipefail` WITHOUT -e so every case
# runs and reports, rather than aborting on the first failed assertion. Each
# assertion tracks PASS/FAIL; the runner exits 1 if any case fails.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="${HERE}/../secret-scan-gate.sh"

PASS=0
FAIL=0
TMPDIRS=()

cleanup() { local d; for d in "${TMPDIRS[@]:-}"; do [[ -n "$d" && -d "$d" ]] && rm -rf "$d"; done; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); printf '  ok   — %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL — %s\n' "$1"; }

assert_contains() { # haystack needle msg
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (expected to contain '$2'; got: '${1:0:200}')"; fi
}
assert_not_contains() { # haystack needle msg
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (expected NOT to contain '$2'; got: '${1:0:200}')"; fi
}
assert_eq() { # actual expected msg
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2'; got '$1')"; fi
}
assert_deny() { # gate_stdout msg — formatting-agnostic: parse the decision via jq
  local dec; dec="$(printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  assert_eq "$dec" "deny" "$2"
}

make_repo() {
  local d; d="$(mktemp -d)"; TMPDIRS+=("$d")
  ( cd "$d" && git init -q && git config user.email t@t.dev && git config user.name tester )
  printf '%s' "$d"
}

# run_gate <repo_dir> <command_string> -> sets OUT (stdout) and RC (exit code)
run_gate() {
  local repo="$1" cmd="$2" json
  json="$(jq -nc --arg c "$cmd" '{tool_name:"Bash", hook_event_name:"PreToolUse", tool_input:{command:$c}}')"
  OUT="$( cd "$repo" && printf '%s' "$json" | bash "$GATE" 2>/dev/null )"
  RC=$?
}

echo "TDD: hooks/secret-scan-gate.sh"

# 1. Planted AWS key in a staged file -> hard deny.
repo="$(make_repo)"
( cd "$repo" && printf 'aws_key = "AKIAIOSFODNN7EXAMPLE"\n' > app.py && git add app.py )  # pragma: allowlist secret
run_gate "$repo" "git commit -m wip"
assert_deny "$OUT" "denies commit with AWS key in staged diff"
assert_eq "$RC" "0" "deny path still exits 0 (decision carried in JSON)"

# 2. Clean staged diff -> allow (no deny, silent).
repo="$(make_repo)"
( cd "$repo" && printf 'def add(a, b):\n    return a + b\n' > app.py && git add app.py )
run_gate "$repo" "git commit -m clean"
assert_not_contains "$OUT" 'deny' "allows a clean staged commit"
assert_eq "$RC" "0" "clean commit exits 0"

# 3. Non-git-commit Bash -> silent allow.
repo="$(make_repo)"
run_gate "$repo" "ls -la"
assert_eq "$OUT" "" "non-commit Bash produces no output"
assert_eq "$RC" "0" "non-commit Bash exits 0"

# 4. Override env -> allow even with a planted secret.
repo="$(make_repo)"
( cd "$repo" && printf 'token = "AKIAIOSFODNN7EXAMPLE"\n' > app.py && git add app.py )  # pragma: allowlist secret
OUT="$( cd "$repo" && jq -nc '{tool_name:"Bash",hook_event_name:"PreToolUse",tool_input:{command:"git commit -m x"}}' | ALLOW_SECRET_COMMIT=1 bash "$GATE" 2>/dev/null )"; RC=$?
assert_not_contains "$OUT" 'deny' "ALLOW_SECRET_COMMIT=1 bypasses the gate"
assert_eq "$RC" "0" "override path exits 0"

# 5. Not a git repo -> fail-open allow (+ warning on stderr).
nodir="$(mktemp -d)"; TMPDIRS+=("$nodir")
ERR="$( cd "$nodir" && jq -nc '{tool_name:"Bash",hook_event_name:"PreToolUse",tool_input:{command:"git commit -m x"}}' | bash "$GATE" 2>&1 1>/dev/null )"
run_gate "$nodir" "git commit -m x"
assert_not_contains "$OUT" 'deny' "fail-open: non-git-repo commit is allowed"
assert_eq "$RC" "0" "fail-open exits 0"
assert_contains "$ERR" "secret-scan-gate" "fail-open emits a stderr warning"

# 6. Staged .env file -> deny (filename rule).
repo="$(make_repo)"
( cd "$repo" && printf 'X=1\n' > .env && git add .env )
run_gate "$repo" "git commit -m env"
assert_deny "$OUT" "denies staging a .env file"

# 7. -a flag scans tracked-unstaged changes too.
repo="$(make_repo)"
( cd "$repo" && printf 'v = 1\n' > app.py && git add app.py && git commit -qm init \
    && printf 'key = "AKIAIOSFODNN7EXAMPLE"\n' >> app.py )  # pragma: allowlist secret
run_gate "$repo" "git commit -am wip"
assert_deny "$OUT" "git commit -a scans unstaged tracked changes"

# 8. Malformed JSON on stdin -> fail-open allow (exit 0), no deny.
badrepo="$(make_repo)"
OUT="$( cd "$badrepo" && printf 'not-json{' | bash "$GATE" 2>/dev/null )"; RC=$?
assert_not_contains "$OUT" 'deny' "fail-open on malformed stdin (no deny)"
assert_eq "$RC" "0" "malformed stdin exits 0 (set -e must not leak jq's error code)"

# 9. Inline allow pragma -> a flagged line carrying the pragma is exempt.
repo="$(make_repo)"
( cd "$repo" && printf 'k = "AKIAIOSFODNN7EXAMPLE"  # pragma: allowlist secret\n' > app.py && git add app.py )
run_gate "$repo" "git commit -m fixture"
assert_not_contains "$OUT" 'deny' "inline 'pragma: allowlist secret' exempts the line"

echo "-----"
printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
