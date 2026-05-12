---
paths: "**/prompts/**/*,**/agents/**/*,**/skills/**/*,**/llm/**/*,**/SKILL.md,**/AGENT.md"
description: AI / LLM engineering rules — prompt-cache aware, eval-first, no provider lock-in, citation discipline.
---

# AI engineering rules

These rules apply when you touch prompt files, agent definitions, skill specs, or any code path that calls an LLM. They reflect the user's strong-focus expertise area (AI Engineering) and matching standards.

## Eval-first

- **No production-bound agent or skill ships without evals.** Hero queries → `evals/loading.jsonl` (does the skill activate?) → `evals/e2e.jsonl` (does it produce the right output?) → `evals/rubric.md` (how do we score?).
- **The five failure modes**: silent (never fires), hijacker (fires when it shouldn't), drifter (fires correctly then wanders), fragile (works on hero queries, fails near-by ones), overachiever (does more than asked).
- **Skill calibration before trust** — see `~/.claude/skills/skill-harness/` for the adversarial-review pattern.

## Prompt-cache awareness

- **Stable prefixes go first**, dynamic suffix last. Anthropic's prompt cache hits on prefix equality.
- **System prompts are cacheable** when they don't carry dynamic per-request content. Lift dynamic bits into the user turn.
- **Long, stable references** (docs, schemas, examples) belong above the dynamic content. They cache for hours.
- **Measure cache hit rate** — for any production app, log `cache_creation_input_tokens` vs `cache_read_input_tokens` and aim for >80% read.

## Context engineering

- **Context budget** is real. Use the auto-compact override (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80` in our settings) to defend against silent truncation.
- **Skill SKILL.md ≤ ~150 lines.** Push details into `references/<topic>.md` (one level deep, never cross-linked — Claude truncates when it has to chase chains).
- **Prefer subagents (`context: fork`) over inline reasoning** when the work needs ~50%+ of the parent context.
- **`maxTurns` on every agent** — bound the agentic loop. Default 5-10; only raise for genuine multi-step research.

## Harness engineering

- **Adversarial review of every shippable AI artifact.** Skills go through `skill-harness`. Repos go through `critical-harness`. Code review in RPI is two adversarial reviewers (code + security), not one.
- **Worktree isolation for the Critic** when the reviewer must be free of parent-session bias. Frontmatter: `isolation: "worktree"`.
- **Citation Grounding on P0/P1 findings**: every high-severity finding cites a source (Tavily, vendor docs, RFC). Findings without citations are downgraded. Never softened.
- **Separate the Analyst from the Critic** — distinct agents, distinct contexts. The Analyst infers the charter; the Critic grades against it. Mixing them produces self-fulfilling reviews.

## Provider neutrality

- **No `import Anthropic` in shared interfaces.** Define a `ChatProvider` protocol; route through it.
- **Prompt formats stay text-and-XML where possible** — neutral, debuggable, doesn't depend on a specific tool-calling API.
- **Use Claude API native features (caching, citations, computer use, code execution) inside the Anthropic adapter** — don't leak them into provider-neutral layers.

## SKILL.md frontmatter conventions

```yaml
---
name: <kebab-case>
description: >
  <Lead with semantics, NOT trigger lists. The first 100-200 chars drive auto-activation.>
  <Then add trigger phrases (FR + EN) explicitly.>
  Do NOT activate for: <list of look-alike but distinct intents>.
argument-hint: "<positional-args-hint>"
user-invocable: true             # appears in /-menu
disable-model-invocation: false  # auto-activation enabled
allowed-tools: <comma-separated explicit list>
model: opus | sonnet | haiku     # only when override needed
context: fork                    # for isolated subagent execution
agent: <subagent-type>           # required if context: fork
---
```

The `description` field is load-bearing. Vague descriptions = silent skills.

## Anti-patterns

- ❌ Skill with trigger list but no `Do NOT activate for:` block — overlaps with sibling skills, fires on the wrong intent.
- ❌ Reference files that link to other reference files (one-level-deep rule violated).
- ❌ `***` instead of `---` as frontmatter delimiters — silently disables the skill.
- ❌ Hardcoded model names in shared code (`model='claude-3-opus-20240229'`); use aliases (`opus`) and let the platform resolve.
- ❌ Agents with `maxTurns: 100`. Either trust the agent (≤10 turns) or it's the wrong abstraction.
- ❌ Logging full conversation transcripts without PII filtering. Apply a redaction layer before any persistence.
