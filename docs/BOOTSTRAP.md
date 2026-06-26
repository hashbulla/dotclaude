# Bootstrap — fresh-machine setup

Step-by-step walkthrough for setting up dotclaude on a new machine.

## Prerequisites

Install before cloning dotclaude:

- **Git** (any modern version)
- **Python 3.10+** (3.11+ recommended)
- **jq** — JSON validation in scripts
- **gh CLI** — GitHub auth + repo operations
- **An audio player** (Linux: `paplay` or `aplay`; macOS: `afplay` ships built-in)
- **Claude Code CLI** ([claude.com/claude-code](https://claude.com/claude-code))

Optional but useful:

- **direnv** — auto-load `.env.local` per directory
- **rtk** — token-saving proxy (see [RTK.md](../RTK.md))

## Step 1 — Clone

```bash
git clone https://github.com/hashbulla/dotclaude.git ~/.claude
cd ~/.claude
```

> Owner / contributors (push access): `git clone git@github.com:hashbulla/dotclaude.git ~/.clone`

If `~/.claude/` already exists (Claude Code initialized it on first run), back it up first:

```bash
mv ~/.claude ~/.claude.bak.$(date +%Y%m%d)
git clone https://github.com/hashbulla/dotclaude.git ~/.claude
cp ~/.claude.bak.*/{settings.local.json,identity.md,profile.md,.env.local,history.jsonl} ~/.claude/ 2>/dev/null || true
```

## Step 2 — Bootstrap

```bash
bash bootstrap.sh
```

Expected output:

```
━━━ 1/5 Host dependencies ━━━
  ✓ found: git
  ✓ found: jq
  ✓ found: python3
  ✓ audio player: paplay
  ✓ gh CLI: present

━━━ 2/5 Local templates ━━━
  ✓ seeded identity.md from identity.example.md
    → edit identity.md with your real values
  ✓ seeded profile.md from profile.example.md
    → edit profile.md with your real values
  ✓ seeded .env.local from .env.example
    → edit .env.local with your real values
  ✓ seeded settings.local.json from settings.example.local.json
  ✓ seeded hooks/config/hooks-config.local.json from hooks/config/hooks-config.local.example.json

━━━ 3/5 First-party skills ━━━
  ↓ cloning deep-research → ~/.local/share/dotclaude/skills/deep-research
  ✓ deep-research symlinked: ~/.claude/skills/deep-research → ~/.local/share/dotclaude/skills/deep-research
  ↓ cloning critical-harness → ~/.local/share/dotclaude/skills/critical-harness
  ✓ critical-harness symlinked: ~/.claude/skills/critical-harness → ~/.local/share/dotclaude/skills/critical-harness
  …

━━━ 4/5 Dangling symlink detector ━━━
  ✓ no dangling symlinks

━━━ 5/5 Hook system ━━━
  ✓ hook dispatcher imports + sound tree reachable

━━━ Done ━━━
```

## Step 3 — Fill in local-only files

The bootstrap seeded templates. Fill them in with real values:

```bash
$EDITOR ~/.claude/identity.md      # registrar contact / billing / KYC
$EDITOR ~/.claude/profile.md       # professional persona
$EDITOR ~/.claude/.env.local       # secrets (POSTHOG_API_KEY, etc.)
```

`settings.local.json` and `hooks-config.local.json` typically stay minimal. Add per-machine overrides as needed.

## Step 4 — Export secrets

`settings.json` references secrets via `${VAR}` interpolation. Source `.env.local` before launching Claude Code:

```bash
set -a
source ~/.claude/.env.local
set +a
```

Or use direnv:

```bash
cd ~/.claude
echo 'dotenv .env.local' > .envrc
direnv allow
```

After direnv setup, the env loads automatically whenever you `cd ~/.claude` (and propagates to child shells that launch `claude`).

## Step 5 — Launch

```bash
claude
```

Verify:

- `/skills list` — should show 50+ skills including `rpi:request`, `rpi:research`, `rpi:plan`, `rpi:implement`.
- `/agents list` — should show 10 RPI agents + symlinked agents.
- A `Stop` event hook should fire a sound when the turn ends.

## Step 6 — (Optional) Customize the third-party skill ecosystem

dotclaude documents (but does not auto-install) 25+ third-party skills:

- 18 `pbakaus/impeccable` skills
- 6 `paperclipai/paperclip` skills
- `hashbulla/dossier-intelligence`
- `hashbulla/proposition-commerciale-skill`

See `skills/EXTERNAL.md` for the full catalog and per-skill install commands.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common errors.
