# Research plan: benchmark the loops! agent-loop marketplace + hook enforcement

> Generated: 2026-06-19 · Skill: deep-research · Status: planned — proceeding to Phase 1

## 1. Question & scope

**Research question:** Benchmark the loops! marketplace (https://loops.elorm.xyz/) and the broader agentic-loop pattern. Determine (a) what closed-loop agentic coding workflows are and when they help vs. hurt, (b) what loops! offers and whether it is worth adopting/mining, and (c) whether Claude Code hooks are the right mechanism to *force* (lock) loop usage systematically for precise generic tasks. Adversarial angle: challenge the ticket premise that loops should be hook-enforced.

**Classification:** technical (mixed)
**Tier profile:** Tier 1+2 technical — Anthropic docs (primary on hooks/`/loop`), GitHub, recognized practitioner blogs (Tier 2), tech press (Tier 2). The loops.elorm.xyz / prompts.elorm.xyz sites are Tier 3 personal-project sources, admitted as **primary sources about themselves** only.
**Length:** standard (target 35–60 cited sources; 6 sub-questions)
**Output language:** en
**Recency window:** last 18 months (since 2025-01-01) — agentic-loop tooling is fast-moving; older material is background only.
**Min corroboration:** 2
**Model tier:** session model opus 4.8 · synthesis opus · subagent overrides: per-sub-question retrieval+grading = sonnet
**Confidential path:** no

## 2. Sub-question decomposition

| ID | Category | Sub-question | Tavily tool | include_domains (preview) | recency | Target |
|---|---|---|---|---|---|---|
| sq1 | factual | Origin & definition of the autonomous agentic coding loop ("Ralph Wiggum" pattern): who coined it, mechanics, 2025–26 state | tavily_search | ghuntley.com, simonwillison.net, github.com, anthropic.com | since 2024 | 10 |
| sq2 | contextual | When agentic loops measurably help vs. hurt — failure modes (runaway iteration, token-cost blowup, reward-hacking/false-green exit gates) and best practices for exit conditions & feedback gates | tavily_search | anthropic.com, simonwillison.net, github.com, arxiv.org | since 2025 | 10 |
| sq3 | factual | Claude Code enforcement mechanics: hooks (PreToolUse/PostToolUse/Stop/SubagentStop) capabilities & limits, the `/loop` primitive, Stop-hook continuation — what hooks CAN and CANNOT force | tavily_search + context7 | docs.anthropic.com, anthropic.com, github.com | since 2025 | 10 |
| sq4 | factual | The loops! marketplace (loops.elorm.xyz), elorm provenance, prompts.elorm.xyz sibling: what it is, taxonomy (manual/event/interval), loop-entry structure, author credibility, traction signals | tavily_search + tavily_extract | loops.elorm.xyz, elorm.xyz, news.ycombinator.com, github.com | since 2025 | 10 |
| sq5 | contradictory | Security / supply-chain posture of copy-pasting or installing third-party hook bundles & loop prompts into coding agents; comparison vs native `/loop` skill, ralph-loop plugin, and DIY loops | tavily_search | anthropic.com, github.com, simonwillison.net, snyk.io | since 2025 | 10 |
| sq6 | contradictory | When is FORCING a loop via a deterministic hook the right call vs. an anti-pattern? Which generic tasks benefit from a locked loop vs. should stay opt-in? Mandatory-enforcement failure modes | tavily_search | anthropic.com, github.com, simonwillison.net, martinfowler.com | since 2025 | 10 |

## 3. Domain allowlist / blocklist

**Baseline (Tier 1+2 technical):** docs.anthropic.com, anthropic.com, github.com, arxiv.org, simonwillison.net, ghuntley.com, martinfowler.com, news.ycombinator.com (signal), snyk.io, infoq.com, thenewstack.io, …+adjacent.

**User `--domains` additions:** loops.elorm.xyz, elorm.xyz, prompts.elorm.xyz (subject primary sources, Tier 3 — admitted for self-description only).
**User `--exclude` additions:** none.

**Flagged additions below Tier 2** (confirm): loops.elorm.xyz / elorm.xyz / prompts.elorm.xyz — admitted intentionally as the **subject** of the benchmark; any claim resting on them alone is capped at credibility 3 (POSSIBLY TRUE) unless corroborated by a Tier 1/2 source.

**Credibility overlay (MBFC):** dataset absent — overlay skipped.

## 4. Retrieval plan

**Phase 1 (broad recall):** 6 sub-questions, each retrieved + graded by a parallel sonnet subagent (≈2–4 `tavily_search` calls each), returning condensed graded rows only. 1 `tavily_extract` on loops.elorm.xyz key pages (sq4).

**Conditional sources:**
- Context7: docs.anthropic.com Claude Code hooks reference (sq3) if indexed; degrade to Tavily on miss.
- Newsletter-signal: not applicable (corpus not assumed present).
- GitHub: ralph-loop / loop tooling repos (sq1, sq5) via `site:github.com` if needed.

**Estimated total Tavily calls:** ≈18–24 search + 1 extract.
**Estimated runtime:** ~5 min (standard).
**Rate-limit headroom:** subagents staggered; well under 15 research/min.

## 5. Expected contradiction axes

1. **Loops as productivity multiplier vs. cost/runaway hazard** — practitioner enthusiasm (ghuntley "let it loop") vs. skeptics on token burn, reward-hacking the exit gate, and false-green checks.
2. **Hook-forced loops vs. model self-pacing** — determinism/guarantee vs. brittleness, blocked legitimate work, and developer friction.
3. **Third-party loop/hook bundles: convenience vs. supply-chain risk** — copy-paste marketplace velocity vs. arbitrary-command execution exposure.

## 6. Stop conditions

- [ ] Groundedness ≥ 0.95
- [ ] Source quality ≥ 0.80 Tier 1/2
- [ ] Coverage ≥ 0.90 of sub-questions
- [ ] Corroboration rate ≥ 0.80
- [ ] Source-count floor: standard ≥ 35
- [ ] Zero pending CRAG iterations

Failure routes affected claims to "Needs Verification" + Methodology note.

## 7. Known gaps at planning time

- loops.elorm.xyz is a new, single-author project; external Tier 1/2 coverage is likely thin. Traction/credibility claims about it will largely land in "Needs Verification" — an honest and decision-relevant outcome for the challenge.
- No full-text academic search (Exa/Valyu absent); arXiv reached via Tavily `include_domains` only.
- "Ralph Wiggum loop" provenance lives mostly in practitioner blogs (Tier 2) and social (Tier 4 signal) — corroboration sought across ≥2 Tier 2 sources.

## 8. Artifacts

- `research-plan.md` (this file)
- `research-report.md`
- `research-sources.json`
- `research-evidence.json`
