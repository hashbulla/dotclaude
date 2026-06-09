# Code generation — prime → spec/TDD → review → verify

The doctrine behind dotclaude's code-generation discipline. It wires an *already-installed* toolchain into a default workflow so code generation stops being "type into the file" and becomes a short, evidenced loop. Implemented by [`../rules/code-generation.md`](../rules/code-generation.md) (lazy, fires on code files) and the **Code Generation Routing Decision Table** + **Autonomous Code-Gen Triggers** blocks in [`../CLAUDE.md`](../CLAUDE.md).

## Why this exists

dotclaude was strong at *research/scraping/docs* routing and silent about *writing code*. The capability was already present — it just was not routed:

| Technique | Owned by (already installed) | Was it wired? |
|---|---|---|
| Graph context-priming | `codegraph` MCP (connected) | No |
| Spec-first / TDD | `superpowers`, `/rpi:*` | Partially (RPI only) |
| Verification gate | `superpowers:verification-before-completion` | No |
| Anti-slop + review/simplify | `impeccable`, `/code-review`, `/simplify` | No |

The gap was a decision table and an autonomous-trigger block, the same pattern the Scrapling and Context7 sections already use. This layer closes it.

## The principle

**Evidence before assertion, design before code, the graph before the grep.** Each step removes a class of failure:

- *Priming* removes "edited the wrong place / missed a caller" — the graph already knows the call structure (`codegraph_context`, `codegraph_trace`, `codegraph_impact`).
- *Spec/TDD* removes "built the wrong thing / no safety net" — the test is the spec made executable.
- *Review/simplify* removes "works but is slop" — correctness then reuse/efficiency.
- *Verification* removes the most expensive lie: "done" when it is not. Run it, quote the output.

## Scope: the discipline is the floor

The cost of ceremony is real, so the default is **do-directly** and the named trivial set is exempt (typo, log line, one-liner, rename, single obvious-function change, comment, throwaway stdlib script) — this set wins on overlap, so a multi-file rename stays trivial. The structural signals (new behavior, ≥2 files, ≥~20 LOC of logic, control-flow change, external API/SDK integration, behavior change to an existing feature) are a **backstop** that fires only when the change is *also* unfamiliar or risky. **When unsure, do the smaller thing first** — over-firing taxes every edit, while under-firing self-corrects on the retry. This is the deliberate inversion of "fail toward ceremony": an advisory layer that cannot enforce anything should not make every two-file edit expensive.

## Worked example — "add lead-scoring to the outreach pipeline"

A real multi-file TS feature (cf. `unipile-outreach/`, ~1,329 LOC). The loop:

1. **Prime.** `codegraph_context` on `scoring` and `leads` → one `codegraph_explore` on the surfaced source. Now Claude knows `stages.ts` consumes the score and `state.ts` persists it — *before* touching anything.
2. **Spec.** `superpowers:brainstorming` → `writing-plans`: agree the scoring inputs, the threshold, where it plugs in. No code yet.
3. **TDD.** Failing test for `score(lead) → number`; minimal impl; green; refactor.
4. **Impact check.** `codegraph_impact` on the changed signature → confirms `stages.ts` and `dryrun.ts` are the only consumers; update them.
5. **Passes.** `/code-review` the diff (correctness), then `/simplify` (reuse/efficiency).
6. **Verify.** Run the suite + a `dryrun`; quote the output. *Then* say done.

Contrast the anti-workflow: grep for "score", paste a function into `leads.ts`, claim "added scoring ✓" with nothing run. Same feature, none of the guarantees.

## Calibration — the two cases that fix the boundary

The boundary is prose, not an executable gate, so calibrate it against two canonical cases (Anthropic's own do-directly exemplars: "typo, log line, rename a variable → do it directly", code.claude.com/docs/en/best-practices, ret. 2026-06-09):

- **Trivial — discipline must NOT fire.** "Rename `score()` and update its two callers." Touches ≥2 files, but it is a rename — the trivial set wins on overlap. No codegraph prime, no spec, no TDD. Doing the ceremony here is the over-firing the layer is scoped to avoid.
- **Non-trivial — discipline fires.** The lead-scoring feature above: new behavior, external SDK, multiple consumers, and unfamiliar code. Prime → spec → TDD → review → verify.

If a real session fires the full loop on the first case, the boundary text is too aggressive — loosen it. If it blind-writes the second, it is too loose.

## Anti-patterns

- ❌ Blind grep+read when codegraph is connected.
- ❌ Multi-file feature before an approved design.
- ❌ "Done" with no command output quoted.
- ❌ Spec/TDD ceremony on a one-line fix.
- ❌ Duplicating the *style* rules here — this is process; style lives in [`../rules/python-style.md`](../rules/python-style.md) et al.
