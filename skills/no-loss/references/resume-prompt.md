# Resume-prompt format

A short block the user pastes into the next session. It rehydrates by POINTING at the durable
checkpoint, never by inlining it. Keep it under ~6 lines.

## Template

```text
Resume <ticket/goal>. First read ./.claude/no-loss/latest.md for full context.
TL;DR: <2–3 lines of where we are>.
We were about to <next concrete step>. Watch out for <top gotcha>.
Continue from there.
```

## Rules

- First line always names `./.claude/no-loss/latest.md` (the path is relative to the project root
  the next session opens in).
- The TL;DR is orientation, not a transcript — 2–3 lines max.
- Exactly one "next concrete step" — the same one in the checkpoint's Status section.
- One gotcha — the single thing most likely to trip a fresh context.
- No secrets, tokens, or credentials in the block (it gets pasted around).
