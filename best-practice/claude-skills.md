# Claude Skills — frontmatter and patterns

Skills are reusable, addressable knowledge units. Each skill lives in a directory with `SKILL.md` at the top. They appear in the `/-menu` for explicit invocation, can be auto-invoked by Claude based on description-driven matching, or can be preloaded into an agent's context.

## Two patterns

### 1. User-invocable skills (Skill tool)

Activated by user via `/<skill-name>` or by Claude auto-discovering based on description. The skill body is executed when invoked.

```yaml
---
name: <kebab-case>
description: <semantic-first, then trigger phrases — see ai-engineering rule>
argument-hint: "[arg-name]"
user-invocable: true              # appears in /-menu
disable-model-invocation: false   # auto-activation enabled
allowed-tools: <comma-separated>
model: opus | sonnet | haiku      # optional override
---
```

Example: `/critical-harness <repo-url>` → runs the adversarial review pipeline.

### 2. Agent-skills (preloaded knowledge)

Loaded into an agent's context at startup via the agent's `skills:` frontmatter. The skill body is *background knowledge*, not an action to invoke.

```yaml
# In an agent definition
---
name: my-agent
skills:
  - claude-api    # adds Anthropic SDK doctrine to my-agent's context
---
```

## Frontmatter reference (full)

```yaml
---
name: <kebab-case>                # slash command name
description: >                    # the load-bearing field for auto-discovery
  <First 100-200 chars: semantic activation criteria>
  Trigger phrases (FR + EN): ...
  Do NOT activate for: ...
argument-hint: "[positional]"     # autocomplete hint
user-invocable: true              # appears in /-menu
disable-model-invocation: false   # set true to disable auto-invocation
allowed-tools: <comma list>       # tools allowed without prompt during skill execution
model: opus | sonnet | haiku      # only when override needed
context: fork                     # run in isolated subagent (default: parent context)
agent: general-purpose            # which subagent type for context: fork
hooks:                            # lifecycle hooks scoped to this skill
  PreToolUse: ...
license: MIT                      # optional, for published skills
metadata:                         # optional arbitrary metadata
  version: 1.0.0
---
```

## description field — the load-bearing one

The `description` field drives auto-discovery. Best practice (cribbed from `skill-generator`):

1. **Lead with semantics**, NOT trigger lists. First 100-200 chars say what the skill does and when it fires.
2. **Then list trigger phrases** explicitly — FR + EN if multilingual.
3. **End with `Do NOT activate for:`** — overlapping intents the skill should NOT claim.

Without the negative-prefix list, sibling skills overlap and fire on the wrong intent. This is the most common skill failure mode.

## The 5 failure modes (skill-harness taxonomy)

1. **Silent** — skill never fires when it should. Cause: vague description, missing trigger phrases.
2. **Hijacker** — skill fires when it shouldn't. Cause: missing "Do NOT activate for" block.
3. **Drifter** — fires correctly then wanders off-task. Cause: missing scope guardrails in the body.
4. **Fragile** — works on hero queries, fails near-by ones. Cause: weak generalization, missing evals.
5. **Overachiever** — does more than asked. Cause: scope creep in the body, no done-definition.

## Reference files

Skills can carry supporting docs:

```
my-skill/
├── SKILL.md              # the spec
├── references/           # one level deep, NEVER cross-linked
│   ├── methodology.md
│   └── conventions.md
├── scripts/              # any runtime helpers
└── evals/                # hero query fixtures
    ├── loading.jsonl     # does the skill activate?
    ├── e2e.jsonl         # does it produce correct output?
    └── rubric.md         # how to score
```

**One-level-deep rule**: `references/<topic>.md` is fine. `references/<topic>/sub-topic.md` is not — Claude truncates when it has to chase chains.

## Inline skills vs symlinked vs auto-installed

dotclaude has three kinds:

1. **Inline** — `~/.claude/skills/<name>/` is a real directory committed to dotclaude. Shipped with the repo. Example: `synthese`.
2. **Auto-installed** — declared in `skills.manifest.toml`, cloned by `bootstrap.sh`, symlinked into `~/.claude/skills/`. 3 of them: `deep-research`, `critical-harness`, `claude-init`. (`skill-generator` and `skill-harness` are private — not-yet-public, not in the manifest.)
3. **Symlinked-out (third-party)** — symlinks to `~/.local/share/dotclaude/skills/<ecosystem>/<skill>`. Catalogued in `skills/EXTERNAL.md`. Not auto-installed; user clones the ecosystem repo manually.

## Verifying

```bash
ls -la ~/.claude/skills/        # shows symlinks vs real dirs
claude /skills list             # what Claude actually loads
```

## Anti-patterns

- `***` delimiters instead of `---` — silently disables the skill.
- `description` that's only trigger phrases, no semantics — silent skill.
- Reference files cross-linking other reference files — truncation.
- `allowed-tools` so wide that user prompts vanish — accidental destructive ops.
- Skill name in `name:` field that doesn't match the directory — confusion in `/-menu`.
