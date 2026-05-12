# Troubleshooting

Common errors and the fix paths.

## Bootstrap fails with "missing required: jq"

Install jq:

```bash
# macOS
brew install jq

# Debian / Ubuntu
sudo apt install jq

# Arch
sudo pacman -S jq

# Fedora
sudo dnf install jq
```

Re-run `bash bootstrap.sh`.

## Bootstrap fails with "no audio player found"

Hooks will run silently — not fatal. Install an audio player:

```bash
# Linux
sudo apt install pulseaudio-utils    # paplay
# or
sudo apt install alsa-utils           # aplay

# macOS — afplay is built-in
```

Or set `SOUNDS_DISABLED=1` permanently in your shell rc; then dotclaude never tries to play sounds.

## Bootstrap fails cloning a first-party skill

The skill is private (`hashbulla/*` repos default to private). Check:

```bash
gh auth status
```

If not logged in: `gh auth login`. Then re-run bootstrap.

If the repo doesn't exist (e.g., user is on a different GitHub account), edit `skills.manifest.toml` to remove that skill, or change the `repo` URL.

## Claude Code says "POSTHOG_API_KEY not set"

The env var isn't sourced. Either:

```bash
set -a; source ~/.claude/.env.local; set +a
claude
```

Or set up direnv (see `docs/BOOTSTRAP.md`).

Or, if you don't use PostHog, remove the `posthog` MCP server block from `settings.json` and the env var reference from the `env` block.

## "Skill foo not found" or appears dangling

Run the dangling detector:

```bash
bash bootstrap.sh   # prints dangling symlinks
```

For each dangling skill:

- If it's a `hashbulla/*` first-party: re-run bootstrap, ensure `gh auth status` is OK.
- If it's a third-party (`pbakaus/impeccable`, etc.): see `skills/EXTERNAL.md` for the manual clone command.
- If you don't use it: `rm ~/.claude/skills/<name>`.

## Sound dispatcher fires but no sound plays

```bash
# Manual test
echo '{"hook_event_name":"Stop"}' | python3 ~/.claude/hooks/scripts/hooks.py
```

If silent:

```bash
# Check sound file exists
ls ~/.claude/hooks/sounds/stop/

# Check player works directly
paplay ~/.claude/hooks/sounds/stop/stop.wav

# Check env vars aren't suppressing
echo $SOUNDS_DISABLED $CLAUDE_QUIET
```

If `paplay` succeeds but dispatcher is silent: check `hooks/config/hooks-config.json` for `disableStopHook: true`.

## RPI command doesn't appear in /-menu

```bash
ls ~/.claude/commands/rpi/
# expect: implement.md  plan.md  request.md  research.md
```

If files exist but `/-menu` is empty, restart Claude Code (skill discovery happens at session start).

## CLAUDE.md changes don't take effect

CLAUDE.md is loaded at session start. Restart Claude Code (or `/clear` and start a fresh turn). The `@-import` chain (RTK.md → identity.md → profile.md) is shallow — verify those three files are readable.

## Hook script throws Python error

```bash
python3 ~/.claude/hooks/scripts/hooks.py --dry-run
```

If this fails, the dispatcher import is broken. Check the file hasn't been edited with syntax errors. Reset from origin:

```bash
cd ~/.claude
git checkout hooks/scripts/hooks.py
```

## Posthog or other MCP server fails to start

Check the env var is set in the shell that launched `claude`:

```bash
echo $POSTHOG_API_KEY    # should be non-empty
```

If empty: source `.env.local`.

If the value is wrong: edit `.env.local`, then restart Claude Code.

## "Permission denied" on a tool you expect to be allowed

dotclaude's `permissions.allow` is intentionally narrow. To widen for a specific case:

- Project-scope: add to `<project>/.claude/settings.local.json`.
- Per-machine: add to `~/.claude/settings.local.json`.
- Global: add to `~/.claude/settings.json` (commit it).

## Recovering from a broken commit

`~/.claude/` is a git repo. If something breaks:

```bash
cd ~/.claude
git status
git diff
git checkout -- <file>      # discard local changes to that file
```

Or rewind one commit:

```bash
git reset --hard HEAD~1     # destructive; user-authorized only
```

## Preflight backups

If bootstrap was run on top of an existing `~/.claude/`, the original critical files are at `/tmp/dotclaude.preflight/`:

```bash
ls /tmp/dotclaude.preflight/
# settings.json.orig  CLAUDE.md.orig  identity.md.orig  RTK.md.orig
# claude-init.SKILL.md.bak  claude-init.dir.bak/
# deep-research.pre-symlink-bak/
```

`/tmp` is volatile across reboots. If you need a longer-lived backup, copy elsewhere.

## When in doubt

```bash
/doctor                  # Claude Code's built-in diagnostics
git log --oneline -10    # what changed recently in dotclaude
```
