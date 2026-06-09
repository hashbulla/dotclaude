# Scrapling playbook

> Validated 2026-05-20 against scrapling 0.4.8. Re-run `/research` and refresh this folder if more than 4 weeks have passed since the validation date.

## What's in this folder

- [research-report.md](research-report.md) — the canonical decision document. Sections: API surface (§1), MCP server (§2), anti-detection breakdown (§3), performance honest verdict (§4), production concerns (§5), critiques (§6), comparison matrix (§7), recommendation (§8). 27 cited sources, 85% Tier 1/2, 100% groundedness.
- [research-sources.json](research-sources.json) — Admiralty-graded ledger of every cited source.
- [research-evidence.json](research-evidence.json) — claim → source-IDs map with credibility (1–6).

## What's wired globally

1. **`scrapling` MCP server at user scope** (stdio) — see the MCP Registry table in `~/.claude/CLAUDE.md`.
2. **Scraping Routing Decision Table** in `~/.claude/CLAUDE.md` — codifies when to reach for Scrapling vs `selectolax` vs `httpx` vs Scrapy.
3. **Pipx-installed `scrapling` CLI** at `~/.local/bin/scrapling` (Python 3.13 venv managed by pipx).

## When to refresh

- A new minor release (0.5.x) — re-run `/research --since` on the changelog and update §1, §2 of the report.
- A new MCP tool added to `scrapling/core/ai.py` — refresh §2.2 (the 10-tool table).
- A new anti-bot countermeasure incident (e.g. Cloudflare WAF revamp) — refresh §3.2.
- The maintainer's bus factor changes (project archived, second maintainer added) — refresh §6.
