# Linear PM discipline — every Linear touch is PM-grade

Doctrine for AI-184. How the agent behaves as a seasoned Linear PM on **every** Linear op — any project, any session, user scope. Backed by `~/.claude/research/ai-184-linear-pm/` (deep-research, gate PASS). Surfaced by the CLAUDE.md `<important if="touching Linear">` trigger. Kept tight — this is a rule, every byte costs context.

## The cardinal rule

**Never overwrite a human-authored description/spec.** The issue/project description is the durable contract; comments are the conversation. Linear's agent guidance is explicit: comments are editable and unreliable to read back — so post progress, findings, questions, and decisions as **comments**, and edit the **description** only to author or refine a spec the agent itself owns. Propose corrections to a human's spec in a comment; never clobber the body.

## Decision table — every Linear op

| Signal / Intent | Action | Rationale |
|---|---|---|
| Starting work on an issue | Set **In Progress**; comment the plan | State mirrors reality; the plan is visible and idempotent |
| Progress / finding / decision | Post a **comment** (append-only) | Comments are the log; never edit the spec for this |
| Authoring/refining a spec the agent owns | Edit the **description** | The description is the durable contract |
| Hitting a blocker | Set a **blocked-by relation** to the blocker (+ short comment) | Relations are filterable and surface in views; prose "blocked" doesn't |
| Finishing | **Ask the human before Done** — don't self-close | Assignment = delegation; the human stays responsible |
| Creating an issue | Title = the problem/outcome concretely; body per the checklist below | Issue quality directly drives agent + human efficiency |
| Before creating | `list_issues` / search first to dedupe | `save_*` without an `id` creates; avoid duplicates |
| Prioritizing | Fixed enum only: Urgent / High / Medium / Low / No priority | No custom priority values exist |
| Sizing | Estimate XS=1 … XXXL=21; if ≥ L (5), split into sub-issues | Large issues hide scope |
| Project-level stakeholder progress | `save_status_update` (On-track / At-risk / Off-track) — solo: rare | Status updates are stakeholder-alignment tooling |

## Writing a good issue — self-applied checklist

- [ ] Title states the **problem/outcome concretely** — not "search is broken" but "issue search excludes archived projects even when *Include archived* is on".
- [ ] Body: problem → desired behaviour → **scope** → **what NOT to change** → patterns to reuse.
- [ ] Problem, not solution. No user-story theater. If it isn't a concrete task, it isn't an issue.
- [ ] Acceptance criteria and definition-of-done are explicit and checkable.
- [ ] Priority set (fixed enum); estimate set; ≥ L (5) → split.
- [ ] Right primitive (below); right `Type` label; relations set for every dependency.

## Primitive selection

- **Issue** — one concrete task with a defined outcome (sub-issues for independently-trackable parts; a checklist for trivial in-unit steps — promote checklist → sub-issues only when needed).
- **Project** — a specific, time-bound deliverable grouping many issues (page, target date, milestones). Promote an issue here only when it outgrows a single issue.
- **Initiative** — a curated portfolio of projects toward an objective. **Unused in this workspace.**
- **Lean-solo default**: most work = issue; an occasional multi-week build = project.

## Workspace snapshot — AI Agency (update on drift)

- **Team** `AI Agency` (key `AI`). **Workflow**: Backlog → Todo → In Progress → Done; plus Canceled, Duplicate.
- **`Type` labels (canonical)**: 🗂️ Admin · 🐛 Bug · 🎙️ Réunion · 🔎 Veille · 🧭 Conseil · ✍️ Contenu · 🤖 IA / Dev. Ignore the 3 orphan defaults (`Feature` / `Bug` / `Improvement`) — they duplicate `Type/Bug` (cleanup tracked in AI-210).
- **Projects**: 🧠 AI Engineering · 📦 Interne / Agence (agency ops incl. Linear/tooling config) · ⚖️ Client retainer (NDA; each mission = a dated milestone) · 🔒 Landing DevOps · 🌱 Perso.
- **No cycles, no initiatives in use.**

## What's overkill here (lean-solo carve-outs)

Generic Linear advice that does **not** apply to a one-person workspace: sprint/cycle planning, velocity, and rollover; WIP-column limits (degrade to *finish In Progress before starting more*); initiative/OKR hierarchy; scheduled status-update cadence (post a project update only as a genuine multi-week thinking or handoff artifact).

## Idempotence & delegation mechanics

`save_*` tools upsert: with an `id` → update, without → create — so dedupe before create, and re-asserting a state (set Done when already Done) is a safe no-op. Assigning an issue to an agent is **delegation, not ownership**: the human stays primary and responsible, which is why the agent acknowledges → moves to In Progress → comments progress → verifies → **asks before Done**.

## Skill decision (DoD #3)

**Rule-only — no `/linear-pm` skill.** Every finding here is declarative routing that must shape *every* Linear op (ambient by nature), not a heavy invocable procedure with an eval surface. A skill would duplicate the rule for zero behavioral gain. Revisit only if a repeatable multi-step Linear *workflow* (autonomous triage sweep, delegated-issue execution loop) later needs its own isolated context and eval harness — that would be a workflow skill that *consumes* this rule, not a replacement for it.
