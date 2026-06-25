# Claude Rules — lazy-loaded doctrine via `paths:`

Rules are doctrine that loads on demand — only when Claude touches a file matching the rule's `paths:` glob. Heavy enforcement stays out of every-session context.

## When to use a rule vs CLAUDE.md

| If the doctrine… | Use |
|---|---|
| Applies to *every* session, *every* file | CLAUDE.md (or @-imported file like `profile.md`) |
| Applies only when a specific file type is touched | `rules/<topic>.md` with `paths:` |
| Is reference material (a skill's references/) | `references/<topic>.md` |
| Is a workflow with steps | command (`commands/<name>.md`) |
| Is a persona / behavior package | agent (`agents/<name>.md`) |

The mistake to avoid: dumping all doctrine into CLAUDE.md. Every byte loaded every session compounds. Lazy-load aggressively.

## Frontmatter

```yaml
---
paths: "**/*.py"                                    # glob, comma-separated for multiple
description: <one-line summary for editor>
---

# Body of the rule
```

Without frontmatter `paths:`, the rule loads in every session like CLAUDE.md. With `paths:`, it loads only when Claude reads/edits a matching file.

## Glob syntax

Standard glob: `*`, `**`, `[…]`, `{a,b,c}`.

```yaml
paths: "**/*.{py,pyi}"                              # all Python files
paths: ".git/**,**/COMMIT_EDITMSG"                  # git internals + commit messages
paths: "**/prompts/**/*,**/agents/**/*,**/llm/**/*" # AI engineering dirs
paths: "rpi/**/*"                                   # only when in an RPI feature dir
```

dotclaude rules apply user-scope — they're in `~/.claude/rules/`. Project-scope rules live in `<project>/.claude/rules/`. Both fire; user-scope is the floor, project-scope overrides on conflict.

## Default rules in dotclaude

11 rules total. Most use `paths:` for lazy-loading; three use CLAUDE.md `<important if>` triggers instead (see note below).

| File | `paths:` | Topic |
|---|---|---|
| `markdown-docs.md` | `**/*.md` | Documentation style |
| `git-commit-discipline.md` | `**/.git/**,**/COMMIT_EDITMSG` | One-file-one-commit, conventional commits |
| `shell-scripts.md` | `**/*.sh,**/*.bash` | strict mode, quoting, shellcheck |
| `python-style.md` | `**/*.py,**/pyproject.toml` | Type hints, ruff, no print debugging |
| `typescript-style.md` | `**/*.ts,**/*.tsx` | strict mode, no `any`, ESM-first |
| `ai-engineering.md` | AI dirs | Prompt-cache, eval-first, citation discipline |
| `secrets-discipline.md` | secret-looking paths | Refuse to read, suggest env vars |
| `rpi-review-citation.md` | `rpi/**/*` | Citation Grounding rule for RPI reviewers |
| `agentic-loops.md` | *(CLAUDE.md trigger)* | Lock vs. opt-in gates; hook enforcement policy |
| `linear-pm.md` | *(CLAUDE.md trigger)* | Linear PM discipline on every Linear op |
| `code-generation.md` | `**/*.{py,ts,tsx,js,sh,…}` | Codegraph prime, spec-first, TDD, verify before done |

**Note:** rules without `paths:` frontmatter (`agentic-loops.md`, `linear-pm.md`) are surfaced by CLAUDE.md `<important if>` triggers instead. This is a legitimate design choice for ambient doctrine that applies to any task regardless of which files are open — it is not the anti-pattern of dumping everything into CLAUDE.md, because the rule body stays in its own file and loads only when the trigger fires.

## Writing a new rule

Keep rules ≤ 100 lines. If a rule needs more, split it or move heavy doctrine into `best-practice/<topic>.md` and link from the rule.

Lead with **the contract** (what MUST or MUST NOT happen). Then **how** (specific patterns to use/avoid). End with **anti-patterns** as a bulleted list.

## Anti-patterns (for rule design itself)

- Rules without `paths:` frontmatter AND without a CLAUDE.md `<important if>` trigger — they load every session. Defeats the purpose.
- Rules longer than ~100 lines — Claude's attention drops; split.
- Rules that duplicate CLAUDE.md content — pick one location.
- Rules whose `paths:` glob is so wide it always fires (`paths: "**/*"`) — equivalent to no glob.
- Rules that conflict with each other (e.g. python-style and ai-engineering both saying contradictory things) — coordinate, or scope tighter.

## Verifying rule load

When Claude touches a matching file, the rule appears in the loaded context. You can verify by asking Claude what rules are loaded after opening a `.py` file vs after opening a `.md` file.
