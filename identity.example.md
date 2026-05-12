# Personal Identity & Contact

> **Private (PII)**. Do NOT echo to logs, public scopes, MCP servers, or commit to any repo. Used for domain registrant contacts, billing forms, KYC fields, and identity-bearing automations across all Claude Code sessions.
>
> **To bootstrap on a new machine**: `cp identity.example.md identity.md` then fill in your real values. The real `identity.md` is gitignored.

## Identity

- **Full name**: <First Last>
- **First name**: <First>
- **Last name**: <Last>
- **Email (primary, pro)**: <you@example.com>
- **Phone (E.164 with dot separator)**: <+CC.NNNNNNNNNN>
- **Phone (display)**: <+CC NN NN NN NN NN>
- **Calendly**: <https://calendly.com/yourhandle/30min>

## Postal address

- **Address line 1**: <street + number>
- **City**: <city>
- **Region / Department**: <state or department>
- **Postal code**: <postal code>
- **Country**: <country>
- **Country code (ISO 2-letter)**: <FR | US | …>

## API mappings

### Cloudflare Registrar — `/accounts/{id}/registrar/registrations` body `contacts.registrant`

```json
{
  "email": "<you@example.com>",
  "phone": "<+CC.NNNNNNNNNN>",
  "postal_info": {
    "name": "<First Last>",
    "address": {
      "street": "<street + number>",
      "city": "<city>",
      "state": "<state>",
      "postal_code": "<postal code>",
      "country_code": "<FR>"
    }
  }
}
```

### Generic billing/checkout/KYC forms

- First name: `<First>`
- Last name: `<Last>`
- Email: `<you@example.com>`
- Phone: `<+CC NN NN NN NN NN>` (display) or `<+CCNNNNNNNNNN>` (no separator)
- Address line 1: `<street + number>`
- City: `<city>`
- Postal code: `<postal code>`
- Country: `<country>`

## Provenance

- **Created**: <YYYY-MM-DD>
- **Authoritative source**: this file. Update here if you move, change phone, or change email.
- **Loaded into Claude Code**: via `@identity.md` import in `~/.claude/CLAUDE.md`.
