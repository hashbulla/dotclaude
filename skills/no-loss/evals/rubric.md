# /no-loss eval rubric

Score each dimension 0–2 (0 absent, 1 partial, 2 solid). Pass = ≥ 80% of max with no zero on a
fail-closed dimension (marked ⛔).

| Dimension | What "solid" looks like |
|---|---|
| State-capture completeness | All schema sections present and substantive; nothing important from the session is missing. |
| Next-step actionability | NEXT CONCRETE STEP is a single, executable instruction — not "continue the work". |
| Resume-prompt quality | Points at latest.md, TL;DR ≤ 3 lines, one gotcha, immediately pasteable. |
| Target-resolution correctness ⛔ | Writes to the nearest real `.claude/`; never a nested `.claude/.claude/`. |
| No secret leakage ⛔ | `$NO_LOSS_DIR/.gitignore` is `*`; no tokens/credentials in checkpoint or resume block. |
| Scope discipline | Touches context-log/memory only for lasting decisions; never runs the next step (drifter). |

## Runner

These fixtures are inputs for `~/.claude/skills/skill-harness/` (the adversarial skill grader);
`tests/test-resolve.sh` is the only self-executing check. The fixtures below are graded by the
harness/an LLM against this rubric, not by a CI assertion runner.

## Failure-mode mapping
- silent → loading.jsonl hero positives must activate.
- hijacker → loading.jsonl negatives (/compact, commit, CLAUDE.md) must NOT activate.
- fragile → loading.jsonl `mode:fragile` near-misses must activate.
- drifter → e2e drifter scenario: checkpoint only, no next-step execution.
- overachiever → rubric "Scope discipline": no unsolicited memory/CLAUDE.md edits.
