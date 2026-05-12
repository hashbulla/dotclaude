# Claude Subagents — frontmatter and orchestration

Subagents are isolated context forks. They run with their own context window, their own tool allow-list, and (optionally) their own working directory (`isolation: "worktree"`). Used right, they're the difference between a clean main session and a sprawling, lost-its-thread one.

## When to use a subagent

- The task needs ≥50% of the parent context's budget on its own.
- The task should be free of parent-session bias (e.g., adversarial review — see `code-reviewer`, `security-reviewer`).
- The task is recurring and worth a dedicated persona (the 10 RPI agents in `agents/`).
- The task can be parallelized with other independent work (run reviewer trio simultaneously).

## When NOT to use a subagent

- The task fits in 1-2 turns of the parent context — overhead outweighs benefit.
- The task needs to read the parent's intermediate reasoning — context forks lose that.
- The task is conversational — agents can't ask the user mid-stream (the parent has to).

## Frontmatter contract

```yaml
---
name: <kebab-case>                    # required
description: <one-line + "PROACTIVELY" if auto-invocation desired>
model: opus | sonnet | haiku | inherit  # default: inherit
color: <red|green|blue|...>            # CLI output color
tools: <explicit comma-separated>      # safer than wildcard
disallowedTools: <list>                # removes from inherited set
maxTurns: <N>                          # bound the agentic loop (default 5-10)
permissionMode: acceptEdits|plan|bypassPermissions
skills: [<skill-name>, ...]            # preloaded into agent context
mcpServers: [<server>, ...]            # MCP servers available
memory: user | project | local         # persistent memory scope
isolation: "worktree"                  # run in temp git worktree
background: true                       # always run async
effort: low | medium | high | max
hooks:                                 # agent-scoped lifecycle hooks
  PreToolUse: ...
---
```

The dotclaude RPI agents use a subset of these:

- **`requirement-parser`** — model: haiku, maxTurns: 5, no skills (fast extraction).
- **`code-reviewer` / `security-reviewer`** — model: opus, `isolation: worktree` (adversarial review needs context isolation), tools includes Tavily for Citation Grounding.
- **`constitutional-validator`** — model: sonnet (lighter — reads project rules, doesn't reason from scratch).
- **`senior-software-engineer`** — model: opus, maxTurns: 20, allowed to invoke other agents via `Agent(subagent_type=...)`.

## PROACTIVELY keyword

If you want Claude to auto-invoke the agent without an explicit `Agent(...)` call:

```yaml
description: PROACTIVELY use this agent when reviewing a security-sensitive diff.
```

The keyword triggers automatic delegation. Use sparingly — too many proactive agents = unpredictable orchestration.

## Worktree isolation

```yaml
isolation: "worktree"
```

Claude Code spawns the agent in a temporary git worktree. After completion the worktree is removed. Use for:

- Adversarial review — reviewer can't see parent's prior reasoning.
- Experimental refactors that you might throw away.
- Parallel work across multiple branches without checkout flips.

`code-reviewer` and `security-reviewer` use this in dotclaude.

## Agent → Agent invocation

Subagents **cannot** invoke other subagents via Bash. They must use the `Agent` tool:

```
Agent(subagent_type="code-reviewer", description="Review phase 1", prompt="...")
```

Vague verbs like "launch" or "run" can be misread as Bash commands. Be explicit in the agent's system prompt about using the `Agent` tool.

## Skills preloading

```yaml
skills: [deep-research, critical-harness]
```

These skills load into the agent's context at startup — useful for agents that always need certain doctrines available (e.g., RPI's `senior-software-engineer` might preload `claude-api` if working on Anthropic SDK code).

## Default agents in dotclaude

| Agent | Model | Color | When |
|---|---|---|---|
| `requirement-parser` | haiku | yellow | `/rpi:request` |
| `product-manager` | sonnet | cyan | `/rpi:research`, `/rpi:plan` |
| `technical-cto-advisor` | opus | magenta | `/rpi:research`, `/rpi:plan` |
| `ux-designer` | sonnet | pink | `/rpi:plan` (when feature has UX surface) |
| `senior-software-engineer` | opus | blue | `/rpi:plan`, `/rpi:implement` |
| `code-reviewer` | opus | red | `/rpi:implement` after each phase |
| `security-reviewer` | opus | red | `/rpi:implement` after each phase |
| `constitutional-validator` | sonnet | red | `/rpi:implement` after each phase |
| `performance-analyst` | opus | orange | on-demand within `/rpi:implement` |
| `documentation-analyst-writer` | sonnet | cyan | all RPI phases (assembler) |
| `pdf-design-evaluator` | (inherits) | — | adversarial PDF review |
| `project-memory-architect` | (inherits) | — | scaffolds project `.claude/` |
| `anti-patterns` (symlinked) | (inherits) | — | impeccable design anti-pattern detection |

## Verifying agent discovery

```bash
claude /agents list 2>/dev/null | head
ls ~/.claude/agents/*.md
```
