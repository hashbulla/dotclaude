# Changelog

All notable changes to dotclaude are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] — 2026-05-12

The genesis commit. dotclaude scaffolding lifted from a working `~/.claude/` and shaped into a portable, versionable, senior-AI-engineer-grade repo. Inspired by [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice).

### Added

#### Configuration

- `settings.json` rewritten: 27 hook events wired, `${POSTHOG_API_KEY}` env interpolation, `outputStyle: Explanatory`, peer-engineer `spinnerVerbs`, `respectGitignore: true`, `skipDangerousModePermissionPrompt`, `agentPushNotifEnabled`, `enableAllProjectMcpServers`.
- `settings.example.local.json` template for per-machine overrides.
- `.env.example` template + `.env.local` (gitignored) for secret env vars.
- `.gitignore` aggressive: 23 runtime / cache / ephemera directories + secret patterns + stale backups.

#### Identity (split for context-budget reasons)

- `identity.example.md` — PII template (postal address, phone, registrar JSON, generic billing fields).
- `profile.example.md` — professional persona template (role, expertise, working style, decision priorities, current focus).
- `identity.md` + `profile.md` ship gitignored; bootstrap seeds from templates.
- `CLAUDE.md` extended to `@-import` both via the same shallow-import pattern as `@RTK.md`.

#### Subagents (10 RPI + extras)

- `requirement-parser` (haiku) — parses prose into structured `REQUEST.md` with `needs_deep_research` / `risk_level` / `reversibility` flags.
- `product-manager` (sonnet) — user stories, G/W/T acceptance criteria, success metrics with targets and baselines, non-goals expanded.
- `technical-cto-advisor` (opus) — architecture trade-offs (≥2 alternatives), risk register, "what changes the answer" section.
- `ux-designer` (sonnet) — flows, state coverage matrix, error catalogue, microcopy, WCAG accessibility. Routes to `impeccable` / `critique` / `harden` skills.
- `senior-software-engineer` (opus, `maxTurns: 20`) — pragmatic IC; reversible slices; orchestrates reviewer trio.
- `code-reviewer` (opus, `isolation: worktree`) — adversarial correctness review. Citation Grounding on P0/P1.
- `security-reviewer` (opus, `isolation: worktree`) — OWASP top-10 + LLM-specific (prompt injection, tool abuse, supply chain). Citation Grounding on P0/P1.
- `constitutional-validator` (sonnet) — adherence to CLAUDE.md + rules + non-goals. Citations point inward at the project's own files.
- `performance-analyst` (opus) — on-demand. Measure first, recommend after.
- `documentation-analyst-writer` (sonnet) — aggregator + Citation Grounding enforcer (downgrades uncited P0/P1 to P2, logs downgrades).
- `agents/EXTERNAL.md` — catalog of symlinked-out agents (currently `anti-patterns.md` ← `pbakaus/impeccable`).

#### Slash commands (RPI)

- `/rpi:request` (haiku) — interview + write `REQUEST.md`.
- `/rpi:research` (opus) — conditional `/deep-research` gate, parallel agent contributions, GO/NO-GO verdict.
- `/rpi:plan` (opus) — parallel `pm.md` / `ux.md` / `eng.md` from three agents, assembler produces `PLAN.md`.
- `/rpi:implement` (opus) — per-slice: implement → reviewer trio (parallel, worktree-isolated) → on-demand perf → consolidation. Citation Grounding enforced.

#### Rules (8 lazy-loaded with `paths:` frontmatter)

- `markdown-docs.md` — documentation style.
- `git-commit-discipline.md` — one-file-one-commit, conventional commits, never `--no-verify` or `--no-gpg-sign`.
- `shell-scripts.md` — `set -euo pipefail`, quoting, shellcheck.
- `python-style.md` — type hints, ruff, no print-debugging, AI-engineering subsection for `prompts/` / `agents/` / `skills/` / `llm/` paths.
- `typescript-style.md` — strict mode, no `any`, ESM-first.
- `ai-engineering.md` — prompt-cache, context budget, eval-first, harness engineering, citation discipline, provider neutrality.
- `secrets-discipline.md` — refuse to read, suggest env vars, incident response.
- `rpi-review-citation.md` — Citation Grounding rule scoped to `rpi/**`.

#### Hooks

- `hooks/scripts/hooks.py` ported from `shanraisshan/claude-code-best-practice` + three enhancements:
  - `SOUNDS_DISABLED` / `CLAUDE_QUIET` env-var bail-out.
  - `--dry-run` flag for bootstrap verification.
  - User-scope path resolution (`CLAUDE_PROJECT_DIR` fallback to `~/.claude`).
- `hooks/config/hooks-config.json` — per-event toggles. Conservative defaults: 5 hooks (PostToolUseFailure, PermissionRequest, Notification, Stop, TaskCompleted) enabled out of the box.
- `hooks/config/hooks-config.local.example.json` — template for per-machine overrides.
- `hooks/sounds/` — full 27-event sound tree copied from reference repo (68 audio files, both `.wav` and `.mp3`).
- All 27 hook events wired in `settings.json` with `async: true`, 5000ms timeout (30000ms for `Setup`).
- Pre-existing custom hooks preserved: `rtk-rewrite.sh`, `worktree-create.sh`, `worktree-remove.sh`.

#### Skills

- `skills.manifest.toml` — declarative bootstrap manifest for 5 first-party skills.
- `bootstrap.sh` — idempotent. Checks deps, seeds templates, clones manifest skills, detects dangling symlinks, dry-runs hook dispatcher.
- `skills/EXTERNAL.md` — catalog of 25+ symlinked third-party skills with manual-install commands.
- Published 3 new GitHub repos: `hashbulla/skill-generator`, `hashbulla/skill-harness`. Updated `hashbulla/claude-init-skill` with professional README/LICENSE/.gitignore.
- Migration: `critical-harness` moved from `~/.claude/skills/critical-harness/` (real dir + nested .git) to `~/local-skills/Skills/critical-harness` + symlinked back, matching the `deep-research` pattern.

#### Doctrine

- `best-practice/` (10 docs): `README.md`, `claude-memory.md`, `claude-settings.md`, `claude-hooks.md`, `claude-subagents.md`, `claude-skills.md`, `claude-commands.md`, `claude-rules.md`, `claude-mcp.md`, `rpi-workflow.md`.
- `docs/` (4 docs): `ARCHITECTURE.md`, `BOOTSTRAP.md`, `PORTABILITY.md`, `TROUBLESHOOTING.md`.
- `playbooks/README.md` — playbook index + 4-week freshness rule.

#### Top-level

- `README.md` — reference-grade with 15 sections, concept table, agent catalog, slash-command table, skills section, rules table, hooks table, MCP registry, search routing, playbooks, RPI workflow, config hierarchy, security, roadmap, credits.
- `SECURITY.md` — three rules, gitignore policy, secret-rotation workflow, the PostHog incident note, future-proofing checklist.
- `LICENSE` — MIT.

### Changed

- `settings.json`: PostHog API key moved from inline to `${POSTHOG_API_KEY}` env interpolation. Required user action: rotate the key.
- `CLAUDE.md`: added `@profile.md` import alongside `@identity.md` and `@RTK.md`.
- `~/.claude/skills/claude-init`: was a real directory with `SKILL.md` only; now a symlink to `~/local-skills/Skills/claude-init-skill/skills/claude-init` (canonical repo).
- `~/.claude/skills/critical-harness`: was a real directory with nested `.git`; now a symlink to `~/local-skills/Skills/critical-harness` (canonical, no nested git).

### Preserved

- `RTK.md` — RTK token-saving proxy doctrine.
- `mcp.json` — three user-scope MCP servers (tavily, fetch, presenton).
- All non-RPI agents and commands pre-existing at scaffold time (`pdf-design-evaluator`, `project-memory-architect`, `/research`, `/domain-setup`).
- All inline skills: `deck-generator`, `humanize-fr`, `linkedin-post`, `synthese`, `voice-check`.
- Playbooks: `claude-code-koyeb-channels`, `klavis-mcp`.
- All symlinks into `~/local-skills/` (impeccable, paperclip, dossier-intelligence, proposition-commerciale, the `hashbulla/*` first-party skills).

### Backed up (in `/tmp/dotclaude.preflight/`, ephemeral)

- `settings.json.orig` — pre-rewrite settings.
- `CLAUDE.md.orig`
- `identity.md.orig`
- `RTK.md.orig`
- `claude-init.SKILL.md.bak`
- `claude-init.dir.bak/`
- `deep-research.pre-symlink-bak/`

These are in `/tmp` and disappear on reboot. Copy to encrypted backup if you want them long-lived.

### Security note

The PostHog API key (prefix `phx_REDACTED…`, full value redacted) was previously inline in `settings.json` and appeared in the planning transcript for this work. **User action required**: rotate at <https://eu.posthog.com> → Project settings → API keys.

---

## [Unreleased]

See [ROADMAP](README.md#-roadmap) in the README for what's queued.
