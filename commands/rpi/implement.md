---
description: Implementation phase of RPI — senior-software-engineer ships in reversible slices; reviewer trio gates each phase with Citation-Grounded findings.
model: opus
allowed-tools: AskUserQuestion, Agent, Read, Write, Edit, Glob, Grep, Bash, mcp__tavily__tavily_skill, mcp__tavily__tavily_search
argument-hint: "<feature-slug>"
---

# `/rpi:implement` — ship the feature in reversible slices

Use this command after `/rpi:plan` produced `rpi/<slug>/plan/PLAN.md` and the user approved. The command orchestrates the actual code changes, slice by slice, under the gaze of the adversarial reviewer trio.

## Inputs

`$ARGUMENTS` — the feature slug. Requires the full RPI artifact set:

- `rpi/<slug>/REQUEST.md`
- `rpi/<slug>/research/RESEARCH.md`
- `rpi/<slug>/plan/{PLAN,pm,ux,eng}.md`

## Workflow

### 0. Validate inputs

```bash
for f in REQUEST.md research/RESEARCH.md plan/PLAN.md plan/pm.md plan/ux.md plan/eng.md; do
  test -f rpi/<slug>/$f || abort "Missing rpi/<slug>/$f — run preceding RPI phase"
done
mkdir -p rpi/<slug>/implement/
```

Read PLAN.md. Extract the slice list.

### 1. Initialize IMPLEMENT.md

```
Agent(subagent_type="senior-software-engineer",
      description="Initialize IMPLEMENT.md with phase headers",
      prompt="Initialize rpi/<slug>/implement/IMPLEMENT.md.
              Header section: feature title, link to PLAN.md, start timestamp.
              One subsection per slice from PLAN.md (empty placeholders).
              Status: 'phase 1 in progress'.")
```

### 2. For each slice, run the implementation+review loop

The senior-software-engineer drives. After each slice:

#### 2a. Implementation

```
Agent(subagent_type="senior-software-engineer",
      description="Implement slice <N>: <name>",
      prompt="Implement slice <N> of rpi/<slug>/plan/eng.md.
              Make the code changes. Run the tests in eng.md's test strategy.
              Commit each file separately per git-commit-discipline.md.
              Update IMPLEMENT.md with what you did and what tests passed.
              Do NOT proceed past this slice — return to caller.")
```

#### 2b. Reviewer trio runs in PARALLEL

Send a single message with three `Agent` tool uses. The reviewers operate in worktree isolation; they don't see each other's findings until later.

```
Agent(subagent_type="code-reviewer",
      description="Code review of slice <N>",
      prompt="Review the diff produced for slice <N> of rpi/<slug>/.
              Files touched are in the IMPLEMENT.md slice section.
              Apply Citation Grounding (rules/rpi-review-citation.md).
              Verdict: APPROVE | REQUEST CHANGES | BLOCK.")

Agent(subagent_type="security-reviewer",
      description="Security review of slice <N>",
      prompt="Security review the slice <N> diff. OWASP top-10 + LLM-specific
              concerns. Citation Grounding required for P0/P1.
              Verdict: APPROVE | REQUEST CHANGES | BLOCK.")

Agent(subagent_type="constitutional-validator",
      description="Constitutional check of slice <N>",
      prompt="Validate slice <N> against project CLAUDE.md, .claude/rules/*.md,
              and stated non-goals. Cite the project's own files for any P0/P1.
              Verdict: APPROVE | REQUEST CHANGES | BLOCK.")
```

#### 2c. On-demand: performance-analyst

If `pm.md` lists a perf budget acceptance criterion AND that criterion is touched by this slice, OR if `code-reviewer` flagged a P1 perf finding:

```
Agent(subagent_type="performance-analyst",
      description="Perf analysis for slice <N>",
      prompt="Measure the current behavior of <hot path identified by reviewer>.
              Recommend optimizations. Verify the perf budget from pm.md is met.")
```

#### 2d. Adjudication

Look at all reviewer verdicts:

- **All APPROVE** → mark slice complete in IMPLEMENT.md, proceed to next slice.
- **Any REQUEST CHANGES** → senior-software-engineer addresses the findings (back to 2a for the addressed scope), then reviewer trio runs again.
- **Any BLOCK** → halt. Surface to user via `AskUserQuestion` with the blocking finding and options (fix now / defer / override-with-justification).

#### 2e. Documentation pass

After the trio approves:

```
Agent(subagent_type="documentation-analyst-writer",
      description="Phase summary for slice <N>",
      prompt="Append a Phase Summary to rpi/<slug>/implement/IMPLEMENT.md
              for slice <N>. Verify Citation Grounding compliance on all
              P0/P1 findings. Downgrade any uncited P0/P1 and log the downgrade.
              List commits, acceptance criteria covered, follow-ups.")
```

### 3. Final consolidation

After all slices complete:

```
Agent(subagent_type="documentation-analyst-writer",
      description="Final IMPLEMENT.md consolidation",
      prompt="Final pass on rpi/<slug>/implement/IMPLEMENT.md.
              Summary section: total commits, total findings by severity,
              total tests added, final acceptance criteria status.
              Surface ALL open follow-ups for user review.")
```

Present the final report to the user.

## Output contract

Produced files:
- `rpi/<slug>/implement/IMPLEMENT.md` — running log + final report.
- Code changes in the project, committed atomically (one file per commit per `git-commit-discipline.md`).
- Tests added or updated per `pm.md` acceptance criteria.

## When NOT to use this command

- The plan artifacts don't exist. Run the preceding RPI phases first.
- The user wants to "just code it" without the reviewer trio. Respect their call, but warn — this is where production bugs ship.
- The feature is so urgent that the loop is too slow. Surface the trade-off explicitly; let the user decide.

## Anti-patterns the command guards against

- ❌ Bundling multiple slices into one implementation pass (reviewer signal weakens).
- ❌ Skipping the reviewer trio on "small" slices (Citation Grounding catches what small-change intuition misses).
- ❌ Overriding a BLOCK verdict without explicit user authorization (the trio exists to slow the user down on dangerous changes).
- ❌ Letting the senior-software-engineer self-review (defeats the worktree-isolation purpose).
