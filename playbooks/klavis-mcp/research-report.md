# Klavis Strata MCP — integration playbook (Gmail focus)

> **Validated: 2026-06-25 (partial re-validation via Tavily; live MCP surface not empirically re-probed — run a discovery probe before any backlog session) · Original empirical source: 2026-04-30 (live integration with `klavis-gmail` Strata server, instance `823fd391-...`) + Tavily passes against `klavis.ai/docs` and `docs.klavis.ai`. Companion playbook to `~/.claude/playbooks/claude-code-koyeb-channels/` (which deploys the runtime that consumes Klavis).**
>
> **⚠ Stale-by guidance:** Klavis is in active iteration. Re-validate (`tools/list` probe + a single `gmail_modify_email` round-trip) if **either** of the following is true: (a) the timestamp above is more than 4 weeks old, or (b) you see the v1 silent-label-drop symptom (`addedLabels` returns `["UNREAD"]` instead of your requested labels). Klavis ships breaking renames at the toolkit-server level without explicit deprecation in the MCP surface.
>
> **⚠ ARCHITECTURE CHANGE (2026-06-25):** Strata now uses a **progressive-discovery model**, not a flat 10-tool surface. See §TL;DR and the STALE banner below. Live MCP surface was not empirically re-probed — run `discover_server_categories_or_actions` before any session. Next check: 2026-07-23.

## TL;DR — what every consumer needs to know

> **⚠ STALE (as of 2026-06-25):** The "verified 10-tool surface" section below was empirically accurate as of 2026-04-30. **Strata has since moved to a progressive-discovery model.** See the updated findings immediately below before relying on the tool-name list. (Source: klavis.ai/docs/concepts/strata, retrieved 2026-06-25.)

### Updated architecture — Strata progressive-discovery (2026-06-25)

Current Strata exposes **5–6 meta-tools** instead of a flat 10-tool surface:

| Meta-tool | Purpose |
|---|---|
| `discover_server_categories_or_actions` | First call — discover available categories or actions for a server |
| `get_category_actions` | Get actions within a category |
| `get_action_details` | Get full schema for a specific action |
| `execute_action` | Execute an action: `execute_action(server_name="Gmail", category_name=…, action_name=…)` |
| `search_documentation` | Search Klavis documentation |
| `handle_auth_failure` | Handle OAuth failures |

**Critical change:** agents do NOT call `gmail_*` names directly anymore. They call `execute_action(server_name="Gmail", category_name=…, action_name=…)`. Tool names are resolved at runtime via `get_action_details` — the old anti-pattern of pinning `tools/list` names is **doubly wrong** now. (Source: klavis.ai/docs/concepts/strata, retrieved 2026-06-25.)

The canonical starting call for any backlog session is now `discover_server_categories_or_actions`, not `tools/list`.

### Gmail tool names (runtime-resolved, 2026-06-25)

Current official docs show: `gmail_search_messages`, `gmail_get_message`, `gmail_delete_message`, `gmail_send_message`, `gmail_create_draft`, `gmail_reply_message`, `gmail_mark_as_read`. Note these are now resolved at runtime via `get_action_details` — do not pin them as static names. (Source: klavis.ai/use-case/gmail-llm-automation-guide, retrieved 2026-06-25.)

> **Note:** The old `*_email` naming (`gmail_search_emails`, `gmail_modify_email`, etc.) was accurate at 2026-04-30. Current docs show `*_message` naming. Names should be resolved dynamically at session start.

---

### Original TL;DR (2026-04-30 empirical — partially stale, see above)

| # | Finding | Operational consequence |
|---|---|---|
| 1 | **Klavis Strata exposes only a default *subset* via MCP `tools/list`.** For Gmail, that subset was **10 tools** (full list below; see STALE banner — architecture changed). The wider toolkit was reachable only via `raw-actions` endpoint. | **`raw-actions` endpoint is not in current docs; treat as unverified/probably obsolete — do not design around it; re-probe live.** (unverified at 2026-06-25 — re-probe live) |
| 2 | **Canonical Gmail tool names were `*_email` at 2026-04-30; current docs show `*_message`, resolved at runtime.** Don't trust any pinned names. | Always run `discover_server_categories_or_actions` → `get_action_details` at session start. Never hardcode tool names. |
| 3 | **`gmail_modify_email` accepts unknown label *names* silently.** The Gmail API requires label *IDs* (`Label_NNN`). Klavis forwards your `addLabelIds` array verbatim; if you pass `_Agent/Triage/Bucket` (a name, not an ID), the call returns 200 OK with `addedLabels: ["UNREAD"]` and your label is silently dropped. | After every modify call, verify `response.addedLabels` ⊇ what you asked for. Treat any divergence as a hard error. **Never** pass label names; always resolve to IDs first. |
| 4 | **The `strata_id` (`strataId` in API paths) in the MCP URL IS the credential.** The path-style URL is `https://strata.klavis.ai/mcp/?strata_id={strata_id}` and possession of `strata_id` grants full access to the bound Gmail OAuth grant. (Identifier renamed `instance_id` → `strata_id` in current SDK/API reference; source: klavis.ai/docs/api-reference/strata, retrieved 2026-06-25.) | Treat the full MCP URL as a P0 secret. Never log it, never commit it, and rotate by deleting+recreating the Strata instance if leaked. |
| 5 | **Transport is HTTP+SSE JSON-RPC.** Initialize → `tools/list` → `tools/call`. The Strata server holds OAuth state per instance — a single `instance_id` = a single Gmail account = one user's mailbox. | Multi-tenant deployments need one Strata instance per user. Pricing/scale implications: factor this into capacity planning. |

## The verified Gmail tool surface (default subset)

Probe command (idempotent; safe to run as often as you need to re-pin):

```bash
python3 scripts/backlog-triage-v2.py probe-tools --output data/klavis-tools-schema.json
```

(equivalent: a direct `tools/list` JSON-RPC request to the MCP URL with `Authorization: Bearer ${KLAVIS_API_KEY}` header.)

The 10 tools and their relevant signatures:

| Tool name | Required params | Notes |
|---|---|---|
| `gmail_search_emails` | `query: string` | Gmail search syntax; supports the full `is:`, `from:`, `label:`, `newer_than:` operators. `maxResults` defaults Klavis-side; pass it explicitly. |
| `gmail_read_email` | `messageId: string` | Returns the full thread — *all messages*, not just the requested one. Plan for this in token budgeting. |
| `gmail_modify_email` | `messageId: string`, optional `addLabelIds`, `removeLabelIds` | **Label IDs only, never names.** See finding 3. |
| `gmail_batch_modify_emails` | `messageIds: string[]`, optional `addLabelIds`, `removeLabelIds`, `batchSize: number (default 50)` | Wraps Gmail's `users.messages.batchModify` (1000-message ceiling per call). Use this for any backlog-scale label apply. |
| `gmail_delete_email` | `messageId: string` | **HARD DELETE** (Gmail `messages.delete`, not `messages.trash`). Banned outright in any HITL pipeline. |
| `gmail_batch_delete_emails` | `messageIds: string[]` | Same — banned. |
| `gmail_send_email` | `to: string[]`, `subject: string`, `body: string` | Banned in HITL pipelines without explicit per-message approval. |
| `gmail_draft_email` | `to: string[]`, `subject: string`, `body: string` | Drafts only — non-destructive, but creates user-visible state, so still gate behind approval. |
| `gmail_get_email_attachments` | `messageId` | Read-only. |
| `gmail_search_contacts` | (varies) | Read-only contact directory lookup. |

**Critically absent (load-bearing):**
- `gmail_create_label`
- `gmail_list_labels`
- `gmail_trash_email` (only hard-delete is exposed)
- `gmail_modify_thread`, `gmail_trash_thread`

## How to recover the missing label-management tools

> **⚠ `raw-actions` endpoint:** not in current Klavis docs as of 2026-06-25 — treat as unverified/probably obsolete. Do not design around it; re-probe live before relying on it. (unverified at 2026-06-25 — re-probe live)

Klavis's "raw actions" endpoint formerly exposed the *full* toolkit before the default-subset filter is applied. **Verified path (2026-04-30; may be obsolete — see above)** (note: `instance/<id>` not `strata/<id>`):

```http
GET https://api.klavis.ai/mcp-server/instance/{instance_id}/raw-actions?server=GMAIL
Authorization: Bearer ${KLAVIS_API_KEY}
```

For Gmail, `raw-actions` returns the **same 10 tools** as `tools/list` — there is no hidden label-management tool. So this endpoint's value for Gmail is empty; for other servers it may matter.

**Verified workaround for getting label IDs (validated 2026-04-30):** use Google's [OAuth Playground](https://developers.google.com/oauthplayground/) with scope `https://www.googleapis.com/auth/gmail.labels`, send `GET https://gmail.googleapis.com/gmail/v1/users/me/labels`, and parse the response. ~2 minutes; no Cloud Console setup; gives you the canonical `name → Label_<digits>` map directly.

### Modern Gmail label IDs are 19-digit, NOT small sequential

**Critical empirical correction.** This playbook's earlier draft suggested brute-forcing label IDs by probing `Label_1..Label_500` via `gmail_modify_email` and checking idempotency (`addedLabels: []` means already present). **This does not work for modern Gmail accounts.**

User labels created in modern Gmail accounts have IDs of the form `Label_<19-digit-number>`, e.g. `Label_3675345408755522104`. Brute force is completely infeasible across that space. The Label IDs ARE numeric, but the numbers are essentially randomised in the 10^18+ range — they are **not** sequential per account.

(Older labels — created before some Gmail-internal cutover — may still have small IDs like `Label_9`, `Label_10`. Both formats co-exist in the same account. The system labels keep their stable names: `INBOX`, `STARRED`, `TRASH`, `UNREAD`, `IMPORTANT`, `SPAM`, `CHAT`, `SENT`, `DRAFT`, `YELLOW_STAR`, plus the five `CATEGORY_*` labels.)

**Implication:** there is no within-Klavis path to discover label IDs for newly-created user labels. OAuth Playground (or any other Gmail API direct call) is the only viable resolution route.

### Klavis's label name cache is stale post-OAuth

When the user creates new Gmail labels via the web UI **after** the Klavis OAuth grant, Klavis's name-to-ID cache does NOT refresh automatically. Calling `gmail_modify_email` with `addLabelIds: ["_Agent/Triage/transactional"]` (a name) returns `{"error": "Invalid label: _Agent/Triage/transactional"}` even when the label exists in Gmail.

Re-visiting the OAuth authorize URL (`https://api.klavis.ai/oauth/gmail/authorize?instance_id=<id>`) does **not** refresh the name cache — verified empirically. There appears to be no public refresh endpoint. **Only Label IDs are reliable** as input to `gmail_modify_email` / `gmail_batch_modify_emails`. Resolve names → IDs once via Gmail API direct, persist the map, and never pass names to Klavis modify tools.

### Klavis admin endpoints (verified 2026-04-30)

Path discoveries:
- `GET https://api.klavis.ai/mcp-server/instance/{instance_id}` — instance metadata, including `oauthUrl`, `isAuthenticated`, `serverName`, `externalUserId`
- `GET https://api.klavis.ai/mcp-server/instance/{instance_id}/raw-actions?server=GMAIL` — raw action list (same as `tools/list` for Gmail)

NOT working (verified 404 / 422):
- `mcp-server/strata/{id}/...` (older path style, defunct)
- `mcp-server/instance/{id}/auth/GMAIL` (no longer at this path; check klavis.ai dashboard for OAuth status instead)
- `mcp-server/instance/{id}/refresh` / `refresh-cache` / `sync` / `labels` / `refresh-tools` — none exist

## Architecture pattern: instance-per-user, credential-via-URL

```
┌───────────────────┐    HTTPS+SSE    ┌─────────────────────────────┐
│  Claude Code CLI  │  ─────────────▶ │  strata.klavis.ai/mcp/      │
│  (.mcp.json)      │   Bearer KEY    │  ?strata_id=<strata_id>     │
└───────────────────┘                 └──────────────┬──────────────┘
                                                     │ Gmail OAuth grant
                                                     │ (held by Klavis,
                                                     │  bound to instance)
                                                     ▼
                                      ┌─────────────────────────────┐
                                      │      Gmail API (user)       │
                                      └─────────────────────────────┘
```

`.mcp.json` shape that works with Claude Code v2.1.x:

```json
{
  "mcpServers": {
    "klavis-gmail": {
      "url": "${KLAVIS_GMAIL_MCP_URL}",
      "headers": {
        "Authorization": "Bearer ${KLAVIS_GMAIL_API_KEY}"
      }
    }
  }
}
```

(Claude Code's MCP HTTP transport supports header injection via the `headers` map. Verified via Stage B of the email-triage rollout, 2026-04-30.)

## OAuth health check (24h cadence)

Klavis's Gmail grants can lapse silently — refresh-token rotation, OAuth-consent screen changes, the user revoking app access in Google Account settings. Poll (identifier is now `strata_id` / `strataId` in API paths; source: klavis.ai/docs/api-reference/strata, retrieved 2026-06-25):

```http
GET https://api.klavis.ai/mcp-server/strata/{strataId}/auth/GMAIL
Authorization: Bearer ${KLAVIS_API_KEY}
```

Response (healthy): `{"isAuthenticated": true, "...": "..."}`. On `false`, the agent should pause its `/loop` and post a Telegram alert. This is a small wrapper script's job in the Koyeb container, not the agent's job.

## Anti-patterns observed in the wild (this is the playbook's debt-paydown ledger)

### 1. Silent label drop (the v1 backlog burn)
**Symptom:** `gmail_modify_email` returns 200 OK; `response.addedLabels` is `["UNREAD"]` (or empty). User-visible result: nothing happened.
**Root cause:** Passed label *names* (`_Agent/Triage/Promotional`) where Gmail expects label *IDs* (`Label_<19-digit-number>`). Klavis forwards verbatim; Gmail silently drops unknown IDs. (Update: as of 2026-04-30 Klavis returns explicit `{"error": "Invalid label: <name>"}` instead of silent drop — but the underlying issue stands. Whether silent or explicit, names don't work.)
**Fix:** Always resolve names → IDs **once** via Google OAuth Playground (`gmail.labels` scope, GET `users/me/labels`), persist the map to `data/backlog/label-map.json`, and pass IDs to every subsequent Klavis modify call. After each modify, assert `set(addedLabels) ⊇ set(requestedLabelIds)`.

### 2. Trusting third-party MCP registries or static tool names
**Symptom:** Agent calls `gmail_modify_message` or `gmail_modify_email`; Klavis returns "tool not found" or unexpected behaviour.
**Root cause:** Reverse-engineered MCP registries document stale naming. Klavis renamed from `*_message` → `*_email` (pre-2026), and current docs now show `*_message` again (runtime-resolved). With progressive discovery, tool names are **never stable** across Strata updates.
**Fix (updated 2026-06-25):** Start every session with `discover_server_categories_or_actions`, then `get_action_details` to get the current action schema. Do NOT hardcode `*_email` names (now `*_message`, runtime-resolved). The Phase-0 probe is mandatory.

### 3. Per-email LLM reasoning at backlog scale
**Symptom:** 10k-email backlog burns ~$30+ in Claude API or hits a Max-subscription monthly cap mid-run.
**Root cause:** Calling Claude once per message to classify is exponential overkill. >90% of messages can be bucketed by sender + subject regex + Gmail's `CATEGORY_*` headers alone.
**Fix:** Two-phase. Phase A: deterministic Python rules on metadata only — no LLM. Phase B: LLM (Haiku 4.5 minimum, Sonnet only if Haiku fails) on the ambiguous tail, batched 50 messages per call, with `cache_control` on the system prompt + tool definition. Stack the Anthropic Batch API (50% discount) on top if you can wait for batch processing (<24h, usually <1h). Net: ~85% cheaper than per-email synchronous calls.

### 4. Reading the email body for classification
**Symptom:** Token budget blows up; classification accuracy doesn't improve.
**Root cause:** The body is 90% of per-email tokens but adds little signal beyond `subject + sender + headers (List-Unsubscribe, CATEGORY_*)`. Plus, bodies carry prompt-injection risk.
**Fix:** Classify on metadata only. Wrap any body content in `<email_body_untrusted>...</email_body_untrusted>` if you absolutely must include it.

### 5. Hard delete vs trash confusion
**Symptom:** Agent "trashed" a message but the user can't find it in Trash.
**Root cause:** `gmail_delete_email` is hard delete (`messages.delete` API), not trash (`messages.trash`). Klavis's default toolkit only exposes the destructive one in this slot.
**Fix:** Don't call `gmail_delete_email` at all. To "trash", use `gmail_modify_email` with `addLabelIds: ["TRASH"]` (system label). Better yet, gate the operation behind HITL approval and use `addLabelIds: ["TRASH"]` only after explicit user confirmation.

### 6. Letting the agent guess tool names mid-run
**Symptom:** Agent burns 5–15 minutes "thinking" about how to call a tool, often getting it wrong.
**Root cause (2026-06-25 update):** With progressive discovery, tool names are resolved at runtime — static schema dumps from a previous session are stale. The agent must call `discover_server_categories_or_actions` → `get_action_details` first, not guess from training data or cached schemas.
**Fix (updated 2026-06-25):** Phase-0 discovery call (`discover_server_categories_or_actions`) at session start. Hard rule in the agent prompt: "Only call `execute_action` with action names returned by `get_action_details` in this session. If you need an action not returned by discovery, halt and report. Never hardcode `*_email` or `*_message` names."

## Operational tips collected today

- **Probe is cheap and idempotent.** Run it at the start of every backlog session. Cost: ~1 round-trip to Klavis. Benefit: pins all tool names for the run, eliminates the entire "guess the schema" failure mode.
- **`gmail_batch_modify_emails` defaults to 50/batch and supports up to 1000.** Override `batchSize` if you have headroom. For a 10k-email backlog with 6 buckets, this is 6 batch calls (or 10–12 if any bucket exceeds 1000), versus 10k individual modify calls. Wall-clock: minutes vs hours.
- **Gmail search syntax is fully passed through.** All `is:`, `from:`, `label:`, `newer_than:N`, `category:` operators work. This is your primary inventory tool.
- **Klavis instance URL persists across container rebuilds** — instance_id is a stable handle. You don't need to re-pair Gmail OAuth on every Koyeb deploy.

## Vault binding (for non-Claude-Code consumers)

If you're calling Klavis from Anthropic Managed Agents (now superseded in this project but still valid as a pattern):

```
Vault entry:
  type: static_bearer
  endpoint: https://strata.klavis.ai/mcp/?strata_id=<instance_id>
  bearer:   <KLAVIS_API_KEY>
```

The Managed Agents runtime sends the bearer header on every MCP call. Same security model as direct: `instance_id` is the credential.

## Sources & cross-references

- `~/.claude/playbooks/claude-code-koyeb-channels/research-report.md` — parent playbook; §1 discusses Klavis Gmail integration in the Koyeb context
- `~/.claude/playbooks/claude-code-koyeb-channels/backlog-triage-research.md` — sister doc; covers the LLM-side cost optimisation (Haiku, batch API, prompt caching) that pairs with the Klavis tool surface findings here
- Klavis docs: `https://klavis.ai/docs` and `https://docs.klavis.ai`
- Klavis Strata progressive-discovery: `https://klavis.ai/docs/concepts/strata` (retrieved 2026-06-25) — canonical for current architecture
- Klavis Gmail automation guide: `https://klavis.ai/use-case/gmail-llm-automation-guide` (retrieved 2026-06-25) — canonical for current Gmail action names
- Klavis API reference (strata_id / strataId): `https://klavis.ai/docs/api-reference/strata` (retrieved 2026-06-25)
- Klavis raw-actions endpoint: `GET /mcp-server/strata/{strataId}/raw-actions?server=GMAIL` (verified live 2026-04-30 — **unverified at 2026-06-25, treat as probably obsolete; re-probe live**)
- Empirical schema dump: `Agents/email-triage-agent/data/backlog/tools-schema.json` in the email-triage project — canonical reference for the 10-tool subset as of 2026-04-30; **stale post-progressive-discovery migration**.
- Gmail API: `users.messages.batchModify` (1000-message limit) — `https://developers.google.com/gmail/api/reference/rest/v1/users.messages/batchModify`

## Findings — session 2 (2026-04-30 PM, post-1872-message backlog run)

These are empirical observations that landed only after a full Phase 3-7 backlog pass against ~651 reachable inbox messages. They are NOT in earlier docs and add to the canonical anti-pattern list above.

### 7. `gmail_search_emails` returns a bare LIST, not a dict
**Symptom:** Code that does `resp.get("messages")` on the search result silently returns nothing.
**Root cause:** Klavis returns `[{id, subject, from, date}, …]` directly — there is no `{"messages": [...]}` wrapper. (And no `nextPageToken` either — see finding 9.)
**Fix:** Treat the result as `list[dict]`; if you must dual-handle, branch on `isinstance(resp, list)`.

### 8. `gmail_read_email` strips `labelIds` AND headers
**Symptom:** A rule classifier that depends on `CATEGORY_PROMOTIONS`, `List-Unsubscribe`, etc. silently classifies everything as "ambiguous".
**Root cause:** Klavis's read tool returns *only* `{messageId, subject, from, to, date, body: {text, html, preferredFormat}}`. There is no `headers` field, no `labelIds` field, and no representation of Gmail's `CATEGORY_*` system labels at all. The body is wrapped under a single nested `body.text` / `body.html` pair.
**Fix:** Don't classify on signals Klavis can't surface. Either (a) operate on the search-response metadata only (`subject` + `from` + `date`), which is enough for ~80% of messages with strong rule heuristics; or (b) reach to the Gmail API directly outside Klavis (OAuth Playground or a separate access token) when you need full headers / labels.

### 9. No pagination — 500-result hard cap, then silent zero
**Symptom:** A query that obviously matches >500 messages returns exactly 500 results; a much broader query (e.g. unfiltered `in:inbox` with `maxResults=500`) returns `0` (a `dict`, not a `list`).
**Root cause:** Klavis caps `gmail_search_emails` at 500/call. There is no `pageToken` field in the schema or response. When the underlying Gmail call would yield "very many" results, Klavis appears to time out or otherwise give up and returns an empty dict (NOT a list, NOT an error).
**Fix:** Drive search via narrow, time-windowed queries (`older_than:Nd newer_than:Md`) sized so each window stays well under 500. The empty-dict-vs-empty-list distinction is your "I overshot" signal — if you see a dict, retry with a tighter window or smaller `maxResults`.

### 10. `gmail_batch_modify_emails` returns aggregate counts only
**Symptom:** A batch of 1000 message IDs returns `{message: "...", successCount: 992, failureCount: 8}` and you have no way to identify which 8 failed.
**Root cause:** Klavis wraps Gmail's `users.messages.batchModify` and surfaces only the aggregate. Per-message status is not exposed.
**Fix:** Don't try to recover the failures inline. Klavis modify is idempotent (already-labelled = no-op success), so just re-run the same labelling pass on the next cron tick — failed messages haven't moved to "Done" state, so they'll be re-attempted naturally. Report `failureCount` to the user but treat 1-3% transient failure rate as expected (Klavis is in active beta).

### 11. `gmail_modify_email` (single) DOES return populated `addedLabels`
**Symptom:** None — this is a positive finding that contradicts the v1-era "always empty" lore.
**What actually happens:** Single-message modify returns `{message, messageId, addedLabels: [Label_<id>]}`. Empty `addedLabels: []` reliably indicates idempotent re-apply (label already present). This makes single-message modify a usable HITL gate — you *can* trust the response shape.

### 12. SSE transport — two parsing landmines
**Symptom A:** Long messages (e.g., search results with 100+ subject lines containing emoji) parse fine sometimes, then suddenly fail with `json.JSONDecodeError: Unterminated string at char N`.
**Root cause A:** `requests.iter_lines()` splits the SSE stream on chunk boundaries, which can fall mid-line for long `data:` payloads.
**Fix A:** Read the whole response (`r.text`), then split events on `"\n\n"` and lines on `"\n"`.

**Symptom B:** After fixing A, still seeing truncation on payloads with emoji.
**Root cause B:** Python's `str.splitlines()` treats Unicode chars `\x85` (NEL), ` ` (LS), ` ` (PS) as line terminators. Emoji UTF-8 byte sequences can contain `\x85`, so `splitlines()` chops the payload mid-string.
**Fix B:** Use `text.split("\n")` *only* — never `splitlines()` — anywhere in the SSE parser. Verified: the email-triage project hit this exact bug on subjects like `"AI Companion 🐝 Beehiiv update"`.

### 13. Klavis cache vs source-of-truth label IDs
**Symptom:** Newly-created labels return `{"error": "Invalid label: <name>"}` even after re-running the OAuth grant flow.
**Root cause:** Klavis caches Gmail's `users.labels.list` response at OAuth-grant time and does NOT refresh it on subsequent grants of the same instance. Verified with two consecutive OAuth grants against the same instance — the second grant did not pick up labels created between grants.
**Fix:** Treat name-resolution as a **one-time, out-of-band** operation. Use OAuth Playground (`gmail.labels` scope) to dump `users/me/labels`, persist to `data/backlog/label-map.json` under a top-level `mapping` key, and call Klavis with raw IDs only.

### 14. Anthropic SDK + Haiku 4.5 — pricing & caching nuances
**Symptom:** Phase 4 with 136 ambiguous messages, 3 batches of ~50, returned `cache_create_input_tokens: 0` and `cache_read_input_tokens: 0` despite `cache_control: ephemeral` on system + tools.
**Root cause:** Ephemeral cache requires the cached block to exceed a minimum-size threshold (~1024 tokens for Haiku as of 2026-04). A short system prompt + a small tool schema fall below that threshold and silently bypass the cache.
**Operational impact:** None for small backlogs (~3k Haiku output × $0.40/MTok = essentially free). But for 100k+ backlogs, expand the system prompt deliberately past the cache threshold to lock in the discount.
**Sonnet-equivalent multipliers (verified 2026-04):** Haiku 4.5 input ≈ 0.1× Sonnet input; Haiku output ≈ 0.2× Sonnet output. Cache reads are 0.1× the corresponding fresh-input cost. Use these for cost-projection sanity checks.

### Updated probe / smoke-test recipe (2026-06-25 — progressive discovery)

> **Architecture changed.** The canonical first call is now `discover_server_categories_or_actions`, not `tools/list`. The 2026-04-30 recipe below is preserved for reference but the step 1 must be updated before use.

```python
# UPDATED preflight (2026-06-25 — progressive discovery):
# 1. discover_server_categories_or_actions {server_name: "Gmail"}
#    Assert: returns categories or actions list.
# 2. get_action_details {server_name: "Gmail", action_name: <search action>}
#    Assert: schema returned. Note the current action name — do NOT assume gmail_search_emails.
# 3. execute_action {server_name: "Gmail", action_name: <search>, params: {query: "in:inbox newer_than:1d", maxResults: 5}}
#    Assert: response contains message list.
# 4. (Optional) execute_action for modify — assert addedLabels on single message.

# ORIGINAL preflight (2026-04-30 — may still work if Strata still exposes flat surface):
# 1. Initialize + tools/list (once).
# 2. gmail_search_emails {query: "in:inbox newer_than:1d", maxResults: 5}
#    Assert: response is a list, len(response) > 0, first item has 'id'.
# 3. gmail_read_email {messageId: <first id>}
#    Assert: response is a dict with 'emails' key.
#    Assert: emails[0] has 'subject', 'from'. Note: NO 'labelIds'.
# 4. gmail_modify_email {messageId: <test id>, addLabelIds: ['<known-id>']}
#    Assert: response.addedLabels matches OR is [] (idempotent).
# 5. gmail_batch_modify_emails {messageIds: [<id>], addLabelIds: ['<known-id>']}
#    Assert: response.successCount == 1, response.failureCount == 0.
```

If any assertion fails, halt and re-validate. Don't proceed with a backlog pass on a wobbly Klavis instance.

## When to re-validate this report

Re-run a `tools/list` probe + a single round-trip test if **any** of:

1. The validated date is > 4 weeks old.
2. You see `addedLabels` divergence in production after a previously-working run.
3. Klavis ships a changelog entry mentioning Gmail toolkit changes.
4. A new MCP registry source (hive-tools, awesome-mcp, etc.) lists tool names that conflict with the canonical names in this doc.
5. You start a project that needs a Gmail tool not in the 10-tool subset — re-fetch via raw-actions before designing around its absence.
