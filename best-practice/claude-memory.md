# Claude Memory — CLAUDE.md design

Every byte in `~/.claude/CLAUDE.md` is loaded into every Claude Code session at user scope. The doctrine: keep it under 200 lines and surface only what's load-bearing on every prompt.

## The 200-line ceiling

The reference repo (`shanraisshan/claude-code-best-practice`) flagged 200 lines as the empirical ceiling for reliable adherence. Past that, attention to individual directives drops. dotclaude's `CLAUDE.md` is ~75 lines; the heavy content lives in:

- `@identity.md` — PII (gitignored).
- `@profile.md` — professional persona (gitignored).
- Tables for MCP registry, search routing, slash commands, playbooks (concise — each row is ~120 chars).

Heavy doctrine (this folder) is NOT loaded at session start. It loads only when Claude reads it directly, or when a rule with `paths:` fires.

## `@` imports

`@file.md` in CLAUDE.md inlines the contents of `file.md` at session start. The pattern:

```markdown
@RTK.md
@identity.md
@profile.md
```

Three imports = three small files instead of one big file. Each can be edited / gitignored independently. The downside: `@` is shallow — imports don't chain; an `@-imported` file can't itself contain another `@`.

## Lazy-loaded rules

For doctrine that should *only* load when a relevant file is touched, use `.claude/rules/<topic>.md` with YAML frontmatter:

```yaml
---
paths: "**/*.py"
description: Python style rules — loaded only when Claude touches a .py file.
---
```

The rule loads on demand. Heavy enforcement (e.g., 200-line Python style guide) belongs in a rule, not in CLAUDE.md.

## Per-project vs user-scope

dotclaude lives at user scope (`~/.claude/`). It loads in every project. For project-specific guidance, the project has its own `.claude/CLAUDE.md` (project root or repo root). Both load; the project's wins on conflict.

## Why split identity from profile

`identity.md` is PII (postal address, phone, registrar JSON). It must be gitignored. It's also ~60 lines.

`profile.md` is professional persona (role, expertise, working style). It's also gitignored, but for a different reason — it's personal preference, not PII. Splitting lets either file evolve without dragging the other.

Together they're ~140 lines; merged they'd cross the 200-line ceiling.

## When to add content to CLAUDE.md

- The directive needs to fire on **every** session, regardless of which file you're editing.
- The directive is short enough not to dominate context.
- Tables / registries beat prose for repeated lookups.

## When NOT to add content to CLAUDE.md

- The directive applies only to a specific file type → use a rule with `paths:`.
- The directive is doctrine that explains *why* something works the way it does → put it in `best-practice/` (this folder).
- The directive duplicates a skill or agent's own description → trust the skill's `description` field for auto-discovery.

## Verifying CLAUDE.md size

```bash
wc -l ~/.claude/CLAUDE.md ~/.claude/identity.md ~/.claude/profile.md ~/.claude/RTK.md
```

Total across all `@-imported` files should stay around 200 lines.
