# External skills (symlinked from ~/.claude/skills/)

This file catalogs every skill in `~/.claude/skills/` that is a symlink pointing outside this repo. Inline skills (real directories) and bootstrap-installable skills (declared in `../skills.manifest.toml`) are listed separately at the bottom.

## Symlinked from third-party repos

### pbakaus/impeccable (18 skills + 1 agent)

Public repo: <https://github.com/pbakaus/impeccable>

| Symlink | Target inside upstream |
|---|---|
| `~/.claude/skills/adapt` | `.claude/skills/adapt` |
| `~/.claude/skills/animate` | `.claude/skills/animate` |
| `~/.claude/skills/audit` | `.claude/skills/audit` |
| `~/.claude/skills/bolder` | `.claude/skills/bolder` |
| `~/.claude/skills/clarify` | `.claude/skills/clarify` |
| `~/.claude/skills/colorize` | `.claude/skills/colorize` |
| `~/.claude/skills/critique` | `.claude/skills/critique` |
| `~/.claude/skills/delight` | `.claude/skills/delight` |
| `~/.claude/skills/distill` | `.claude/skills/distill` |
| `~/.claude/skills/harden` | `.claude/skills/harden` |
| `~/.claude/skills/impeccable` | `.claude/skills/impeccable` |
| `~/.claude/skills/layout` | `.claude/skills/layout` |
| `~/.claude/skills/optimize` | `.claude/skills/optimize` |
| `~/.claude/skills/overdrive` | `.claude/skills/overdrive` |
| `~/.claude/skills/polish` | `.claude/skills/polish` |
| `~/.claude/skills/quieter` | `.claude/skills/quieter` |
| `~/.claude/skills/shape` | `.claude/skills/shape` |
| `~/.claude/skills/typeset` | `.claude/skills/typeset` |
| `~/.claude/agents/anti-patterns.md` | `.claude/agents/anti-patterns.md` |

**Install**: `git clone https://github.com/pbakaus/impeccable.git ~/local-skills/Skills/impeccable` — the symlinks resolve automatically.

### paperclipai/paperclip (6 skills)

| Symlink | Target inside upstream |
|---|---|
| `~/.claude/skills/paperclip` | `skills/paperclip` |
| `~/.claude/skills/paperclip-converting-plans-to-tasks` | `skills/paperclip-converting-plans-to-tasks` |
| `~/.claude/skills/paperclip-create-agent` | `skills/paperclip-create-agent` |
| `~/.claude/skills/paperclip-create-plugin` | `skills/paperclip-create-plugin` |
| `~/.claude/skills/paperclip-dev` | `skills/paperclip-dev` |
| `~/.claude/skills/para-memory-files` | `skills/para-memory-files` |

**Install**: `git clone https://github.com/paperclipai/paperclip.git ~/local-skills/paperclip` — adjust paths if your AIEngineering layout differs.

## Symlinked but no remote (machine-local content)

`skill-generator` and `skill-harness` were in this category historically. Since the migration on 2026-05-12 they are auto-installed via the manifest (`hashbulla/skill-generator`, `hashbulla/skill-harness`). No machine-local-only skills remain.

## Inline skills (real directories in this repo)

These ship with dotclaude itself and don't need installation:

- `~/.claude/skills/no-loss/` — zero-context-loss session checkpoint + resume prompt (AI-70).

## Bootstrap-installed (per skills.manifest.toml)

Auto-installed by `bootstrap.sh` from `hashbulla/*` GH repos. Symlinks resolve after bootstrap:

- `deep-research`
- `critical-harness`
- `claude-init`
- `skill-generator`
- `skill-harness`

## On a fresh machine

Bootstrap detects dangling symlinks. For each one pointing to a third-party ecosystem you want:

```bash
# pbakaus/impeccable
git clone https://github.com/pbakaus/impeccable.git ~/local-skills/Skills/impeccable

# paperclipai/paperclip
git clone https://github.com/paperclipai/paperclip.git ~/local-skills/paperclip
```

If you don't want a particular symlink at all:

```bash
rm ~/.claude/skills/<symlink-name>
```

The skill simply disappears from `/-menu`.
