# Agentic loops — lock vs. opt-in

Doctrine for AI-177. When to *force* a loop/gate via a deterministic hook vs. keep it opt-in. Backed by `~/.claude/research/ai-177-loops-marketplace/` (deep-research, gate PASS). Kept tight — this is a rule, every byte costs context.

## The decision boundary

**LOCK (hook-enforced) only when BOTH hold:**
- the check is **cheap** (sub-second, no network round-trip), AND
- skipping it is **irreversible or expensive** (secret in git history, broken main, leaked PII).

**Keep OPT-IN (a `/loop` kickoff the user starts) when** the work is slow, judgment-laden, or context-dependent — CI-until-green, deploy verification, PR-until-green. Forcing these systematically burns tokens, blocks legitimate work, and breeds a bypass reflex.

Two hard facts that constrain enforcement:
- **A hook cannot force a loop.** It can `block` a tool call (PreToolUse), `refuse to let the agent stop` (Stop), or inject context — the model still decides. "Force the use of loops" is a category error; the achievable thing is **enforce an exit gate**.
- **Local enforcement is always bypassable** (`--no-verify`, unset `core.hooksPath`). A local hook is an aid, not a guarantee. Pair every locked local gate with an authoritative, bypass-resistant **server-side CI gate** (defense-in-depth).

Also: a forced gate the loop can *game* is theater — autonomous loops weaken assertions / delete tests to hit "green". Make the check hard to fake, and verify with something the implementer doesn't control.

## The locked set (this machine)

| Gate | Event | Strength | Enforces |
|------|-------|----------|----------|
| `hooks/secret-scan-gate.sh` | PreToolUse · Bash | **hard deny** | no secret enters git history (`git commit`). Escapes: inline `# pragma: allowlist secret` on the line (works for in-session commits), or `export ALLOW_SECRET_COMMIT=1` (terminal commits only — the env var can't reach the hook from a per-command prefix). Fail-open if jq/git absent. |
| `hooks/pdf-design-gate.sh` | PostToolUse · Bash | soft inject | grade a produced PDF with `pdf-design-evaluator` before final |

House style: **soft-inject (fail-open, exit 0) is the default**; reserve hard-deny for the cheap+irreversible case (secrets). New gates follow the standalone-script-per-matcher idiom — never a branch in the observe-only `hooks/scripts/hooks.py`.

## Security guardrail (non-negotiable)

**Never install third-party `.claude/settings.json` hook bundles** (e.g. from loops.elorm.xyz). They run arbitrary shell on agent events — a proven RCE surface (CVE-2025-59536 CVSS 8.7; CVE-2026-21852 API-key exfil; both fired before any trust prompt). Mine patterns, author in-house, audit under your own git history.

## Opt-in loops

Catalog of `/loop` kickoffs (start them yourself, nothing forces them): `playbooks/agentic-loops/loop-kickoffs.md`.

## Follow-ups (not yet wired)

- Add a CLAUDE.md `<important if=…>` trigger so this rule surfaces on loop/hook work.
- Layer `gitleaks` into `secret-scan-gate.sh` when present (regex is the current baseline).
