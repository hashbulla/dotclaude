# Security — secrets hygiene and rotation

dotclaude treats secret hygiene as load-bearing. The repo is private, but private-repo discipline is still defense-in-depth: clones land on laptops, screenshots get shared, paste-bins get indexed, CI logs get archived.

## The three rules

1. **No secret values in `settings.json`.** Anywhere a secret would appear, it's `${VAR_NAME}` interpolated from `~/.claude/.env.local`.
2. **`.env*`, `*.key`, `*.pem`, `credentials.*` are deny-listed.** Both at the `settings.json` `permissions.deny` layer and at the `rules/secrets-discipline.md` conscience layer.
3. **PII split from persona.** `identity.md` (PII) and `profile.md` (professional persona) are gitignored. Templates ship as `.example.md`.

## What's gitignored

```
.credentials.json
.env
.env.local
.env.presenton
.env.*
identity.md           # real PII (registrar address, phone, etc.)
profile.md            # real persona (gitignored to keep it personal)
settings.local.json   # per-machine setting overrides
hooks/config/hooks-config.local.json
history.jsonl         # session transcripts — may contain anything
hooks/logs/           # hook event log — may contain command lines
```

Plus all runtime ephemera (`cache/`, `sessions/`, `projects/`, `todos/`, `tasks/`, `telemetry/`, `statsig/`, `_archives/`, `backups/`, etc.).

## Secret-handling workflow

When you need a new secret:

1. Add a line to `~/.claude/.env.example` (template, committed):
   ```
   NEW_SERVICE_API_KEY=replace_me
   ```
2. Add the real value to `~/.claude/.env.local` (gitignored):
   ```
   NEW_SERVICE_API_KEY=real_value_here
   ```
3. Reference in `settings.json` or `mcp.json` via `${NEW_SERVICE_API_KEY}`.
4. Restart Claude Code so it re-reads the env.

## When a secret leaks

A secret has "leaked" the moment it lands somewhere outside `.env.local`:

- A chat transcript (this one counts).
- A screenshot you took for documentation.
- A paste-bin / GitHub Gist / Slack message.
- A CI log archive.
- A `git status` diff that captured `.env.local` accidentally.

Rotation steps in order:

1. **Rotate at the source.** Provider dashboard → revoke + issue new key.
2. **Update `~/.claude/.env.local`** with the new value.
3. **Restart Claude Code.**
4. **Sweep for residual instances** — `git log -p -S "<partial-prefix>"` across this repo and any related repo.
5. **If the secret was checked in**, also rewrite history: `git filter-repo --invert-paths --path <file>`. Force-push only after explicit authorization (you, the user, decide).

## The PostHog key incident (2026-05-12)

During the dotclaude bootstrap, the previous `settings.json` had a PostHog API key inline (prefix `phx_REDACTED…`, value redacted). This is the only secret known to have leaked: it appeared in the planning conversation for this repo.

Action taken:
1. Moved the value to `~/.claude/.env.local` (gitignored).
2. Replaced the inline value in `settings.json` with `${POSTHOG_API_KEY}`.

**Action still required from the user**: rotate the key at <https://eu.posthog.com> → Project settings → API keys. The leaked value should be revoked, not just hidden.

## Permissions layer

`settings.json` enforces the deny-list at the tool layer. If Claude tries to read a deny-listed path, the `Read` tool returns a permission denial before the file is opened. The deny patterns:

```jsonc
"deny": [
  "Bash(rm -rf *)",
  "Bash(rm -rf /)",
  "Read(path: **/.env)",
  "Read(path: **/.env.*)",
  "Read(path: **/.env.local)",
  "Read(path: **/config/secrets.*)",
  "Read(path: **/*.key)",
  "Read(path: **/*.pem)",
  "Read(path: **/credentials.json)",
  "Read(path: **/.aws/credentials)",
  "Read(path: **/.ssh/id_*)"
]
```

The `rules/secrets-discipline.md` rule loads when Claude touches a path matching the same patterns and adds the conscience layer: surface the file, refuse to echo, suggest env-var workflow.

## What goes in `history.jsonl`

Claude Code writes session transcripts here. The file can contain:

- User prompts (including any secrets you typed)
- Tool outputs (including command stdout / stderr)
- Tool inputs (the commands Claude ran)

`history.jsonl` is gitignored. Treat it as sensitive — back it up to encrypted storage, never to a public location. Inspect periodically and rotate when it grows large:

```bash
mv ~/.claude/history.jsonl ~/.claude/history.jsonl.$(date +%Y%m%d).bak
# Move .bak to encrypted backup, then delete.
```

## What goes in `hooks/logs/hooks-log.jsonl`

The hook dispatcher logs every event it receives. The log can contain:

- Tool names (`Bash`, `Read`, etc.)
- For `Bash`, the command string (which may contain sensitive flags, paths, or piped secrets)
- Event names + timestamps

Also gitignored. Same rotation cadence as `history.jsonl`. Disable entirely via `"disableLogging": true` in `hooks/config/hooks-config.json` if you don't need the audit trail.

## Backup discipline

- `~/.claude/` is a git repo. Push regularly.
- Local-only files (`identity.md`, `profile.md`, `.env.local`, `settings.local.json`) need a separate encrypted backup — 1Password, Doppler, infisical, vault, or encrypted disk image.
- Don't back up `cache/`, `sessions/`, `projects/`, `todos/` — they regenerate.

## Reporting a vulnerability

This is a personal dotfiles repo, not a product. If you spot a security issue (e.g., a leaked secret in commit history, a permission misconfiguration), open a GitHub issue with title prefixed `[security]`. The repo is private; security issues should not be made public on third-party forums or social.

## Future-proofing

If dotclaude ever goes public (the LICENSE permits it), do this first:

1. Sweep history for any committed secrets: `git log -p | grep -iE 'key|secret|token|api'` (manual review).
2. Decide whether to filter-repo or rewrite the entire history.
3. Verify `.gitignore` covers everything in this doc.
4. Rotate every secret in `.env.local` regardless — assume the worst.
