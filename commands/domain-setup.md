# /domain-setup — Cloudflare Registrar + Koyeb peering, end-to-end

Register a domain through Cloudflare Registrar API, provision DNS pointing to a Koyeb app, attach it, and verify TLS — all in a single autonomous run.

## Usage

```
/domain-setup <domain> <koyeb-app>
/domain-setup victor-poiraud.com my-app
/domain-setup acmecorp.dev acmecorp-prod
```

If only a TLD or keyword is provided, the agent runs Phase A discovery first.

## Inputs (env or .env.local, gitignored)

- `CF_API_TOKEN` — must include scopes: `Account:Cloudflare Registrar:Edit`, `Zone:DNS:Edit`, `Zone:Zone:Read`. Zone Resources MUST be `Include all zones from an account` (without it, Zone permissions are silently ignored).
- `CF_ACCOUNT_ID` — 32-char hex, visible in any CF dashboard URL.
- `~/.claude/identity.md` — registrant contact (auto-loaded via `@identity.md` in user CLAUDE.md). Required for first-time registrations.

## Constraints (hard-learned)

1. **Cloudflare Registrar API beta supports only gTLDs** as of 2026-05. `.fr/.eu/.me/.io/.de/.it/.es` return `extension_not_supported` or `extension_not_supported_via_api`. Working: `.com/.net/.org/.dev/.app/.co/...`. For ccTLDs, register at OVH/Gandi and delegate NS to Cloudflare for DNS-only flow (not covered by this command).
2. **CNAME proxy state matters at two stages**:
   - **During Phase C/D (initial DNS + Koyeb verification)**: `proxied: false` is required so Koyeb's verification can see the CNAME pointing at its target (proxied records hide the underlying chain behind CF edge IPs).
   - **After Phase D ACTIVE**: switch to `proxied: true` IF you want HTTP→HTTPS auto-redirect (Koyeb's edge does NOT redirect HTTP→HTTPS — confirmed in `koyeb.com/docs/reference/edge-network`). Phase E below handles this. SSL mode must be `full` so CF can establish TLS to Koyeb origin.
3. **Apex domain via CNAME flattening** is supported by Cloudflare only — `CNAME @` resolves to A records publicly. Other DNS providers reject CNAME apex.
4. **Koyeb cname target is org-wide** (`<org-uuid>.cname.koyeb.app`), identical for every app on the same Koyeb account. Discoverable via `host -t CNAME <any-existing-custom-domain-on-account>` — no need to wait for `koyeb domains create` to learn it. This enables the **CNAME pre-post optimization** below.
5. **`dig` may not be installed** on Linux Debian-derivatives. Use `host -t CNAME <name>` instead.
6. **Phase B requires either** a default registrant contact configured in CF dashboard OR an inline `contacts.registrant` block in the body. The dashboard path triggers an account-wide UI form; the inline path is preferred for autonomous runs and uses `~/.claude/identity.md`.

## Workflow

### Phase A — Discovery

```bash
curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -X POST -d '{"domains":["<domain>","<alt1>","<alt2>"]}' \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/registrar/domain-check"
```

For each candidate: `registrable: true|false`, `pricing.registration_cost`, `pricing.renewal_cost` (USD, at-cost). If all return `extension_not_supported`, suggest gTLD pivot to user.

**Gate**: explicit user confirmation of `<domain>` + price before Phase B.

### Phase B — Registration (BILLABLE, irreversible)

Build body with inline registrant from `~/.claude/identity.md` (UTF-8 safe; write to `/tmp/cf-register-body.json` then `--data @file` to avoid shell quoting on accents):

```json
{
  "domain_name": "<domain>",
  "contacts": {
    "registrant": {
      "email": "<from identity.md>",
      "phone": "<+33.XXXXXXXXX>",
      "postal_info": {
        "name": "<Full Name>",
        "address": {
          "street": "<street>",
          "city": "<city>",
          "state": "<region>",
          "postal_code": "<zip>",
          "country_code": "<ISO-2>"
        }
      }
    }
  }
}
```

```bash
curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -X POST --data @/tmp/cf-register-body.json \
  "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/registrar/registrations"
shred -u /tmp/cf-register-body.json   # PII cleanup
```

Expect HTTP 201, `result.state=succeeded`, `result.completed=true`. CF auto-creates a DNS zone and saves the inline contact as default for future registrations on the account.

### Phase C — DNS provisioning (CNAME pre-post optimization)

```bash
ZONE_ID=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=<domain>" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['id'])")

KOYEB_TARGET=$(host -t CNAME <any-existing-koyeb-custom-domain> | awk '/alias for/{print $NF}' | sed 's/\.$//')
# fallback: extract from `koyeb domains list` of an existing entry, or from `koyeb domains create` first-call output

API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" -X POST \
  -d '{"type":"CNAME","name":"www","content":"'$KOYEB_TARGET'","ttl":1,"proxied":false}' "$API"
curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" -X POST \
  -d '{"type":"CNAME","name":"@","content":"'$KOYEB_TARGET'","ttl":1,"proxied":false}' "$API"
for ca in letsencrypt.org digicert.com comodoca.com pki.goog; do
  curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" -X POST \
    -d '{"type":"CAA","name":"@","data":{"flags":0,"tag":"issue","value":"'$ca'"},"ttl":1}' "$API"
done
```

Wait 30-60s for public DNS propagation, then `host <www.domain>` should chain through to Koyeb edge IPs.

### Phase D — Koyeb attach + TLS verify

```bash
koyeb domains create www.<domain> --attach-to <koyeb-app> -o json
koyeb domains create <domain> --attach-to <koyeb-app> -o json
# poll until ACTIVE (typical 15s when CNAME pre-posted, up to 5 min worst case)
while true; do
  STATE=$(koyeb domains list 2>&1 | grep "<domain>" | awk '{print $4}' | sort -u)
  echo "[poll] $STATE"
  [[ "$STATE" == "ACTIVE" ]] && break
  sleep 15
  koyeb domains refresh www.<domain>
  koyeb domains refresh <domain>
done
curl -sI https://<domain>/      # expect HTTP/2 200
curl -sI https://www.<domain>/  # expect HTTP/2 200
```

TLS cert is auto-issued by the CDN edge (CN=`<domain>`, Cloudflare ECC CA — Koyeb's free static-export tier routes through Cloudflare CDN, so the cert is CF's, not Let's Encrypt directly).

### Phase E — HTTP→HTTPS redirect via Cloudflare proxy (post-validation)

Koyeb's Edge Network does NOT redirect HTTP traffic to HTTPS for custom domains (the `.app` Koyeb subdomain works only because `.app` is on the HSTS preload list — a `.com/.net/...` custom domain serves HTTP plain by default). To get the canonical 301 redirect, route traffic through Cloudflare proxy:

```bash
# 1. Verify SSL mode is "full" (or set it)
curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl"
# expect: result.value = "full"  (if not, PATCH it)

# 2. Enable "Always Use HTTPS" on the zone
curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -X PATCH -d '{"value":"on"}' \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https"

# 3. Switch both CNAMEs from proxied:false → proxied:true
for record_id in "$WWW_ID" "$APEX_ID"; do
  curl -s -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    -X PATCH -d '{"proxied":true}' \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id"
done

# 4. Wait 20s, verify
sleep 20
curl -sI http://<domain>/   # expect: HTTP/1.1 301 + Location: https://<domain>/
curl -sI https://<domain>/  # expect: HTTP/2 200 + valid CF cert
```

**Order matters**: do Phase E AFTER Koyeb domain status reaches ACTIVE. If you proxy CNAMEs before Koyeb verification, Koyeb sees CF edge IPs instead of the expected CNAME target and validation fails or stays PENDING.

**Rollback**: if anything breaks (cert error, 521/522 from CF), revert with `proxied:false` and `always_use_https=off`. Site goes back to HTTP plain (no redirect) but still serves on HTTPS as before.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Agent registers domain without user OK | Phase A gate: surface exact price, require explicit confirmation. Inline contact also requires upstream PII consent. |
| Registrar API charges and fails | HTTP 4xx returns `success: false` BEFORE charging — verify `success: true` before treating as billed. |
| `proxied: true` breaks Koyeb TLS | Hard contract: all CNAMEs to Koyeb target are `proxied: false`. |
| Token edit didn't actually save | After any token modification, verify with `GET /zones/{id}/dns_records` returning success before retrying writes. Symptom of failed edit: `code 10000 Authentication error`. |
| `dig` not on PATH | Use `host -t CNAME` everywhere; this command never invokes `dig`. |
| Identity.md contains stale PII | Verify `~/.claude/identity.md` last-updated section before run; ask user to refresh if 6+ months old. |

## Idempotency

This command is **not** idempotent on Phase B (paying twice for the same registration is impossible — CF returns "already registered"). Phase C and D are idempotent: existing DNS records and Koyeb domain attachments will return 409/already-exists which is treated as success. Re-runs after partial failure should resume mid-pipeline rather than restarting.
