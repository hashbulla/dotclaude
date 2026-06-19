#!/usr/bin/env python3
"""Generate research-sources.json + research-evidence.json for AI-177.

Mirrors the deep-research skill's normative cascade (references/methodology.md
§4.1) so the persisted credibility/label/counts match what verify_gates.py
recomputes. Compute, don't self-report.
"""
from __future__ import annotations
import json
from urllib.parse import urlsplit

ACCESSED = "2026-06-19"
TIER_ADMIRALTY = {1: "A", 2: "B", 3: "C", 4: "D"}
LABELS = {1: "CONFIRMED", 2: "PROBABLY TRUE", 3: "POSSIBLY TRUE",
          4: "DOUBTFUL", 5: "IMPROBABLE", 6: "UNVERIFIED"}


def cascade(s12: int, s1: int, c: int) -> int:
    if s12 >= 2 and c == 0:
        return 1
    if s1 >= 1 and c == 0:
        return 2
    if s12 >= 2 and c == 1:
        return 2
    if s12 == 1 and c == 0:
        return 3
    if s12 >= 1 and c >= 1:
        return 4
    if c >= 2:
        return 5
    return 6


# key: (url, title, publisher, author, published_date, tier, score, tool, query, primary, notes, subqs)
LOW = "Tier-1/2 authority source manually retained; Tavily relevance score reflects broad query phrasing, not source quality (methodology §3.1 carve-out)."
EXTRACTED = "Extracted via tavily_extract (score-less); admitted as a Tier-3 PRIMARY-ABOUT-ITSELF source — the marketplace describing its own features. Any claim resting on it alone is capped at UNVERIFIED."
S = {
 # sq1
 "ghuntley_ralph": ("https://ghuntley.com/ralph", "Ralph Wiggum as a \"software engineer\"", "ghuntley.com", "Geoffrey Huntley", "2025-07-14", 2, 0.719, "tavily_search", "Geoffrey Huntley Ralph Wiggum agentic loop coding agents", True, LOW, ["sq1"]),
 "ghuntley_bio": ("https://ghuntley.com/bio", "Geoffrey Huntley — bio", "ghuntley.com", "Geoffrey Huntley", None, 2, 0.904, "tavily_search", "Geoffrey Huntley Ralph Wiggum agentic loop coding agents", True, "", ["sq1"]),
 "ghuntley_loop": ("https://ghuntley.com/loop", "everything is a ralph loop", "ghuntley.com", "Geoffrey Huntley", None, 2, 0.727, "tavily_search", "Geoffrey Huntley everything is a ralph loop", True, "", ["sq1", "sq4"]),
 "venturebeat_ralph": ("https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now", "How Ralph Wiggum went from 'The Simpsons' to the biggest name in AI right now", "VentureBeat", None, None, 2, 0.770, "tavily_search", "Ralph Wiggum loop Claude Code one-shot vs iterative agentic coding 2025 origin", False, "", ["sq1"]),
 "tessl_ralph": ("https://tessl.io/blog/unpacking-the-unpossible-logic-of-ralph-wiggumstyle-ai-coding", "The 'unpossible' logic of Ralph Wiggum-style AI coding", "Tessl", None, None, 2, 0.756, "tavily_search", "Ralph Wiggum style AI coding Huntley compaction", False, "", ["sq1"]),
 "anthropic_longrunning": ("https://www.anthropic.com/research/long-running-Claude", "Long-running Claude for scientific computing", "Anthropic", None, None, 1, 0.536, "tavily_search", "ralph loop claude code orchestration pattern long running", True, LOW, ["sq1", "sq2"]),
 "gh_wiggumdev": ("https://github.com/wiggumdev/ralph", "Ralph Wiggum agentic loop TUI", "GitHub (wiggumdev)", None, None, 2, 0.834, "tavily_search", "Ralph Wiggum agentic loop github", False, "", ["sq1"]),
 "gh_vercel_ralph": ("https://github.com/vercel-labs/ralph-loop-agent", "ralph-loop-agent: continuous autonomy for the AI SDK", "GitHub (Vercel Labs)", None, None, 2, 0.774, "tavily_search", "ralph loop agent vercel ai sdk", False, "", ["sq1"]),
 # sq2
 "anthropic_measuring": ("https://www.anthropic.com/research/measuring-agent-autonomy", "Measuring AI agent autonomy in practice", "Anthropic", None, "2026-02-18", 1, 0.6348, "tavily_search", "Claude agent autonomy human oversight interrupt exit conditions", True, LOW, ["sq2"]),
 "anthropic_contain": ("https://www.anthropic.com/engineering/how-we-contain-claude", "How we contain Claude across products", "Anthropic", None, "2026-05-25", 1, 0.808, "tavily_search", "Anthropic Claude Code hooks security containment devcontainer", True, "", ["sq2", "sq5"]),
 "anthropic_nist": ("https://www-cdn.anthropic.com/43ec7e770925deabc3f0bc1dbf0133769fd03812.pdf", "Anthropic response to NIST RFI on Agentic Security", "Anthropic", None, "2026-03-09", 1, 0.6922, "tavily_search", "Anthropic agentic security oversight human in the loop", True, LOW, ["sq2"]),
 "anthropic_context_eng": ("https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents", "Effective context engineering for AI agents", "Anthropic", None, None, 1, 0.3258, "tavily_search", "context rot degradation LLM agent recall long context", True, LOW, ["sq2"]),
 "anthropic_harnesses": ("https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents", "Effective harnesses for long-running agents", "Anthropic", None, "2025-11-26", 1, 0.4455, "tavily_search", "harness long running agents initializer progress artifacts", True, LOW, ["sq2"]),
 "arxiv_testrepair": ("https://arxiv.org/html/2605.01471v1", "Practical Limits of Autonomous Test Repair: A Multi-Agent Case Study", "arXiv", None, None, 1, 0.4309, "tavily_search", "autonomous test repair false green assertion weakening LLM agent", True, LOW, ["sq2"]),
 "arxiv_harness": ("https://arxiv.org/html/2605.23950v1", "Stop Comparing LLM Agents Without Disclosing the Harness", "arXiv", None, None, 1, 0.3551, "tavily_search", "agent harness variance model ranking reversal", True, LOW, ["sq2"]),
 "arxiv_sast": ("https://arxiv.org/html/2601.22952v1", "Sifting the Noise: LLM Agents in Vulnerability False-Positive Filtering", "arXiv", None, None, 1, 0.5121, "tavily_search", "agentic SAST false positive filtering reduction LLM", True, LOW, ["sq2"]),
 "arxiv_drift": ("https://arxiv.org/html/2601.04170v1", "Agent Drift: Quantifying Behavioral Degradation in Multi-Agent LLM Systems", "arXiv", None, None, 1, 0.3400, "tavily_search", "agent drift behavioral degradation multi agent extended interaction", True, LOW, ["sq2"]),
 "arxiv_refute": ("https://arxiv.org/html/2604.19049v1", "Refute-or-Promote: Adversarial Stage-Gated Multi-Agent Review", "arXiv", None, None, 1, 0.3129, "tavily_search", "adversarial stage gated review false positive defect discovery independent verifier", True, LOW, ["sq2"]),
 # sq3
 "docs_hooks": ("https://docs.anthropic.com/en/docs/claude-code/hooks", "Hooks reference — Claude Code Docs", "Anthropic", None, None, 1, 0.885, "tavily_search", "Claude Code hooks PreToolUse PostToolUse Stop SubagentStop exit code 2", True, "", ["sq3"]),
 "docs_hooks_guide": ("https://docs.anthropic.com/en/docs/claude-code/hooks-guide", "Automate actions with hooks — Claude Code Docs", "Anthropic", None, None, 1, 0.984, "tavily_search", "Claude Code Stop hook additionalContext continue limits", True, "", ["sq3"]),
 "gh_issue_37559": ("https://github.com/anthropics/claude-code/issues/37559", "Hook documentation is misleading — prompt hooks can't inject context (#37559)", "GitHub (anthropics/claude-code)", None, None, 2, 0.978, "tavily_search", "Claude Code prompt hook cannot inject additionalContext", False, "", ["sq3"]),
 "gh_issue_3656": ("https://github.com/anthropics/claude-code/issues/3656", "Restore Blocking Stop Command Hooks (#3656)", "GitHub (anthropics/claude-code)", None, None, 2, 0.817, "tavily_search", "Claude Code blocking stop hook exit code 2", False, "", ["sq3"]),
 "gh_issue_10412": ("https://github.com/anthropics/claude-code/issues/10412", "Stop hooks with exit code 2 fail to continue when installed via plugins (#10412)", "GitHub (anthropics/claude-code)", None, None, 2, 0.751, "tavily_search", "Claude Code stop hook plugin exit code 2 ignored", False, "", ["sq3"]),
 "morphllm_hooks": ("https://www.morphllm.com/claude-code-hooks", "Claude Code & Agent SDK Hooks (2026)", "Morph LLM", None, None, 2, 0.873, "tavily_search", "Claude Code hooks Stop SubagentStop block continue 2026", False, "", ["sq3"]),
 "claudefast_hooks": ("https://claudefa.st/blog/tools/hooks/hooks-guide", "Claude Code Hooks: Complete Guide to All 12 Lifecycle Events", "Claude Fast", None, None, 2, 0.827, "tavily_search", "Claude Code hooks lifecycle events block exit code 2", False, "", ["sq3"]),
 "gist_loop": ("https://gist.github.com/sorrycc/1b2166228413234928039e84a26a3b8f", "loop command implementation analysis in Claude Code 2.1.71", "GitHub Gist (sorrycc)", None, None, 2, 0.797, "tavily_search", "Claude Code /loop command kairos cron interval implementation", False, "", ["sq3"]),
 # sq4 — the subject (Tier 3, primary-about-itself)
 "loops_home": ("https://loops.elorm.xyz", "loops! | Pre-built agent loops", "loops.elorm.xyz", "elorm", None, 3, 0.514, "tavily_search", "loops.elorm.xyz marketplace coding agents", False, EXTRACTED, ["sq4"]),
 "loops_browse": ("https://loops.elorm.xyz/loops", "Browse loops | loops!", "loops.elorm.xyz", "elorm", None, 3, None, "tavily_extract", "extract loops.elorm.xyz/loops", False, EXTRACTED, ["sq4"]),
 "loops_install": ("https://loops.elorm.xyz/install", "How to install loops | loops!", "loops.elorm.xyz", "elorm", None, 3, None, "tavily_extract", "extract loops.elorm.xyz/install", False, EXTRACTED, ["sq4"]),
 "elorm_home": ("https://elorm.xyz", "elorm.tsx — Creative Software Engineer", "elorm.xyz", "elorm", None, 3, None, "tavily_extract", "extract elorm.xyz author provenance", False, EXTRACTED, ["sq4"]),
 "prompts_elorm": ("https://prompts.elorm.xyz", "prompts! | AI prompts that work", "prompts.elorm.xyz", "elorm", None, 3, None, "tavily_extract", "extract prompts.elorm.xyz sibling site", False, EXTRACTED, ["sq4"]),
 "addyosmani_loopeng": ("https://addyosmani.com/blog/loop-engineering", "Loop Engineering", "addyosmani.com", "Addy Osmani", "2026-06-07", 2, 0.383, "tavily_search", "loop engineering coding agents kickoff gate exit", False, LOW, ["sq4"]),
 # sq5
 "checkpoint_cve": ("https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536", "Caught in the Hook: RCE and API Token Exfiltration via Claude Code Project Files (CVE-2025-59536, CVE-2026-21852)", "Check Point Research", None, "2026-02-26", 1, 0.876, "tavily_search", "Claude Code hooks settings.json arbitrary command execution CVE-2025-59536", True, "", ["sq5"]),
 "theregister_rce": ("https://www.theregister.com/security/2026/02/26/claudes-collaboration-tools-allowed-remote-code-execution/4753986", "Claude collaboration tools left the door wide open to remote code execution", "The Register", None, "2026-02-26", 2, 0.756, "tavily_search", "Claude Code remote code execution hooks settings.json CVE", False, "", ["sq5"]),
 "csa_attacksurface": ("https://labs.cloudsecurityalliance.org/wp-content/uploads/2026/04/CSA_research_note_ai-coding-assistant-attack-surface_20260403-csa-styled.pdf", "AI Coding Assistants as Attack Surface: Code, Skills, and Secrets", "Cloud Security Alliance Labs", None, "2026-04-03", 2, 0.849, "tavily_search", "coding agent skills marketplace hook bundle supply chain malicious ClawHub IDEsaster", True, "", ["sq5"]),
 "simonw_trifecta": ("https://simonwillison.net/2025/Jun/16/the-lethal-trifecta", "The lethal trifecta for AI agents", "simonwillison.net", "Simon Willison", "2025-06-16", 2, 0.690, "tavily_search", "lethal trifecta prompt injection private data exfiltration AI agents", True, LOW, ["sq5"]),
 "thehackernews_cve": ("https://thehackernews.com/2026/02/claude-code-flaws-allow-remote-code.html", "Claude Code Flaws Allow Remote Code Execution and API Key Exfiltration", "The Hacker News", None, "2026-02-26", 2, 0.830, "tavily_search", "Claude Code flaws RCE API key exfiltration hooks", False, "", ["sq5"]),
 "sentinelone_cve": ("https://www.sentinelone.com/vulnerability-database/cve-2026-25725", "CVE-2026-25725: Claude Code Privilege Escalation Flaw", "SentinelOne", None, "2026-05-14", 2, 0.749, "tavily_search", "CVE-2026-25725 Claude Code sandbox escape settings.json hook", False, "", ["sq5"]),
 "dwarvesf_guardrails": ("https://github.com/dwarvesf/claude-guardrails/blob/main/full/SETUP.md", "Claude Code Security Config (claude-guardrails)", "GitHub (dwarvesf)", None, None, 3, 0.706, "tavily_search", "Claude Code supply chain malicious .claude directory hooks guardrails", False, "", ["sq5"]),
 # sq6
 "precommit_official": ("https://pre-commit.com", "pre-commit — a framework for managing git pre-commit hooks", "pre-commit.com", None, None, 1, 0.488, "tavily_search", "pre-commit hooks bypass no-verify SKIP fast checks", True, LOW, ["sq6"]),
 "switowski_precommit": ("https://switowski.com/blog/pre-commit-vs-ci", "pre-commit vs. CI", "switowski.com", None, None, 2, 0.434, "tavily_search", "pre-commit vs CI slow tests blocking bypass developer experience", False, LOW, ["sq6"]),
 "circleci_testhooks": ("https://circleci.com/blog/test-hooks-ai-development", "What are test hooks in AI-native development?", "CircleCI", None, None, 2, 0.565, "tavily_search", "AI coding agent hooks deterministic test gate CLAUDE.md compaction", False, LOW, ["sq6"]),
 "addyosmani_aiworkflow": ("https://addyosmani.com/blog/ai-coding-workflow", "My LLM coding workflow going into 2026", "addyosmani.com", "Addy Osmani", "2026-01-04", 2, 0.611, "tavily_search", "AI coding agent refuse done until tests pass workflow 2026", False, LOW, ["sq6"]),
 "lobsters_precommit": ("https://lobste.rs/s/7ovnze/discussion_benefits_drawbacks_git_pre", "Discussion: Benefits and Drawbacks of the Git Pre-Commit Hook", "Lobsters", None, "2025-10-09", 2, 0.424, "tavily_search", "pre-commit hooks value team maturity CI annoyance", False, LOW, ["sq6"]),
}

# Assign sequential ids in insertion order
keys = list(S.keys())
ids = {k: f"S{idx+1:03d}" for idx, k in enumerate(keys)}

sources_out = []
for k in keys:
    url, title, pub, author, pdate, tier, score, tool, query, primary, notes, subqs = S[k]
    host = (urlsplit(url).hostname or "").lower()
    path = urlsplit(url).path or ""
    canonical = host + path.rstrip("/")
    sources_out.append({
        "id": ids[k], "url": url, "url_canonical": canonical, "url_punycode": canonical,
        "title": title, "publisher": pub, "author": author,
        "published_date": pdate, "accessed_date": ACCESSED,
        "domain_tier": tier, "admiralty_reliability": TIER_ADMIRALTY[tier],
        "tavily_score": score, "retrieval_tool": tool, "retrieval_query": query,
        "sub_questions": subqs, "primary_source": primary, "notes": notes,
    })

# claims: (claim_id, text, section, [support keys])
SEC_ES = "Executive summary"
SEC1 = "1. The agentic loop pattern (Ralph) and its 2025-26 state"
SEC2 = "2. When agentic loops help vs. hurt"
SEC3 = "3. Claude Code enforcement mechanics: hooks and /loop"
SEC4 = "4. The loops! marketplace"
SEC5 = "5. Supply-chain and security posture of loop/hook bundles"
SEC6 = "6. Forced vs. opt-in: when to lock a loop"
NV = "Needs Verification"

CLAIMS = [
 ("C001", "On long-horizon agentic coding the execution harness (the loop scaffold around the model) is often a stronger determinant of success than the model itself, with harness-induced variance exceeding model-induced variance.", SEC_ES, ["arxiv_harness", "anthropic_harnesses"]),
 ("C002", "Claude Code hooks can deterministically block a tool call and force the agent not to stop, but they cannot direct the model's reasoning or guarantee its next action — they only block, inject context, or mutate inputs.", SEC_ES, ["docs_hooks", "docs_hooks_guide"]),
 ("C003", "A repository's .claude/settings.json hooks are a proven remote-code-execution attack surface (CVE-2025-59536, CVSS 8.7): the hook fired on startup before any trust prompt, so merely opening a cloned repo executed attacker code.", SEC_ES, ["checkpoint_cve", "thehackernews_cve", "anthropic_contain"]),
 ("C004", "Mandatory (blocking) hooks are the right tool for cheap, irreversible checks (secret leaks, lint, format) but the wrong tool for slow checks, which drive systematic bypass and belong in CI.", SEC_ES, ["precommit_official", "switowski_precommit"]),

 ("C101", "Geoffrey Huntley coined the 'Ralph Wiggum' agentic loop, first described May 2025 with the canonical post on 2025-07-14.", SEC1, ["ghuntley_bio", "venturebeat_ralph", "tessl_ralph"]),
 ("C102", "In its canonical form Ralph is a bash while-loop that feeds a coding agent the same prompt repeatedly until a completion condition is met.", SEC1, ["ghuntley_ralph", "gh_wiggumdev", "gh_vercel_ralph"]),
 ("C103", "Ralph's defining mechanic is resetting the agent's context window between iterations while persisting state externally (git, progress files), the opposite of one-shot prompting's single accumulating context.", SEC1, ["ghuntley_ralph", "gh_wiggumdev", "anthropic_longrunning"]),
 ("C104", "The pattern is named after the Simpsons character Ralph Wiggum, embodying naive persistence despite repeated failure.", SEC1, ["gh_wiggumdev", "tessl_ralph"]),
 ("C105", "Anthropic has adopted the Ralph loop as a documented orchestration pattern — a for-loop that kicks the agent back into context when it claims completion and asks whether it is really done.", SEC1, ["anthropic_longrunning", "venturebeat_ralph"]),
 ("C106", "By late 2025 Anthropic packaged the community technique into an official ralph-wiggum plugin in the Claude Code marketplace.", SEC1, ["venturebeat_ralph", "tessl_ralph"]),

 ("C201", "Claude Code auto-approve usage rises with experience (~20% of new-user sessions to over 40% for experienced users), i.e. autonomy scales with trust.", SEC2, ["anthropic_measuring", "anthropic_contain"]),
 ("C202", "Agent-initiated pauses are a critical oversight signal: on the most complex tasks the agent stops to ask for clarification more than twice as often as humans interrupt it.", SEC2, ["anthropic_measuring", "anthropic_contain"]),
 ("C203", "Human approval is an unreliable safeguard at scale: telemetry showed ~93% of permission prompts approved, with attention declining as volume rises.", SEC2, ["anthropic_contain"]),
 ("C204", "Autonomous loops can game their own verification gate ('false green'): test-repair agents weakened assertions and deleted tests to reach superficial passing states.", SEC2, ["arxiv_testrepair"]),
 ("C205", "Long-horizon multi-session work depends on an explicit harness (initializer plus progress artifacts); even a frontier model in a loop fails to produce production-quality output from only a high-level prompt.", SEC2, ["anthropic_harnesses", "arxiv_harness"]),
 ("C206", "Context is a finite, degrading resource: recall accuracy falls as the context window grows ('context rot'), motivating context resets and external memory in long loops.", SEC2, ["anthropic_context_eng", "anthropic_harnesses"]),
 ("C207", "Same-generator verification is unsafe; adversarial, independent stage-gated review catches confident-but-wrong findings that a self-checking loop endorses.", SEC2, ["arxiv_refute"]),

 ("C301", "A PreToolUse hook returning exit code 2 (or permissionDecision deny) blocks the tool call before it executes.", SEC3, ["docs_hooks", "claudefast_hooks"]),
 ("C302", "A PostToolUse hook cannot block — the tool already ran; it can only inject feedback context.", SEC3, ["docs_hooks", "claudefast_hooks"]),
 ("C303", "A Stop hook returning exit code 2 / decision:block prevents Claude from stopping and forces the conversation to continue.", SEC3, ["docs_hooks", "morphllm_hooks"]),
 ("C304", "SubagentStop mirrors Stop semantics, preventing a subagent from stopping.", SEC3, ["docs_hooks", "morphllm_hooks"]),
 ("C305", "A Stop hook that always exits 2 creates an infinite loop; it must be gated on a real check that returns exit 0 once cleared.", SEC3, ["morphllm_hooks", "claudefast_hooks"]),
 ("C306", "Stop-hook blocking has had reliability regressions, notably for hooks installed via plugins rather than the .claude/hooks path.", SEC3, ["gh_issue_10412", "gh_issue_3656"]),

 ("C401", "'Loop engineering' — designing a kickoff plus feedback gate plus exit condition for coding agents — has emerged as a named, independently discussed practice in 2026, of which loops! is one catalog.", SEC4, ["addyosmani_loopeng", "ghuntley_loop"]),

 ("C501", "CVE-2026-21852 let a project's .claude/settings.json override ANTHROPIC_BASE_URL to route API traffic through an attacker proxy and steal API keys before any trust prompt.", SEC5, ["checkpoint_cve", "thehackernews_cve"]),
 ("C502", "In-house/native loops (the /loop skill, an audited ralph plugin) carry lower supply-chain risk than third-party install bundles, and Anthropic's recommended containment is a devcontainer perimeter rather than per-action trust in the bundle.", SEC5, ["anthropic_contain", "csa_attacksurface"]),

 ("C601", "Client-side hook enforcement is always bypassable (git commit --no-verify, unsetting core.hooksPath), so a local hook is an aid, not a guarantee.", SEC6, ["precommit_official", "switowski_precommit"]),
 ("C602", "Slow checks (full test suites) are unsuitable for blocking pre-commit hooks and belong in CI; blocking inverts cost-benefit once waits exceed a second or two.", SEC6, ["switowski_precommit", "precommit_official"]),
 ("C603", "Deterministic hooks counter a structural LLM failure: agents forget or ignore CLAUDE.md instructions over long sessions and after context compaction, so a hook enforces what a prompt cannot.", SEC6, ["circleci_testhooks", "addyosmani_aiworkflow"]),
 ("C604", "The robust pattern is defense-in-depth: fast checks as local hooks plus an authoritative, bypass-resistant server-side CI gate.", SEC6, ["switowski_precommit", "circleci_testhooks"]),
 ("C605", "Git pre-commit and CI gating are established prior art that AI-agent loop enforcement directly parallels — the design questions are not new.", SEC6, ["precommit_official", "circleci_testhooks"]),

 # Needs Verification (Tier-3-only -> credibility 6)
 ("C701", "loops! exposes three trigger types (manual, event, interval) and a loop-entry anatomy of goal, max iterations, between-iterations check command, exit condition, kickoff prompt, and optional hook install bundle.", NV, ["loops_browse", "loops_install"]),
 ("C702", "loops! self-reports per-loop traction (copy and install counters in the high hundreds to low thousands) and a 'going viral' support appeal, with no external corroboration found.", NV, ["loops_home"]),
 ("C703", "Third-party coding-agent skill/extension marketplaces have been weaponized at scale (e.g. the ClawHub/ClawHavoc campaign; IDEsaster found 100% of ten tested AI IDEs prompt-injectable).", SEC5, ["csa_attacksurface"]),
]

tier_by_id = {s["id"]: s["domain_tier"] for s in sources_out}
evidence_out = []
for cid, text, section, sup_keys in CLAIMS:
    sup = [ids[k] for k in sup_keys]
    stiers = [tier_by_id[r] for r in sup]
    s12 = sum(1 for t in stiers if t <= 2)
    s1 = sum(1 for t in stiers if t == 1)
    cred = cascade(s12, s1, 0)
    evidence_out.append({
        "claim_id": cid, "claim_text": text, "section": section,
        "supporting_source_ids": sup, "contradicting_source_ids": [],
        "admiralty_credibility": cred, "label": LABELS[cred],
        "corroboration_count": len(set(sup)), "independent_tier12_count": s12,
        "primary_source_present": any(
            next(s for s in sources_out if s["id"] == r)["primary_source"] for r in sup),
        "notes": "",
    })

with open("research-sources.json", "w", encoding="utf-8") as f:
    json.dump(sources_out, f, indent=2, ensure_ascii=False)
with open("research-evidence.json", "w", encoding="utf-8") as f:
    json.dump(evidence_out, f, indent=2, ensure_ascii=False)

# quick local stats
n = len(evidence_out)
corr = sum(1 for c in evidence_out if c["independent_tier12_count"] >= 2)
t12 = sum(1 for s in sources_out if s["domain_tier"] <= 2)
print(f"sources={len(sources_out)} t1/2={t12} ({t12/len(sources_out):.3f})")
print(f"claims={n} corroborated={corr} ({corr/n:.3f})")
print("cred dist:", {k: sum(1 for c in evidence_out if c['admiralty_credibility'] == k) for k in range(1, 7)})
