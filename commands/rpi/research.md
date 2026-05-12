---
description: Research phase of RPI — runs feasibility analysis, gathers cited evidence, emits a GO/NO-GO verdict in RESEARCH.md.
model: opus
allowed-tools: AskUserQuestion, Agent, Skill, Read, Write, Glob, Grep, mcp__tavily__tavily_skill, mcp__tavily__tavily_search
argument-hint: "<feature-slug>"
---

# `/rpi:research` — feasibility analysis with cited evidence

Use this command after `/rpi:request` has produced `rpi/<slug>/REQUEST.md`. The command runs the full research pipeline and emits `rpi/<slug>/research/RESEARCH.md` with a GO/NO-GO verdict and an evidence table.

## Inputs

`$ARGUMENTS` — the feature slug. Maps to `rpi/<slug>/`.

## Workflow

### 0. Validate inputs

```bash
test -f rpi/<slug>/REQUEST.md || abort "Run /rpi:request first"
mkdir -p rpi/<slug>/research/
```

Read `REQUEST.md`. Extract:
- `needs_deep_research: <bool>`
- `risk_level: <low|medium|high>`
- `reversibility: <reversible|one-way-door>`

### 1. Evidence gathering — branch on `needs_deep_research`

#### If `needs_deep_research: true`

```
Skill(
  skill="deep-research",
  query="<synthesized research question derived from REQUEST.md>"
)
```

The synthesized question should bundle:
- The core problem from REQUEST.md
- The constraints
- The options to compare (if any)
- The success criteria

Save the deep-research output as `rpi/<slug>/research/deep-research-output.md` (the deep-research skill writes this; just keep the path).

#### If `needs_deep_research: false`

Run lighter parallel searches:

```
mcp__tavily__tavily_skill (library/API/framework docs the feature touches)
mcp__tavily__tavily_search (vulnerability disclosures, vendor advisories if security-adjacent)
```

Save the raw outputs as `rpi/<slug>/research/evidence-tavily.md`.

### 2. Agent pipeline — sequential

Each agent reads the artifacts produced by the previous one. Invoke via `Agent` tool.

```
Agent(subagent_type="product-manager",
      description="User stories + acceptance criteria",
      prompt="Read REQUEST.md and the evidence files in rpi/<slug>/research/.
              Contribute the 'User stories (draft)' section to RESEARCH.md
              per your agent spec.")

Agent(subagent_type="technical-cto-advisor",
      description="Architecture + trade-offs + risk register",
      prompt="Read REQUEST.md, evidence, and PM contribution.
              Contribute the 'Architecture (draft)' section to RESEARCH.md.
              Use Tavily for cited evidence on non-obvious claims.")

Agent(subagent_type="senior-software-engineer",
      description="Feasibility + first-slice shape",
      prompt="Read everything above. Add a 'Feasibility' section to
              RESEARCH.md: can we build this in 1-3 reversible slices
              within the constraints? If not, what would need to change?")
```

### 3. Assemble with `documentation-analyst-writer`

```
Agent(subagent_type="documentation-analyst-writer",
      description="Assemble RESEARCH.md from agent contributions",
      prompt="Assemble rpi/<slug>/research/RESEARCH.md from:
                - REQUEST.md
                - Evidence files
                - PM contribution
                - CTO contribution
                - Engineering feasibility

              Use the RESEARCH.md template from your agent spec.
              Enforce: every external claim has a citation in the Evidence table.
              Emit the verdict: GO | NO-GO | NEEDS-CLARIFICATION.")
```

### 4. Present to user

After `documentation-analyst-writer` returns, show the user:

- The verdict (GO / NO-GO / NEEDS-CLARIFICATION).
- The top 3 trade-offs from the architecture section.
- The risk register (table).
- The next step the verdict implies.

### 5. Suggest next step

- **GO** → `/rpi:plan <slug>` for detailed implementation planning.
- **NO-GO** → stop. Document why and what would change the answer.
- **NEEDS-CLARIFICATION** → re-run `/rpi:request <slug>` with the clarifications, then re-run research.

## Output contract

Produced files:
- `rpi/<slug>/research/RESEARCH.md` — the canonical research report.
- `rpi/<slug>/research/deep-research-output.md` (if `needs_deep_research: true`).
- `rpi/<slug>/research/evidence-tavily.md` (always).

No code changes. No commits.

## When NOT to use this command

- `REQUEST.md` doesn't exist. Run `/rpi:request` first.
- The feature is trivial (you already know the answer is GO and the path is obvious). Skip RPI and just do the work.
- The user wants a quick literature review rather than a structured feasibility report. Use `/research` (Tavily-first) instead.
