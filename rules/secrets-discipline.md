---
paths: "**/.env*,**/secrets.*,**/credentials.*,**/*.key,**/*.pem,**/.aws/credentials,**/.ssh/id_*"
description: Secrets — refuse to read, never log, suggest env-var workflow. Applies whenever Claude touches a secret-looking file.
---

# Secrets discipline

When you encounter a file that matches the `paths:` patterns above, you must follow this contract — no exceptions.

## The contract

1. **Do not read the contents.** The `~/.claude/settings.json` deny-list already blocks this at the tool layer; this rule is the conscience layer.
2. **Do not echo, log, or quote** the contents anywhere — chat output, comments, commit messages, screenshots, MCP server payloads, telemetry.
3. **Do not commit the file.** Refuse, even if asked. Suggest the env-var workflow instead.
4. **Suggest rotation if a value has plausibly leaked** (entered a transcript, a public screenshot, a paste-bin, a CI log, an external MCP server).

## When the user asks you to handle a secret

Default reply pattern:

> The path you mentioned looks like a secret file. Per my secrets-discipline rule:
> - I won't read or echo the contents.
> - If you need to inject the value at runtime, the pattern is: store it in `~/.claude/.env.local` (gitignored) and reference it from `settings.json` via `${VAR_NAME}` interpolation.
> - If you need to share the secret across machines, use a secrets manager (1Password, Doppler, infisical, vault) — never a checked-in file.
> Want me to set up the env-var wiring?

## When you find a secret already in a tracked file

This is an incident. Steps in order:

1. **Stop and surface it.** Tell the user, paste the file path and the line, but **never the secret value itself**.
2. **Refuse to add the file to a commit.** Even if it was already tracked in a prior commit, don't add a new diff that touches the secret line.
3. **Suggest rotation immediately.** The secret has plausibly leaked (history, screen-share, log archive, etc.).
4. **Document the cleanup path**:
   - Rotate the secret at the source (provider dashboard).
   - Remove the secret from the file; replace with `${VAR_NAME}` interpolation.
   - Purge from git history if the repo is sensitive: `git filter-repo --invert-paths --path <file>`. **Confirm with the user before destructive history rewrite.**
   - Force-push only after explicit user authorization.

## Env-var workflow (the recommended pattern)

1. Real value lives in `~/.claude/.env.local` (gitignored, mode 600).
2. Template `~/.claude/.env.example` (committed, no real values) documents which env vars exist.
3. Shell exports the value before launching `claude` — typically via `direnv` or a shell rc snippet that reads `.env.local`.
4. `~/.claude/settings.json` references it as `${VAR_NAME}`. Claude Code interpolates at process start.

## Anti-patterns

- ❌ "Just this one time" exception — every leaked secret was a "just this one time".
- ❌ Base64-encoding a secret to "hide" it in a commit. Base64 is not encryption.
- ❌ Embedding secrets in `*.example.*` templates as "placeholders the user will replace". Placeholders look like `<replace-me>`, not real-looking values.
- ❌ Using a secret as an MCP server argument inline (visible in `claude mcp list`). Wire it through env vars.
- ❌ Reading `.env` files "just to check the format". The format is the same everywhere; read `.env.example` instead.
