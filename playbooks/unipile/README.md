# Unipile — the messaging bridge between your social networks and your Claude agents

> Unipile is the unified messaging API that lets a Claude agent *receive* (webhooks) and *act* (send) across LinkedIn, WhatsApp, Telegram, and Gmail on Victor's behalf. One connected account per network, agent-native DX, GDPR-FR hosting. Validated GO 2026-06-07; credentials live 2026-06-30.

## What it is

- **Unified messaging API**: one HTTP surface + official SDKs over LinkedIn, WhatsApp, Telegram, Gmail/email, Instagram, X — a single integration instead of one per network.
- **Pricing**: 49€/mo flat for 1-10 connected accounts, unlimited API calls, 7-day trial without a card. One account = one linked identity (LinkedIn ≠ WhatsApp ≠ Gmail), billed on the peak number of linked accounts.
- **Vendor durability**: French company since 2020; official Node/TS v2 + Python v2 + PHP SDKs, active changelog. Not bus-factor-1.
- **Agent-native by design**: every doc page exposes `llms.txt` (Markdown index) + OpenAPI explicitly "for AI agents"; routes are testable interactively without writing code.

## The bridge pattern (how an agent uses it)

Two directions, one model — this is the whole point of the tool:

| Direction | Mechanism | Methods / events |
|---|---|---|
| **Act** (agent → network) | SDK / REST call | `sendInvitation`, `startNewChat` (DM / InMail), send message |
| **Receive** (network → agent) | Webhook (push) | `new_relation` (invite accepted), `new_message` (reply / inbound) |

Never poll on a fixed schedule — Unipile's own docs flag fixed-interval polling as automation-detectable. The webhook is the receive channel.

## Auth & account model

- **API auth**: header `X-API-KEY: {token}`, base URL = your DSN. SDK: `new UnipileClient(UNIPILE_DSN, UNIPILE_API_TOKEN)`.
- **Connect a network account via Hosted-Auth** (dashboard) — the session credential (e.g. LinkedIn's `li_at` cookie) never transits the agent or the chat. Copy the returned `account_id`.
- Every send/receive call is scoped to an `account_id` — that's which identity acts.

## Credentials (zero live secrets in this repo)

Canonical values live in the gitignored brain store, never here:

`~/second-brain/.secrets/unipile.env` — mode 600, `.secrets/` gitignored.

```bash
UNIPILE_DSN          # base URL of your instance (dashboard, e.g. https://apiXXX.unipile.com:XXXXX)
UNIPILE_API_TOKEN    # access token — header X-API-KEY. Rotate immediately if leaked.
UNIPILE_ACCOUNT_ID   # connected-identity id, from a Hosted-Auth connect
# WEBHOOK_SECRET     # shared secret for inbound webhooks (openssl rand -hex 24) — fill when wiring receive
```

Provision / rotate: Unipile dashboard > API (token), Hosted-Auth reconnect (`account_id`). Secret in env, never the chat — a pasted token is a burned token (rotate it).

## Guardrails (the one rule that generalizes)

**Unipile relays each platform's rate-limits but never lifts them — cadence is always the agent's responsibility.** Per-network specifics:

- **LinkedIn** (highest risk): driven via the `li_at` session cookie, so Unipile is a technical intermediary, *not* a LinkedIn partner → ban-risk is non-zero, identical to any sending tool. Safety comes from cadence + personalization, not the tool. Sustainable ceiling ~20-30 invitations/day (~100/week), blank invitation notes, lexical rotation of the body, 2-3 week warmup, accept-rate >30%. No sending loop is zero-ban.
- **GDPR gate before connecting any real account**: Unipile is the GDPR gold standard — Scaleway France exclusive hosting, SOC2 Type II + CASA Tier 2, no extra-EU transfer, DPA Art. 28 signable, ≤30-day deletion on termination. Obtain the signed DPA + proxy-provider locations before connecting a production account.

## Worked example — LinkedIn outreach (If-Connection loop)

Reference implementation (live, account connected as of 2026-06-30):
`~/Desktop/AgenceIA/outbound/freelance_devsecops/outreach/scripts/unipile-outreach/`
Operational doctrine: that project's `.claude/rules/outreach-tooling.md` + `docs/unipile_integration.md`.

The loop: parse leads → `getProfile` reads connection degree → 1st-degree routes to a direct-DM lane, non-connected to a blank invitation → webhook `new_relation` detects acceptance → DM drafted, human-approved (hybrid autonomy) → webhook `new_message` pauses the sequence on a reply. Sends are triple-gated (`ALLOW_SEND=I_UNDERSTAND` + score≠BLOCK + draft approval).

> Live-state note (2026-06-30): the project's older docs say "never connected", but the credentials are provisioned and the send-gate is armed. Treat the integration as live.

## Planned second use — second-brain ingestion notifications

The `_inbox` → ingest pipeline (Linear AI-171) will notify Victor via Unipile (WhatsApp / Telegram) when a note is ingested — same bridge, act-only (outbound notification). Brain-side note: `~/second-brain/50-stack/unipile.md`.

## Validation & freshness

GO verdict + ~19 graded sources: [research-report.md](research-report.md) (deep-research, 2026-06-07), with [research-sources.json](research-sources.json) / [research-evidence.json](research-evidence.json). Re-validate with `/deep-research` if more than 4 weeks stale — cadence numbers and LinkedIn limits drift.
