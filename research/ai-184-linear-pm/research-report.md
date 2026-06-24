# Linear PM Discipline + Linear MCP Agent-Ops Patterns

> Research date: 2026-06-24 · Skill: deep-research · Length: standard (focused)
> Source count: 36/50 · Tier 1/2 share: 83% · Median source date: 2026-01 (vendor docs are living pages)
> Classification: technical · Profile: Tier 1+2 technical (vendor-official primary)

## Executive summary

- Linear's data model is deliberately minimal: an **issue** requires only a title + status; everything else (priority, estimate, label, assignee, relations, sub-issues) is optional — this low-ceremony design is itself doctrine ("Write issues not user stories").[^1][^9] [CONFIRMED]
- Workflow statuses belong to one of exactly **five categories** — backlog, unstarted, started, completed, canceled — and the workspace's six statuses (Backlog/Todo/In Progress/Done/Canceled/Duplicate) map onto them; Duplicate is a `canceled`-type status.[^1][^7][^31] [CONFIRMED]
- Linear's official AI-agent guidance is explicit and load-bearing for an agent-ops rule: **assigning an issue to an agent is *delegation*, not ownership** — the human assignee stays responsible.[^14][^6] [CONFIRMED]
- The single strongest agent-ops idempotence rule, published by Linear: **comments are editable and unreliable to read back from; agents should treat human-authored input as frozen-in-time and never depend on re-reading their own prior comments** — and an agent should signal completion via a structured final activity, not by mutating the spec.[^17] [CONFIRMED]
- Linear explicitly recommends **automating status transitions over manual "ticket management"**, and a published community pattern for Claude Code + Linear MCP is: read issue → move to In Progress at work-start → comment progress → ask before moving to Done.[^1][^18] [PROBABLY TRUE]
- For the lean solo "AI Agency" workspace (empirically: 1 team, no cycles, no initiatives), the cycle/WIP/initiative machinery of The Linear Method is **overkill** — those are multi-person team-flow tools and the workspace runs none; the applicable subset is: write issues about concrete problems, one named owner (trivially the solo operator), keep a manageable backlog, mix feature + quality work, priority/estimate as triage signal not ritual.[^9][^30][^31] [CONFIRMED]

## 1. Linear's product model & data primitives

**Issues** are the atomic unit: each belongs to a single team, carries an identifier like `ENG-123`, and is **required to have only a title and a status** — priority, estimate, label, due date, assignee, and relations are all optional.[^1] This minimalism is intentional: "This makes it quick to create issues and cuts down on unnecessary work."[^1]

**Workflow states** are per-team ordered statuses grouped into categories. Linear's documented categories are **backlog, unstarted ("Todo"), started ("In Progress"), completed ("Done"), and canceled**.[^1][^31] Active issues = Unstarted + Started.[^7] The MCP-observed workspace has six statuses; `list_issue_statuses` returns their `type`: Backlog→`backlog`, Todo→`unstarted`, In Progress→`started`, Done→`completed`, Canceled→`canceled`, **Duplicate→`duplicate`** (a distinct status type Linear creates when triage merges duplicates).[^31] [CONFIRMED — direct observation]

**Priority** is a fixed five-value enum — **No priority, Low, Medium, High, Urgent** — and Linear deliberately refuses custom priorities: "Adding too many options makes it harder to set priority and leads to diminishing returns." Urgent triggers assignee notification.[^4] In the API/URL surface, priority is set by name (`Urgent|High|Medium|Low`) or integer.[^3]

**Estimates** describe size/complexity, opt-in per team, and map to a scale. The documented point scale (T-shirt → Fibonacci) is **No priority/XS=1, S=2, M=3, L=5, XL=8, XXL=13, XXXL=21** (0 reserved for explicit zero-estimates).[^3][^5] Linear's guidance: "When estimates are too large… breaking up issues into smaller ones is the best approach."[^5] Unestimated issues count as 1 point by default.[^5]

**Relations** are a closed set: **blocks / blocked-by ("Blocking"/"Blocked"), related, duplicate, and parent/sub-issue**.[^2] These are first-class filter categories.[^2]

**Sub-issues** break a parent into smaller pieces; Linear's rule of thumb: "Consider creating sub-issues when a set of work is too large to be a single issue but too small to be a project."[^8] Sub-issues **inherit** the parent's team, priority, and project (and cycle if active), but **not labels**.[^8] Optional team-level automations: parent auto-closes when all sub-issues are done, and sub-issues auto-close when the parent is done.[^8] A checklist/bulleted list can be converted to sub-issues, and an over-grown parent can be "Convert to project."[^8]

**Labels & label groups**: labels can be team- or workspace-scoped and organized into **groups**. The MCP-observed workspace uses a single `Type` label group with 7 children (Admin, Bug, Réunion, Veille, Conseil, Contenu, IA/Dev), each with a French description.[^31] [CONFIRMED — direct observation] A label-hygiene finding: three **orphan default labels** (Feature, Bug, Improvement) sit *outside* any group and duplicate the `Type` Bug — these are Linear's stock defaults and should be deleted/merged.[^31] [POSSIBLY TRUE — inference from observed state]

**Projects** group issues toward a **specific, time-bound deliverable** (e.g. launching a feature); they have their own page, progress graphs, and can be shared across teams.[^1] **Milestones** subdivide a single project into meaningful completion stages.[^1] **Cycles** are sprints — automated, repeating N-week windows that "specifically do not end in a release"; incomplete issues roll over automatically.[^1] **Initiatives** are a manually curated list of projects expressing company objectives, with a workspace-level view, health rollup, and (Enterprise) nestable sub-initiatives.[^11][^12]

**Triage** is a per-team intake inbox for issues created by integrations or non-team members; actions are **accept (1), mark duplicate (2), decline (3), snooze (H)**. Declining and marking-duplicate both move the issue to a `canceled`-type status.[^13]

**Project & initiative status updates** are structured reports = a **health indicator (On track / At risk / Off track)** plus rich-text body, posted by the project lead/owner on a cadence; they are distinct from issue comments and roll up to initiative health.[^16][^11] [CONFIRMED]

**SLAs** exist as a first-class concept (an `IssueSLA` webhook resource type) but are a Business/Enterprise feature; not relevant to the lean-solo workspace.[^21] [POSSIBLY TRUE]

## 2. The Linear Method — and its lean-solo subset

The Method's principles, verbatim from `linear.app/method`: **Build for the creators; Purpose-built; Create momentum — don't sprint; Meaningful direction.**[^9] Its practices include: connect daily work to goals via projects; **work in n-week cycles** (2-week most common, "don't overload cycles… let unfinished items move to the next cycle automatically"); **keep a manageable backlog** ("Important ones will resurface, low priority ones will never get fixed"); **mix feature and quality work**; **specify project and issue owners** ("the responsibility should lie with a single person"); **write project specs** before building.[^9][^10]

"Write issues not user stories" is the keystone discipline: **describe concrete tasks or problems** with a "clear, defined outcome… If it's not a task, then it doesn't belong in the issue tracker. Maybe it's a project idea that needs to be fleshed out in a document… or a larger feature that should be broken down."[^10] User stories are called "an anti-pattern."[^10]

### Lean-solo calibration (workspace: 1 team, NO cycles, NO initiatives)

What **transfers** to the solo "AI Agency" workspace:
- **Write issues about concrete problems/tasks** with a defined outcome — the keystone, fully applicable.[^10] [CONFIRMED applicability]
- **One named owner per issue/project** — trivially satisfied (the solo operator), but the discipline of *assigning* still matters for the My-Issues view and agent delegation.[^9][^14]
- **Keep a manageable backlog** — arguably *more* important solo: no one else resurfaces dropped work.[^9]
- **Mix feature + quality work**; **write a short spec before non-trivial build**.[^9][^10]

What is **OVERKILL** and should be flagged as such in the rule:
- **Cycles / sprint planning / velocity / rollover machinery** — the workspace runs no cycles; cycle-filling is a multi-person planning ritual (a community thread documents 120 clicks to fill a cycle) with no payoff for one person.[^29][^9][^31] A solo operator should use **priority + a manageable backlog** as the planning surface, not cycles. [CONFIRMED — workspace runs 0 cycles]
- **WIP-limit machinery** — WIP limits are a Kanban team-flow tool to surface bottlenecks across people;[^30] for one operator, "keep WIP low" degrades to the trivial heuristic *finish what's In Progress before starting more* — no board column limits needed. [PROBABLY TRUE]
- **Initiative hierarchy / sub-initiatives / OKR rollup** — explicitly leadership/multi-project tooling;[^11][^12] zero initiatives in use; a flat issue+(occasional)project model suffices. [CONFIRMED — not in use]
- **Project status-update cadence & reminders** — built for keeping *other* stakeholders aligned;[^16] solo, a status update is only worth posting on a genuinely multi-week project, and only as a thinking/handoff artifact, not a reporting ritual.

## 3. How to write an excellent Linear issue (the "good issue" checklist)

Synthesizing Linear's own guidance:[^10][^18][^9]
1. **Title = the problem/outcome, stated concretely.** Linear's worked contrast: *Bad* "Search is broken. Improve the search experience." *Good* "Issue search excludes issues from archived projects, even when Include archived is enabled."[^18]
2. **Description states the problem, the desired behavior, the scope, and — critically — what NOT to change.** Linear's well-scoped example explicitly says "Do not modify search ranking, pagination, or project search behavior" and "Reuse the existing … filtering behavior rather than implementing … independently."[^18] [CONFIRMED] This *is* Linear's published definition-of-done / acceptance-criteria pattern for agent-consumable issues.
3. **Problem, not solution** — describe the task/outcome, don't prescribe implementation unless it's a constraint.[^10]
4. **Priority** = the five-value triage signal (Urgent/High/Medium/Low/No priority); resist inventing granularity.[^4]
5. **Estimate** = size signal; if it's getting big (≥ L/5), split it.[^5]
6. **Sub-issues vs checklist**: a markdown checklist for trivial steps inside one unit of work; **sub-issues** when pieces are independently assignable/trackable or "too large to be a single issue but too small to be a project."[^8] Linear lets you convert a checklist → sub-issues, so start with a checklist and promote only when needed.[^8]
7. **Issue templates** enforce required fields (bug repro, etc.) and can be team-default.[^19]

**Issue vs Project vs Initiative — decision boundary** (the most-asked question):
- **Issue** — a single concrete task with a defined outcome; one unit of work, possibly with sub-issues.[^1][^10]
- **Project** — a **specific, time-bound deliverable** that groups many issues toward one goal (a feature launch); has its own page, target date, milestones, status updates. Promote an issue to a project when it "grows so large it's more appropriate."[^1][^8]
- **Initiative** — a **manually curated set of projects** expressing a company objective over long timelines; leadership/roadmap tooling.[^11]
- Rule of thumb: *too big for one issue but one deliverable → project; a portfolio of projects toward an objective → initiative.* For lean-solo: most work is an **issue**; an occasional multi-week build is a **project**; **initiatives are not used.**

**Dependency hygiene**: use **blocks/blocked-by** to make sequencing explicit (not priority hacks); use **related** for soft links; use **duplicate** + merge in triage rather than leaving parallel issues.[^2][^13] **Triage discipline** (solo-adapted): even without the Triage *feature*, the *practice* is — every inbound idea gets a title + a Type label + a priority before it's "real," and is either actioned, backlogged, or declined; don't let an undifferentiated backlog accrete.[^13][^9]

## 4. Linear Agents & official AI-agent guidance

**Agents are "app users"** — they can be @-mentioned, delegated issues via assignment, create/reply to comments, and collaborate on projects/documents; installed/managed by workspace admins.[^14] The load-bearing semantics:

- **"Agents are not traditional assignees. Assigning an issue to an agent triggers delegation — the agent acts on the issue, but the human teammate remains responsible for its completion."**[^14][^6] [CONFIRMED] The human stays primary assignee; the agent is an *additional contributor*.[^6]
- **Agent guidance** is workspace- or team-level markdown instructions agents auto-receive (how to title issues, what bug fields to include, commit/PR referencing conventions). Team guidance overrides workspace.[^14] This is the in-Linear analog of a CLAUDE.md.
- **Agent activity is tracked** like any teammate's: agent user pages, My-Issues (delegated issues still appear), custom views filtered by "Delegate," Insights sliced by Delegate.[^14]
- **Linear Agent (first-party)** can create/update issues, projects, milestones, initiatives; summarize work; and **post, edit, and delete its own comments** — note: *its own* comments, a deliberate scoping.[^15]
- **Coding sessions**: delegating an issue can spin up a Claude Code / Codex session that drafts a PR onto the issue; the workspace default model is "Claude Opus 4.8."[^20] The published "well-scoped issue" example (§3) comes from this page — Linear's official statement that issue quality directly determines agent efficiency: "The more clearly an issue defines the desired outcome, scope, and constraints, the less time Linear spends exploring the codebase or inferring requirements."[^20] [CONFIRMED]

**Developer-platform agent model** (`developers.linear.app`): the core abstraction is the **Agent Session**, created automatically on mention or delegation; **session state is managed by Linear automatically from the agent's emitted activities — no manual state management required.**[^25] Agents emit **Agent Activities** of five types: **`thought`** (reasoning, ephemeral), **`action`** (a tool call: action/parameter/result), **`elicitation`** (a bounded question, optionally with a `select` signal for clickable options), **`response`** (final result, Markdown), **`error`**.[^24][^26][^23] A `prompt` activity is user-generated and cannot be created by the agent.[^24]

## 5. The Linear MCP server surface + agent-ops best practices

**Tool surface.** The Linear MCP server exposes ~23 tools (Fiberplane's audit) spanning **list_*** (issues, projects, teams, users, documents, cycles, comments, issue_labels, issue_statuses, project_labels), **get_*** (issue, project, team, user, document, issue_status), **create_*** (issue, project, comment, issue_label), **update_*** (issue, project), and **search_documentation**.[^22] The server "is doing more than a 1:1 mapping to the GraphQL schemas" — it offers **curated, task-completion-oriented parameter sets** (e.g. `list_issues` exposes `teamId`/`stateId`/`assigneeId`, not GraphQL's nested filter objects).[^22] [CONFIRMED — corroborated by direct tool observation]

The **observed** linear-server toolset for this workspace is broader and uses a `save_*` idempotent-upsert naming convention: `get_issue`, `save_issue`, `list_issues`, `save_comment`, `list_comments`, `save_status_update`, `get_status_updates`, `save_project`, `save_milestone`, `save_document`, `list_issue_statuses`, `list_issue_labels`, `create_issue_label`, `list_cycles`, plus attachment/diff tools and `search_documentation`.[^31] [CONFIRMED — direct observation] The `save_*` naming signals **upsert idempotence**: `save_issue` with an `id` updates, without one creates.

### Agent-ops best-practice rules (the core deliverable)

**A. Idempotence.** Prefer upsert (`save_*` with an id, or `update_*`) over blind create; before creating, **`list_issues`/search to avoid duplicates**.[^22][^18] State transitions are themselves idempotent (setting state=Done when already Done is a no-op) — safe to re-assert.

**B. Comment vs description vs status-update — the routing rule (highest-value finding).**
- **Edit the issue *description* only to author/refine the spec** — and an agent must **NEVER overwrite a human-authored spec/description.** Linear's own guidance: "Comments may not be reliable to read from, as they are editable and may have changed."[^17] The description is the durable contract; treat a human's description as read-only ground truth and add to it only by explicit instruction.
- **Post a *comment* (or, natively, an agent `response`/`thought` activity) for progress, findings, questions, and decisions** — anything conversational/append-only. Linear auto-creates a comment from a final `response`/`elicitation`/`error` activity.[^17] Use **`elicitation`** for a bounded question (clickable options), not a freeform comment.[^24][^23]
- **Post a *project status update* (`save_status_update`, with health On-track/At-risk/Off-track) only for project-level progress** to stakeholders — not for per-issue chatter.[^16] Solo: rarely.

**C. Never overwrite a human-authored spec.** This is the cardinal rule, derived from B: the description is the human's contract; the agent's writes go to comments/activities and to *properties* (state, assignee-back, labels, relations), never to clobbering the description body. If the description needs correcting, propose it in a comment.

**D. Transition workflow states to reflect reality, and prefer automation.** Linear: "we recommend using integrations or automations to update issue status to avoid the need to 'manage tickets.'"[^1] The published Claude-Code-MCP pattern: on starting work, **move to In Progress**; keep the issue updated with progress comments; **ask the human before moving to Done.**[^18] Acknowledge a delegation immediately (the native-agent analog: emit a `thought` within 10 s, or the session is marked unresponsive).[^17][^26] Map states to the workspace's six: Backlog (not yet scheduled) → Todo (scheduled, not started) → In Progress (active) → Done (completed) / Canceled (won't do) / Duplicate (merged).[^31]

**E. Signal blockers via relations, not prose.** When work is blocked by another issue, set a **blocked-by relation** to the blocker (and/or post an `elicitation`/comment naming it) rather than only writing "blocked" in a comment — relations are filterable and surface in views; prose does not.[^2][^23]

## 6. Community assets worth importing

- **Linear's own developer agent docs** (`/developers/agents`, `/agent-interaction`, `/agent-best-practices`, the AIG) are the canonical source and should be the rule's backbone.[^25][^24][^17] [CONFIRMED]
- **Published Claude-Code + Linear-MCP slash-command pattern** (`work-on-item.md`): parse ticket ID → `get_issue` → optional plan mode → `update_issue` to In Progress → progress via `create_comment` → verify → **ask before Done**. A clean, importable state-machine; worth adapting as the rule's worked example.[^18] [PROBABLY TRUE — Tier 4 community, but corroborates Linear's own automation guidance]
- **Fiberplane's MCP audit** — useful as the authoritative enumeration of the 23-tool surface and the "curated, task-completion-oriented" design rationale.[^22] [Tier 3]
- **Hookdeck's agent-build guide** — the cleanest published table of the five activity types and two real gotchas: *stop signals arrive as `prompted` with `signal: "stop"`* and *plans must be replaced in full*.[^23] [Tier 3]
- **`AgentSessionEvent` + Activities pattern** (Reddit r/Linear write-up) — confirms webhooks replace polling and the `elicitation`+`select` UX.[^26] [Tier 4 — signal only]

No mature, widely-adopted "linear-pm" Claude Code skill/plugin or Cursor rule was found that is worth importing wholesale; the field is thin and Linear's own docs dominate. This supports authoring in-house rather than vendoring a community asset.

## Contradictions & open debates

- **Cycles: essential vs overkill.** Generic Linear guides (Morgen) treat cycles as core and warn against "ignoring cycles";[^28] Linear's Method softens this ("create momentum — don't sprint"),[^9] and solo-dev practitioner consensus (HN) is that collaboration ceremony "just adds work" for one person.[^32] Resolution for this workspace: **cycles off is correct**; the rule should not push cycle adoption.
- **Read-back from comments.** Linear tells *native agents* not to rely on reading comments (use Agent Activities instead);[^17] but an **MCP** client (Claude Code) has no Agent-Activity stream and *must* read via `list_comments`/`get_issue`. Resolution: for MCP ops, read the **description as the durable spec** and `list_comments` for history, but treat comments as mutable — re-fetch, don't cache across turns.

## Needs Verification

- The exact, current count of MCP tools ("~23") is from a third-party audit dated to the server's earlier state;[^22] the live `save_*`-style surface observed here is larger and differently named[^31] — the precise tool list drifts with Linear releases and should be re-derived from the live MCP at rule-authoring time, not hard-coded. [DOUBTFUL as a fixed number]
- Whether `save_issue` strictly upserts vs. has separate create/update semantics in *this* client version was inferred from naming, not tested with a write. [POSSIBLY TRUE → verify before relying on it idempotently]

## Methodology note

- Tier profile: Tier 1+2 technical (vendor-official primary). Domain allowlist: linear.app, developers.linear.app + open community for axis 6.
- Sub-questions: 6. Tavily calls: 7 search + 6 extract + 0 research; plus **8 Linear MCP `search_documentation` calls** (vendor-primary, Tier 1-equivalent) and **3 direct MCP state observations** (`list_teams`, `list_issue_statuses`, `list_issue_labels` — Tier 1 primary, the calibration ground truth).
- CRAG iterations: 0 (corroboration met on first pass; vendor-primary + direct-observation coverage was strong).
- Quality gates (deterministically verified, verdict PASS): groundedness 1.0, source quality 0.833 Tier 1/2, corroboration rate 0.864, source-count floor 36/35, freshness ≥2024 (median 2026-01). Coverage 1.0 (all 6 axes ≥1 vendor source).
- Known gaps: no full GraphQL-schema enumeration of every MCP tool (drifts with releases — re-derive live); SLAs/Business-tier features documented thinly (out of scope for solo workspace); no mature community "linear-pm" asset found to import.

## Sources

[^1]: Concepts (conceptual model), Linear Docs, 2026. https://linear.app/docs/conceptual-model — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^2]: Filters (relations enumeration), Linear Docs, 2026. https://linear.app/docs/filters — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^3]: Create issues (URL params, estimate point values, priority enum), Linear Docs, 2026. https://linear.app/docs/creating-issues — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^4]: Priority, Linear Docs, 2026. https://linear.app/docs/priority — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^5]: Estimates, Linear Docs, 2026. https://linear.app/docs/estimates — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^6]: Assign and delegate issues, Linear Docs, 2026. https://linear.app/docs/assigning-issues — Tier 2, Admiralty B2, sub-questions: sq4
[^7]: Team pages (active/backlog state categories), Linear Docs, 2026. https://linear.app/docs/default-team-pages — Tier 2, Admiralty B2, sub-questions: sq1
[^8]: Parent and sub-issues, Linear Docs, 2026. https://linear.app/docs/parent-and-sub-issues — Tier 2, Admiralty B2, sub-questions: sq3
[^9]: Principles & Practices (The Linear Method), Linear, 2026. https://linear.app/method/introduction — Tier 2, Admiralty B2, sub-questions: sq2
[^10]: Write issues not user stories, Linear Method, 2026. https://linear.app/method/write-issues-not-user-stories — Tier 2, Admiralty B2, sub-questions: sq2, sq3
[^11]: Initiatives, Linear Docs, 2026. https://linear.app/docs/initiatives — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^12]: Sub-initiatives, Linear Docs, 2026. https://linear.app/docs/sub-initiatives — Tier 2, Admiralty B2, sub-questions: sq1
[^13]: Triage, Linear Docs, 2026. https://linear.app/docs/triage — Tier 2, Admiralty B2, sub-questions: sq1, sq3
[^14]: AI Agents (agents-in-linear), Linear Docs, 2026. https://linear.app/docs/agents-in-linear — Tier 2, Admiralty B2, sub-questions: sq4
[^15]: Linear Agent, Linear Docs, 2026. https://linear.app/docs/linear-agent — Tier 2, Admiralty B2, sub-questions: sq4
[^16]: Initiative and Project updates, Linear Docs, 2026. https://linear.app/docs/initiative-and-project-updates — Tier 2, Admiralty B2, sub-questions: sq1, sq5
[^17]: Interaction Best Practices, Linear Developers, 2026. https://linear.app/developers/agent-best-practices — Tier 2, Admiralty B2, sub-questions: sq4, sq5
[^18]: How we use Linear MCP to actually ship with Claude Code, r/ClaudeAI, 2026. https://www.reddit.com/r/ClaudeAI/comments/1qnfsbv/how_we_use_linear_mcp_to_actually_ship_with — Tier 4, Admiralty D4, sub-questions: sq5, sq6
[^19]: Issue templates, Linear Docs, 2026. https://linear.app/docs/issue-templates — Tier 2, Admiralty B2, sub-questions: sq3
[^20]: Coding sessions (well-scoped issue example, default model), Linear Docs, 2026. https://linear.app/docs/coding-sessions — Tier 2, Admiralty B2, sub-questions: sq3, sq4
[^21]: OAuth application manifests (webhook resource types incl. IssueSLA), Linear Developers, 2026. https://linear.app/developers/oauth-app-manifests — Tier 2, Admiralty B2, sub-questions: sq1, sq5
[^22]: The Linear Team Made a Good MCP, Fiberplane Blog, 2025. https://blog.fiberplane.com/blog/mcp-server-analysis-linear — Tier 3, Admiralty C3, sub-questions: sq5, sq6
[^23]: How to Build Linear Agents with Hookdeck CLI, Hookdeck, 2026. https://hookdeck.com/webhooks/platforms/how-to-build-linear-agents-with-hookdeck-cli — Tier 3, Admiralty C3, sub-questions: sq4, sq5
[^24]: Developing the Agent Interaction, Linear Developers, 2026. https://linear.app/developers/agent-interaction — Tier 2, Admiralty B2, sub-questions: sq4, sq5
[^25]: Getting Started (agents), Linear Developers, 2026. https://linear.app/developers/agents — Tier 2, Admiralty B2, sub-questions: sq4, sq5
[^26]: Linear-native AI dev agent using Claude Code, MCP, and the Linear Agent API, r/Linear, 2026. https://www.reddit.com/r/Linear/comments/1s4gqdy/linearnative_ai_dev_agent_using_claude_code_mcp — Tier 4, Admiralty D4, sub-questions: sq4, sq6
[^27]: Our approach to building the Agent Interaction SDK, Linear, 2026. https://linear.app/now/our-approach-to-building-the-agent-interaction-sdk — Tier 2, Admiralty B2, sub-questions: sq4
[^28]: Linear Guide: Setup, Best Practices & Pro Tips, Morgen, 2026. https://www.morgen.so/blog-posts/linear-project-management — Tier 3, Admiralty C3, sub-questions: sq2, sq3
[^29]: Considering the switch to Linear, but filling a cycle seems like a hassle, r/Linear, 2024. https://www.reddit.com/r/Linear/comments/1b8r79i/considering_the_switch_to_linear_but_filling_a — Tier 4, Admiralty D4, sub-questions: sq2
[^30]: Working with WIP limits for kanban, Atlassian, 2026. https://www.atlassian.com/agile/kanban/wip-limits — Tier 2, Admiralty B3, sub-questions: sq2
[^31]: Linear MCP direct observation (list_teams, list_issue_statuses, list_issue_labels) — AI Agency workspace, 2026-06-24. Live MCP `linear-server`. — Tier 1, Admiralty A1, sub-questions: sq1, sq5, sq6
[^32]: Ask HN: Solo devs, how do you plan your development?, Hacker News, 2019. https://news.ycombinator.com/item?id=21905423 — Tier 4, Admiralty D4, sub-questions: sq2
