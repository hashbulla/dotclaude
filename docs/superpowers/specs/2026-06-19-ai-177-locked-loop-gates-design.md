# AI-177 — Locked exit-gate set + loop policy + opt-in loop catalog (design spec)

> Date: 2026-06-19 · Ticket: AI-177 (reframed: "force loops" → exit-gate enforcement)
> Status: design — awaiting user review before writing-plans
> Research basis: `~/.claude/research/ai-177-loops-marketplace/` (deep-research, gate PASS)

## 1. Goal & non-goals

**Goal.** Capture the *defensible core* of AI-177 as three small, in-house artifacts:
1. one new **locked** (hard-blocking) gate — secret-scan on `git commit`;
2. a **LOCK-vs-OPT-IN policy** rule that answers "which tasks deserve a forced loop";
3. an **opt-in `/loop` kickoff catalog**, authored in-house (patterns mined from loops!, never installed).

**Non-goals (explicitly rejected by the research + the challenge):**
- No "force loops systematically for generic tasks" — over-locking is an anti-pattern (token burn, blocked work, `--no-verify` reflex, gameable gates).
- No installing third-party hook bundles from loops.elorm.xyz — proven RCE surface (CVE-2025-59536, CVE-2026-21852).
- No generic config-driven gate framework — YAGNI for a solo setup.
- No Stop-hook "tests-green-before-done" gate — overlaps the `verification-before-completion` skill and carries documented Stop-hook fragility.

## 2. Architecture fit

The observe-only dispatcher `hooks/scripts/hooks.py` (sounds + JSONL logging, always `exit 0`) is **untouched**. Enforcement follows the existing standalone-gate idiom — one focused shell script per gate on a narrow matcher, exactly like `hooks/pdf-design-gate.sh` (PostToolUse·Bash) and `hooks/rtk-rewrite.sh` (PreToolUse·Bash). The "locked set" is the conceptual union of the existing PDF + voice gates and the new secret gate.

## 3. Component A — `hooks/secret-scan-gate.sh`

**Wiring.** New `settings.json` PreToolUse entry, matcher `Bash`, alongside the existing `rtk-rewrite.sh` (order: rtk-rewrite first, then secret-scan).

**Contract.**
- `#!/usr/bin/env bash` + `set -euo pipefail`; jq to parse stdin; shellcheck-clean.
- Read stdin JSON → `.tool_input.command`. If it is not a `git commit` invocation, `exit 0` silently (loop-safe; consumer/non-commit Bash costs nothing).
- Resolve what would be committed: `git diff --cached`; if the command carries `-a`/`-am`/`--all`, also include `git diff` (tracked-but-unstaged).
- **Detection (layered):** if `gitleaks` is on PATH, run `gitleaks` over the staged content; else fall back to a conservative regex set:
  - `AKIA[0-9A-Z]{16}` (AWS), `-----BEGIN [A-Z ]*PRIVATE KEY-----`, `xox[baprs]-[0-9A-Za-z-]{10,}` (Slack), `ghp_[0-9A-Za-z]{36}` / `github_pat_` (GitHub), `sk-ant-[0-9A-Za-z-]{20,}` (Anthropic), `sk-[A-Za-z0-9]{32,}` (OpenAI-style), and a staged-filename check for `.env` / `.env.*` excluding `*.example`.
- **On match → HARD BLOCK:** emit
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<pattern> in <file>; remove it or set ALLOW_SECRET_COMMIT=1 to override"}}` and `exit 0`.
- **Override:** env `ALLOW_SECRET_COMMIT=1` bypasses the gate (documented escape hatch for legitimate fixtures — addresses the "blocking legitimate work" failure mode).
- **Fail-open (decided):** if `jq` is absent, the cwd is not a git repo, or any git call errors → `exit 0` (allow) + a one-line stderr warning + a JSONL log entry. Matches the house fail-open posture; a missing dep never blocks commits.
- Never logs the secret value itself — only the matched pattern name and file path (PII/secret-light, consistent with `hooks.py` logging).

**Data flow.** `git commit` Bash call → PreToolUse JSON on stdin → script scans staged diff → allow (`exit 0`) or deny (JSON). Deterministic; no model involvement.

## 4. Component B — `rules/agentic-loops.md`

A loaded-on-relevance rule documenting:
- **The LOCK-vs-OPT-IN boundary:** LOCK only checks that are *cheap to run* AND *irreversible to skip* (secrets, lint, format). Keep slow or judgment-laden work OPT-IN. Always pair a local hook with an authoritative, bypass-resistant server-side CI gate (local enforcement is always client-bypassable).
- **The locked-set registry:** secret-scan (new), pdf-design-gate, voice-check — what each enforces and how (hard-deny vs soft-inject).
- **Security guardrail:** never install third-party `.claude/settings.json` hook bundles; cite CVE-2025-59536 / CVE-2026-21852; mine patterns, build in-house.
- **Pointer** to the research artifacts and to the loop catalog (Component C).
- Optional follow-up: add a one-line `<important if=...>` trigger to CLAUDE.md so the rule surfaces on loop/hook work (flagged, not done in v0).

## 5. Component C — `playbooks/agentic-loops/loop-kickoffs.md`

In-house, copy-paste `/loop` kickoffs (patterns adapted to Victor's stack — `gh`, pytest/ruff, Koyeb). Each entry: name · trigger type · goal · max-iter · check command · exit condition · kickoff text. Initial set:
- **ship-pr-until-green** (manual) — implement → test → push → PR → loop on `gh pr checks` until all green (max 10).
- **independent-verifier-pass** (manual) — `npm/uv` build + ruff + pytest as an independent verifier trusting only command output (max 8).
- **ci-failure-watcher** (interval) — `/loop 5m` poll `gh run list --branch $(git branch --show-current) --limit 1` until success.
- **deploy-verification** (interval) — `/loop 15m` curl Koyeb health/smoke endpoints until healthy.

All are OPT-IN kickoffs — the user starts them; nothing forces them.

## 6. Testing & verification plan

- `shellcheck hooks/secret-scan-gate.sh` (clean, or `# shellcheck disable` with rationale) + `bash -n`.
- **TDD harness** `hooks/tests/test-secret-scan-gate.sh` (mirrors the no-loss harness), written first:
  1. planted `AKIA…` in a staged file in a temp git repo → asserts `permissionDecision:deny`.
  2. clean staged diff → asserts `exit 0`, no deny.
  3. non-`git commit` Bash (e.g. `ls`) → asserts silent `exit 0`.
  4. `ALLOW_SECRET_COMMIT=1` with a planted secret → asserts allow.
  5. simulated missing `jq` → asserts fail-open allow + warning.
- Docs (B, C) verified by review only.

## 7. Build sequence (for writing-plans)

1. Branch off `main` (e.g. `poiraudvictor42/ai-177-...`).
2. TDD the secret gate: harness (red) → `secret-scan-gate.sh` (green) → shellcheck/bash -n.
3. Wire the PreToolUse·Bash entry in `settings.json` (via update-config skill).
4. Write `rules/agentic-loops.md` + `playbooks/agentic-loops/loop-kickoffs.md`.
5. `/code-review` → `/simplify` on the diff; verification-before-completion.
6. Commit only on explicit request.

## 8. Open risks

- Regex false positives on real fixtures → mitigated by `ALLOW_SECRET_COMMIT=1` + preferring `gitleaks` when present.
- Hooks fire on every Bash call → kept cheap by an early non-`git commit` `exit 0`.
- `settings.json` is user-global → the gate applies to every project; acceptable for a secret gate, documented in the policy rule.
