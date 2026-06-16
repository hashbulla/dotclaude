---
name: no-loss-skill-design
status: approved
ticket: AI-70
date: 2026-06-16
---

# Design — `/no-loss` skill (checkpoint + zero context loss + resume prompt)

> A user-invocable Claude Code skill that captures a zero-loss checkpoint of the current
> session before context is lost, persists it under project-local `./.claude/`, updates the
> durable context log and memory, and emits a copy-paste resume prompt for the next session.

## 1. Problem & scope

Linear **AI-70** asks for a `/no-loss` skill that tells Claude Code to: (1) checkpoint, (2)
guarantee zero context loss while updating `./.claude`, (3) generate a resume prompt for the
next session. The ticket lists auto-compaction interception as an *ideal* stretch goal.

**In scope:** the skill itself — procedure, checkpoint schema, resume-block format, durable-surface
updates, and eval-first fixtures.

**Out of scope (deliberate, YAGNI):** the `PreCompact` hook that would auto-fire before
compaction. A hook is an external process that cannot make the model reason; auto-writing files
on *every* compaction is a behavior change to the global harness best deferred until the
checkpoint format is proven in practice. Documented as a future extension (§7), not built now.

## 2. Decisions (locked with the user, 2026-06-16)

| Decision | Choice | Rationale |
|---|---|---|
| Automation | Skill only, no hook | Reversibility — prove the format before touching the global hook dispatcher. |
| Storage | `./.claude/no-loss/`, gitignored | Matches the ticket's "update ./.claude"; checkpoints hold transient/sensitive context, so never committed. |
| Durable updates | `context-log.md` + memory/CLAUDE.md | Append session summary to the project context log; surface only *lasting* decisions to memory. |
| Resume artifact | Paste block + persisted file | Short block fits the next prompt and points at the durable file. |
| Model invocation | On, but conservative | `/no-loss` typed, **and** Claude may fire it on an explicit checkpoint intent — never silently. |

## 3. Layout

```
~/.claude/skills/no-loss/
  SKILL.md                       # <=150 lines, the procedure
  references/
    checkpoint-schema.md         # checkpoint file structure + worked example
    resume-prompt.md             # resume-block template + example
  evals/
    loading.jsonl                # activation positives + near-miss negatives
    e2e.jsonl                    # checkpoint-content assertions
    rubric.md                    # scoring dimensions
```

Frontmatter (per `rules/ai-engineering.md`):

```yaml
---
name: no-loss
description: >
  Captures a zero-loss checkpoint before context is lost — session state, decisions,
  mental model — writes it to ./.claude/no-loss/, updates the project context log and
  durable memory, and emits a copy-paste resume prompt for the next session.
  Triggers: "/no-loss", "checkpoint this session", "save context before compaction",
  "génère un prompt de reprise", "sauvegarde le contexte avant compaction",
  "on perd le fil, checkpoint".
  Do NOT activate for: git commits, writing a CLAUDE.md from scratch, /compact itself,
  memory writes unrelated to session handoff, or routine note-taking.
argument-hint: "[optional focus/note for the checkpoint]"
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---
```

## 4. Procedure (SKILL.md body)

- **Phase 0 — Resolve & guard.** `DIR=./.claude/no-loss/` relative to cwd. Create it. Ensure
  `.gitignore` (repo root) contains `/.claude/no-loss/`; append if absent. Idempotent.
- **Phase 1 — Gather state.**
  - Deterministic via Bash: `git branch --show-current`, `git status --short`, `git diff --stat`,
    `date -u +%Y-%m-%dT%H:%M:%SZ` (the model cannot read the clock itself).
  - Model synthesis from the conversation: mission (+ ticket ref), decisions with rationale and
    rejected alternatives, done / in-progress / **next concrete step**, mental model & gotchas,
    key `file:line` anchors, open questions / blockers.
- **Phase 2 — Write checkpoint.** Write `latest.md` (overwrite) **and** `<timestamp>-<slug>.md`
  (append-only history), both using the §5 schema.
- **Phase 3 — Update durable surfaces.** Append a dated one-paragraph entry to
  `./.claude/context-log.md` (create if missing). For genuinely *lasting* decisions only,
  write/update a memory file (or note in CLAUDE.md). Transient working state never leaks here.
- **Phase 4 — Emit resume block.** Print the §6 fenced block to the user.

## 5. Checkpoint schema (`references/checkpoint-schema.md`)

```markdown
# No-Loss Checkpoint — <project> — <ISO-8601 UTC>

## Mission
<one line + ticket ref, e.g. AI-70>

## Status
- Done: ...
- In progress: ...
- NEXT CONCRETE STEP: ...

## Decisions
- <decision> — because <why> — rejected: <alternative>

## Mental model & gotchas
- ...

## Working state
- Branch: <branch>
- Uncommitted: <git status --short>
- Key files: <path:line — role>

## Open questions / blockers
- ...

## Resume prompt
<the same block printed to the user>
```

## 6. Resume block (`references/resume-prompt.md`)

```text
Resume <ticket/goal>. First read ./.claude/no-loss/latest.md for full context.
TL;DR: <2–3 lines of where we are>.
We were about to <next concrete step>. Watch out for <gotcha>.
Continue from there.
```

## 7. Future extension (not built) — `PreCompact` auto-fire

The dispatcher `~/.claude/hooks/scripts/hooks.py` already receives `PreCompact`. A future
extension would, on `PreCompact`, deterministically dump transcript path + git state + todos to
`./.claude/no-loss/` and inject a post-compaction breadcrumb so the fresh context reads the
checkpoint. Deferred per the reversibility decision in §2.

## 8. Evals (eval-first, per `rules/ai-engineering.md`)

- **`loading.jsonl`** — positives (`/no-loss`, "checkpoint this session", "sauvegarde le contexte
  avant compaction") + near-miss negatives (`/compact`, "commit this", "write a CLAUDE.md")
  guarding the **hijacker** failure mode.
- **`e2e.jsonl`** — assert the checkpoint contains every schema section, a non-empty next step,
  and that `.gitignore` received `/.claude/no-loss/`.
- **`rubric.md`** — dimensions: state-capture completeness, resume-prompt actionability,
  no-secret-leakage, gitignore correctness, idempotent re-runs.

## 9. Failure modes guarded

| Mode | Guard |
|---|---|
| Silent (never fires) | Semantic-first description + explicit FR/EN triggers. |
| Hijacker (fires wrong) | `Do NOT activate for:` block; near-miss negatives in `loading.jsonl`. |
| Overachiever | Phase 3 touches durable surfaces *only* for lasting decisions; checkpoint stays the primary artifact. |
| Secret leakage | Checkpoints gitignored; rubric checks no secrets in persisted files. |
| Non-idempotent | `latest.md` overwrite + gitignore append-if-absent are re-run safe. |
