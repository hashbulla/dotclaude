# Claude Hooks — 27 events, async dispatcher, sound system

Hooks are Claude Code's reactive layer. They fire on lifecycle events (tool use, session start, agent stop, file change, etc.) and run a shell command. dotclaude wires all 27 events to a single Python dispatcher.

## Why a single dispatcher

The reference repo (`shanraisshan/claude-code-best-practice`) used one Python script for all 27 events. Three reasons it's the right shape:

1. **One place to add new behaviors.** All hook side-effects live in `hooks/scripts/hooks.py`.
2. **Async, non-blocking by default.** Every hook in `settings.json` has `async: true` so failures never block Claude's work.
3. **Per-event toggles via `hooks-config.json`** without editing `settings.json`.

## Event surface

| Event | When | Default sound |
|---|---|---|
| `PreToolUse` | Before a tool call | enabled (disabled in conf — noisy) |
| `PostToolUse` | After a successful tool call | disabled by default (noisy) |
| `PostToolUseFailure` | Tool call failed | enabled |
| `PermissionRequest` | User prompted to approve | enabled |
| `PermissionDenied` | User declined | enabled |
| `UserPromptSubmit` | User submitted a prompt | disabled |
| `Notification` | Claude needs attention | enabled |
| `Stop` | Turn complete | enabled |
| `StopFailure` | Turn ended in error | enabled |
| `SubagentStart` | Agent tool spawned | disabled |
| `SubagentStop` | Agent returned | enabled |
| `PreCompact` | Before context compaction | enabled (once) |
| `PostCompact` | After compaction | disabled |
| `SessionStart` | New session | enabled (once) |
| `SessionEnd` | Session ended | disabled |
| `Setup` | Setup MCP/skill discovery | disabled (chatty at session boot) |
| `TeammateIdle` | Parallel session idle | disabled |
| `TaskCreated`, `TaskCompleted` | Task lifecycle | TaskCompleted only |
| `ConfigChange` | settings.json changed | disabled |
| `WorktreeCreate`, `WorktreeRemove` | Git worktree lifecycle | disabled |
| `InstructionsLoaded` | New CLAUDE.md loaded | disabled |
| `Elicitation`, `ElicitationResult` | MCP elicitation lifecycle | disabled |
| `CwdChanged` | Working directory changed | disabled |
| `FileChanged` | Matcher-filtered file edit | disabled (matcher: `.envrc|.env|.env.local`) |

Toggles live in `~/.claude/hooks/config/hooks-config.json`. Per-machine overrides in `hooks-config.local.json`.

## Quiet mode

Two env vars short-circuit the dispatcher before any sound or log:

```bash
SOUNDS_DISABLED=1 claude     # silent for this session
CLAUDE_QUIET=1 claude        # alias
```

Useful for SSH sessions, CI, recordings, late-night work.

## Audio chain

The dispatcher detects the platform and picks an audio player:

- **macOS**: `afplay` (built-in).
- **Linux**: `paplay` → `aplay` → `ffplay` → `mpg123` (first one available).
- **Windows**: `winsound` module, WAV only.

dotclaude ships both `.wav` and `.mp3` for each sound. PulseAudio (paplay) doesn't support MP3; the dispatcher tries `.wav` first.

## Logging

Every event the dispatcher receives is appended to `~/.claude/hooks/logs/hooks-log.jsonl` (gitignored — see `.gitignore`). Disable via `disableLogging: true` in `hooks-config.json` or `hooks-config.local.json`.

## Agent-scoped hooks

When an agent definition (`agents/<name>.md`) declares its own hooks via frontmatter, the dispatcher uses `agent_*` sound folders for the 6 supported events: PreToolUse, PostToolUse, PermissionRequest, PostToolUseFailure, Stop, SubagentStop. Invoke with `--agent=<name>`.

## Special handling

The dispatcher pattern-matches Bash commands and swaps the sound when relevant:

- `git commit` → `pretooluse-git-committing.wav`

Add more patterns by editing `BASH_PATTERNS` at the top of `hooks.py`.

## Extending

Adding a new hook reaction:

1. Add behavior to `hooks.py` (new `get_sound_name` branch, or a new function).
2. Add a sound file under `sounds/<event-lowercase>/<name>.{wav,mp3}` if you want audio.
3. Add a toggle (`disable<Event>Hook`) to `hooks-config.json` if needed.

No `settings.json` change required — the hook event is already wired to the dispatcher.

## Verifying

```bash
python3 ~/.claude/hooks/scripts/hooks.py --dry-run
echo '{"hook_event_name":"Stop"}' | python3 ~/.claude/hooks/scripts/hooks.py
```

First confirms imports + sound tree. Second triggers a fake Stop event end-to-end.
