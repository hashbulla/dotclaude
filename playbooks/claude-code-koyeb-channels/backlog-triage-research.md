# Backlog email triage research — findings for v2 hardening

> Research date: 2026-04-29 · Scope: targeted (not exhaustive) — 4 Tavily calls + code review of `scripts/backlog-triage-v2.py` and `prompts/backlog-triage-v2.md`. Goal: harden the v2 plan before it executes.

## TL;DR — top 5 actionable improvements

| # | Improvement | File | Token / time impact |
|---|---|---|---|
| 1 | **Use canonical Klavis Gmail tool names**: `gmail_create_label`, `gmail_modify_message` (NOT `gmail_modify_email`), `gmail_batch_modify_messages`, `gmail_list_labels`, `gmail_batch_get_messages`. v1 burned 30k tokens guessing. | both v2 files | Eliminates 5–15 min of trial-and-error per run |
| 2 | **Use `gmail_batch_modify_messages` in Phase 5** to apply labels to up to ~1000 messages per call instead of one-by-one. | `scripts/backlog-triage-v2.py` apply subcommand | 80 min wall-clock → ~30 s; no token cost (Python-side) |
| 3 | **Add Phase 0 — probe & dump Klavis tool schemas**. Before any classification, call the Klavis tool discovery, dump the canonical names + parameter schemas to `data/backlog/tools-schema.json`. Phase 1+ reads from this file. | both | Removes the entire "agent figures out tool names" failure mode |
| 4 | **Use Anthropic Batch API + prompt caching for Phase 4** (the LLM tail). 50% discount on batch + cache discount stacks. For 1000 ambiguous emails, drops cost ~75% vs synchronous `claude -p` calls. | `scripts/backlog-triage-v2.py` (new optional `--use-batch-api` flag) | ~50–75% token savings on Phase 4 |
| 5 | **Use Claude tool-use with `input_schema`, NOT prose JSON output.** Force `tool_choice` to a single classifier tool. Eliminates parsing failures + reduces output tokens. | Phase 4 prompt | More reliable; fewer retries |

## Per sub-question findings

### Q1 — Klavis Gmail tool names (CRITICAL — load-bearing for tomorrow's run)

Klavis Strata uses **progressive discovery** — the actual tool names are not in their public docs (`klavis.ai/docs/mcp-server/gmail` redirects you to the runtime `get_tools` API). However, the **`hive-tools` MCP integration** reverse-engineered the standard Gmail MCP toolkit and lists exactly the tool names Klavis uses (the underlying Gmail-toolkit naming is consistent across MCP implementations):[^1]

```
gmail_list_messages          gmail_get_message            gmail_trash_message
gmail_modify_message         gmail_batch_modify_messages  gmail_batch_get_messages
gmail_create_draft           gmail_list_labels            gmail_create_label
gmail_reply_email            send_email
```

**Critical correction**: v1's agent called `mcp__klavis-gmail__gmail_modify_email`. The canonical name is `gmail_modify_message` (or `gmail_batch_modify_messages` for the batch variant). The v1 call DID succeed because Klavis silently accepted it — but `addedLabels` only returned `["UNREAD"]` (the system label that already exists), confirming the non-existent `_Agent/*` labels were dropped.

**Action for tomorrow**: in Phase 0, the agent calls `get_tools` (or `discover_server_categories` → `get_category_actions("GMAIL", "labels")` → `get_action_details`) and dumps the schemas to disk. From then on, every tool call uses the canonical name from that schema.

### Q2 — `gmail_batch_modify_messages` capabilities

The Gmail REST API exposes `users.messages.batchModify` which accepts up to 1000 message IDs per call.[^2] Klavis exposes this as `gmail_batch_modify_messages` (per the hive-tools registry).[^1]

Expected request shape (mirrors Gmail API):
```json
{
  "ids": ["msg_id_1", "msg_id_2", ...],   // up to ~1000
  "addLabelIds": ["Label_1234"],
  "removeLabelIds": []
}
```

Phase 5 currently iterates `gmail_modify_email` per message. **Replace with**: group messages by `(addLabelIds set)` (i.e., one bucket per group), then one `gmail_batch_modify_messages` call per group. For a 10k-email backlog with ~6 buckets, that's 6 batch calls (or ~10 if any bucket exceeds 1000).

If Klavis's exact tool name differs (`gmail_batch_modify` etc.), Phase 0 dump will reveal it.

### Q3 — Anthropic structured output for Phase 4

Two relevant features:

**Tool use with `input_schema` (CONFIRMED)**[^3][^4]: this is Anthropic's structured-output mechanism. Define a single tool whose `input_schema` is your JSON contract, and force `tool_choice` to that tool:

```python
classifier_tool = {
    "name": "classify_emails",
    "description": "Classify each email into one of 6 buckets.",
    "input_schema": {
        "type": "object",
        "properties": {
            "classifications": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "bucket": {"enum": [
                            "transactional", "personal", "newsletter",
                            "promotional", "spam-like", "actionable"
                        ]}
                    },
                    "required": ["id", "bucket"]
                }
            }
        },
        "required": ["classifications"]
    }
}
# Invoke with tool_choice = {"type": "tool", "name": "classify_emails"}
```

Output tokens: each classification is ~30 tokens with this schema (vs ~80 for prose JSON). For 50 messages: ~1.5k output tokens vs ~4k. Plus parsing is failure-proof.

**Prompt caching (CONFIRMED)**[^5]: tool definitions + system prompt are cached if you add `cache_control` to the last cacheable block. For a 50-batch run, the system+tools cache hit rate is ~98% after the first call. Cache reads are billed at 0.1× of input pricing.

**Batch API (CONFIRMED)**[^6]: 50% discount on all input + output tokens. Stacks with prompt caching. Trade-off: batches process within 24h (most finish in <1h). For our use case where the user is OK waiting overnight, this is the cheapest path.

**Combined cost example** for 1000 ambiguous emails in 20 batches of 50:
- Synchronous `claude -p` with no caching: ~120k tokens × full price
- Batch API + prompt caching: ~120k tokens × 0.5× × ~0.3 effective input rate ≈ **~85% cheaper**

### Q4 — Anti-patterns to avoid

From the v1 failure + best-practice patterns:

1. **Per-email LLM reasoning** — what killed v1. Either rules first, then LLM only on the tail; or batch many emails per LLM call.
2. **Silent label drop** — Gmail API accepts label names but only applies pre-existing ones. Always check `addedLabels` in the response equals what you requested. v2's apply subcommand does this.
3. **Loading the email body for classification** — body is 90% of the token cost per email and rarely needed for bucketing. Subject + sender + headers (`List-Unsubscribe`, Gmail's `CATEGORY_*` labels) is enough for ≥90% of cases.
4. **Hallucinated tool names** — agents will guess tool names that look plausible. The Phase 0 dump-to-disk is the structural fix.
5. **Trusting the agent's "I'll process this efficiently" thinking** — v1 spent 8m thinking about how to create labels via Bash that wasn't allowed. Pre-bake the steps into the script; agent's job is to call `python3 scripts/backlog-triage-v2.py <subcommand>`, not to redesign the pipeline mid-run.
6. **Untrusted email body in classifier prompt** — emails contain `<email_body_untrusted>` patterns. v2 classifies on metadata only (sender, subject, headers), so prompt injection from body text never reaches the LLM. Maintain this in v3 if body becomes input.

### Q5 — Open verifications for tomorrow's runtime

- Exact Klavis tool names (Phase 0 dump answers this).
- Exact response shape from Klavis tools (Phase 0 dump answers this for inputs; the agent should also dump one example response for `gmail_get_message` to confirm `extract_metadata` parses it correctly).
- Whether the user has the ANTHROPIC_API_KEY env set so the script can call the Batch API directly (vs spawning `claude -p` which uses the Max subscription and faces the same monthly cap that bit us today).

## Recommended additions to v2 files

### `scripts/backlog-triage-v2.py`

Add a `probe-tools` subcommand:

```python
def cmd_probe_tools(args, env):
    klavis = KlavisMCP(env["KLAVIS_GMAIL_MCP_URL"], env["KLAVIS_GMAIL_API_KEY"])
    klavis.initialize()
    tools = klavis.list_tools()
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(tools, indent=2))
    print(f"Wrote {len(tools)} tool schemas to {out}")
    # Print human summary
    for t in tools:
        print(f"  • {t['name']}")
```

Add a `--use-batch-modify` flag to `apply` that groups by `(addLabelIds set)` and uses `gmail_batch_modify_messages`. Keep one-by-one as fallback if the batch tool isn't in the schema dump.

Replace `gmail_modify_email` with `gmail_modify_message` in the one-by-one path.

### `prompts/backlog-triage-v2.md`

Insert a Phase 0 (before Phase 1):

```
Phase 0 — Probe Klavis tool schemas (≤500 tokens):
a. Run: `python3 scripts/backlog-triage-v2.py probe-tools --output data/backlog/tools-schema.json`.
b. Verify the dump contains entries for: gmail_create_label, gmail_modify_message, gmail_batch_modify_messages (or close variants), gmail_list_labels, gmail_search_emails (or gmail_list_messages), gmail_read_email (or gmail_get_message).
c. If any expected tool is missing, halt and report — the v2 plan needs that tool. (Klavis adds tools regularly; the absence indicates a config problem, not a Klavis-side issue.)
d. Tell me the canonical names you found.
```

In Phase 4, add the structured-output guidance:

```
Phase 4 — Claude classifier on ambiguous tail (≤5k tokens per batch, with caching):
... (existing steps) ...
The classification call MUST use Claude tool-use with input_schema, NOT prose JSON. Define one tool `classify_batch` with input_schema enforcing `[{id: string, bucket: enum}]`. Force tool_choice to this tool. Add cache_control to the system prompt to maximize cache hits across batches. If you have ANTHROPIC_API_KEY in .env, use the Batch API (50% discount). If not, use synchronous `claude -p` and accept full price.
```

## Sources

[^1]: Hive-tools MCP registry tool list (reverse-engineering of standard Gmail MCP toolkit). https://github.com/aden-hive/hive/issues/5316 — Tier 2, dated 2026-02
[^2]: Google Workspace Gmail API: `users.messages.batchModify`. https://developers.google.com/gmail/api/reference/rest/v1/users.messages/batchModify — Tier 1
[^3]: Anthropic Engineering: Advanced tool use. https://www.anthropic.com/engineering/advanced-tool-use — Tier 1
[^4]: Claude Console llms-full.txt — claude-api skill describes structured outputs via tool use. https://console.anthropic.com/llms-full.txt — Tier 1
[^5]: Anthropic prompt caching docs. https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching — Tier 1
[^6]: Anthropic Batch processing docs (50% discount, stacks with prompt caching). https://platform.anthropic.com/docs/en/build-with-claude/batch-processing — Tier 1
[^7]: Klavis Gmail integration docs (progressive discovery). https://klavis.ai/docs/mcp-server/gmail — Tier 1
