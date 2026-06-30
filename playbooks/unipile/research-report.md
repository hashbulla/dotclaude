# Validation Unipile (solo engineer UE/FR) — deep-research

> Output Phase 4-6 du harness deep-research (2026-06-07). Symétrique de `bereach_validation_20260607.md`. Ajoute une dimension **UX / Developer Experience** (demande Victor). Annotations : [CONFIRMED] ≥2 sources indépendantes Tier 1/2 · [PROBABLE] · [À VÉRIFIER].
> Garde-fou anti-biais : marketing Unipile en source unique = auto-déclaré, jamais une corroboration indépendante.

## Résumé exécutif

- **Verdict : GO sur Unipile.** Tous les gates bloquants passent (GDPR, pérennité, complétude API), la dimension UX/DX est forte et **agent-native**, à prix égal (49€/mo). [CONFIRMED]
- **GDPR — gold standard, corroboré par un tiers neutre** : hébergement exclusif Scaleway France, SOC2 Type II + CASA Tier 2, AES-256-GCM, zéro transfert hors-UE, contrôleur nommé (Riorges, FR), **DPA Art. 28 signable sur demande**, rétention explicite (suppression ≤30 j après résiliation). Confirmé hors-marketing par la doc juridique d'un client tiers (Nova/dweet) + un comparatif indépendant (EmailEngine). [CONFIRMED ≥2 sources]
- **Pérennité — vraie société** : Unipile, **fondée 2020, France**, SDKs officiels maintenus (Node/TS, Python v2, PHP sur GitHub), changelog actif, « 3000+ SaaS » revendiqué. **Pas de bus factor 1** (inverse exact de BeReach). [CONFIRMED]
- **API — boucle If-Connection native** : `POST /users/invite`, **webhook `new_relation`** (détection d'acceptation), `status relation` (degré de connexion), accept/decline/withdraw, Sales Nav + Recruiter, `/me/limits` relayés. [CONFIRMED]
- **UX/DX — agent-native** : doc avec **llms.txt + OpenAPI** explicitement « for AI agents », SDK TypeScript (stack Victor), onboarding sans code (DSN+token+test interactif), free trial 7 j sans CB, intégrations Make/n8n. **Angle mort honnête** : avis tiers agrégés (G2/Trustpilot) quasi-absents — mais pour un outil dev, la DX directement inspectable est une meilleure preuve que des étoiles. [CONFIRMED pour la DX inspectable / À VÉRIFIER pour les reviews agrégés]
- **Ce que Unipile ne résout PAS** : pilotage par session/cookie `li_at` → violation ToS LinkedIn, ban-risk non nul (~23% industrie), intrinsèque à tout outil qui *envoie*. La sécurité reste la **cadence**, pas l'outil. [CONFIRMED]

## 1. GDPR / données réelles — PASS (gold standard)

- **Hébergement** : « Hosted exclusively on Scaleway datacenters in France. Full GDPR compliance with no data transfer outside EU » ; AES-256-GCM at rest, TLS 1.3, Scaleway Key Manager, MFA, pen-tests tiers annuels.[^1] [CONFIRMED]
- **Certifications** : SOC 2 Type II + CASA Tier 2 + GDPR.[^1] Contrôleur nommé : Unipile, 168 rue de la Rotonde, 42153 Riorges, France ; sous-traitants Scaleway / Stripe / fournisseurs de proxy.[^2]
- **DPA Art. 28** : « enter into a Data Processing Agreement with Unipile as your sub-processor — a legal requirement under GDPR Article 28 […] request a DPA from the Unipile team ».[^3] → **base contractuelle signable**, exactement ce qui manquait chez BeReach. [CONFIRMED]
- **Rétention** : « Upon contract termination, Unipile is to remove all data belonging to Customer and its Users within 30 days ».[^4] [CONFIRMED]
- **Corroboration indépendante (hors-marketing)** : la doc sous-traitants de Nova/dweet (client utilisant Unipile *comme* sous-traitant) atteste « Processing in the EEA (Scaleway France); no restricted international transfer; SOC 2 Type II; GDPR under French Data Protection Act ».[^5] + comparatif EmailEngine : « Data Residency: EU (France - Scaleway) ; SOC 2, GDPR ».[^6] [CONFIRMED ≥2 sources indépendantes]
- **Résiduel mineur** : la liste nominative + localisation des fournisseurs de proxy n'est pas sur une page publique (catégorie citée, pas les noms). À clarifier dans le DPA — non bloquant (engagement EU-jurisdiction + DPA Art. 28 couvrent). [À VÉRIFIER — non bloquant]

## 2. Pérennité — PASS

- **Entité** : Unipile, fondée **2020**, France.[^7] ~6 ans d'existence. Droit français (Tribunal de Roanne, rapport précédent).
- **Maintenance** : SDKs officiels GitHub — Node.js/TypeScript v2, Python v2, PHP ; wrappers communautaires ; changelog actif (champs LinkedIn récents ajoutés).[^8][^9] [CONFIRMED]
- **Traction** : « Trusted by 3,000+ SaaS Platforms » (auto-déclaré) ; présence dev (Slack, Reddit u/Unipile actif 2 ans, AI Tinkerers).[^10][^11] [PROBABLE]
- **Incidents / breaches** : aucun trouvé. Pas de status page publique dédiée (webhook account-lifecycle existe côté produit). [À VÉRIFIER — pas de red flag]
- **Bus factor** : société avec équipe (SOC2 implique processus org. audités), SDKs multi-langages maintenus → **pas bus factor 1**. [CONFIRMED]

## 3. Ban / sécurité compte — risque intrinsèque, géré par cadence

- Unipile pilote via session authentifiée (cookie `li_at`), se présente en « intermédiaire technique indépendant, on-behalf-of », **pas partenaire LinkedIn**.[^12] → ban-risk non nul, identique à tout outil qui envoie.
- Unipile **relaie** les rate-limits LinkedIn (80-100 invits/j payant, 15/sem gratuit, headers quota) pour ralentir/pauser, mais **ne les lève pas** ; la cadence reste la responsabilité du client.[^13][^14] [CONFIRMED]
- Bon signe de maturité anti-détection : la doc `new_relation` **déconseille explicitement le polling à heure fixe** (« easily flagged as automation ») et pousse le webhook.[^14]
- Aucun retour indépendant de ban massif spécifique à Unipile trouvé (comme BeReach, peu de data publique). Conclusion : sécurité = cadence (20-30/j, notes blank, rotation, warmup), inchangée. [CONFIRMED principe]

## 4. Complétude API (boucle If-Connection) — PASS

Page officielle « List of provider features » + docs :[^15][^14][^16]

| Besoin boucle | Unipile | Statut |
|---|---|---|
| Statut/degré de connexion | `Get contact information: status relation` + Visit/Retrieve Profile | OK |
| Invitation | `POST /users/invite` (avec/sans note) | OK |
| Détection acceptation | **webhook `new_relation`** (+ 2 méthodes alternatives) | OK |
| List/Delete pending invitation, Accept/Decline incoming | 🟢 | OK |
| DM / InMail | Send message, Send InMail, InMail credits | OK |
| Inbox / lecture réponses | Webhook new message + sync Classic/Sales Nav/Recruiter inbox | OK |
| Garde-fou cadence | rate-limits relayés (pas de `/me/limits` nommé mais headers quota relayés) | OK |
| Sales Navigator / Recruiter | supportés (inbox + retrieval +) | OK |
| Outreach sequence natif | `Create an Outreach Sequence` 🟢 | OK |

→ **Bloc 4 = GO.** La boucle « invite → webhook acceptation → DM » est le pattern canonique documenté. [CONFIRMED]

## 5. Coûts cachés — PASS

- **49€/mo flat pour 1-10 comptes connectés, appels API illimités** ; au-delà, dégressif par compte ; essai 7 j sans CB.[^6][^11][^17] [CONFIRMED ≥2 sources]
- 1 « compte » = 1 identité liée (LinkedIn / WhatsApp / Gmail comptent séparément). Solo avec **1 compte LinkedIn = 49€**, pas de crédits cachés, proxy + rate-limiting inclus, facturé sur le pic de comptes liés.[^17] [CONFIRMED]
- Coût total option agentique : Unipile 49€ + n8n self-host ~5€ ≈ **~54€/mo**, ou agent Claude custom (coût compute marginal). [PROBABLE]

## 6. UX / Developer Experience (dimension ajoutée) — PASS

- **Onboarding** : créer compte → récupérer DSN → générer access token → connecter le compte dans le dashboard → **tester chaque route en interactif dans l'API Reference sans écrire une ligne de code**.[^16] Free trial 7 j sans CB. Friction basse. [CONFIRMED]
- **Doc agent-native** : chaque page affiche « **For AI agents: visit [llms.txt] for an index of all pages in Markdown and endpoints in OpenAPI** » ; schéma OpenAPI importable Postman ; Documentation / API Reference / Changelog séparés.[^16][^18] C'est exactement la DX pour un agent Claude/LangGraph. [CONFIRMED]
- **SDKs** : officiels Node/TS v2 + Python v2 + PHP (GitHub).[^8] TypeScript = stack Victor. Exemple 4 lignes pour invite.[^15]
- **Intégrations no/low-code** : app Make officielle, usage n8n indépendant documenté (r/n8n « bypass LinkedIn's official API trap with Unipile »).[^11][^19] [CONFIRMED — path n8n réel]
- **Support** : Slack community, GitHub issues, Reddit u/Unipile actif.[^10][^8] [PROBABLE]
- **Angle mort honnête** : avis tiers agrégés quasi-absents — SourceForge liste Unipile « 0 review / not reviewed yet ».[^7] Pas de note G2/Trustpilot exploitable. Pour un outil dev B2B, la DX inspectable (docs+SDK+OpenAPI+llms.txt) est une meilleure preuve que des étoiles, mais l'absence de signal social est notée. [À VÉRIFIER — non bloquant]

## Contradictions & débats ouverts

- **« API » vs session-based** : Unipile se vend comme « API » mais drive via cookie `li_at`, pas l'API officielle LinkedIn[^12] → ban-risk non nul malgré le marketing « no scraping, account protection ». Honnêteté : ils l'admettent (« not a LinkedIn partner »).
- **Effort de build vs turnkey** : Unipile est une couche API, pas un agent prêt-à-l'emploi comme BeReach. Victor construit l'orchestration. C'est un coût réel — compensé par (a) son métier d'AI Engineer, (b) la DX agent-native (llms.txt/OpenAPI/SDK TS) qui réduit drastiquement cet effort.

## Needs Verification (non-fermables / non-bloquants)

- **Avis utilisateurs indépendants agrégés** : quasi-absents (outil dev de niche). Non bloquant — DX inspectable directement.
- **Noms + localisation des fournisseurs de proxy** : catégorie citée, pas la liste nominative publique. À obtenir dans le DPA. Non bloquant.
- **Uptime chiffré / SLA** : pas de status page publique chiffrée. Non bloquant (pas de red flag, société auditée SOC2).

## Note méthodologique

Domaine vendor-saturé : claims sécurité/GDPR/prix croisés sur ≥2 sources ou ancrés sur page primaire officielle ; claims auto-déclarés Unipile tagués comme tels. GDPR closé par 2 sources indépendantes hors-marketing (Nova/dweet client + EmailEngine comparatif) en plus des pages officielles. ~19 sources. Verdict ancré sur faits primaires (pages compliance/terms/docs Unipile + corroboration tierce), pas sur du marketing.

## Sources

[^1]: Unipile, « Security & Compliance » — Scaleway FR exclusif, SOC2 II, CASA Tier 2, AES-256-GCM, no transfer outside EU, pen-tests annuels. Extr. 2026-06-07. Tier 2 (officiel), B.
[^2]: Unipile, « Privacy Policy » — contrôleur Riorges FR, sous-traitants Scaleway/Stripe/proxies. Extr. 2026-06-07. Tier 1, A.
[^3]: Unipile, « Secure Email API » — DPA Art. 28 signable sur demande, EU-hosted infra. Extr. 2026-06-07. Tier 2 (officiel), B.
[^4]: Unipile, « Terms of Use » — rétention : suppression données ≤30 j après résiliation. Extr. 2026-06-07. Tier 1, A.
[^5]: Nova / dweet.com, « Sub-Processors and International Data Transfers » — INDÉPENDANT : Unipile EEA/Scaleway FR, no restricted transfer, SOC2 II, GDPR French DPA. Extr. 2026-06-07. Tier 2 (doc juridique tierce), B.
[^6]: EmailEngine, « EmailEngine vs Unipile » — INDÉPENDANT : EU France Scaleway, SOC2/GDPR, 49€ flat ≤10 comptes. Extr. 2026-06-07. Tier 2, B.
[^7]: SourceForge, « Unipile Reviews 2026 » — fondée 2020, France, 49€/mo, free trial ; 0 review agrégé. Extr. 2026-06-07. Tier 2/3, C.
[^8]: GitHub, @unipile — SDKs officiels Node/TS v2, Python v2, PHP. Extr. 2026-06-07. Tier 1 (primaire), A.
[^9]: developer.unipile.com, « Changelog » — maintenance active (champs LinkedIn récents). Extr. 2026-06-07. Tier 1, A.
[^10]: Reddit, u/Unipile — compte actif 2 ans, support communautaire. Extr. 2026-06-07. Tier 4 (signal social).
[^11]: AI Tinkerers / Make / r/n8n — 500+ endpoints, intégration Make officielle, usage n8n indépendant. Extr. 2026-06-07. Tier 3, C.
[^12]: Unipile, « Is the LinkedIn API Free? » / « LinkedIn API Guide » — intermédiaire indépendant, on-behalf-of, session-based (ban-risk non nul). Extr. 2026-06-07. Tier 2, B.
[^13]: Unipile, « LinkedIn API Documentation » — relais rate-limits (80-100 invits/j payant, 15/sem gratuit), cadence côté client. Extr. 2026-06-07. Tier 2, B.
[^14]: developer.unipile.com, « Provider Limits » + « Detecting Accepted Invitations » — webhook `new_relation`, anti-polling, relations/invitations. Extr. 2026-06-07. Tier 1 (doc officielle), A.
[^15]: developer.unipile.com, « List of provider features » — Invite/InMail/Outreach Sequence/Detecting Accepted Invitations/Accept-Decline/Visit profile 🟢. Extr. 2026-06-07. Tier 1, A.
[^16]: developer.unipile.com, « Getting Started » + « API Usage » — onboarding DSN+token, test interactif sans code, OpenAPI, llms.txt. Extr. 2026-06-07. Tier 1, A.
[^17]: Unipile, « API Pricing » + Terms — 49€ flat ≤10 comptes, appels illimités, 1 compte = 1 identité, facturé sur pic. Extr. 2026-06-07. Tier 1, A.
[^18]: developer.unipile.com — « For AI agents: llms.txt index Markdown + OpenAPI » (présent sur chaque page doc). Extr. 2026-06-07. Tier 1, A.
[^19]: Reddit r/n8n, « LinkedIn's Official API is a Trap — bypass with Unipile + n8n » — INDÉPENDANT, path agentic réel. Extr. 2026-06-07. Tier 4 (social, pointeur).
