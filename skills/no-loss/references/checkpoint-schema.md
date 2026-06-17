# Checkpoint schema

Fill every section. Empty a section explicitly with `- (none)` rather than deleting it — a
reader must distinguish "nothing here" from "forgot to capture".

```markdown
# No-Loss Checkpoint — <project> — <ISO-8601 UTC timestamp>

## Mission
<one line; include the ticket id if any, e.g. AI-70>

## Status
- Done: <bullet list>
- In progress: <bullet list>
- NEXT CONCRETE STEP: <one actionable sentence>

## Decisions
- <decision> — because <why> — rejected: <alternative>

## Mental model & gotchas
- <non-obvious facts a fresh session needs: invariants, traps, env quirks>

## Working state
- Branch: <branch | "no git context">
- Uncommitted: <output of `git status --short`, or "(clean)" / "no git context">
- Key files: <path:line — role>

## Open questions / blockers
- <unresolved decisions or external waits>

## Resume prompt
<the exact block printed to the user — see resume-prompt.md>
```

## Worked example (abridged)

```markdown
# No-Loss Checkpoint — dotclaude — 2026-06-16T15:40:02Z

## Mission
AI-70 — build the /no-loss checkpoint skill.

## Status
- Done: spec approved + adversarially reviewed; resolve helper + tests green.
- In progress: writing SKILL.md.
- NEXT CONCRETE STEP: write references/checkpoint-schema.md and resume-prompt.md.

## Decisions
- Skill-only, hook deferred — because reversibility; prove the format first — rejected: PreCompact auto-fire.
- Self-ignoring `.gitignore` (`*`) inside no-loss/ — because root-anchored patterns miss monorepo subdirs — rejected: repo-root .gitignore entry.

## Mental model & gotchas
- This repo's project .claude is the NESTED ~/.claude/.claude — walk-up resolves to it.

## Working state
- Branch: poiraudvictor42/ai-70-...
- Uncommitted: (clean)
- Key files: skills/no-loss/scripts/no-loss-resolve.sh:1 — deterministic resolver

## Open questions / blockers
- (none)

## Resume prompt
Resume AI-70 (/no-loss skill). First read ./.claude/no-loss/latest.md for full context.
TL;DR: helper + tests done, SKILL.md done; references next.
We were about to write the two reference files. Watch out: SKILL.md must stay <=150 lines.
Continue from there.
```
