---
description: Scrapling-first autonomous scraping — probe the target, pick the fetcher, extract with anti-bot handling.
argument-hint: "<url-or-target>"
allowed-tools: Bash, Read, Write, Skill, mcp__scrapling__get, mcp__scrapling__fetch, mcp__scrapling__stealthy_fetch, mcp__scrapling__open_session, mcp__scrapling__close_session, mcp__scrapling__screenshot, mcp__fetch__fetch
---

# /scrape — Scrapling-first autonomous scraping

Execute a scraping task with state-of-the-art tool selection. Validated playbook: [~/.claude/playbooks/scrapling/research-report.md](../playbooks/scrapling/research-report.md).

## Pre-conditions

- `scrapling` MCP server is registered at user scope (run `claude mcp list | grep scrapling` to verify).
- For project work, `scrapling[fetchers]` is in the project's `pyproject.toml` (run `uv add 'scrapling[fetchers]>=0.4.8,<0.5'` if not).

## Decision Gates

### 1. What is the target's anti-bot posture?

Run a 2-second probe before choosing a fetcher:

```bash
curl -sI -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "<url>" | head -20
```

Look for these signals in the response headers / body:

| Signal | Decision |
|---|---|
| `Server: cloudflare` + `cf-ray:` | → Step 4 (StealthyFetcher) |
| `Server: Lego Server` (Tencent WAF), `X-DD-B:` (DataDome), `Server: AkamaiGHost` | → Step 4 (StealthyFetcher), flag that probabilistic failure is expected |
| `Server: nginx` / `Server: Apache` plain | → Step 2 |
| 403/429 on a plain `curl` UA | → Step 4 (anti-bot active) |
| 200 OK plain | → Step 2 |

### 2. Is the page static or JavaScript-rendered?

Inspect the response body. If the HTML returned by `curl` already contains the target content (selectors return data), the page is static. If the body is mostly a `<script>` shell that loads content dynamically, it is JS-rendered.

| Page type | Fetcher | Import |
|---|---|---|
| Static HTML, no anti-bot | `Fetcher` (curl_cffi) | `from scrapling import Fetcher` |
| Static HTML, async at scale | `AsyncFetcher` | `from scrapling import AsyncFetcher` |
| Dynamic JS-rendered, no anti-bot | `DynamicFetcher` (Playwright) | `from scrapling import DynamicFetcher` |
| Anti-bot active (any form) | `StealthyFetcher` (patchright + browserforge) | `from scrapling import StealthyFetcher` |

### 3. Does `robots.txt` allow the target path?

NON-NEGOTIABLE. Even for one-off scrapes, check:

```bash
curl -s "<scheme>://<host>/robots.txt" | head -50
```

For spider runs, set `robots_txt_obey=True` (Scrapling default). For one-off `Fetcher.get()` calls, check the path against the policy manually. If the path is `Disallow:`, escalate to the user — do NOT proceed without explicit written authorization.

### 4. Choose the execution path

| Need | Execution |
|---|---|
| Inside Claude Code, one-shot fetch | Call `mcp__scrapling__get` or `mcp__scrapling__stealthy_fetch` directly — fastest, no code |
| Inside Claude Code, multi-page session | Call `mcp__scrapling__open_session` → loop on `mcp__scrapling__fetch`/`stealthy_fetch` with the returned `session_id` |
| Outside Claude Code (scripted job) | Scaffold typed Python; see Step 5 |
| Quick CLI dump to file | `scrapling extract {get,fetch,stealth} <url> out.{md,html,txt}` |

### 5. Scaffold (when scripting is needed)

For project work, scaffold under `src/scrapes/<target_slug>.py`:

```python
"""Scrape <target description>.

Source: <canonical url>
Retrieved: <YYYY-MM-DD>
Robots.txt verified: <YYYY-MM-DD>, path allowed
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from scrapling import Fetcher  # or StealthyFetcher / DynamicFetcher

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class TargetItem:
    title: str
    url: str
    # ... typed fields per the target's schema


def scrape(url: str) -> list[TargetItem]:
    """Fetch <url> and return parsed items."""
    response = Fetcher.get(url, stealthy_headers=True, timeout=20)
    if response.status != 200:
        raise RuntimeError(f"Unexpected status {response.status} for {url}")

    return [
        TargetItem(
            title=el.css_first("h2::text").get() or "",
            url=el.css_first("a::attr(href)").get() or "",
        )
        for el in response.css("article.item")
    ]
```

Run `ruff check --fix && pyright --strict <file>` before committing.

## Anti-patterns — do not do these

- ❌ Defaulting to `StealthyFetcher` for every target. It launches a real Chromium per call — orders of magnitude slower than `Fetcher`. Escalate to it only when Step 1 says yes.
- ❌ Setting `robots_txt_obey=False` without a written exception from the target documented in the module docstring.
- ❌ Running `scrapling mcp --http` without `--host 127.0.0.1`. The default `0.0.0.0:8000` exposes a headless Chromium to the local network.
- ❌ Treating `PlayWrightFetcher` as a valid import — it does not exist in 0.4.x. The class is `DynamicFetcher`.
- ❌ Citing the README's "35-620× faster" claim as evidence. That benchmark is vs MechanicalSoup and BS4+html5lib (known-slow choices). Against Parsel/lxml Scrapling is at parity, against selectolax it is slower.
- ❌ Bypassing rate limits inferred from the target's `Crawl-delay` directive in robots.txt or from response headers like `Retry-After`. Use `protego`-backed enforcement (built into spiders).

## Pitfalls captured in the research report

1. **Patchright cache drift (Issue #265)**: `StealthyFetcher` uses patchright's own `.local-browsers` directory. If you see `BrowserType.launch_persistent_context: Executable doesn't exist`, run `scrapling install --force`.
2. **Probabilistic WAF bypass**: Cloudflare Turnstile usually solves; Tencent / DataDome with fluctuating risk-score models block probabilistically. Acknowledge and add retries + backoff, do not pretend the bypass is deterministic.
3. **Headed mode requires Xvfb on Linux CI**. Headless works for most targets; switch to `headless=False` only when a target explicitly detects headless.
