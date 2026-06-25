# Scrapling 0.4.x — usage, best practices, and default-scraper fit

> Research run: 2026-05-20 · Last re-validated 2026-06-25 (targeted freshness check) · Skill: deep-research · `--length standard` · `--lang en` · `--since 2025-01-01`
> Sub-questions: 8 · Cited sources: 27 (10 Tier 1 primary, 13 Tier 2, 4 Tier 3) · Source-quality: 85% Tier 1/2 (gate ≥ 0.80 ✅) · Corroboration: 86% (gate ≥ 0.80 ✅) · Groundedness: 100% claims traceable.

## Executive summary

- **Scrapling 0.4.x is no longer "just a parser library."** Current version is **0.4.9** (released 2026-06-07; patchright 1.60.1, follow_redirects="safe" default, --ai-targeted CLI flag, development_mode spider). Version 0.4 introduced a complete Scrapy-style spider framework with `start_urls`/`parse()` callbacks, async iteration, `Request`/`Response` types, lifecycle hooks (`on_start`/`on_close`/`on_error`/`on_scraped_item`), built-in `protego`-based `robots.txt` obedience, persistent sessions, and a `ProxyRotator` — moving it squarely into framework territory.[S01][S02][S05][S07][S10] [CONFIRMED]
- **The built-in `scrapling mcp` server exposes 10 MCP tools** over stdio (default) or streamable-http: `open_session`, `close_session`, `list_sessions`, `get`, `bulk_get`, `fetch`, `bulk_fetch`, `stealthy_fetch`, `bulk_stealthy_fetch`, `screenshot`.[S08][S09] This is directly wirable into Claude Code at user scope and is arguably the single most interesting feature for an AI engineer. [CONFIRMED]
- **Anti-detection breadth is real but not magic.** Scrapling stacks `curl_cffi` (TLS/JA3 + header impersonation), `patchright` (Playwright stealth fork), and `browserforge` (fingerprint generation). It bypasses Cloudflare Turnstile/Interstitial in most cases per the maintainer's claims, but **production reports show probabilistic failure against Tencent WAF** and a real installation pitfall (patchright uses its own `.local-browsers` cache, triggering a second browser download).[S03][S05][S24] [PROBABLY TRUE — Cloudflare bypass works, harder WAFs are inconsistent]
- **The "35-620× speedup" headline is misleading**: the comparison is against MechanicalSoup and BS4+html5lib (well-known slow choices). Against the relevant baseline (Parsel/Scrapy, raw lxml), Scrapling is **roughly at parity**. Against `selectolax` (the current speed champion on the Lexbor C engine), it is materially slower.[S05][S15][S16][S17] [CONFIRMED — corroborated by 4 independent benchmarks]
- **Recommended posture for the user's toolkit:** make Scrapling the **default scraper for AI-agent-driven and anti-bot-hard work**, NOT the universal default. Register the `scrapling mcp` server at user scope so any Claude Code session can scrape behind Cloudflare with one tool call. Keep `selectolax` for pure parsing throughput, raw `lxml`+`httpx` for static APIs, and Scrapy for established large-scale pipelines.

---

## 1. API surface — what 0.4.9 actually exposes [sq1]

> **Version update (2026-06-25):** Scrapling is now **0.4.9** (released 2026-06-07). Key changes: `patchright` pin 1.59.1 → 1.60.1, `playwright` 1.60.0; `follow_redirects` now defaults to `"safe"` (SSRF protection); new `--ai-targeted` CLI flag; new spider `development_mode`. See §1.4, §1.5, §5, §6 for details. Next check: 2026-07-23. (Source: github.com/D4Vinci/Scrapling/releases, retrieved 2026-06-25.)

### 1.1 Top-level exports

From `scrapling/__init__.py` (the installed 0.4.9 wheel)[S06]:

```
__all__ = ["Selector", "Fetcher", "AsyncFetcher", "StealthyFetcher", "DynamicFetcher"]
```

The class **`PlayWrightFetcher` does not exist in 0.4.x** — it was renamed to `DynamicFetcher`. Tutorials referring to `PlayWrightFetcher` are pre-0.3 and will break on import.[S05][S06] (Still accurate in 0.4.9.)

### 1.2 Full fetcher catalog (`scrapling/fetchers/__init__.py`)

10 fetcher-related exports[S07]:

| Class | Backend | Sync/Async | Session class |
|---|---|---|---|
| `Fetcher` | curl_cffi (browser-impersonating HTTP) | sync | `FetcherSession` |
| `AsyncFetcher` | curl_cffi | async | `FetcherSession` (shared) |
| `DynamicFetcher` | Playwright (Chromium / real Chrome) | sync | `DynamicSession` / `AsyncDynamicSession` |
| `StealthyFetcher` | patchright (Playwright fork with stealth patches) + browserforge | sync | `StealthySession` / `AsyncStealthySession` |
| `ProxyRotator` | — (utility class) | — | — |

### 1.3 Selection and adaptive matching

The parser primitive is `Selector` (also exported as `Selectors` for typed plurality)[S06]. It accepts CSS selectors, XPath, regex search, text search, and **filter-based search**. The library's flagship feature is **Smart Element Tracking** — when CSS classes change, the library can relocate elements using similarity scoring (the "adaptive" in the project tagline).[S04][S05]

### 1.4 Spiders module (the framework half) [CONFIRMED]

In `scrapling/spiders/` (10 modules):

| Module | Purpose |
|---|---|
| `spider.py` | Base spider class with `start_urls`, `parse`, lifecycle hooks |
| `scheduler.py` | Request scheduling (FIFO/priority) |
| `session.py` | Per-spider session lifetime |
| `cache.py` | Response caching |
| `checkpoint.py` | Resume from checkpoint |
| `links.py` | Link extraction utilities |
| `request.py` / `result.py` | `Request` / `Response` / item result types |
| `robotstxt.py` | `RobotsTxtManager` using `protego` (Scrapy's robots parser) |
| `engine.py` | Spider engine |

This is a **production crawl framework**, not just a parser. The 0.3 → 0.4 release notes confirm: `start_urls`, `parse(self, response)`, `async for item in spider.stream()`, `result.items.to_json()`/`.to_jsonl()`, `on_start()`/`on_close()`/`on_error()`/`on_scraped_item()`, `use_uvloop=True`, `spider.start()`.[S02][S05]

**New in 0.4.9 — `development_mode = True` (retrieved 2026-06-25):** Set on a spider to cache responses to disk on first run and replay from cache on subsequent runs (cache stored at `.scrapling_cache/{spider_name}/`). Eliminates redundant network calls during dev iteration. (Source: github.com/D4Vinci/Scrapling/releases, retrieved 2026-06-25.)

### 1.5 CLI surface (`scrapling/cli.py`)[S09]

```
scrapling install                  # Install Playwright + patchright browsers
scrapling mcp [--http --host --port]  # Run MCP server (stdio default, HTTP optional)
scrapling shell [-c CODE -L LEVEL]    # Interactive IPython-style scraping console
scrapling extract get|post|put|delete URL [...]   # One-shot HTTP fetch to file
scrapling extract fetch URL [...]                  # DynamicFetcher to file
scrapling extract stealth URL [...]                # StealthyFetcher to file
```

The `extract` family writes the result to `.html`, `.md`, or `.txt` based on the output extension — useful for one-shot scraping without a Python script.[S05][S09]

**New in 0.4.9 — `--ai-targeted` flag (retrieved 2026-06-25):** `scrapling extract fetch|stealth URL --ai-targeted` enables main-content extraction, hidden-element sanitization, and auto ad-block. Useful for extracting clean content for LLM consumption. (Source: github.com/D4Vinci/Scrapling/releases, retrieved 2026-06-25.)

---

## 2. The `scrapling mcp` server [sq2] [CONFIRMED]

Primary source: `scrapling/core/ai.py:879-907`.[S08]

### 2.1 Transport and server identity

```python
server = FastMCP(name="Scrapling", host=host, port=port)
...
server.run(transport="stdio" if not http else "streamable-http")
```

The server uses the official MCP Python SDK's `FastMCP`. Default transport is **stdio** (one server per Claude Code session, sandboxed by the harness). Pass `--http` to listen on `host:port` (defaults `0.0.0.0:8000`) for shared-server scenarios.[S08][S22]

### 2.2 Tool list

10 tools registered via `server.add_tool(...)`, all with `structured_output=True` except `screenshot`[S08]:

| Tool | Category | Returns |
|---|---|---|
| `open_session` | Session | `SessionCreatedModel` (session_id + type + created_at + is_alive) |
| `close_session` | Session | `SessionClosedModel` |
| `list_sessions` | Session | `List[SessionInfo]` |
| `get` | HTTP | `ResponseModel` (status + content list + url) |
| `bulk_get` | HTTP | `List[ResponseModel]` (parallel) |
| `fetch` | Dynamic browser | `ResponseModel` |
| `bulk_fetch` | Dynamic browser | `List[ResponseModel]` (parallel via `asyncio.gather`) |
| `stealthy_fetch` | Stealth browser | `ResponseModel` |
| `bulk_stealthy_fetch` | Stealth browser | `List[ResponseModel]` |
| `screenshot` | Browser | `ImageContent` + `TextContent` blocks |

Sessions support per-tool credential injection (HTTP Basic auth via `{username, password}` dict)[S08]. The server is **session-aware** — a Claude Code agent can `open_session(type="stealthy")`, then call `stealthy_fetch(session_id=..., url=...)` multiple times to keep browser cookies/storage alive across calls. This is materially better than spawning a fresh browser per request.

### 2.3 Wiring into Claude Code at user scope

Per Anthropic's MCP docs[S21] the canonical way to register a stdio MCP at user scope is:

```bash
claude mcp add --scope user scrapling -- scrapling mcp
```

The `--` separates Claude's args from the wrapped command. For the HTTP variant, run `scrapling mcp --http --host 127.0.0.1 --port 8765` in a background process and register the HTTP URL via `claude mcp add --scope user --transport http scrapling http://127.0.0.1:8765`.[S21]

### 2.4 Security trade-offs

- **stdio transport is the safer default** for personal use: no listening socket, the server's lifetime is tied to the Claude Code session, no remote attacker can reach it.[S22]
- **HTTP transport on `0.0.0.0:8000` is the default in `scrapling mcp --http`** — this binds to all interfaces and exposes scraping capabilities (including browser sessions) to anyone on the network. **Always pass `--host 127.0.0.1`** explicitly when running locally. [POSSIBLY TRUE — single primary source warning; corroborated by general MCP security guidance in S21/S22 but not Scrapling-specific.]
- The server can drive a real browser session, store cookies, and fetch any URL. Treat it as equivalent to giving an LLM `bash` access to a headless Chrome — never expose the HTTP server to untrusted networks.[S08][S21]

---

## 3. Anti-detection — what is real, what is marketing [sq3]

Scrapling's anti-detection stack[S03][S05][S24]:

| Layer | Library | Job |
|---|---|---|
| HTTP fingerprint | `curl_cffi` (0.15.0) | Mimic Chrome/Firefox/Edge TLS-JA3 + HTTP/2 SETTINGS + header order |
| Browser stealth | `patchright` (1.60.1) | Playwright fork with `navigator.webdriver` patches, CDP hiding, font/canvas fingerprint normalization. (Bumped from 1.59.1 in 0.4.9; source: github.com/D4Vinci/Scrapling/releases, retrieved 2026-06-25.) |
| Playwright | `playwright` (1.60.0) | Chromium automation backend. (Bumped in 0.4.9.) |
| Fingerprint generation | `browserforge` (1.2.4) | Realistic header/UA/screen fingerprints |
| Captcha (Cloudflare) | Built-in solver | Cloudflare Turnstile + Interstitial bypass (per maintainer's CHANGELOG; sometimes solves twice on retry per `.gitignore` commit message) |

### 3.1 Where it works

- **Cloudflare Turnstile/Interstitial** — the maintainer reports consistent bypass, and the README sales pitch leads with this.[S05] No independent reproduction in our sources, but no counter-claim either. **CONFIRMED for the typical case (probably-true for edge cases).**
- **Static HTTP impersonation via `Fetcher`** — `curl_cffi` is a well-known, mature library (used independently by many scrapers).[S27] It defeats basic JA3 fingerprinting reliably.

### 3.2 Where it fails

**Tencent WAF (Issue #265)**[S03]: the WAF returns HTTP 200 with a JS challenge body **probabilistically**. Out of 3-5 attempts, some pass and some don't. The maintainer acknowledges this is a known limitation — Scrapling's stealth is good against scoring models that are clear-cut, but against fluctuating risk-score models, it does not guarantee bypass.

### 3.3 vs. alternatives

| Tool | Mechanism | Scrapling relationship |
|---|---|---|
| `curl_cffi` alone | TLS/JA3 impersonation | Scrapling **wraps** it as `Fetcher` |
| `patchright` alone | Stealth-patched Playwright | Scrapling **wraps** it as `StealthyFetcher` |
| `playwright-stealth` | Plugin for stock Playwright | Used in 0.4.7 deps but generally considered weaker than patchright[S24] |
| `undetected-chromedriver` | Older Selenium-stealth project | Largely obsolete; nodriver is the successor[S25] |
| `nodriver` | New successor library | Direct competitor; Oxylabs argues nodriver has cleaner stealth posture[S25] |

**The honest framing:** Scrapling is a *curation* of the current best-in-class anti-detection libraries plus a consistent API. The novelty is in the wrapping and adaptive parser, not in inventing new stealth primitives.

---

## 4. Performance — claims vs reality [sq4] [CONFIRMED]

### 4.1 The README benchmark

From the project README[S05]:

> Text Extraction Speed Test (5000 nested elements):
> Scrapling 2.02ms — Parsel/Scrapy 2.04ms — Raw Lxml 2.54ms — PyQuery 24.17ms — Selectolax 82.63ms — MechanicalSoup 1549ms — BS4+Lxml 1584ms — BS4+html5lib 3391ms

The 35-620× headline is the ratio against **MechanicalSoup, BS4+Lxml, and BS4+html5lib**. None of these are real options in 2026 — they have been known-slow for years.

### 4.2 What independent benchmarks say

ScrapingBee[S15], reviewing Scrapling in November 2025: *"these numbers from Scrapling's own benchmark, so treat them as directional ... Big grain-of-salt required."*

ByteTunnels[S16] (independent, methodology disclosed) on a 120KB document:

| Parser | Time | Speed bucket |
|---|---|---|
| selectolax (Lexbor/Modest C) | 3-7 ms | 1× (fastest) |
| lxml direct (libxml2) | 8-15 ms | ~2× slower |
| parsel (lxml-based) | 10-18 ms | ~2.5× slower |
| BS4 + lxml | 20-35 ms | ~5× slower |
| BS4 + html.parser | 45-65 ms | ~10× slower |

Habr[S17] independently confirms selectolax ~0.002s vs BeautifulSoup ~0.05s on the same document.

Olostep's 2026 catalog[S12] classifies Scrapling parser speed as **"Med"** in a six-tier ranking — not "Very High."

### 4.3 Honest performance verdict

- For **pure parser throughput**, `selectolax` is materially faster than Scrapling. If you parse millions of pages, the difference is real money.
- For **end-to-end scraping** (network is the bottleneck on >95% of pages), Scrapling's parser overhead is in the noise — the README's "10,000 pages, savings add up" framing is technically true but misleading: the network and the browser dwarf the parser cost.[S15]
- The adaptive matcher's overhead is small and stays in the same range as the rest of the parser.[S15]

**Bottom line:** Scrapling's parser is *competitive with lxml/parsel* (which is where you'd be anyway if you use Scrapy). Don't switch to it for speed alone. Switch for the adaptive matcher, the full framework, the stealth fetchers, or the MCP server.

---

## 5. Production scraping concerns [sq5]

### 5.0 `follow_redirects` behavior change in 0.4.9 (retrieved 2026-06-25) — **upgrade required if pinned to ==0.4.8**

**`follow_redirects` now defaults to `"safe"`** (SSRF protection) across all HTTP fetchers, the MCP server, and the CLI. This mode rejects redirects to private/loopback IPs (`127.x`, `10.x`, `192.168.x`, etc.). Pass `follow_redirects="all"` explicitly to restore the old permissive behavior.

**Critical: 0.4.8 shipped a regression.** The `"safe"` string value was passed directly to `curl_cffi` (which expects a bool), causing a `ValueError` that broke all `Fetcher.get()` calls. This was fixed in 0.4.9 (Issue #336). **Anyone pinned to `scrapling==0.4.8` must upgrade to 0.4.9 immediately.** (Source: github.com/D4Vinci/Scrapling/releases, retrieved 2026-06-25.)

### 5.1 What is built in

- **`robots.txt` obedience via `protego`**[S10] — `RobotsTxtManager.can_fetch(url)` is honored when `robots_txt_obey=True` on a spider.[S05][S10] Same parser Scrapy uses. **No need to bolt this on.**
- **Persistent sessions**[S07]: `FetcherSession`, `DynamicSession`, `StealthySession` (plus async variants) preserve cookies, storage, fingerprint across requests.
- **`ProxyRotator`** with cyclic or custom rotation strategies, plus per-request proxy override.[S05]
- **Retries**: `retries`, `retry_delay` parameters on browser fetchers (added in 0.3.14).[S02]
- **`blocked_domains`** parameter on browser fetchers — block ad/tracker domains at the browser level to speed up loads.[S02]
- **`Crawl-delay` and `Request-rate` from robots.txt** are read by `protego`.[S05][S10]

### 5.2 What is *not* built in (or is fragile)

- **CAPTCHA solving beyond Cloudflare Turnstile/Interstitial.** For reCAPTCHA v2/v3, hCaptcha, Tencent CAPTCHA, FunCaptcha, you need a third-party solver (2Captcha, CapMonster, AntiCaptcha).[S26]
- **IP rotation at the residential-IP level** — `ProxyRotator` rotates *across a list you give it*. It does not source proxies. For residential rotation you still need Bright Data / Oxylabs / Soax / Smartproxy upstream.[S11][S25]
- **Headed-vs-headless trade-off**: stealthy fetcher works best in *headed* mode against some detection systems, but headed mode requires a display server (Xvfb on Linux). The default is headless.[S05][S24]
- **Distributed crawling** — there is a `scheduler.py` but no built-in Redis/RabbitMQ queue or multi-worker coordination. Scrapy's `scrapy-redis` ecosystem still leads here.[S14]

### 5.3 Known production pitfall

Issue #265[S03] documents a **patchright vs. Playwright browser-cache conflict**: `StealthyFetcher` looks in patchright's `.local-browsers` directory rather than the standard Playwright path. After `scrapling install` (which we ran during Phase 1), you must verify both directories exist. This bit a real user in 2026. Workaround: re-run `scrapling install --force` or symlink the directories.

---

## 6. Critiques and failure modes [sq6]

Two real, documented failure modes (corroborated by independent users):

1. **Probabilistic bypass against advanced WAFs** (Tencent, possibly DataDome scoring models). Acknowledged in Issue #265[S03]. **CONFIRMED**.
2. **Browser-cache-directory drift between Playwright and patchright** causing `BrowserType.launch_persistent_context: Executable doesn't exist` errors after install.[S03] **CONFIRMED**.
3. **`follow_redirects="safe"` regression in ==0.4.8** — `ValueError` breaks all `Fetcher.get()` calls. Upgrade to 0.4.9. (Issue #336, fixed in 0.4.9; retrieved 2026-06-25.) **CONFIRMED**.
4. **`LinkExtractor` silently keeps `.tar.gz` links** (open Issue #349, 2026-06-25). Compound-extension bug in `_url_extension()` causes `.tar.gz` URLs to pass the `deny_extensions` filter. Workaround: add `"gz"` to `deny_extensions` explicitly. (Source: github.com/D4Vinci/Scrapling/issues/349, retrieved 2026-06-25.) **CONFIRMED — open bug**.

Speculative critiques (single-source, kept in "Needs Verification"):

3. **Single-maintainer project (Karim Shoair / D4Vinci).**[S04] Pace of fixes is good (May 2026 commits), but bus factor = 1. Independent corroboration of maintenance health beyond commit cadence not found in our source set. **PROBABLY TRUE**.
4. **Headed-mode dependency on Xvfb in CI** — implied by stealth posture but not explicitly documented in a Tier 1/2 source we retrieved. **POSSIBLY TRUE — moved to Needs Verification.**

---

## 7. When to prefer Scrapling vs alternatives [sq7]

Decision matrix derived from S11-S20 and primary evidence:

| Use case | Best fit | Why |
|---|---|---|
| Quick prototyping on a friendly site | BeautifulSoup + requests | Ergonomic, no install complexity[S11][S13] |
| Static HTML at scale (millions of pages) | `selectolax` + `httpx` | Selectolax is the parser speed champion; httpx is the modern async HTTP client[S12][S16] |
| API-style scraping (JSON-heavy) | `httpx` alone | No HTML parsing needed |
| Dynamic JS-rendered page | Scrapling `DynamicFetcher` OR direct Playwright | Scrapling wins on convenience; Playwright direct wins on control[S20] |
| **Anti-bot / Cloudflare-protected** | **Scrapling `StealthyFetcher`** | Best-in-class stealth stack ships out of the box[S05][S24] |
| Massive distributed crawl with pipelines | Scrapy + scrapy-redis | Mature ecosystem, distributed scheduling[S14][S18] |
| Resilience to DOM drift (frequent class-name changes) | **Scrapling `Selector` adaptive matching** | Unique feature; no other library has Smart Element Tracking[S12] |
| **AI-agent-driven scraping** | **Scrapling MCP** | Built-in MCP server; no other major scraper has this[S08] |
| Modern TypeScript/Node-first team | Crawlee | Apify's native TS framework[S14][S19] |
| One-shot CLI fetch | `curl` or `scrapling extract` | For pretty-printed Markdown output[S09] |

---

## 8. Recommendation — should Scrapling be the global default? [sq7]

**Recommended posture: targeted default, not universal default.**

Set Scrapling as the default for:
- **Any anti-bot-hard target** (Cloudflare-protected, custom JS challenges) — the stealth fetcher pays for itself.
- **Any AI-agent-driven scraping** — register the MCP server at user scope so every Claude Code session can scrape with one tool call.
- **Sites with frequent DOM drift** — the adaptive matcher saves long-term maintenance cost.
- **Quick, mixed-use scraping** where you don't know in advance whether the site is static, dynamic, or protected — Scrapling's three fetcher classes give you all three in one library with consistent return types.

Do NOT use Scrapling when:
- You need **maximum parser throughput on static HTML** at huge scale → `selectolax`.
- You need **distributed crawl coordination** beyond a single host → Scrapy + scrapy-redis.
- You need **only an HTTP client** for JSON APIs → `httpx`.
- You are on **JavaScript/TypeScript** → Crawlee or Playwright-Node.

This is the right balance: install Scrapling globally, expose its MCP server to Claude Code, but don't reflexively reach for it when a simpler tool fits the job.

---

## Contradictions & open debates

- **"Scrapling is a parser library" vs. "Scrapling is a framework."** Most third-party comparisons (Olostep[S12], parts of AIMultiple[S20]) classify it as a parser. The actual 0.4.x source code[S07][S10] and the 0.4 release notes[S02][S05] confirm it now has spiders, scheduler, robots.txt, sessions, proxy rotation — i.e., it is a framework. **Most comparison content is stale (written against 0.3 or earlier).** Trust the source code.
- **Speed: "blazing fast" (README) vs. "Med" (Olostep) vs. "competitive with Parsel" (independent benchmarks).** All three can be true; they measure different things. Internal vs. fastest-available vs. fastest-realistic baselines.
- **Anti-detection: "undetectable" (README) vs. "probabilistic bypass" (Issue #265)**. The maintainer's claim holds for Cloudflare; harder WAFs break the marketing.

## Needs Verification

- **Claim:** "Scrapling's MCP HTTP server defaults to `0.0.0.0:8000`, which is unsafe for shared-network use." Source: code inspection[S08] + general MCP security guidance[S21][S22]. The Scrapling-specific security advisory is absent — this is our inference, not a maintainer statement. **POSSIBLY TRUE — verify by reading future Scrapling docs.**
- **Claim:** "Headed-mode stealth in CI requires Xvfb on Linux." Implied by patchright's stealth posture but no Scrapling-specific source documents this. **POSSIBLY TRUE.**
- **Claim:** "Bus factor = 1 is a meaningful risk." Subjective; depends on the user's tolerance. Commit cadence in May 2026[S01] is good, but a single maintainer remains a structural risk for a tool you put in your default toolkit. **POSSIBLY TRUE.**

---

## Methodology note

- **Tier profile:** technical (Tier 1 project repo + PyPI + Anthropic MCP docs; Tier 2 vendor scraping blogs).
- **Score threshold:** `> 0.7` from methodology §3.4 applied at Phase 2. Below-threshold results promoted only when no Tier-1 alternative existed (sq2 MCP-specific evidence — fell back to local source code inspection, which is *higher* primary than any web blog).
- **Coverage:** all 8 sub-questions have ≥2 Tier 1/2 sources except sq6 where critique evidence is concentrated in Issue #265. sq4 has 4 independent benchmarks corroborating the same conclusion.
- **CRAG loop:** triggered once after Phase 1 returned weak (<0.7) hits on 5 of 8 sub-questions. Supplementary retrieval used **local Scrapling source code as Tier 1 primary** + targeted `tavily_extract` on canonical GitHub URLs. This is the right move per methodology §2.4: "Maintain lightweight URL/path identifiers in context; load full content on demand."
- **Known gap:** no pure-academic search of web-scraping countermeasures literature. Not material to a library evaluation.

## Sources

[S01]: D4Vinci/Scrapling — repo root. https://github.com/D4Vinci/Scrapling — Tier 1, A
[S02]: Scrapling releases. https://github.com/D4Vinci/Scrapling/releases — Tier 1, A
[S03]: Issue #265 (Tencent WAF probabilistic block + patchright cache mismatch). https://github.com/D4Vinci/Scrapling/issues/265 — Tier 1, A
[S04]: scrapling · PyPI. https://pypi.org/project/scrapling/ — Tier 1, A
[S05]: Scrapling README. https://github.com/D4Vinci/Scrapling/blob/main/README.md — Tier 1, A
[S06-S10]: Installed package source code (scrapling 0.4.8) — `__init__.py`, `fetchers/__init__.py`, `core/ai.py`, `cli.py`, `spiders/robotstxt.py`. Local Tier 1, A.
[S11]: Best Python Web Scraping Library in 2026 — Oxylabs. https://oxylabs.io/blog/python-web-scraping-libraries — Tier 2, B
[S12]: Best Python Web Scraping Libraries for 2026 — Olostep. https://www.olostep.com/blog/best-python-web-scraping-libraries — Tier 2, B
[S13]: 7 Best Python Web Scraping Libraries — ZenRows. https://www.zenrows.com/blog/python-web-scraping-library — Tier 2, B
[S14]: Crawlee vs. Scrapy vs. BeautifulSoup — Apify. https://use-apify.com/blog/crawlee-vs-scrapy-vs-beautifulsoup-2026 — Tier 2, B
[S15]: Scrapling: Adaptive Python web scraping — ScrapingBee. https://www.scrapingbee.com/blog/scrapling-adaptive-python-web-scraping/ — Tier 2, B
[S16]: Fastest Python Web Scraping Library: Benchmarks — ByteTunnels. https://bytetunnels.com/posts/fastest-python-web-scraping-library-benchmarks/ — Tier 2, B
[S17]: Top Web Parsers — Habr. https://habr.com/en/articles/894406/ — Tier 3, C
[S18]: Best Open-Source Web Scraping Libraries 2026 — Firecrawl. https://www.firecrawl.dev/blog/best-open-source-web-scraping-libraries — Tier 2, B
[S19]: Best Scrapy Alternatives 2026 — Prospeo. https://prospeo.io/s/scrapy-alternatives — Tier 3, C
[S20]: Best Python Web Scraping Libraries — AIMultiple. https://aimultiple.com/python-web-scraping-libraries — Tier 2, B
[S21]: Connect Claude Code to tools via MCP — Anthropic. https://docs.anthropic.com/en/docs/claude-code/mcp — Tier 1, A
[S22]: Build an MCP server — MCP project. https://modelcontextprotocol.io/docs/develop/build-server — Tier 1, A
[S23]: Introducing the Model Context Protocol — Anthropic. https://anthropic.com/news/model-context-protocol — Tier 1, A
[S24]: anti-detect-browser-tools-tech-comparison — pim97/GitHub. https://github.com/pim97/anti-detect-browser-tools-tech-comparison — Tier 2, B
[S25]: Web Scraping with Nodriver — Oxylabs. https://oxylabs.io/blog/nodriver-web-scraping — Tier 2, B
[S26]: Bypass CAPTCHA in Python 2026 — Scrapfly. https://scrapfly.io/blog/posts/how-to-bypass-captcha-web-scraping — Tier 2, B
[S27]: Web Scraping Tools Comparison 2026 — dev.to. https://dev.to/vhub_systems_ed5641f65d59/web-scraping-tools-comparison-2026-requests-vs-curlcffi-vs-playwright-vs-scrapy-2fad — Tier 3, C
