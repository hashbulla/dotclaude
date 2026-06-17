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

# No-Loss — Zero-context-loss session checkpoint

Capture everything needed to resume this session in a fresh context with no loss. You produce
two things: a durable checkpoint file and a short copy-paste resume prompt. Never execute the
"next step" you identify — checkpointing is the whole job.

## Phase 0 — Deterministic setup (run the helper)

Run the resolver. It picks the right `.claude/` (walking up; never a nested `.claude/.claude/`),
creates `.claude/no-loss/`, self-ignores it, and prints facts:

```bash
eval "$(bash ~/.claude/skills/no-loss/scripts/no-loss-resolve.sh)"
printf '%s\n' "$NO_LOSS_DIR" "$CONTEXT_LOG" "$GIT_PRESENT" "$BRANCH" "$TIMESTAMP"
```

You now have `$CLAUDE_DIR`, `$NO_LOSS_DIR`, `$CONTEXT_LOG`, `$GIT_PRESENT`, `$BRANCH`, `$TIMESTAMP`.

## Phase 1 — Gather state

- If `$GIT_PRESENT` = `yes`, capture working state:
  ```bash
  git status --short; git diff --stat
  ```
  If `no`, record "no git context" and skip these.
- Synthesise from THIS conversation (not from files): the mission (+ any ticket id), decisions
  with their rationale and rejected alternatives, what is done, what is in progress, the single
  **next concrete step**, mental-model notes & gotchas, key `file:line` anchors, open questions.

## Phase 2 — Write the checkpoint

Build the checkpoint body using `references/checkpoint-schema.md`. Pick a short `<slug>` from the
mission (kebab-case). Write the history file, then copy it to `latest.md`:

```bash
SLUG="<kebab-mission>"   # e.g. ai-70-no-loss
CKPT="$NO_LOSS_DIR/$TIMESTAMP-$SLUG.md"
```
Use the Write tool to write `$CKPT` with the filled schema, then:
```bash
cp "$CKPT" "$NO_LOSS_DIR/latest.md"
```
`latest.md` is a last-write-wins pointer to the freshest checkpoint (intentional overwrite).

## Phase 3 — Update durable surfaces

- Append one dated paragraph to `$CONTEXT_LOG` (create it if missing) summarising the session.
  Use Edit (or Write if absent). Keep it to 2–4 sentences.
- Only if a *lasting* decision surfaced (a rule/convention that outlives this task), record it in
  the user's memory (`~/.claude/.../memory/`) or note it in the project CLAUDE.md. Never write
  transient working state here — that belongs only in the checkpoint.

## Phase 4 — Emit the resume prompt

Print the fenced block from `references/resume-prompt.md`, filled in, to the user. It must name
`./.claude/no-loss/latest.md`, give a 2–3 line TL;DR, state the next concrete step, and flag the
top gotcha. This block is also the `## Resume prompt` section inside the checkpoint file.

## Guardrails

- Idempotent: re-running overwrites `latest.md` and `.gitignore`, appends a new history file.
- Never commit checkpoints (the helper self-ignores `$NO_LOSS_DIR`).
- Never run the identified next step. Stop after Phase 4.
