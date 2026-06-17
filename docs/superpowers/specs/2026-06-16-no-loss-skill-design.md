---
name: no-loss-skill-design
status: revised-after-adversarial-review
ticket: AI-70
date: 2026-06-16
---

# Design — `/no-loss` skill (checkpoint + zero context loss + resume prompt)

> A user-invocable Claude Code skill that captures a zero-loss checkpoint of the current
> session before context is lost, persists it under the project's `.claude/`, updates the
> durable context log and memory, and emits a copy-paste resume prompt for the next session.

## 1. Problem & scope

Linear **AI-70** asks for a `/no-loss` skill that tells Claude Code to: (1) checkpoint, (2)
guarantee zero context loss while updating `./.claude`, (3) generate a resume prompt for the
next session. The ticket lists auto-compaction interception as an *ideal* stretch goal.

**In scope:** the skill itself — procedure, target resolution, checkpoint schema, resume-block
format, durable-surface updates, and eval-first fixtures.

**Out of scope (deliberate, YAGNI):** the `PreCompact` hook that would auto-fire before
compaction. A hook is an external process that cannot make the model reason; auto-writing files
on *every* compaction is a behavior change to the global harness best deferred until the
checkpoint format is proven. Documented as a future extension (§7), not built now.

## 2. Decisions (locked with the user, 2026-06-16)

| Decision | Choice | Rationale |
|---|---|---|
| Automation | Skill only, no hook | Reversibility — prove the format before touching the global hook dispatcher. |
| Storage | nearest `.claude/no-loss/`, self-gitignored | Matches the ticket's "update ./.claude"; checkpoints hold transient/sensitive context, so never committed. |
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
  mental model — writes it to the project's .claude/no-loss/, updates the context log and
  durable memory, and emits a copy-paste resume prompt for the next session.
  Triggers: "/no-loss", "checkpoint this session", "save context before compaction",
  "snapshot where we are", "I'm running low on context", "génère un prompt de reprise",
  "sauvegarde le contexte", "on va perdre le contexte, checkpoint".
  Do NOT activate for: git commits, writing a CLAUDE.md from scratch, /compact itself,
  "compact this conversation" / "réduis le contexte", memory writes unrelated to session
  handoff, or routine note-taking.
argument-hint: "[optional focus/note for the checkpoint]"
user-invocable: true
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit
---
```

## 4. Procedure (SKILL.md body)

- **Phase 0 — Resolve target `.claude/` (robust, cwd-independent).**
  1. If `basename(realpath(cwd)) == ".claude"`, target dir = cwd.
  2. Else walk up from cwd to the filesystem root; the first existing `.claude/` directory wins.
  3. Else (none found) create `.claude/` at the git toplevel if inside a repo, else at cwd.
  Let `CLAUDE_DIR` be the resolved dir and `DIR=$CLAUDE_DIR/no-loss/`. Create `DIR`.
- **Phase 0b — Self-ignore (P0 fix).** Write `$DIR/.gitignore` containing a single line `*`.
  This makes git ignore the entire checkpoint dir regardless of cwd, repo-root location, or
  monorepo subdir nesting — no root-anchored pattern, no leakage. Idempotent (overwrite-safe).
- **Phase 1 — Gather state.**
  - Probe git once: `git rev-parse --is-inside-work-tree`. If true, collect
    `git branch --show-current`, `git status --short`, `git diff --stat`. If false, skip all git
    fields and note "no git context" in Working state (the conversational synthesis still runs).
  - Deterministic timestamp: `date -u +%Y-%m-%dT%H:%M:%SZ` — a parseable UTC stamp with seconds
    for unique, sortable history filenames.
  - Model synthesis from the conversation: mission (+ ticket ref), decisions with rationale and
    rejected alternatives, done / in-progress / **next concrete step**, mental model & gotchas,
    key `file:line` anchors, open questions / blockers.
- **Phase 2 — Write checkpoint.** Write `$DIR/<timestamp>-<slug>.md` (append-only history) using
  the §5 schema, then write `$DIR/latest.md` as a copy of it. `latest.md` is an intentional
  last-write-wins pointer to the newest checkpoint (not "idempotent" — overwrite by design); the
  resume block (§6) names `latest.md` so the next session always reads the freshest snapshot.
- **Phase 3 — Update durable surfaces.** Append a dated one-paragraph entry to
  `$CLAUDE_DIR/context-log.md` (create if missing). For genuinely *lasting* decisions only,
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
- Branch: <branch | "no git context">
- Uncommitted: <git status --short>
- Key files: <path:line — role>

## Open questions / blockers
- ...

## Resume prompt
<the same block printed to the user>
```

**Retention:** history files are gitignored and cheap; default is manual cleanup. The reference
notes an optional "prune >90 days or keep last 20" convention the user can enable later.

## 6. Resume block (`references/resume-prompt.md`)

```text
Resume <ticket/goal>. First read ./.claude/no-loss/latest.md for full context.
TL;DR: <2–3 lines of where we are>.
We were about to <next concrete step>. Watch out for <gotcha>.
Continue from there.
```

## 7. Future extension (not built) — `PreCompact` auto-fire

The dispatcher `~/.claude/hooks/scripts/hooks.py` receives `PreCompact`, but today it is a
sound-player only — it reads stdin, plays a wav, and exits 0; it never emits
`hookSpecificOutput`/`additionalContext`. A future extension could, on `PreCompact`,
deterministically dump transcript path + git state + todos to `$DIR`. **If** `PostCompact`
supports `additionalContext` injection (unverified — must be confirmed against Claude Code hook
docs before relying on it), the hook could also inject a breadcrumb so the fresh context reads
the checkpoint. Deferred per the reversibility decision in §2.

## 8. Evals (eval-first, per `rules/ai-engineering.md`)

- **`loading.jsonl`** —
  - positives: `/no-loss`, "checkpoint this session", "sauvegarde le contexte avant compaction".
  - **fragile-mode positives** (near-miss phrasings that MUST still activate): "on va perdre le
    contexte", "I'm running low on context", "snapshot where we are", "save my progress before
    we lose it".
  - negatives (hijacker guard): `/compact`, "compact this conversation", "réduis le contexte",
    "commit this", "write a CLAUDE.md".
- **`e2e.jsonl`** —
  - assert the checkpoint contains every schema section and a non-empty NEXT CONCRETE STEP.
  - assert `$DIR/.gitignore` exists and contains `*`.
  - **self-application fixture**: run from a `.claude`-rooted cwd → assert no nested
    `.claude/.claude/` is created (P0 #2 guard).
  - **drifter assertion**: the skill emits a checkpoint + resume block and does NOT execute the
    "next concrete step" it identified.
- **`rubric.md`** — dimensions: state-capture completeness, resume-prompt actionability,
  no-secret-leakage, target-resolution + gitignore correctness, last-write-wins pointer freshness.

## 9. Failure modes guarded

| Mode | Guard |
|---|---|
| Silent (never fires) | Semantic-first description + explicit FR/EN triggers incl. fragile near-misses. |
| Hijacker (fires wrong) | `Do NOT activate for:` block; `/compact` + "compact this" negatives in `loading.jsonl`. |
| Drifter (fires then wanders) | Explicit drifter assertion in `e2e.jsonl`: checkpoint only, never executes the next step. |
| Fragile (hero-only) | Near-miss positive phrasings in `loading.jsonl`. |
| Overachiever | Phase 3 touches durable surfaces *only* for lasting decisions; checkpoint stays primary. |
| Secret leakage | Self-ignoring `$DIR/.gitignore` (`*`), cwd-independent; rubric checks no secrets persisted. |
| Wrong target dir | Phase 0 walk-up resolution + `.claude`-basename special case; self-application e2e fixture. |
