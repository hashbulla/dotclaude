# Loop kickoffs (opt-in)

In-house `/loop` kickoffs for Victor's stack (`gh`, `uv`/pytest/ruff, Koyeb). Patterns mined from loops.elorm.xyz but **authored and audited here** — no installed bundles (see [`rules/agentic-loops.md`](../../rules/agentic-loops.md) → security guardrail).

These are **opt-in**: you start them. Nothing forces them. Each is a closed loop — trigger → check command → exit condition → bounded iterations. The agent self-paces: after each pass it runs the check, reads the output, and only continues if the exit condition is unmet.

How to read an entry: paste the **kickoff** into Claude Code. For `interval` loops, the leading `/loop <interval>` schedules the recurrence; for `manual` loops, the agent self-paces in-session.

---

## ship-pr-until-green  · manual

- **Goal:** PR open with every CI check passing.
- **Max iterations:** 10 · **Check:** `gh pr checks` · **Exit:** all checks success.

> Implement the change on a branch, run tests locally, push, open a PR, then loop:
> after each push run `gh pr checks`, read the output, and only continue if any check is
> not yet success. Fix the root cause of failures and push again. Stop when all checks
> pass (or after 10 iterations). Give a one-line status each pass. Self-pace.

## independent-verifier-pass · manual

- **Goal:** build + lint + tests pass under independent verification.
- **Max iterations:** 8 · **Check:** `uv run ruff check . && uv run pytest -q` · **Exit:** all exit 0.

> Act as an independent verifier of the change just made. Trust only command output, not
> prior claims. Run ruff then pytest. If anything fails, fix the root cause and re-run.
> Stop when both pass (or after 8 iterations). Self-pace; report only command-verified status.

## ci-failure-watcher · interval

- **Goal:** latest CI run on this branch is green.
- **Check:** `gh run list --branch $(git branch --show-current) --limit 1` · **Exit:** latest run conclusion success.

> /loop 5m Watch CI for this branch. Each tick: run
> `gh run list --branch $(git branch --show-current) --limit 1`. If the latest run failed,
> read its logs (`gh run view --log-failed`), fix the root cause, verify locally, push.
> Stop when the latest run is success. Max 12 ticks.

## deploy-verification · interval

- **Goal:** post-deploy Koyeb health/smoke endpoints all return healthy.
- **Check:** `curl -fsS "$HEALTH_URL"` · **Exit:** every configured endpoint succeeds.

> /loop 15m After the Koyeb deploy, verify health. Each tick: `curl -fsS "$HEALTH_URL"`
> (and any smoke endpoints). If any fail, inspect the Koyeb deploy logs and fix or escalate.
> Stop when every endpoint returns success. Max 8 ticks.

---

**When to lock one of these instead:** never the slow/interval ones. Only a cheap+irreversible check earns a hard gate — see the LOCK-vs-OPT-IN boundary in [`rules/agentic-loops.md`](../../rules/agentic-loops.md).
