# Architecture

dotclaude is a versioned dotfiles repo for `~/.claude/`. It organizes Claude Code's user-scope configuration into a layered architecture with clear separation of concerns.

## Layers (top to bottom)

```
┌──────────────────────────────────────────────────────────────┐
│  README.md / CHANGELOG / LICENSE                              │  Meta
├──────────────────────────────────────────────────────────────┤
│  CLAUDE.md  + @identity.md + @profile.md + @RTK.md            │  Every-session context
├──────────────────────────────────────────────────────────────┤
│  rules/<topic>.md                              (lazy-loaded)  │  File-pattern doctrine
├──────────────────────────────────────────────────────────────┤
│  agents/<name>.md                                             │  Subagent personas
│  commands/<name>.md                                           │  Slash workflows
│  skills/<name>/SKILL.md (inline + symlinked)                  │  Reusable knowledge
├──────────────────────────────────────────────────────────────┤
│  hooks/scripts/hooks.py + hooks/config/ + hooks/sounds/       │  Reactive layer
├──────────────────────────────────────────────────────────────┤
│  settings.json (+ settings.local.json overrides)              │  Configuration
│  .env.local (gitignored)                                      │  Secrets
├──────────────────────────────────────────────────────────────┤
│  best-practice/<topic>.md                                     │  Doctrine docs
│  docs/<topic>.md                                              │  Reference docs
│  playbooks/<name>/                                            │  Operational runbooks
│  workflows/rpi/                                               │  RPI template + diagram
└──────────────────────────────────────────────────────────────┘
```

## Separation of concerns

Each layer has one job. Mixing layers is the most common dotfile-repo failure mode.

| Layer | Owns | Doesn't own |
|---|---|---|
| **CLAUDE.md** | what loads every session | how things are implemented |
| **rules** | doctrine that applies to specific file types | every-session behavior (that's CLAUDE.md's job) |
| **agents** | personas + behavior contracts | orchestration (commands do that) |
| **commands** | workflow orchestration | implementation (agents do that) |
| **skills** | reusable, addressable knowledge | session-level guidance (rules / CLAUDE.md) |
| **hooks** | reactive side-effects on events | proactive guidance (CLAUDE.md / rules / agents) |
| **settings** | configuration | guidance / doctrine |
| **secrets** | secret values | configuration shape (settings.json does that) |
| **best-practice** | doctrine explanations | runtime behavior |
| **docs** | reference for humans | runtime behavior |
| **playbooks** | operational runbooks (multi-system orchestration) | single-system docs |

## The chain of trust

```
User → CLAUDE.md (loaded every session)
         ↓
       rules (loaded when relevant files touched)
         ↓
       agents (invoked by commands)
         ↓
       skills (invoked by agents or directly)
         ↓
       hooks (reactive, run on events)
```

Each layer can only invoke the layer below it. CLAUDE.md can reference everything; rules can mention agents/skills; agents can invoke skills and other agents (via `Agent` tool); skills can use hooks; hooks are leaves.

## Portability boundary

The repo lives at `~/.claude/`. On a fresh machine:

1. `git clone git@github.com:hashbulla/dotclaude.git ~/.claude`
2. `cd ~/.claude && bash bootstrap.sh`

The bootstrap script:

- Seeds local-only files (`identity.md`, `profile.md`, `.env.local`, `settings.local.json`, `hooks-config.local.json`) from `.example` templates.
- Clones first-party skills declared in `skills.manifest.toml`.
- Verifies the hook dispatcher works.
- Reports any dangling symlinks.

After that, launching `claude` works.

## Symlink strategy

Three categories of skill in `~/.claude/skills/`:

1. **Inline** (real directories committed): `no-loss`. Ships with dotclaude. (`claude-init` and `synthese` are not tracked inline — they install via `skills.manifest.toml` or manual clone.)
2. **Auto-installed first-party** (cloned by bootstrap, symlinked): `deep-research`, `critical-harness`, `claude-init`. Manifest in `skills.manifest.toml`. (`skill-generator` and `skill-harness` are private — not-yet-public, not in the manifest.)
3. **Symlinked third-party** (manual install): `impeccable/*` (18 skills), `paperclip/*` (6 skills), `dossier-intelligence`, `proposition-commerciale`. Catalogued in `skills/EXTERNAL.md`.

Bootstrap detects dangling symlinks and prints repair commands.

## What dotclaude doesn't ship

- The actual project work (lives in per-project `.claude/`).
- The Claude Code binary (installed separately).
- Third-party MCP server binaries (installed separately).
- Browser, audio drivers, git, jq, python3 (host responsibilities — bootstrap checks for them).
