# Design — `dotclaude` → public flagship repo

- **Date:** 2026-06-25
- **Linear:** AI-213 (Interne / Agence · 🤖 IA / Dev · High · 8pt · In Progress)
- **Status:** approved design, pre-plan
- **Owner:** Victor (human) · executed by agent (delegation ≠ ownership)

> Leak tokens are referenced by **category** throughout (e.g. "the NDA client name") and never written literally, because this spec ships publicly. The exact `filter-repo` replacement strings are generated into a gitignored scratchpad file at WS6 execution time — never committed.

## 1. Problem

`~/.claude` (`dotclaude`) will be made **public** on GitHub as a flagship on Victor's profile, so that leads and senior peers conclude "confirmed AI engineer" from the **documentation** alone (most won't read config internals). Publishing is a **one-way door**: anything in the tracked set *or git history* becomes permanently public.

## 2. Audit summary

Method: 4 parallel adversarial reviewers (privacy/secret-leak · front-door docs · doctrine depth · tooling surface) + independent verification of the 3 load-bearing facts.

**Verdict: substance is genuinely senior-grade (depth scored 7.5–8/10), but DO NOT publish as-is.** The blocker is the private→public transition discipline gap, not quality. The engineering story (eval-first, adversarial RPI review trio, Citation-Grounding with auto-downgrade, defense-in-depth gates, a TDD'd secret-scan gate at 16/16 green) is legible from the docs and reads as a confirmed AI engineer — not AI slop.

**Verified facts:**
- ✅ Top-tier PII (phone all formats, postal address, both emails) clean in working tree **and all 35 commits** (`git log -S` → 0). The `.example` + `.gitignore` discipline held.
- ❌ Leak-by-reference in history: NDA client name, a prospect name, the Calendly handle, and a PostHog key prefix each appear in 1 past commit → working-tree edit insufficient, history rewrite required.
- ❌ 27 tracked symlinks, all → a private local path (dead on clone + leak local layout).
- ❌ Advertised `voice-check` PostToolUse hook is **not wired** in `settings.json` (0 matches) — doctrine-vs-reality drift.

## 3. Decisions locked (via AskUserQuestion, 2026-06-25)

1. **Scope:** full flagship in one pass — all P0 + all P1 elevation + stale-playbook refresh, *before* publish.
2. **FR-B2B inline skills** (voice-check, deck-generator, humanize-fr, linkedin-post): **exclude** from the public repo (gitignore + filter from history). Off-message for an AI-engineering flagship and the largest confidentiality surface. Side benefit: dissolves the "4-of-5 skills aren't eval-first" finding, since the remaining inline skill (`no-loss`) already has evals.
3. **Git history:** `git filter-repo` surgical scrub, **preserving** conventional-commit + AI-NNN history (a discipline signal). Force-push to a fresh/clean remote.
4. **Symlinks:** `git rm` them; `bootstrap.sh` recreates externals from `skills.manifest.toml` + `EXTERNAL.md` at install.

**Standing assumptions (owner-approved):**
- Keep `victor-poiraud.com` (deliberate profile→repo→site loop); genericize only the Koyeb **app name**.
- Keep `rules/linear-pm.md` + `research/ai-1NN/` as a disciplined-PM showcase — scrub the client name only; keep AI-NNN refs as traceability.
- Promote the two `docs/superpowers/specs/*.md` RPI specs to *featured worked examples* (link from README); do not hide.
- Never touch the gitignored real `identity.md` / `profile.md` / `.env` (verified clean & untracked).

## 4. Architecture of the change

The change is a **pipeline over the repo**, gated by ordering. The load-bearing constraint: `git filter-repo` rewrites every commit hash, so **WS6 must run last** — any normal commit after it would be orphaned and the scrub re-done. The exclusion set (WS1) defines the `--path` filters WS6 needs. Everything before the final force-push is reversible; the force-push is the only true one-way door.

```
WS1 scrub ─┐
WS2 portability ─┤
WS3 correctness ─┼─ (normal commits on working tree, any order among themselves)
WS4 elevation ─┤
WS5 playbook refresh ─┘
                     │ gate: leak-grep + fresh-clone smoke test both green
                     ▼
WS6 history rewrite + publish  (irreversible)
```

## 5. Workstreams

### WS1 — Confidentiality scrub (working tree) · GATE: leak-grep clean
- Exclude 4 FR-B2B inline skills: add to `.gitignore`, `git rm -r --cached skills/{voice-check,deck-generator,humanize-fr,linkedin-post}`.
- Scrub every reference to those skills in **public tracked docs**: `CLAUDE.md` (Search/Doc/Scrape/Code-gen routing tables + voice/FR-B2B mentions), `rules/agentic-loops.md` (locked-set `voice-check` row), `README.md` (inline-skills list), `profile.md` is gitignored (no action), any `best-practice/*` references.
- Replace the **NDA client name** with a generic placeholder in `rules/linear-pm.md:44` and any `research/ai-184-*` artifacts that reproduce the project list.
- Scrub the **PostHog key prefix** → `phx_…` in `CHANGELOG.md` and `SECURITY.md` (confirm the key was rotated; if not, flag to Victor).
- `deep-research/experts.yaml`: gitignore + `git rm --cached` (its own header says "PRIVATE — never commit"); optionally ship `experts.example.yaml`. Same check for `deep-research/mbfc-overlay.json` (document or ignore).
- Genericize the Koyeb **app name** in `commands/domain-setup.md` + `CLAUDE.md` (keep the domain).
- **Gate (must pass before WS6):** re-run the verification grep (read real PII from gitignored originals → grep tracked set) → zero hits in working tree.

### WS2 — Clone portability · GATE: fresh-clone smoke test
- `git rm` all 27 symlinks under `skills/` + `agents/anti-patterns.md`. Add a `.gitignore` rule so they aren't re-added.
- Update `bootstrap.sh`: recreate external skills/agents from `skills.manifest.toml` + `skills/EXTERNAL.md` + `agents/EXTERNAL.md` at install (clone upstreams to an XDG path, then symlink — or document the manual path). Keep it `set -euo pipefail`, idempotent, offline-tolerant.
- Fix the 5 hardcoded absolute `$HOME/.claude/...` hook paths in `settings.json` → `${CLAUDE_PROJECT_DIR:-$HOME/.claude}/hooks/...` (match the dispatcher convention already used).
- Verify `CLAUDE.md`'s `@identity.md`/`@profile.md`/`@RTK.md` imports resolve on a fresh clone (bootstrap seeds `identity.md`/`profile.md` from `.example`).
- **Gate:** `git clone` into a temp dir → no dangling symlinks, no dead links, hooks resolve, `bootstrap.sh` runs green, `scripts/audit-config.sh` passes.

### WS3 — Correctness & doctrine-vs-reality
- Kill "the repo is private" ×3 (`SECURITY.md:3,127`, `README.md:325`) → public posture; replace SECURITY disclosure path with GitHub Security Advisories (private vuln reporting).
- Fix broken README links: `workflows/rpi/feature-template/` (track the files or drop the link); claude-init link → public repo URL (not the symlinked path).
- Reconcile **all counts**: rules 8→11 (+ add missing rows: ai-engineering, code-generation, agentic-loops, linear-pm), inline-skills list (post-exclusion truth), playbooks (5, surface scrapling + context7), best-practice count, agents arithmetic. Document the "CLAUDE.md-trigger rules (no `paths:` by design)" exception in `best-practice/claude-rules.md` + README.
- Reconcile MCP-server count drift (CLAUDE.md = 5; secondary docs say 3) across `README.md`, `best-practice/claude-mcp.md`, `docs/PORTABILITY.md`, `CHANGELOG.md`.
- `CHANGELOG.md`: merge the two `[Unreleased]` sections into one; add a public-release entry.
- Fix dead cross-ref `crystalline-snacking-lighthouse.md` in `rules/git-commit-discipline.md`; soften the hardcoded model version in the co-author trailer.
- Resolve voice-check-hook drift — now by **removal** (skill excluded), so drop/adjust the `agentic-loops.md` locked-set row.
- Fix shipping RPI agents/commands: single `eng.md` author (engineer, not CTO); correct CTO phase wiring; add an RPI command sub-table to `CLAUDE.md`; `pdf-design-evaluator` missing `vertical-rhythm.md` ref + declare `Write` tool; `documentation-analyst-writer` Bash-tool gap; normalize agent frontmatter `tools:` dialect.

### WS4 — Flagship elevation
- `README.md`: add a **Highlights box** under the thesis (RPI trio · Citation auto-downgrade · executable drift gate · 27-event hooks · secrets posture); add **Mermaid** diagrams (RPI pipeline + config-layer hierarchy); add **badges** (MIT · shellcheck · Claude Code); surface `docs/ARCHITECTURE.md`, `docs/PORTABILITY.md`, and the two RPI worked-example specs; sharpen "confirmed AI engineer" positioning.
- Add `CONTRIBUTING.md` (short: personal config, MIT, run `scripts/audit-config.sh` before pushing).
- Add `.github/` (issue + PR templates + Security Advisory config).
- Optional: a terminal cast (asciinema/screenshot) of the 5-stage `bootstrap.sh` run.

### WS5 — Stale-playbook refresh
- `/deep-research` refresh: `claude-code-koyeb-channels` (04-29), `klavis-mcp` (04-30), `scrapling` (05-20), `context7` (05-28 borderline). Bump validation dates in `playbooks/README.md` + the repo README playbook table.

### WS6 — History rewrite + publish · LAST, IRREVERSIBLE
- Generate a `--replace-text` patterns file **in scratchpad** (gitignored, never committed) covering: NDA client name (both spellings), Calendly handle, prospect name, the voice-check confidential tokens (competitors/pricing/governance date/infra), PostHog key prefix.
- `git filter-repo --replace-text <scratchpad-file>` + `--path` removal of the 4 excluded skills from history.
- **Gate:** re-run `git log -S` for every PII/NDA token → all 0 commits.
- Fresh remote / force-push; set repo topics (`claude-code`, `dotfiles`, `ai-engineering`, `agentic-workflows`, `mcp`, `llm`, `prompt-engineering`), description, `homepageUrl` = victor-poiraud.com; flip public; verify links render on GitHub web; **final fresh-clone smoke test** on the public URL.

## 6. Risks & rollback

| Risk | Mitigation |
|---|---|
| filter-repo run before other commits → orphaned work | Hard ordering: WS6 last; CI-style checklist gate |
| Missed leak token in patterns file | Patterns file derived from the verified audit list; re-run full leak-grep as the WS6 gate |
| Force-push to existing remote loses collaborators' refs | Solo repo; publish to a fresh/clean remote, keep the private origin until verified |
| Excluding a skill breaks a doc reference | WS1 scrubs refs; WS3 reconciles counts; `scripts/audit-config.sh` + fresh-clone smoke test catch dangles |
| PostHog key not actually rotated | WS1 flags to Victor before scrubbing the narrative |

Reversible until the WS6 force-push. Keep the private origin untouched until the public clone passes its smoke test.

## 7. Acceptance criteria / DoD

- `git log -S` for every PII/NDA token → **0 commits**.
- Fresh `git clone` → no broken symlinks, no dead README links, hooks resolve, `bootstrap.sh` + `audit-config.sh` green.
- README: public posture, accurate counts, ≥1 Mermaid diagram, Highlights box, badges; ARCHITECTURE/PORTABILITY/RPI-specs linked.
- All P0 audit findings closed; P1 elevation shipped.
- Repo public with topics/description/homepageUrl set; **Victor confirms before AI-213 → Done**.

## 8. Out of scope (YAGNI)

- CODE_OF_CONDUCT.md (cargo-cult for personal dotfiles).
- Squash/fresh-init history (rejected in favor of preserving commit discipline).
- Redacting the FR-B2B skills to keep them public (rejected: excluded instead).
- Genericizing the public domain or the local `user` username (low-sensitivity, kept).
