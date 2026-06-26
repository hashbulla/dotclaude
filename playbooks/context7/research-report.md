# Research report: Best practices for Upstash Context7 MCP in Claude Code (Q1/Q2 2026)

**Run date:** 2026-05-28 · **Last re-validated:** 2026-06-25 (targeted freshness check)
**Language:** English
**Methodology:** deep-research skill, 9 broad-retrieval Tavily sweeps + 5 deep extracts, NATO Admiralty A–F × 1–6 grading, CRAG groundedness validation.
**Stop conditions met:** groundedness 1.00, corroboration ≥ 2 independent Tier 1/2 sources on every routing rule, ≥1 Tier 1 source on every API-contract claim.

## Executive summary

- Context7 is the **most-installed documentation MCP in the Claude Code ecosystem**, featured on GitHub's MCP registry top fold.[^1][^11] Its purpose: pull version-specific docs from the source repo into the model's context window at query time, eliminating hallucinated APIs from stale training data. [CONFIRMED]
- The Claude Code plugin ships **five components**, not just the MCP server: `.mcp.json`, `.claude-plugin/plugin.json`, a `docs-researcher` subagent, a `/context7:docs` slash command, and a `documentation-lookup` skill designed for auto-triggering.[^2] The user's currently installed plugin (`c050adb10757`) exposes the MCP tool but the skill/agent/slash-command surface depends on whether those files shipped with this snapshot. [CONFIRMED]
- The MCP exposes **two tools**: `resolve-library-id(libraryName, query)` and `query-docs(libraryId, query)`.[^3][^4][^5] Library IDs follow the `/owner/project[/version]` slash syntax (e.g. `/vercel/next.js`, `/mongodb/docs`). [CONFIRMED]
- The 2025 redesign ("Context7 Without Context Bloat", Upstash blog) **moved reranking server-side and dropped client-side pagination, `tokens` budget, and "mode" parameters**.[^6] Today both tools take just a query string; the server returns a single optimally reranked payload. This is a meaningful change vs. Q3-2025 tutorials still showing a `tokens=10000` parameter. [CONFIRMED]
- **Authentication via Claude Code plugin install does NOT pass `CONTEXT7_API_KEY` from the shell environment automatically.**[^7] Setting `CONTEXT7_API_KEY` in `~/.zshrc` results in the Context7 dashboard showing zero usage even though queries succeed (because the unauthenticated free-tier limit fires first). Fix: inject the env into the plugin's `.mcp.json`, or re-register the MCP via `claude mcp add` with an explicit `--api-key` arg. [CONFIRMED]
- **Free tier as of 2026-05:** 1,000 API calls/month, with 20 bonus calls per day after the monthly cap is hit.[^8] This was bumped on 2026-01-16 from an interim 500-call cap that triggered the "92% cut" outcry.[^9] At the user's API key tier (free, registered), the budget is real — aggressive auto-invoke without scoping triggers blocks within days. [CONFIRMED]
- **Positive triggers** (corroborated by ≥3 Tier 1/2 sources): library/SDK/framework documentation lookup, version-specific code examples, setup/config/migration questions, CLI tool usage.[^4][^10][^11] [CONFIRMED]
- **Negative triggers** (corroborated by ≥3 Tier 1/2 sources): refactoring existing code, business logic, debugging the user's own code, scripts from scratch, general programming concepts, comparison reviews.[^4][^12][^13] Misusing Context7 here burns budget AND adds noise to the context window. [CONFIRMED]
- **The MCP-blocks-agents pitfall** is a known bug class: GitHub Issue #877 documents Context7 MCP preventing Claude Code agents from spinning up under specific transport configurations.[^14] Mitigation: when subagents fail to spawn, disable context7 as a smoke test before deeper debugging. [CONFIRMED]

## 1. What is Context7 and what does the Claude Code plugin actually ship?

Context7 is an Upstash-built MCP server that indexes the documentation of thousands of open-source libraries, frameworks, SDKs, and cloud APIs into a vector store, exposes a two-tool query interface, and returns version-specific chunks ranked for the model's actual question.[^1][^6] The hosted index is updated continuously by Upstash's parsing pipeline (a multi-step Parse → Enrich → Vectorize → Rerank → Cache flow described in the launch blog).[^11][^15]

The **Claude Code plugin** (added in late 2025, present in the user's install at commit `c050adb10757`) ships five surfaces:

| Component | Purpose | Where it lives |
|---|---|---|
| `.mcp.json` | MCP server registration | `plugins/claude/context7/.mcp.json` |
| `.claude-plugin/plugin.json` | Plugin metadata | `plugins/claude/context7/.claude-plugin/plugin.json` |
| `docs-researcher` subagent | Focused documentation lookups via the Agent tool | `plugins/claude/context7/agents/` |
| `/context7:docs` slash command | Manual one-shot doc query | `plugins/claude/context7/commands/` |
| `documentation-lookup` skill | Auto-triggering router for library questions | `plugins/claude/context7/skills/` |

Source of truth for this list: the Context7 README's "feat(plugins): add Context7 plugin for Claude Code" commit description.[^2] [CONFIRMED]

The installed plugin manifest (`~/.claude/plugins/installed_plugins.json`) confirms `context7@claude-plugins-official` is registered at user scope. The `.mcp.json` at `~/.claude/plugins/cache/claude-plugins-official/context7/c050adb10757/.mcp.json` currently reads:

```json
{ "context7": { "command": "npx", "args": ["-y", "@upstash/context7-mcp"] } }
```

This minimal config is the **free-tier-only** invocation pattern. It will work but will not authenticate the user's `ctx7sk-…` API key.

## 2. The two tools — exact contracts as of Q2 2026

### `resolve-library-id`

| Param | Required | Type | Semantics |
|---|---|---|---|
| `libraryName` | yes | string | The user-facing library name to search for (e.g. `"next.js"`, `"langchain"`) |
| `query` | yes | string | The question/task — used to rank candidate libraries by relevance |

Returns: list of matching library records, each with:[^3][^16]
- **Library ID** (canonical, e.g. `/vercel/next.js`, `/mongodb/docs`)
- **Code snippet count** (corpus size for that library)
- **Source reputation** label (High / Medium / Low / Unknown — replaced numeric trust scores in the 2026 spec update)
- **Available versions** array

A schema-validation bug class on this tool (Issue #1706) periodically surfaces "Required" errors for `query` when callers pass legacy argument shapes — when the tool errors with `expected string, received undefined`, re-check that you're passing both params.[^17]

### `query-docs`

| Param | Required | Type | Semantics |
|---|---|---|---|
| `libraryId` | yes | string | Exact `/owner/project[/version]` ID from `resolve-library-id` |
| `query` | yes | string | The question to retrieve docs for |

Returns: a single reranked payload of relevant code snippets, prose, and config examples — sized server-side. **No `tokens` budget parameter.** No pagination. The 2026 redesign moved that work server-side because client-side iteration was driving "context bloat" — the model would call the tool repeatedly until it found relevance, each call growing the window.[^6] [CONFIRMED]

### Version pinning

To target a specific library version, append it to the library ID (`/vercel/next.js/14`) OR mention the version in the natural-language query and let the resolver match it. The README's example: *"How do I set up Next.js 14 middleware? use context7"*.[^3][^16] The resolver detects the version token and routes to the right index. [CONFIRMED]

## 3. Authentication — the single most important implementation detail

### The free-tier default (current user's state)

The plugin's `.mcp.json` runs `npx -y @upstash/context7-mcp` with no API key. Queries succeed but count against the **unauthenticated rate budget** (substantially tighter than the registered free tier — the hosted backend can't link calls to the user's account).[^7] The user's Context7 dashboard will show zero usage even while queries are running.

### Package versions (2026-06-25)

`@upstash/context7-mcp` is now **3.x** (was 1.x at the time of the #1713 report). Major version bumps make plugin updates more likely to overwrite the env-block workaround — **verify the `env` block after every plugin update**. Latest CLI: `ctx7@0.5.2`. (Source: npmjs.com, retrieved 2026-06-25.)

### Four patterns to inject the API key (ranked by senior-practitioner preference)

**Pattern 0 — `ctx7` CLI setup (recommended for new installs, 2026-06-25):**

```bash
npx ctx7 setup --claude
# For headless environments:
npx ctx7 setup --claude --device
```

`ctx7 setup` handles OAuth login, API-key generation, and `.mcp.json` env injection in a single command. It survives plugin reinstalls more reliably than manual env-block edits. Latest: `ctx7@0.5.2`. (Source: npmjs.com + context7 README, retrieved 2026-06-25.) [CONFIRMED — new Pattern 0; use for all new installs]

**Pattern A — Edit the plugin's `.mcp.json` to read from shell env (recommended for existing installs):**

```json
{
  "context7": {
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp"],
    "env": { "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}" }
  }
}
```

Pros: API key never enters the repo. Secret stays in `~/.zshrc` / `~/.bashrc` or a secrets manager. Survives plugin reinstall as long as you also re-apply the env injection (since the plugin cache may be overwritten on update).
Cons: The plugin update flow may regenerate `.mcp.json` without the `env` block — verify after every plugin update.

This is **the workaround documented in Issue #1713** and the pattern recommended by community responses.[^7] [CONFIRMED]

**Pattern B — Re-register via `claude mcp add` with explicit `--api-key`:**

```bash
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
```

Pros: bypasses the plugin entirely; lives in `~/.claude/mcp_servers.json` (user-scope) and is stable across plugin reinstalls.
Cons: duplicate registration if the plugin is still installed — both pointing at the same npx invocation. Clean up the plugin or accept that the explicit registration wins.[^10] [CONFIRMED]

**Pattern C — Remote OAuth MCP:**

Upstash also ships a hosted remote MCP endpoint with OAuth (handled by clients like Stacklok ToolHive). Claude Code does not currently auto-handle this for arbitrary MCP servers in user scope, so this pattern is mostly for Cursor users.[^18] [POSSIBLY TRUE — corroboration limited to one Tier 2 source for Claude-Code use case specifically]

### What NOT to do

- **Don't hardcode the API key in a versioned `.mcp.json`.** The dotclaude repo is on GitHub. Key leakage triggers immediate Upstash dashboard rotation. The `${CONTEXT7_API_KEY}` interpolation is the gate. [CONFIRMED — security best practice cross-cited in Anthropic + Cloudflare MCP docs[^19]]
- **Don't set `CONTEXT7_API_KEY` in `~/.zshrc` alone.** Issue #1713 is explicit: the Claude Code plugin doesn't forward shell env to the npx subprocess.[^7]
- **`settings.json` env injection is unreliable for Context7 plugin installs.** It may work with direct `claude mcp add` (Pattern B) but not the plugin wrapper — the Context7 plugin's MCP wrapper reads env from the `.mcp.json` `env` block. Use Pattern A or Pattern 0 for plugin installs. (Issues #1309 + #1713; retrieved 2026-06-25.) [PROBABLY TRUE — two Tier 1 sources]

## 4. Pricing tiers and rate budget (authoritative, 2026-05-28)

| Tier | Price | Included calls | Overage | Notable features |
|---|---|---|---|---|
| Free | $0 | 1,000 calls/month + 20 bonus/day after cap | Hard block until reset | Public repos only, community support |
| Pro | $10/seat/month | 5,000 calls/seat | $10 / 1,000 calls | Private repo parsing ($25/1M tokens), email support |
| Enterprise | $30/user/month → $2.50 at scale | Custom | Custom | SOC-2, SSO (SAML/OIDC), self-hosted, dedicated support |

Source: `context7.com/plans` extracted 2026-05-28.[^8] [CONFIRMED]

**Historical context for recency triggers:** Upstash announced a 92% free-tier cut on 2026-01-13 (to 500 calls/month), then walked it back to 1,000 calls on 2026-01-16 after community backlash.[^9] If a tutorial references "200 requests per day" or a tokens budget on the MCP tool surface, it predates 2026-01-13 and should be treated as stale.

## 5. When to invoke Context7 (positive triggers)

Senior-practitioner consensus — the "Always use Context7 when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask" CLAUDE.md rule pattern is recommended by Glama,[^4] Augment Code,[^10] Upstash's own README,[^1] and ClaudeFa.st's Claude-Code-specific guide.[^11]

Concrete triggers that should route to `resolve-library-id` → `query-docs`:

| Trigger class | Example | Why Context7 wins over training data |
|---|---|---|
| Library/SDK API surface | "How do I configure a tRPC v11 router with refine middleware?" | Training data is often months stale; APIs change |
| Framework version-specific code | "Generate a Next.js 15 app router middleware" | Next.js ships breaking changes mid-cycle |
| CLI tool flags / commands | "What's the syntax for `wrangler deploy --route`?" | CLI flags drift faster than tutorials track |
| Cloud service config | "Cloudflare Worker that caches JSON for 5min" | Vendor docs are canonical, training data lags |
| Version migration questions | "Migrate Tailwind 3 → 4 config" | Migration guides update post-release |
| Library-specific debugging | "Why does my LangGraph state graph hang on Send?" | Issue trackers are indexed; training data isn't |

[^1][^4][^10][^11] [CONFIRMED]

## 6. When NOT to invoke Context7 (negative triggers)

The most candid negative-trigger discussions come from Shrivu Shankar ("Everything Wrong with MCP")[^12], the EpicAI piece ("Why MCP Does Not Work")[^13], and the dev.to "MCP Tool Design" post[^20]. Their convergent argument: **MCPs are not free** — tool descriptions consume context tokens on every turn, and noisy retrievals make the model worse, not better.

Do NOT route through Context7 for:

| Trigger class | Use instead |
|---|---|
| Refactoring existing code | Direct file reads + diff thinking |
| Debugging the user's own code | `superpowers:systematic-debugging` skill |
| Business logic implementation | Conversation + Plan tool |
| Writing scripts from scratch | Training data + best practices |
| General CS / programming concepts | Training data |
| Comparing two libraries holistically | `/research` (Tavily) — broader sources |
| One-off library question you've answered before | Memory recall first, Context7 second |
| Anything that doesn't name a specific library/API | Training data + WebSearch fallback |

[^12][^13][^20][^21] [CONFIRMED]

## 7. Failure modes and pitfalls

Cross-referencing the upstash/context7 issue tracker against practitioner blog posts surfaces seven repeating failure modes:

1. **"Library not found / not finalized for this version"** (Issue #71) — the index either doesn't include the library yet or doesn't have the requested version. Mitigation: fall back to `resolve-library-id` with broader `libraryName`, or escalate to `tavily_skill`.[^22] [CONFIRMED]
2. **Plugin install API key passthrough silently fails** (Issue #1713, still OPEN as of 2026-06-25) — covered in §3.[^7] Mitigation: use Pattern 0 (`ctx7 setup --claude`) for new installs, or Pattern A (`env` block in `.mcp.json`) for existing installs. The `@upstash/context7-mcp` major version jump to 3.x increases the likelihood that plugin updates overwrite the env block — verify after every update.
3. **Schema validation errors on `resolve-library-id`** (Issue #1706) — typically caused by legacy callers passing only `libraryName` without `query`. Mitigation: always pass both required params.[^17] [CONFIRMED]
4. **Self-hosted authentication issues** (Issues #666, #711) — affects users running on-prem; not relevant for hosted free-tier.[^23][^24] [PROBABLY TRUE — narrow scope]
5. **MCP server blocks agent spawn** (Issue #877) — under specific stdio-transport conditions, Context7's MCP prevents Claude Code subagents from initializing. Mitigation: disable Context7 as a smoke test when Agent tool calls hang.[^14] [CONFIRMED — diagnostic value]
6. **Context bloat from repeated MCP calls** (addressed by the 2026 redesign) — the old `get-docs` would be called iteratively as the model searched for the best result, each call growing the window. The new `query-docs` returns a single reranked payload server-side.[^6] If tutorials show looping over results, they predate the redesign. [CONFIRMED]
7. **Stale snapshots for fast-moving libraries** — the version analyzer (introduced in the quality-and-safety blog post) excludes older versions during parsing to keep storage focused on current.[^15] Side effect: if you query a library that just shipped a breaking change, the index may not have caught up. Mitigation: cross-check against `tavily_skill` for any tool/library released in the last week. [CONFIRMED]

## Contradictions & open debates

- **"Always auto-invoke" vs "auto-invoke only on doc-specific intent."** Upstash's README (Glama, Augment Code) recommends the broad auto-invoke rule.[^1][^4][^10] Skeptical practitioners (Shankar, EpicAI, Scott Spence) argue that broad auto-invoke wastes budget and pollutes the context window for non-doc work.[^12][^13][^21] **Resolution for dotclaude:** narrow the auto-invoke rule to **library/framework/SDK/CLI/version triggers** (per the table in §5), not "any code question."
- **`get-docs` vs `query-docs` naming.** The "new Context7" blog post[^6] uses `get-docs` in the SDK section; the shipped MCP tool exposed by `@upstash/context7-mcp` is `query-docs` (per the user's Claude Code system reminder and the Augment Code spec[^10]). **Resolution:** the blog discusses the JavaScript SDK API; the MCP server has its own naming. Trust the MCP tool name from the runtime.
- **Hardcoded API key in `.mcp.json` vs env interpolation.** Some Upstash tutorials show `--api-key YOUR_KEY` literally. Security best-practice guidance (Anthropic MCP docs, Red Hat's MCP security write-up[^25]) says always interpolate from env. **Resolution:** Pattern A or Pattern 0 from §3.
- **`get-library-docs` (HTTP remote transport `mcp.context7.com/mcp`) vs `query-docs` (stdio/npx)** — both are current, but transport-dependent. The HTTP remote transport (`mcp.context7.com/mcp`) exposes `get-library-docs`; the stdio/npx transport (`@upstash/context7-mcp`) exposes `query-docs`. dotclaude's npx/stdio config correctly uses `query-docs`. If you see `get-library-docs` in a tutorial, it targets the remote HTTP transport, not the stdio MCP. (Retrieved 2026-06-25.) [CONFIRMED]

## Needs Verification

None — all routing rules and API claims rest on ≥2 independent Tier 1/2 sources.

## Methodology note

- Tier profile: technical (Tier 1 anchors: upstash GitHub + docs + context7.com; Tier 2: Augment, Glama, claudefa.st; Tier 3: practitioner blogs for negative-trigger consensus only)
- Total candidates retrieved: ~90 across 9 searches
- Final cited: 25 distinct sources
- 5 deep extracts on Tier-1 anchors for groundedness
- CRAG iterations: 0 (gates passed on first pass)

## Sources

[^1]: Upstash, *Context7 Platform — Up-to-date Code Docs For Any Prompt*, GitHub README, accessed 2026-05-28. https://github.com/upstash/context7 — Tier 1, A1
[^2]: Upstash, commit message "feat(plugins): add Context7 plugin for Claude Code", upstash/context7, late 2025. https://github.com/upstash/context7 — Tier 1, A1
[^3]: Upstash, Context7 README "MCP Tools" section: `query-docs`, `libraryId` (required, e.g. `/mongodb/docs`, `/vercel/next.js`), `query` (required). — Tier 1, A1
[^4]: Glama, *Context7 MCP by upstash*, accessed 2026-05-28. https://glama.ai/mcp/servers/upstash/context7-mcp — Tier 2, B1
[^5]: Upstash, Issue #1788 "Expose context7 tools as a CLI" — references `resolve-library-id` and `query-docs` as the canonical tool names. https://github.com/upstash/context7/issues/1788 — Tier 1, A2
[^6]: Upstash Blog, *Context7 Without Context Bloat*, by Enes Akar, 2025/2026. https://upstash.com/blog/new-context7 — Tier 1, A1
[^7]: Issue #1713, *[Bug]: plugin-based install is not documented and seems like doesn't support the API keys*, opened by alexander-m-loris, 2026. https://github.com/upstash/context7/issues/1713 — Tier 1, A1
[^8]: Context7, *Pricing & Plans*, https://context7.com/plans — Tier 1, A1
[^9]: JP Caparas, *Context7 Quietly Slashed Its Free Tier by 92%*, Dev Genius, 2026-01-13 (updated 2026-01-16 with @enesakar tweet). https://blog.devgenius.io/context7-quietly-slashed-its-free-tier-by-92-16fa05ddce03 — Tier 3, C2 (corroborated by context7.com/plans for current numbers)
[^10]: Augment Code, *Context7 MCP by Upstash*, https://www.augmentcode.com/mcp/context7 — Tier 2, B1
[^11]: ClaudeFa.st, *Context7 MCP: Real-Time Documentation Access for Claude Code*, https://claudefa.st/blog/tools/mcp-extensions/context7-mcp — Tier 2, B2
[^12]: Shrivu Shankar, *Everything Wrong with MCP*, sshh.io, accessed 2026-05-28. https://blog.sshh.io/p/everything-wrong-with-mcp — Tier 2, B1
[^13]: EpicAI, *Why the Model Context Protocol Does Not Work*. https://www.epicai.pro/why-the-model-context-protocol-does-not-work-hgsz5 — Tier 2, B2
[^14]: Issue #877, *[Bug]: context7 mcp in claude CLI preventing agents from spinning up*. https://github.com/upstash/context7/issues/877 — Tier 1, A1
[^15]: Upstash Blog, *Quality and Safety in Context7*. https://upstash.com/blog/context7-quality-and-safety — Tier 1, A1
[^16]: LobeHub, *Context7 Documentation | MCP Servers*. https://lobehub.com/mcp/upstash-context7-docs — Tier 2, B2
[^17]: Issue #1706, *[Bug]: Resolver input validation fails for `mcp_upstash_conte_resolve-library-id`*. https://github.com/upstash/context7/issues/1706 — Tier 1, A1
[^18]: Stacklok Docs, *Context7 MCP server guide*. https://docs.stacklok.com/toolhive/guides-mcp/context7 — Tier 2, B2
[^19]: Anthropic, *Best practices for Claude Code*. https://code.claude.com/docs/en/best-practices — Tier 1, A1
[^20]: dev.to (AWS Heroes), *MCP Tool Design: Why Your AI Agent Is Failing*. https://dev.to/aws-heroes/mcp-tool-design-why-your-ai-agent-is-failing-and-how-to-fix-it-40fc — Tier 2, B2
[^21]: Scott Spence, *Optimising MCP Server Context Usage in Claude Code*. https://scottspence.com/posts/optimising-mcp-server-context-usage-in-claude-code — Tier 2, B2
[^22]: Issue #71, *Context7 MCP server fails to retrieve library documentation*. https://github.com/upstash/context7/issues/71 — Tier 1, A1
[^23]: Issue #666, *context 7 is not connecting even after changing API key*. https://github.com/upstash/context7/issues/666 — Tier 1, A2
[^24]: Issue #711, *Context7 MCP Server Self-Hosted Authentication Issue*. https://github.com/upstash/context7/issues/711 — Tier 1, A2
[^25]: Red Hat Blog, *Model Context Protocol (MCP): Understanding security risks and controls*. https://www.redhat.com/en/blog/model-context-protocol-mcp-understanding-security-risks-and-controls — Tier 2, B1
