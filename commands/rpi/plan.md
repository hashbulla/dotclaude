---
description: Planning phase of RPI — produces pm.md, ux.md, eng.md, and an aggregated PLAN.md for /rpi:implement to consume.
model: opus
allowed-tools: AskUserQuestion, Agent, Read, Write, Glob, Grep
argument-hint: "<feature-slug>"
---

# `/rpi:plan` — detailed implementation planning

Use this command after `/rpi:research` returned a **GO** verdict. The command produces the full planning artifact set under `rpi/<slug>/plan/`.

## Inputs

`$ARGUMENTS` — the feature slug. Requires `rpi/<slug>/REQUEST.md` and `rpi/<slug>/research/RESEARCH.md` to exist.

## Workflow

### 0. Validate inputs

```bash
test -f rpi/<slug>/REQUEST.md || abort "Run /rpi:request first"
test -f rpi/<slug>/research/RESEARCH.md || abort "Run /rpi:research first"
mkdir -p rpi/<slug>/plan/
```

Read both files. Confirm the research verdict was GO; if NO-GO or NEEDS-CLARIFICATION, abort and tell the user to address the verdict.

### 1. Run the three planning agents in parallel

These three agents can work simultaneously — each reads REQUEST.md + RESEARCH.md and contributes one file. Send them in a single message with three `Agent` tool uses.

```
Agent(subagent_type="product-manager",
      description="Write pm.md — user stories, acceptance, success metrics",
      prompt="Read REQUEST.md and RESEARCH.md.
              Produce rpi/<slug>/plan/pm.md per your agent spec.
              Personas, user stories with G/W/T acceptance, success metrics
              with targets and baselines, non-goals expanded.")

Agent(subagent_type="ux-designer",
      description="Write ux.md — flows, states, errors, microcopy, a11y",
      prompt="Read REQUEST.md and RESEARCH.md.
              Produce rpi/<slug>/plan/ux.md per your agent spec.
              Cover every user-facing surface this feature touches.
              State coverage matrix is non-optional.
              Route to impeccable/critique/harden skills via Skill tool where relevant.")

Agent(subagent_type="senior-software-engineer",
      description="Write eng.md — implementation shape, reversible slices, tests, observability",
      prompt="Read REQUEST.md, RESEARCH.md, and (when they land) pm.md + ux.md.
              Produce rpi/<slug>/plan/eng.md per your agent spec.
              Break work into reversible slices. Each slice ships independently.
              Test strategy is non-optional.")
```

### 2. Assemble PLAN.md

After all three agents return:

```
Agent(subagent_type="documentation-analyst-writer",
      description="Assemble PLAN.md from pm.md + ux.md + eng.md",
      prompt="Assemble rpi/<slug>/plan/PLAN.md per your agent spec.
              Cross-references to pm.md, ux.md, eng.md.
              Slice schedule pulled from eng.md.
              Approval gate clearly stated.")
```

### 3. Present to user via `AskUserQuestion`

Show the slice schedule and ask:

- Does the slice ordering match your priorities?
- Are the acceptance criteria the right shape?
- Are there scope cuts you want before implementation starts?

If the user wants edits, re-run the relevant agent (pm/ux/eng) with the targeted change request.

### 4. Approval gate

```
AskUserQuestion(
  question="Plan is ready. Approve to proceed to /rpi:implement?",
  options=[
    "Yes, run /rpi:implement <slug> now",
    "Yes, but I'll run /rpi:implement myself later",
    "No, I want to revise the plan first"
  ]
)
```

If the user picks "run now", invoke `/rpi:implement <slug>` immediately. Otherwise stop.

## Output contract

Produced files:
- `rpi/<slug>/plan/pm.md` — product plan.
- `rpi/<slug>/plan/ux.md` — UX plan.
- `rpi/<slug>/plan/eng.md` — engineering plan.
- `rpi/<slug>/plan/PLAN.md` — aggregator with slice schedule.

No code changes. No commits.

## When NOT to use this command

- `RESEARCH.md` returned NO-GO. Address the blocker first.
- The feature is so trivial that pm.md/ux.md/eng.md would each be one sentence. Skip RPI; document in the commit message.
- The user wants to skip planning and go straight to code. That's their call; respect it, but warn that `/rpi:implement` relies on planning artifacts and will refuse to run without them.
