# External agents (symlinked into ~/.claude/agents/)

This file catalogs every agent in `~/.claude/agents/` that is a symlink pointing outside this repo. Inline (non-symlinked) agents live next to this file and don't need an entry here.

## What's symlinked here

| Agent file | Upstream symlink target | Provenance | Bootstrap action |
|---|---|---|---|
| [`anti-patterns.md`](anti-patterns.md) | `~/local-skills/Skills/impeccable/.claude/agents/anti-patterns.md` | [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) public repo | Documented; not auto-installed. Manually clone `pbakaus/impeccable` to `~/local-skills/Skills/impeccable` if needed. |

## Why these are symlinked, not vendored

The user keeps a single source of truth per agent. The `pbakaus/impeccable` repo is the canonical source for `anti-patterns.md`; checking in a copy here would diverge. The symlink is preserved; the upstream is documented.

## On a fresh machine

When you clone this dotclaude repo on a new machine and run `bootstrap.sh`, the script detects dangling symlinks and prints them. To resolve:

```bash
# Clone the upstream once
git clone https://github.com/pbakaus/impeccable.git \
  ~/local-skills/Skills/impeccable

# The symlink resolves automatically — no further action.
```

If you no longer use the `impeccable` ecosystem on this machine, delete the symlink:

```bash
rm ~/.claude/agents/anti-patterns.md
```

That removes the agent from your `/-menu` cleanly.
