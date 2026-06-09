# Claude Memory — CLAUDE.md design

Every byte in `~/.claude/CLAUDE.md` is loaded into every Claude Code session at user scope. The doctrine: keep it under 200 lines and surface only what's load-bearing on every prompt.

## The 200-line ceiling

The reference repo (`shanraisshan/claude-code-best-practice`) flagged 200 lines as the empirical ceiling for reliable adherence; Anthropic's own docs say the same ("target under 200 lines… bloated files cause Claude to ignore your actual instructions", retrieved 2026-06-09). Past that, attention to individual directives drops. Run `scripts/audit-config.sh` for the live count — never assert it in prose (asserted numbers rot: this doc once claimed "~75 lines" while the file sat at 317). The heavy content lives in:

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

## Config invariants + growth rule (anti-drift)

`scripts/audit-config.sh` is the executable contract — the gate the 200-line ceiling lacked while the file grew to 317. It hard-fails (exit 1, blocks the commit when wired to `.git/hooks/pre-commit`) on: CLAUDE.md > 200 lines, any `rules/*.md` > 100, or a cheat-sheet/pitfalls block inlined in CLAUDE.md. It warns on a doc that asserts CLAUDE.md's line count and on oversized best-practice docs.

```bash
bash scripts/audit-config.sh          # run before every commit; exit 0 = within budget
```

**The growth rule (why the file drifted, and how it won't again).** dotclaude bloated because each new domain (Scrapling → Context7 → Code-Gen) was added by mirroring the previous one's *always-on dual-block* — a routing table **plus** an autonomous-trigger block **plus** a cheat-sheet **plus** pitfalls. That template cost ~80–100 always-on lines per domain. It stops here:

- A new domain does **not** get an always-on dual-block. It gets either a lazy `rules/<domain>.md` (if file-triggered, like code-gen) **or** one compressed always-on stanza — routing rows + a single "fire proactively when…" line — if intent-triggered (search, docs, scraping).
- **Cheat-sheets, pitfalls, worked examples, and multi-paragraph notes NEVER live in CLAUDE.md.** Their home is the domain's `playbooks/<domain>/` (or the command/skill file); CLAUDE.md keeps a one-line pointer.
- Before adding to CLAUDE.md, apply Anthropic's test: "Would removing this line cause Claude to make a mistake?" If not, cut it.
