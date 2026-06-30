# Playbooks

Reusable architecture playbooks validated across projects. Each playbook is a folder with its own README, deep-research output (if applicable), and operational notes.

## Index

| Playbook | Folder | Validated | Use when |
|---|---|---|---|
| **Claude Code on Koyeb with Channels** | [claude-code-koyeb-channels/](claude-code-koyeb-channels/) | 2026-06-25 | Deploying an always-on Claude Code session triggered by external webhooks (GHA cron), pushing to chat channels (Telegram / Discord / iMessage). Covers OAuth headless auth via `CLAUDE_CODE_OAUTH_REFRESH_TOKEN`, Koyeb tier selection, custom webhook channel scaffolding, Telegram-plugin operational caveats, HMAC vs shared-secret webhook auth. Note: Koyeb acquired by Mistral AI (2026-02-17). |
| **Klavis Strata MCP (Gmail focus)** | [klavis-mcp/](klavis-mcp/) | 2026-06-25 | Integrating the Klavis hosted MCP server (esp. Gmail toolkit) with Claude Code, Managed Agents, or any MCP consumer. **Architecture changed (2026-06-25): Strata now uses progressive discovery (5-6 meta-tools).** Covers strata_id-as-credential security model, silent-label-drop anti-pattern (label IDs vs names), 24h OAuth health check, batch-modify capacity planning. |
| **Scrapling 0.4.x** | [scrapling/](scrapling/) | 2026-06-25 | Production scraping with Scrapling 0.4.x (current: 0.4.9). Anti-detection stack, 10-tool MCP, perf verdict, real failure modes. Note: `follow_redirects="safe"` default added in 0.4.9; 0.4.8 has critical regression — upgrade required. |
| **Context7 MCP** | [context7/](context7/) | 2026-06-25 | Version-current library docs via Upstash Context7. Two-tool surface, 2026 reranking redesign, Issue #1713 workaround (pkg now 3.x), ctx7 CLI (Pattern 0), free-tier budget (1,000 calls/mo). |
| **Unipile (social ↔ agent bridge)** | [unipile/](unipile/) | 2026-06-30 | Wiring a Claude agent to send/receive across LinkedIn, WhatsApp, Telegram, Gmail via Unipile's unified messaging API. Account model (1 identity per network, 49€ ≤10), Hosted-Auth (session cookie never touches the agent), webhooks (`new_relation`/`new_message`) for receive, the cadence guardrail (relays platform limits, never lifts them — LinkedIn ban-risk), GDPR-FR posture (Scaleway FR, DPA Art. 28). Worked example: the LinkedIn outreach If-Connection loop. Live creds 2026-06-30. |

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
