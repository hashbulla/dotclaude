# Research plan: Linear PM discipline + Linear MCP agent-ops patterns

> Generated: 2026-06-24 · Skill: deep-research · Status: planned — proceeding to Phase 1

## 1. Question & scope

**Research question:** Codify a global Claude Code user-scope rule (`~/.claude/rules/linear-pm.md`) so every Linear interaction by the agent is PM-grade — covering Linear's product model, The Linear Method, the "good issue" discipline, Linear Agents, the Linear MCP server surface + agent-ops idempotence rules, and importable community assets. Calibrated for a SOLO freelance "AI Agency" workspace (6-state workflow, single `Type` label group, no cycles, no initiatives).

**Classification:** technical
**Tier profile:** Tier 1+2 technical, with a deliberate exception — the authoritative sources here are vendor-official (`linear.app/docs`, `linear.app/method`, `developers.linear.app`, `mcp.linear.app`, Linear changelog/blog). These are graded Tier 2 reliability B (vendor-official primary documentation). GitHub official-org repos and well-known dev docs are Tier 2. Community assets (GitHub repos, Cursor rules) are Tier 3/4 and admissible only as importable-asset signals, never as factual support for Linear's own semantics.
**Length:** standard (focused) — ~6 sub-questions, target 25–40 cited sources
**Output language:** en
**Recency window:** since 2024-01-01 (Linear Agents + MCP shipped 2025; agent guidance is recent)
**Min corroboration:** 2 (relaxed to 1 for vendor-official primary docs, since linear.app IS the authoritative source for its own product semantics — single-source vendor docs are credibility 3 by cascade and flagged)
**Model tier:** session model opus · synthesis opus · grading inline (≤6 sub-questions)
**Confidential path:** no

## 2. Sub-question decomposition

| ID | Category | Sub-question | Tavily tool | include_domains (preview) | time_range | Target |
|---|---|---|---|---|---|---|
| sq1 | factual | Linear's product-model primitives: issues, sub-issues, projects, initiatives, cycles, milestones, triage, workflow states (4 categories: backlog/unstarted/started/completed/canceled), estimates, labels & label groups, priority levels, relations, project status updates — definitions + semantics | tavily_search + tavily_extract | linear.app, developers.linear.app | — | 10 |
| sq2 | contextual | "The Linear Method" principles and the day-to-day working discipline they prescribe (write issues about problems, keep WIP low, build momentum, project specs) | tavily_search + tavily_extract | linear.app/method | — | 8 |
| sq3 | contextual | How to write an excellent Linear issue (problem statement, acceptance criteria, DoD, titles, sub-issues vs checklists, priority/estimate semantics) + issue-vs-project-vs-initiative decision boundary + dependency hygiene + triage | tavily_search | linear.app, github.com, dev blogs | — | 10 |
| sq4 | factual | Linear Agents / "delegate to agent" feature + Linear's OFFICIAL published guidance for AI agents inside Linear (assignment, etiquette, posting updates, agent activity sessions) | tavily_search + tavily_extract | linear.app, developers.linear.app, linear.app/blog, linear.app/changelog | year | 10 |
| sq5 | factual | Linear MCP server surface (linear-server tools) + agent-ops best practices: idempotence, comment vs description vs status-update, never overwrite human spec, state transitions, blockers via relations | tavily_search + tavily_extract | developers.linear.app, mcp.linear.app, linear.app, github.com | year | 10 |
| sq6 | recency/contradictory | Community assets to import: published Claude Code rules/skills/plugins, Cursor rules, "good Linear issue" + "Linear + AI agent" conventions (GitHub search) — and where generic Linear advice (cycles, WIP limits, initiative hierarchy) is OVERKILL for a lean solo workspace | tavily_search (site:github.com) + WebSearch fallback | github.com, cursor.directory, dev blogs | year | 10 |

## 3. Domain allowlist / blocklist

**Baseline (Tier 1+2 technical):** linear.app, developers.linear.app, mcp.linear.app, github.com, plus established dev press for community conventions.

**User `--domains` additions:** linear.app, developers.linear.app, mcp.linear.app (vendor-official — explicitly authoritative for this topic)
**User `--exclude` additions:** none

**Flagged user additions below Tier 2:** none (community assets in sq6 are Tier 3/4 by nature but used only as importable-asset signals, clearly labeled; not factual support)

**Credibility overlay (MBFC static):** not applicable — technical/vendor-doc profile, no current-affairs domains.

## 4. Retrieval plan

**Phase 1 (broad recall):**
- ~6 parallel `tavily_search` calls (advanced depth) — one per sub-question
- `tavily_extract` (advanced) on the highest-value vendor-doc URLs surfaced (linear.app/method, linear.app/docs core pages, developers.linear.app agents + MCP pages)
- `tavily_research` (mini) reserved for sq5/sq6 if Phase-3 corroboration is thin

**Conditional sources (declared here):**
- GitHub deep research: NOT run as the full sharded pipeline (`gh` SOTA-repo discovery is for tooling-SOTA questions). sq6 uses Tavily `site:github.com` + targeted extract instead. Recorded as a known degradation.
- Context7: not invoked — Linear's product semantics are documentation-as-content best retrieved via Tavily extract of linear.app, not a versioned library API surface.
- Newsletter-signal corpus, OSINT/scrapling, academic graph: not applicable.

**Vendor-doc single-source handling:** linear.app and developers.linear.app are THE authoritative source for Linear's own product semantics and agent guidance. A claim about "what a Linear cycle is" supported only by linear.app/docs is legitimately credibility 3 (single Tier-2 source) per the cascade — but for vendor-own-product-semantics this is the canonical truth, not a weakness. Such claims are tagged [POSSIBLY TRUE] only where genuinely single-sourced; corroboration with developers.linear.app or the MCP tool surface (observed directly) upgrades them.

## 5. Expected contradiction axes

- Generic agile/Scrum WIP-limit + sprint-cycle advice vs The Linear Method's lighter cadence — and both vs the lean-solo reality (no cycles, no initiatives).
- "Sub-issues vs checklists" — community conventions vary.
- Comment vs description-edit for agents — Linear's official agent guidance vs ad-hoc community MCP usage.

## 6. Stop conditions

- Each axis answered with ≥1 vendor-official (Tier 2 B) source; ≥2 where a non-vendor claim is made.
- Coverage ≥ 0.90 of the 6 sub-questions with ≥1 Tier 1/2 source.
- Groundedness ≥ 0.95; corroboration ≥ 0.80 (vendor-single-source claims exempt, tagged).
- Hard stop at ~40 cited sources (focused run, not exhaustive).
