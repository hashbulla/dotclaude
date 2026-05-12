# RPI Workflow — Research → Plan → Implement

dotclaude's flagship workflow. Three commands (plus a setup command) orchestrate ten specialty agents and one citation-grounding rule to turn a vague feature ask into a shipped, reviewed implementation.

## The four phases

```
/rpi:request <prose>           →  rpi/<slug>/REQUEST.md
        ↓ (verdict gate)
/rpi:research <slug>           →  rpi/<slug>/research/RESEARCH.md (GO/NO-GO)
        ↓ (verdict gate)
/rpi:plan <slug>               →  rpi/<slug>/plan/{pm,ux,eng,PLAN}.md
        ↓ (approval gate)
/rpi:implement <slug>          →  code changes + rpi/<slug>/implement/IMPLEMENT.md
```

Each phase produces a versioned artifact under `rpi/<slug>/`. The chain of artifacts is the audit trail.

## Phase 1: `/rpi:request`

**Agent**: `requirement-parser` (haiku).

**Output**: `rpi/<slug>/REQUEST.md` with Problem / Goals / Non-goals / Constraints / Knowns / Unknowns / Flags.

**Key flag**: `needs_deep_research: <bool>`. This drives whether `/rpi:research` triggers `/deep-research` or stays with `tavily_skill` / `tavily_search`. Threshold is wide — most non-trivial features trigger it. See `agents/requirement-parser.md` for the exact heuristic.

## Phase 2: `/rpi:research`

**Agents (sequential)**: `requirement-parser` → (gate: needs_deep_research) → `Skill(deep-research)` OR Tavily lighter pass → `product-manager` → `technical-cto-advisor` → `senior-software-engineer` (feasibility) → `documentation-analyst-writer` (assemble).

**Output**: `rpi/<slug>/research/RESEARCH.md` with a GO / NO-GO / NEEDS-CLARIFICATION verdict, cited evidence table, draft user stories, draft architecture.

**Citation Grounding**: external claims in the Evidence table cite Tavily / deep-research output / vendor docs.

## Phase 3: `/rpi:plan`

**Agents (parallel)**: `product-manager`, `ux-designer`, `senior-software-engineer` — each contributes one file. Then `documentation-analyst-writer` assembles `PLAN.md`.

**Output**:
- `rpi/<slug>/plan/pm.md` — personas, user stories with G/W/T acceptance, success metrics with targets and baselines, non-goals expanded.
- `rpi/<slug>/plan/ux.md` — flows, state coverage matrix, error catalogue, microcopy, accessibility.
- `rpi/<slug>/plan/eng.md` — implementation shape, reversible slices, test strategy, observability.
- `rpi/<slug>/plan/PLAN.md` — aggregator with slice schedule and approval gate.

## Phase 4: `/rpi:implement`

The biggest phase. For each slice in `eng.md`:

1. **`senior-software-engineer`** implements, runs tests, commits one-file-per-commit.
2. **Reviewer trio in parallel** (each in `isolation: worktree`):
   - `code-reviewer` — correctness, readability, test coverage, complexity.
   - `security-reviewer` — OWASP top-10, supply-chain, secret leakage, LLM-specific (prompt injection, tool abuse).
   - `constitutional-validator` — adherence to CLAUDE.md, `.claude/rules/*.md`, REQUEST.md non-goals, settings.json permissions.
3. **On-demand**: `performance-analyst` (when perf is in acceptance criteria).
4. **Citation Grounding rule** (`rules/rpi-review-citation.md` auto-loads since paths matches `rpi/**`): P0/P1 findings must cite Tavily evidence. Findings without citations downgrade to P2 automatically.
5. **`documentation-analyst-writer`** consolidates: verifies citations, logs downgrades, appends Phase Summary to `IMPLEMENT.md`.

Only when all reviewers APPROVE does the slice proceed to commit. BLOCK verdicts halt and prompt the user.

## What makes this senior-AI-engineer grade

Three things differentiate this from a generic "ship the feature" loop:

1. **Adversarial review by default.** Two reviewers (code + security) running in worktree isolation prevent the single-reviewer rubber-stamp pattern.
2. **Citation Grounding on P0/P1.** Borrowed from `/critical-harness`. Findings must back up high-severity claims with external evidence. Reviewers can't soften to avoid citing.
3. **Project-internal constitution check.** The `constitutional-validator` ensures the implementation doesn't drift from the project's own stated rules — a layer that pure code review misses.

## When to skip RPI

- The change is trivial (a typo, a flag rename, a doc tweak). Just do the work.
- The change is a one-off exploration / spike. Plan mode is enough.
- The change is so urgent the RPI loop's slowness is the bigger risk than ship-quality. Document the trade-off explicitly.

## Feature template

A `workflows/rpi/feature-template/` directory ships with empty templates for each artifact. New features can `cp -r workflows/rpi/feature-template rpi/<slug>` to skip the manual setup — but `/rpi:request` does this for you automatically.

## Verifying

End-to-end smoke test on a fresh project:

```
/rpi:request "Add a --verbose flag to my CLI"
# expect: rpi/cli-verbose-flag/REQUEST.md with needs_deep_research: false

/rpi:research cli-verbose-flag
# expect: RESEARCH.md with GO verdict, light tavily evidence only

/rpi:plan cli-verbose-flag
# expect: pm/ux/eng/PLAN.md with 1-2 slices

/rpi:implement cli-verbose-flag
# expect: code change, single-file commits, reviewer trio APPROVE
```

Then the heavier test:

```
/rpi:request "Migrate auth from session cookies to OAuth2 PKCE"
# expect: needs_deep_research: true, risk_level: high, reversibility: one-way-door

/rpi:research auth-oauth2-migration
# expect: /deep-research invoked, RESEARCH.md with 20+ cited sources

…
```
