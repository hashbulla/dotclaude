# Portability

Which parts of dotclaude move cleanly to a new machine, which need configuration, which need full reinstall.

## Fully portable (just clone)

These files ship as-is in the repo and work identically on any host where the prerequisites are installed:

- `CLAUDE.md`, `RTK.md`
- `settings.json`, `settings.example.local.json`
- `agents/*.md`
- `commands/**/*.md`
- `rules/*.md`
- `hooks/scripts/hooks.py`, `hooks/config/hooks-config.json`, `hooks/config/hooks-config.local.example.json`, `hooks/sounds/**`
- `best-practice/*.md`, `docs/*.md`
- `skills/no-loss/` (inline skill, ships with evals)
- `playbooks/{claude-code-koyeb-channels,klavis-mcp}/`
- `bootstrap.sh`, `skills.manifest.toml`
- `.gitignore`, `.env.example`

## Local-only (gitignored, seed from templates)

These files contain machine- or user-specific values. Bootstrap copies the `.example` template; you fill in the real values.

| Local file | Template | Contains |
|---|---|---|
| `identity.md` | `identity.example.md` | PII (postal address, phone, registrar JSON) |
| `profile.md` | `profile.example.md` | Professional persona (role, expertise, preferences) |
| `.env.local` | `.env.example` | Real secret values (POSTHOG_API_KEY, etc.) |
| `settings.local.json` | `settings.example.local.json` | Per-machine setting overrides |
| `hooks/config/hooks-config.local.json` | `hooks/config/hooks-config.local.example.json` | Per-machine hook toggles |

## Cloneable (bootstrap auto-installs)

Skills declared in `skills.manifest.toml`. Bootstrap clones the upstream repo and symlinks it into `~/.claude/skills/`.

- `hashbulla/deep-research`
- `hashbulla/critical-harness`
- `hashbulla/claude-init-skill`
- `hashbulla/skill-generator`
- `hashbulla/skill-harness`

If the bootstrap fails to clone (offline, lack of access), the affected symlinks dangle. The dangling-symlink detector prints them; you re-run bootstrap when connectivity is back.

## Symlinked third-party (manual install)

Catalogued in `skills/EXTERNAL.md`. dotclaude carries the symlink (so the slash command exists) but does NOT auto-clone the upstream.

| Ecosystem | Repo | Symlinks under skills/ |
|---|---|---|
| impeccable | `pbakaus/impeccable` | adapt, animate, audit, bolder, clarify, colorize, critique, delight, distill, harden, impeccable, layout, optimize, overdrive, polish, quieter, shape, typeset (18 skills) |
| paperclip | `paperclipai/paperclip` | paperclip, paperclip-converting-plans-to-tasks, paperclip-create-agent, paperclip-create-plugin, paperclip-dev, para-memory-files |
| Other | `hashbulla/dossier-intelligence`, `hashbulla/proposition-commerciale-skill` | dossier-intelligence, proposition-commerciale |

To install on a new machine: `git clone <repo> ~/local-skills/<path>` — the existing symlinks then resolve.

To remove from your machine: `rm ~/.claude/skills/<name>` for each symlink that points to an ecosystem you don't use.

## Host responsibilities (install separately)

- Claude Code CLI itself
- MCP server binaries (the user-scope MCP registry — `tavily`, `fetch`, `presenton`, `scrapling`, `context7` — is registered via `claude mcp add --scope user`, not from this repo)
- `gh` CLI auth (your GitHub login)
- Audio drivers / shell aliases / OS-level prefs

## Machine-specific differences

If two machines need different settings, use the `settings.local.json` override layer rather than editing `settings.json` and creating drift. Common per-machine overrides:

- Permission allow-list (more relaxed on personal laptop, stricter on work box)
- MCP servers (local-only services on dev machines)
- Hook config toggles (silent in CI, audible in dev)

## Verifying portability

Test the full bootstrap on a clean machine (or a fresh user account):

```bash
git clone git@github.com:hashbulla/dotclaude.git /tmp/dotclaude-test
cd /tmp/dotclaude-test
bash bootstrap.sh
```

Bootstrap should exit 0. Local-only files seeded from templates. First-party skills cloned. Symlinks resolved. Hook dispatcher dry-run passes.
