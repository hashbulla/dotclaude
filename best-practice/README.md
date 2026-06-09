# Best-Practice Doctrine

> Doctrine documents — the *why* behind every layer of dotclaude. Each doc is single-topic, links to the assets that implement the doctrine, and is kept under ~100 lines.

| Doc | Topic | Implements |
|---|---|---|
| [claude-memory.md](claude-memory.md) | CLAUDE.md design — <200 lines, @ imports, ancestor loading | [`../CLAUDE.md`](../CLAUDE.md), `../identity.md`, `../profile.md` |
| [claude-settings.md](claude-settings.md) | Settings hierarchy: managed → CLI → local → shared → global | [`../settings.json`](../settings.json), [`../settings.example.local.json`](../settings.example.local.json) |
| [claude-hooks.md](claude-hooks.md) | 27 hook events, async dispatcher, sound system, env-var bail | [`../hooks/scripts/hooks.py`](../hooks/scripts/hooks.py), [`../hooks/config/hooks-config.json`](../hooks/config/hooks-config.json) |
| [claude-subagents.md](claude-subagents.md) | Agent frontmatter, PROACTIVELY, model/effort/isolation | [`../agents/`](../agents/) |
| [claude-skills.md](claude-skills.md) | Skill frontmatter; agent-skills vs Skill-tool skills | [`../skills/`](../skills/), [`../skills.manifest.toml`](../skills.manifest.toml) |
| [claude-commands.md](claude-commands.md) | Slash commands, namespacing via subdirs, orchestration | [`../commands/`](../commands/) |
| [claude-rules.md](claude-rules.md) | `paths:` lazy loading; when to use rules vs CLAUDE.md | [`../rules/`](../rules/) |
| [claude-mcp.md](claude-mcp.md) | MCP server design; Tavily-first search routing doctrine | [`../CLAUDE.md`](../CLAUDE.md) (MCP Registry section) |
| [rpi-workflow.md](rpi-workflow.md) | Research → Plan → Implement with Citation Grounding | [`../commands/rpi/`](../commands/rpi/), [`../agents/`](../agents/) |
| [code-generation.md](code-generation.md) | Prime→spec/TDD→review→verify; do-directly default, discipline as backstop | [`../rules/code-generation.md`](../rules/code-generation.md), [`../CLAUDE.md`](../CLAUDE.md) (Code Gen routing + triggers) |

## How to read this

If you're skimming, start with `claude-memory.md` and `rpi-workflow.md` — those two carry the most weight.

If you're modifying dotclaude, find the doctrine file whose surface you're touching and read it before you change the implementation. The doctrine doc is the contract; the implementation is the evidence.
