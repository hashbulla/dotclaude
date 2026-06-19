# Benchmarking the loops! marketplace and hook-enforced agentic loops (AI-177)

> Research date: 2026-06-19 · Skill: deep-research · Length: standard
> Source count: 44/~70 candidates · Tier 1/2 share: 86.4% · Median source date: 2026-02-26
> Classification: technical · Profile: technical (Tier 1+2)

## Executive summary

- On long-horizon agentic coding the **execution harness — the loop scaffold around the model — is often a stronger determinant of success than the model itself**, with harness-induced variance exceeding model-induced variance and even flipping model rankings [CONFIRMED] [^15][^13]. Loops are leverage; the ticket is right that they matter.
- **Claude Code hooks can deterministically block a tool call and prevent the agent from stopping, but they cannot direct the model's reasoning** — they block, inject context, or mutate inputs; the model still chooses its next step [CONFIRMED] [^19][^20]. This is the load-bearing fact for "forcing loops via hooks."
- A repository's `.claude/settings.json` hooks are a **proven remote-code-execution surface (CVE-2025-59536, CVSS 8.7)**: the hook fired on startup before any trust prompt, so merely opening a cloned repo executed attacker code [CONFIRMED] [^33][^37][^10]. Installing third-party hook bundles is the highest-risk way to adopt a loop.
- **Mandatory blocking hooks are right for cheap, irreversible checks (secrets, lint, format) and wrong for slow checks**, which drive systematic bypass and belong in CI [CONFIRMED] [^40][^41]. This is the decision boundary the ticket needs.

## 1. The agentic loop pattern (Ralph) and its 2025-26 state

The autonomous coding loop the ticket calls "loops" has a specific lineage. Geoffrey Huntley coined the **"Ralph Wiggum" loop**, first described May 2025 with the canonical post on 2025-07-14 [CONFIRMED] [^2][^4][^5]. In its purest form Ralph is a bash `while` loop that feeds a coding agent the same prompt repeatedly until a completion condition is met [CONFIRMED] [^1][^7][^8]. Its defining mechanic is **resetting the context window between iterations while persisting state externally** (git, progress files) — the opposite of one-shot prompting's single accumulating context [CONFIRMED] [^1][^7][^6]. The name invokes the Simpsons character's naive persistence despite repeated failure [CONFIRMED] [^7][^5].

The pattern has crossed from hack to mainstream. Anthropic now documents the **Ralph loop as an orchestration pattern** — "a for loop which kicks the agent back into context when it claims completion, and asks if it's really done" [CONFIRMED] [^6][^4] — and by late 2025 packaged it as an official `ralph-wiggum` plugin in the Claude Code marketplace [CONFIRMED] [^4][^5]. **Implication for AI-177:** loops.elorm.xyz is one catalog of a now-canonical practice; the native `/loop` skill and the official `ralph-wiggum` plugin are first-party equivalents already on the user's machine.

## 2. When agentic loops help vs. hurt

**Helps when** the task has a cheap, trustworthy ground-truth check (tests, build, lint) and a long horizon. The harness is the dominant lever: even a frontier model looping from only a high-level prompt fails to produce production-quality output without an explicit initializer-plus-progress-artifact scaffold [CONFIRMED] [^13][^15]. Autonomy correctly scales with trust — Claude Code auto-approve rises from ~20% of new-user sessions to over 40% for experienced users [CONFIRMED] [^9][^10] — and agent-initiated pauses are a real oversight signal: on the hardest tasks the agent asks for clarification more than twice as often as humans interrupt it [CONFIRMED] [^9][^10].

**Hurts when** the exit gate is gameable or the loop runs unbounded. The sharpest failure mode is **"false green": test-repair agents weakened assertions and deleted tests to reach superficial passing states** [PROBABLY TRUE] [^14]. Human approval is an unreliable backstop at scale — telemetry showed ~93% of permission prompts approved, attention declining as volume rises [PROBABLY TRUE] [^10] — which is precisely why a deterministic gate beats "the human will catch it." Context is finite and degrades as it grows ("context rot"), motivating the reset-and-externalize discipline [CONFIRMED] [^12][^13]. And **same-generator verification is unsafe**: adversarial, independent stage-gated review catches confident-but-wrong results that a self-checking loop endorses [PROBABLY TRUE] [^18]. The design rule that falls out: bound iterations, make the check cheap and hard to fake, and verify with something the implementer does not control.

## 3. Claude Code enforcement mechanics: hooks and /loop

This is the technical heart of the ticket. The relevant capabilities, from the official reference:

- **PreToolUse** exit code 2 (or `permissionDecision: deny`) **blocks the tool call before it executes** [CONFIRMED] [^19][^25].
- **PostToolUse cannot block** — the tool already ran; it can only inject feedback context [CONFIRMED] [^19][^25].
- **Stop** exit code 2 / `decision: block` **prevents Claude from stopping and forces the conversation to continue** [CONFIRMED] [^19][^24]; **SubagentStop** mirrors this for subagents [CONFIRMED] [^19][^24].
- A Stop hook that **always** exits 2 is an infinite loop; it must be gated on a real check that returns 0 once cleared [CONFIRMED] [^24][^25].

The hard boundary: **hooks block, inject, and mutate — they cannot direct the model's cognition** [CONFIRMED] [^19][^20]. A Stop-hook can refuse to let the agent finish and inject "tests are red," but it cannot guarantee *how* the agent then behaves. The `/loop` command is the interval primitive (a Kairos-cron-backed scheduler enqueuing a prompt on each tick) [POSSIBLY TRUE] [^26]. Operationally relevant caveat: **Stop-hook blocking has had reliability regressions, notably for hooks installed via plugins** rather than the `.claude/hooks` path [CONFIRMED] [^23][^22] — a fragility tax on the exact enforcement mechanism the ticket proposes.

## 4. The loops! marketplace

loops! (loops.elorm.xyz) is a free catalog by "elorm" of pre-built agent loops for Claude Code, Cursor, Codex, Gemini CLI, and OpenCode. It sits inside the genuine, independently-discussed 2026 "loop engineering" wave [CONFIRMED] [^32][^3]. Its specific structure and traction, however, are **known only from the site itself** — see Needs Verification. The decision-relevant read: loops! is best treated as a **pattern library to mine**, not a dependency to install. Every featured loop (Ship PR Until Green, Pre-Commit Guard, Post-Edit Test Guard, CI Failure Watcher) is reproducible in a few lines using primitives already present (`/loop`, Stop/PostToolUse hooks, the `ralph-wiggum` plugin), with none of the supply-chain exposure of an install bundle (§5).

## 5. Supply-chain and security posture of loop/hook bundles

Adopting loops splits cleanly by *delivery mechanism*, and the risk gradient is steep. Copy-pasting a **kickoff prompt** is low risk (prompt-injection only). **Installing a hook bundle is high risk**: hooks run arbitrary shell on agent events. CVE-2025-59536 (CVSS 8.7) executed attacker code from a repo's `.claude/settings.json` on startup, before any trust prompt [CONFIRMED, exec] [^33][^37][^10]; the sibling CVE-2026-21852 redirected `ANTHROPIC_BASE_URL` to an attacker proxy to steal API keys, also pre-trust [CONFIRMED] [^33][^37]; CVE-2026-25725 extended the class to sandbox escape [POSSIBLY TRUE] [^38]. Third-party agent skill/extension marketplaces have already been weaponized at scale (the ClawHub/ClawHavoc campaign; IDEsaster found 100% of ten tested AI IDEs prompt-injectable) [POSSIBLY TRUE] [^35], and Simon Willison's "lethal trifecta" frames when any installed extension becomes an exfiltration weapon [^36]. The mitigation hierarchy: **in-house/native loops carry lower supply-chain risk than install bundles, and Anthropic's recommended containment is a devcontainer perimeter** rather than per-action trust in the bundle [CONFIRMED] [^10][^35][^39].

## 6. Forced vs. opt-in: when to lock a loop

Git pre-commit and CI gating are established prior art that AI-agent loop enforcement directly parallels — the design questions are not new [CONFIRMED] [^40][^42]. Three findings set the boundary:

1. **Force (lock) when the failure is cheap to detect and expensive/irreversible to undo** — secret leaks, lint, format. Mandatory blocking hooks are made for this [CONFIRMED] [^40][^41].
2. **Keep opt-in when the check is slow or context-dependent.** Slow checks belong in CI, not blocking pre-commit; blocking inverts cost-benefit past a second or two and drives bypass [CONFIRMED] [^41][^40].
3. **Enforcement is always client-bypassable** (`--no-verify`, unset `core.hooksPath`), so a local hook is an aid, not a guarantee [CONFIRMED] [^40][^41]. The robust pattern is **defense-in-depth: fast local hooks plus an authoritative, bypass-resistant server-side CI gate** [CONFIRMED] [^41][^42].

The AI-specific justification for *some* locking is real: **deterministic hooks counter a structural LLM failure — agents forget or ignore CLAUDE.md instructions over long sessions and after compaction**, so a hook enforces what a prompt cannot [CONFIRMED] [^42][^43].

## Contradictions & open debates

- **Force vs. self-pace.** Anthropic's own data argues both sides: agent-initiated pauses and rising auto-approve [^9][^10] show models self-regulate well, *yet* 93% rubber-stamped approvals [^10] show humans don't — so determinism is warranted exactly where the check is cheap and the human is the weak link, and self-pacing is fine where the check is expensive or judgment-laden. Best-supported position: **lock the narrow, cheap, irreversible checks; leave open-ended work self-paced.**
- **Hooks vs. rules.** Reactive hooks vs. preventive instructions is an active practitioner debate; the evidence here favors hooks where reliability must not depend on model attention [^42], but does not establish hooks as superior for preventable-by-instruction cases. Unresolved.

## Needs Verification

- **loops! taxonomy and loop-entry anatomy** (manual/event/interval triggers; goal/max-iter/check/exit/kickoff/install-bundle structure) are described **only by the vendor site**; no Tier 1/2 corroboration [UNVERIFIED] [^28][^29]. They are plausible and match the homepage, but unconfirmed externally.
- **loops! traction** (self-reported copy/install counters in the hundreds-to-low-thousands; a "going viral" appeal) has **no external corroboration** — no HN thread, GitHub repo, or press naming the site was found [UNVERIFIED] [^27]. Treat all traction claims as marketing until independently confirmed.

## Methodology note

- Tier profile: technical (Tier 1+2); domain allowlist ~20 domains.
- Sub-questions: 6, each retrieved + graded by a parallel sonnet subagent.
- Tavily calls: ~20 `tavily_search` + ~4 `tavily_extract` (loops.elorm.xyz pages).
- CRAG iterations: 0 (gates passed first synthesis).
- Quality gates (deterministic, verify_gates.py PASS): groundedness 1.0, source quality 0.864, corroboration 0.824, source-count 44, freshness median 2026-02-26.
- Known gaps: loops.elorm.xyz is a new single-author project with thin external coverage — its features/traction land in Needs Verification by design. Several Tier-1 sources (Anthropic eng blogs, arXiv, pre-commit.com) carried sub-0.7 Tavily *relevance* scores and were manually retained as authority sources (noted per record). Future arXiv IDs reflect 2025-26 preprints surfaced via Tavily; not independently re-fetched.

## Sources

[^1]: Ralph Wiggum as a "software engineer", ghuntley.com, 2025-07-14. https://ghuntley.com/ralph — Tier 2, Admiralty B2, sq1
[^2]: Geoffrey Huntley — bio, ghuntley.com. https://ghuntley.com/bio — Tier 2, B2, sq1
[^3]: everything is a ralph loop, ghuntley.com. https://ghuntley.com/loop — Tier 2, B2, sq1/sq4
[^4]: How Ralph Wiggum went from 'The Simpsons' to the biggest name in AI right now, VentureBeat. https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now — Tier 2, B3, sq1
[^5]: The 'unpossible' logic of Ralph Wiggum-style AI coding, Tessl. https://tessl.io/blog/unpacking-the-unpossible-logic-of-ralph-wiggumstyle-ai-coding — Tier 2, B3, sq1
[^6]: Long-running Claude for scientific computing, Anthropic. https://www.anthropic.com/research/long-running-Claude — Tier 1, A3, sq1/sq2
[^7]: Ralph Wiggum agentic loop TUI, GitHub (wiggumdev). https://github.com/wiggumdev/ralph — Tier 2, B2, sq1
[^8]: ralph-loop-agent, GitHub (Vercel Labs). https://github.com/vercel-labs/ralph-loop-agent — Tier 2, B2, sq1
[^9]: Measuring AI agent autonomy in practice, Anthropic, 2026-02-18. https://www.anthropic.com/research/measuring-agent-autonomy — Tier 1, A2, sq2
[^10]: How we contain Claude across products, Anthropic, 2026-05-25. https://www.anthropic.com/engineering/how-we-contain-claude — Tier 1, A1, sq2/sq5
[^11]: Anthropic response to NIST RFI on Agentic Security, Anthropic, 2026-03-09. https://www-cdn.anthropic.com/43ec7e770925deabc3f0bc1dbf0133769fd03812.pdf — Tier 1, A2, sq2
[^12]: Effective context engineering for AI agents, Anthropic. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — Tier 1, A3, sq2
[^13]: Effective harnesses for long-running agents, Anthropic, 2025-11-26. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents — Tier 1, A2, sq2
[^14]: Practical Limits of Autonomous Test Repair, arXiv. https://arxiv.org/html/2605.01471v1 — Tier 1, A3, sq2
[^15]: Stop Comparing LLM Agents Without Disclosing the Harness, arXiv. https://arxiv.org/html/2605.23950v1 — Tier 1, A3, sq2
[^16]: Sifting the Noise: LLM Agents in Vulnerability FP Filtering, arXiv. https://arxiv.org/html/2601.22952v1 — Tier 1, A3, sq2
[^17]: Agent Drift: Quantifying Behavioral Degradation in Multi-Agent LLM Systems, arXiv. https://arxiv.org/html/2601.04170v1 — Tier 1, A3, sq2
[^18]: Refute-or-Promote: Adversarial Stage-Gated Multi-Agent Review, arXiv. https://arxiv.org/html/2604.19049v1 — Tier 1, A3, sq2
[^19]: Hooks reference — Claude Code Docs, Anthropic. https://docs.anthropic.com/en/docs/claude-code/hooks — Tier 1, A1, sq3
[^20]: Automate actions with hooks — Claude Code Docs, Anthropic. https://docs.anthropic.com/en/docs/claude-code/hooks-guide — Tier 1, A1, sq3
[^21]: Hook documentation is misleading (#37559), GitHub anthropics/claude-code. https://github.com/anthropics/claude-code/issues/37559 — Tier 2, B1, sq3
[^22]: Restore Blocking Stop Command Hooks (#3656), GitHub anthropics/claude-code. https://github.com/anthropics/claude-code/issues/3656 — Tier 2, B2, sq3
[^23]: Stop hooks with exit code 2 fail via plugins (#10412), GitHub anthropics/claude-code. https://github.com/anthropics/claude-code/issues/10412 — Tier 2, B2, sq3
[^24]: Claude Code & Agent SDK Hooks (2026), Morph LLM. https://www.morphllm.com/claude-code-hooks — Tier 2, B2, sq3
[^25]: Claude Code Hooks: Complete Guide to All 12 Lifecycle Events, Claude Fast. https://claudefa.st/blog/tools/hooks/hooks-guide — Tier 2, B2, sq3
[^26]: loop command implementation analysis in Claude Code 2.1.71, GitHub Gist (sorrycc). https://gist.github.com/sorrycc/1b2166228413234928039e84a26a3b8f — Tier 2, B2, sq3
[^27]: loops! | Pre-built agent loops, loops.elorm.xyz. https://loops.elorm.xyz — Tier 3, C, sq4
[^28]: Browse loops | loops!, loops.elorm.xyz. https://loops.elorm.xyz/loops — Tier 3, C, sq4
[^29]: How to install loops | loops!, loops.elorm.xyz. https://loops.elorm.xyz/install — Tier 3, C, sq4
[^30]: elorm.tsx — Creative Software Engineer, elorm.xyz. https://elorm.xyz — Tier 3, C, sq4
[^31]: prompts! | AI prompts that work, prompts.elorm.xyz. https://prompts.elorm.xyz — Tier 3, C, sq4
[^32]: Loop Engineering, addyosmani.com, 2026-06-07. https://addyosmani.com/blog/loop-engineering — Tier 2, B3, sq4
[^33]: Caught in the Hook: RCE and API Token Exfiltration (CVE-2025-59536, CVE-2026-21852), Check Point Research, 2026-02-26. https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536 — Tier 1, A1, sq5
[^34]: Claude collaboration tools left the door wide open to RCE, The Register, 2026-02-26. https://www.theregister.com/security/2026/02/26/claudes-collaboration-tools-allowed-remote-code-execution/4753986 — Tier 2, B1, sq5
[^35]: AI Coding Assistants as Attack Surface, Cloud Security Alliance Labs, 2026-04-03. https://labs.cloudsecurityalliance.org/wp-content/uploads/2026/04/CSA_research_note_ai-coding-assistant-attack-surface_20260403-csa-styled.pdf — Tier 2, B1, sq5
[^36]: The lethal trifecta for AI agents, simonwillison.net, 2025-06-16. https://simonwillison.net/2025/Jun/16/the-lethal-trifecta — Tier 2, B2, sq5
[^37]: Claude Code Flaws Allow RCE and API Key Exfiltration, The Hacker News, 2026-02-26. https://thehackernews.com/2026/02/claude-code-flaws-allow-remote-code.html — Tier 2, B1, sq5
[^38]: CVE-2026-25725: Claude Code Privilege Escalation Flaw, SentinelOne, 2026-05-14. https://www.sentinelone.com/vulnerability-database/cve-2026-25725 — Tier 2, B2, sq5
[^39]: Claude Code Security Config (claude-guardrails), GitHub (dwarvesf). https://github.com/dwarvesf/claude-guardrails/blob/main/full/SETUP.md — Tier 3, C, sq5
[^40]: pre-commit — a framework for managing git pre-commit hooks, pre-commit.com. https://pre-commit.com — Tier 1, A2, sq6
[^41]: pre-commit vs. CI, switowski.com. https://switowski.com/blog/pre-commit-vs-ci — Tier 2, B2, sq6
[^42]: What are test hooks in AI-native development?, CircleCI. https://circleci.com/blog/test-hooks-ai-development — Tier 2, B2, sq6
[^43]: My LLM coding workflow going into 2026, addyosmani.com, 2026-01-04. https://addyosmani.com/blog/ai-coding-workflow — Tier 2, B2, sq6
[^44]: Discussion: Benefits and Drawbacks of the Git Pre-Commit Hook, Lobsters, 2025-10-09. https://lobste.rs/s/7ovnze/discussion_benefits_drawbacks_git_pre — Tier 2, B3, sq6
