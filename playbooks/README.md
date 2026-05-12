# Playbooks

Reusable architecture playbooks validated across projects. Each playbook is a folder with its own README, deep-research output (if applicable), and operational notes.

## Index

| Playbook | Folder | Validated | Use when |
|---|---|---|---|
| **Claude Code on Koyeb with Channels** | [claude-code-koyeb-channels/](claude-code-koyeb-channels/) | 2026-04-29 | Deploying an always-on Claude Code session triggered by external webhooks (GHA cron), pushing to chat channels (Telegram / Discord / iMessage). Covers OAuth headless auth via `CLAUDE_CODE_OAUTH_REFRESH_TOKEN`, Koyeb tier selection, custom webhook channel scaffolding, Telegram-plugin operational caveats, HMAC vs shared-secret webhook auth. |
| **Klavis Strata MCP (Gmail focus)** | [klavis-mcp/](klavis-mcp/) | 2026-04-30 | Integrating the Klavis hosted MCP server (esp. Gmail toolkit) with Claude Code, Managed Agents, or any MCP consumer. Covers the 10-tool default subset (canonical `*_email` naming, NOT `*_message`), absence of label-management tools in the default subset, the `raw-actions` endpoint for full discovery, instance_id-as-credential security model, silent-label-drop anti-pattern (label IDs vs names), 24h OAuth health check, batch-modify capacity planning. |

## Freshness rule

> Re-run the playbook's deep-research before relying on it if the report timestamp is more than **4 weeks old**.

Tooling and vendor APIs change. Playbooks rot. The validated date in the table above is the trust horizon. Beyond 4 weeks, re-validate with `/deep-research` against the playbook's core claims before committing to a deployment.

## Adding a new playbook

1. Create a new folder under `playbooks/<name>/`.
2. Write a `README.md` with: purpose, hero use cases, prerequisites, step-by-step deployment, validation checklist, known gotchas.
3. If the playbook is research-heavy, save the `/deep-research` output as `playbooks/<name>/research-report.md` with a clear retrieval timestamp.
4. Add an entry to the table above.

A playbook is worth writing when:

- It orchestrates 3+ separate systems (e.g., Claude Code + Koyeb + GitHub Actions + Telegram).
- It captures operational knowledge that's not in any single vendor's docs.
- It's been deployed at least once successfully (don't speculate — document what you've shipped).
