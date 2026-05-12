---
paths: "**/*.md"
description: Documentation style rules — loaded only when Claude touches a Markdown file.
---

# Markdown documentation rules

These rules govern every `.md` file you create or edit. They are session-level discipline: keep docs precise, navigable, and consistent.

## Structure

- **One topic per file.** If a doc starts to need three top-level sections about unrelated things, split it.
- **Heading hierarchy is never skipped.** H1 → H2 → H3, no jumping H2 → H4.
- **Front-matter at the top, never mid-file.** YAML between `---` delimiters.
- **First line after H1 is a one-sentence summary.** Prefer a `>` blockquote tagline when the file is a skill/agent/command/playbook README.

## Voice

- **Active voice, present tense.** "The hook fires on PreToolUse" — not "PreToolUse is fired by the hook".
- **No hedging** ("perhaps", "you might want to", "it could be useful to"). State the recommendation or omit it.
- **Cite sources for non-obvious technical claims** — Tavily search, vendor docs, RFCs, GitHub permalinks. Include the retrieval date when freshness matters.
- **No emoji** unless the user explicitly asks for them. Section dividers with ☕️ / 🎨 / 🚀 are noise.

## Links

- **Relative links between docs in the same repo.** `[CLAUDE.md](../CLAUDE.md)`, not `https://github.com/…/CLAUDE.md`.
- **Permalinks for external code** — `https://github.com/<org>/<repo>/blob/<commit-sha>/<path>#L<line>`, never `main` (which rots).
- **Backlinks on doctrine pages.** A best-practice doc should link to the file/pattern it documents; that file should link back to the doctrine.

## Code blocks

- **Always declare the language.** `​```bash`, `​```python`, `​```yaml` — never bare triple-backticks.
- **Indentation matches the surrounding ecosystem.** 2 spaces for YAML/TS/JS, 4 for Python (unless you have a reason otherwise).
- **Comments inside code blocks** stay short and explain *why*, not *what*.

## Tables

- **Use tables for structured comparisons** (3+ rows, 2+ columns of parallel data). For ≤2 rows, prefer a bullet list.
- **Left-align unless you have a column of pure numbers**; numeric columns right-align.
- **Header row is mandatory** even when the table is short.

## Lists

- **Bullets for unordered enumerations**, numbers only when order is load-bearing (steps, ranking).
- **Parallel grammar in list items** — every item starts with a verb, or every item is a noun phrase. Don't mix.

## Length

- **CLAUDE.md ≤ 200 lines** for reliable adherence — longer files lose attention.
- **Skill SKILL.md ≤ ~150 lines** with details pushed into `references/` (one level deep, never cross-linked).
- **Rules ≤ ~100 lines** each — if longer, split or move content into a best-practice doc.

## Anti-patterns

- ❌ Mixing tutorial prose with reference material in one file.
- ❌ Embedding screenshots without alt text.
- ❌ Multi-paragraph blockquotes used as content (blockquotes are for short callouts).
- ❌ "TODO: …" markers without an issue number or owner.
- ❌ Bare URLs as link text — use descriptive anchor text.
