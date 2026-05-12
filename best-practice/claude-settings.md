# Claude Settings — hierarchy and secrets

Claude Code resolves settings through a fixed hierarchy. Knowing the order is the difference between "my change took effect" and an hour of debugging.

## Resolution order (highest priority first)

1. **Managed** (`/etc/claude-code/managed-settings.json` / MDM plist / Windows Registry) — organization-enforced. Cannot be overridden by user-level settings.
2. **CLI arguments** (`--model opus`, `--permission-mode plan`) — single-session overrides.
3. **Project local** (`<project>/.claude/settings.local.json`) — per-project personal, gitignored.
4. **Project shared** (`<project>/.claude/settings.json`) — per-project team-shared, committed.
5. **User local** (`~/.claude/settings.local.json`) — per-user-per-machine, gitignored.
6. **User shared** (`~/.claude/settings.json`) — per-user, the dotclaude default.
7. **Defaults** — Claude Code's built-in.

dotclaude's commitments:

- `settings.json` ships the team-shared global config — committed, no secrets.
- `settings.example.local.json` ships as the template for `settings.local.json` (per-machine override).

## Secret hygiene

dotclaude's settings.json holds **no secret values inline**. Anywhere you'd write a secret, you write `${VAR_NAME}`:

```json
{
  "env": { "POSTHOG_API_KEY": "${POSTHOG_API_KEY}" },
  "mcpServers": {
    "posthog": {
      "env": { "POSTHOG_API_KEY": "${POSTHOG_API_KEY}" }
    }
  }
}
```

The real value lives in `~/.claude/.env.local` (gitignored, mode 600). Claude Code interpolates `${VAR_NAME}` from the process env at startup. The shell exports the value via `direnv` or a manual `set -a; source .env.local; set +a` before launching `claude`.

## Required settings.json sections (per dotclaude)

- `$schema` — schemastore entry for editor completion.
- `outputStyle` — `Explanatory` by default (verbose; toggleable per session via `/output-style`).
- `permissions` — `allow` for safe ops, `deny` for secret files + destructive commands, `ask` skipped (we already prompt explicitly).
- `ignorePatterns` — files Claude shouldn't read (e.g., `.env`, `**/__pycache__/**`).
- `hooks` — all 27 hook events wired (see [claude-hooks.md](claude-hooks.md)).
- `mcpServers` — declared servers, env values via `${VAR}` interpolation.
- `spinnerVerbs` — peer-engineer voice (no "admiring X's code" derivative).
- `attribution` — commit + PR templates.
- `statusLine` — current run is `ccstatusline@latest`; replace per taste.

## permissions allow-list philosophy

The dotclaude allow-list is **narrow on purpose** for read-only / inspection commands (e.g., `Bash(git status)`, `Read`, `Glob`, `Grep`). Everything that mutates state requires a prompt.

The deny-list explicitly blocks reads of secret files (`**/.env`, `**/credentials.json`, `**/*.key`). Even with the deny-list, the `secrets-discipline.md` rule applies the conscience layer.

## Why the auto-compact override

`"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"` forces compaction earlier than the default (~95%). For agentic workflows with many tool calls, the late default produces silent context loss because compaction happens mid-turn. 80% gives slack for the current turn to finish.

## Overrides

For per-machine differences (different MCP servers, machine-specific allow-list, machine-specific spinner verbs), edit `~/.claude/settings.local.json`. The template is `settings.example.local.json`.

## Verifying

```bash
jq . ~/.claude/settings.json > /dev/null && echo "OK"
jq -r '.permissions.allow[]' ~/.claude/settings.json
jq -r '.hooks | keys[]' ~/.claude/settings.json  # should list 27 events
```
