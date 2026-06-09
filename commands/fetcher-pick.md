---
description: Decide which Scrapling fetcher fits a target (static vs dynamic, anti-bot posture, concurrency) without running a full scrape.
argument-hint: "<target-or-url>"
allowed-tools: Bash, Read
---

# /fetcher-pick — Decide which Scrapling fetcher fits a target

Lightweight decision helper. For the full execution workflow, use [/scrape](scrape.md).

## Three questions

1. **Is the page static HTML or JavaScript-rendered?**
   - Static (server returns the content directly) → answer A
   - Dynamic (content appears only after client-side JS) → answer B
2. **Does the target have anti-bot protection?** (Cloudflare cf-ray header, 403/429 on plain curl, captcha challenge page)
   - No → answer A
   - Yes → answer C
3. **What is your concurrency need?**
   - One-off / small batch → sync class
   - High parallelism → async class

## Decision matrix

| Static + no anti-bot + sync | Static + no anti-bot + async | Static + anti-bot | Dynamic + no anti-bot | Dynamic + anti-bot |
|---|---|---|---|---|
| `Fetcher` | `AsyncFetcher` | `StealthyFetcher` | `DynamicFetcher` | `StealthyFetcher` |
| `from scrapling import Fetcher` | `from scrapling import AsyncFetcher` | `from scrapling import StealthyFetcher` | `from scrapling import DynamicFetcher` | `from scrapling import StealthyFetcher` |
| curl_cffi backend | curl_cffi backend | patchright Chromium | Playwright Chromium | patchright + browserforge |

## Output format

Reply with three lines:

1. **Class:** `<ClassName>`
2. **Import:** `from scrapling import <ClassName>`
3. **Rationale:** one sentence explaining the choice tied to the three answers.

## Common mistakes

- Defaulting to `StealthyFetcher` "just in case" — it launches a real Chromium per call and is 50-100× slower than `Fetcher`. Confirm anti-bot signals first.
- Reaching for `DynamicFetcher` when `Fetcher` with `stealthy_headers=True` would have worked. Many sites serve full HTML on first response when the request looks browser-like.
- Using `Fetcher` (sync) inside an `async def`. Use `AsyncFetcher` in async code to avoid blocking the event loop.

## See also

- [/scrape](scrape.md) — full URL-to-data workflow with robots.txt check and scaffolding
- [~/.claude/playbooks/scrapling/research-report.md](../playbooks/scrapling/research-report.md) — research source of truth
