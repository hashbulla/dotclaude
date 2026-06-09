# Claude Commands — slash commands and orchestration

Slash commands are user-invocable workflows. They orchestrate agents and skills via the `Agent` and `Skill` tools. They do NOT contain implementation logic themselves — they delegate.

## When to use a command

- The workflow has 2+ phases that should run in a specific order (research → plan → implement).
- The workflow ends with a deliverable file (REQUEST.md, RESEARCH.md, …).
- The user invokes it explicitly (vs auto-discovered skills).
- The workflow benefits from being repeatable and version-controlled.

## Frontmatter contract

```yaml
---
description: <one-line workflow description for /-menu>
model: opus | sonnet | haiku           # default model for the orchestration
allowed-tools: AskUserQuestion, Agent, Skill, Read, Write, …
argument-hint: "<expected-args>"
---
```

Body is the orchestration prose — the steps the command runs, in order.

## Commands are skills now (Claude Code 2026)

Claude Code merged custom commands into skills: `commands/<name>.md` and `skills/<name>/SKILL.md` both create `/<name>` and behave identically ([slash-commands docs](https://code.claude.com/docs/en/slash-commands), retrieved 2026-06-09). `commands/*.md` keep working and take the same frontmatter. Frontmatter is **optional but recommended** — with no `description`, the menu falls back to the file's first paragraph, which is why a bare `# /name — …` H1 still surfaces. All eight dotclaude commands now carry frontmatter for consistency. Add `disable-model-invocation: true` only for commands Claude must never auto-invoke; `/scrape`, `/research`, `/fetcher-pick` deliberately omit it so the autonomous triggers in CLAUDE.md can fire them.

## Subdirectory namespacing

`commands/<name>.md` → `/<name>`.
`commands/<dir>/<name>.md` → `/<dir>:<name>`.

dotclaude uses this for RPI: `commands/rpi/research.md` → `/rpi:research`.

## Commands orchestrate; agents execute

The cardinal rule: commands don't write code. They invoke agents that write code.

```
/rpi:implement (command)
  ↓ Agent(senior-software-engineer)
    ↓ writes code
    ↓ commits
    ↓ Agent(code-reviewer), Agent(security-reviewer), Agent(constitutional-validator) in parallel
      ↓ each writes findings
    ↓ Agent(documentation-analyst-writer)
      ↓ consolidates findings, downgrades uncited P0/P1
```

The command is the conductor; the agents are the orchestra.

## Native AskUserQuestion gates

Multi-step commands often need a user gate between phases. Use `AskUserQuestion`:

```yaml
allowed-tools: AskUserQuestion, Agent, Skill
```

Then in the body:

```
After Phase 1 completes, ask:
  AskUserQuestion(
    question="Phase 1 done. Continue to Phase 2?",
    options=["Yes", "Yes but pause for review", "No"]
  )
```

Don't proceed to Phase 2 without an explicit Yes.

## Command catalog (dotclaude)

| Command | Args | Purpose |
|---|---|---|
| `/research` | `<query>` | Tavily-first web research |
| `/domain-setup` | `<domain> <koyeb-app>` | Cloudflare Registrar + Koyeb peering |
| `/rpi:request` | `<feature description>` | First RPI phase — produce REQUEST.md |
| `/rpi:research` | `<feature-slug>` | Second RPI phase — produce RESEARCH.md |
| `/rpi:plan` | `<feature-slug>` | Third RPI phase — produce pm/ux/eng/PLAN.md |
| `/rpi:implement` | `<feature-slug>` | Fourth RPI phase — ship with reviewer trio |

## Built-in commands (Claude Code)

The platform ships a set Claude Code knows by name: `/help`, `/clear`, `/compact`, `/model`, `/status`, `/agents`, `/skills`, `/doctor`, `/init`, `/output-style`, `/config`, etc. These take precedence over user commands when names collide; pick different names.

## Anti-patterns

- Commands that implement logic inline (bypassing agents). Defeats reusability.
- Commands with `model: haiku` but invoking opus-required agents. Pick model per phase, not globally.
- Commands without `argument-hint` — users guess the args.
- Commands that fork without ever returning a deliverable — the user has nothing to point at.
- Subdirectory namespace nesting beyond 2 levels (`commands/a/b/c.md` is allowed but ugly to invoke).
