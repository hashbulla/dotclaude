# Claude Code on Koyeb with Channels — TTY/headless follow-up

> Research date: 2026-04-29 · Builds on `~/.claude/playbooks/claude-code-koyeb-channels/research-report.md` (do not contradict)
> Sources: 9 cited (Tier 1: code.claude.com docs ×4, GitHub issues ×3; Tier 2: third-party guides ×2)

## TL;DR

- **There is no `--headless` / `--daemon` / `--no-tty` flag and no env var (`CLAUDE_CODE_HEADLESS`, `FORCE_TTY`) to disable the print-mode auto-detection.** The full v2.1.123 flag list at `code.claude.com/docs/en/cli-reference` has no TTY-bypass switch; `code.claude.com/docs/en/env-vars` exposes none either. The Anthropic-documented pattern for keeping `claude --channels` alive on a server is **tmux / screen** — multiple guides converge on it.
- **The `script -q -e -c … /dev/null` PTY-allocation approach is the correct headless workaround.** Matches the published Yieldcode.blog Docker recipe (`docker compose run claude script -q -c "claude --continue" /dev/null`). The `script -qec` failure documented in issue #36001 is for `--output-format stream-json --input-format stream-json` (Ink raw-mode bug) — different invocation than `--channels`.
- **Concrete next-action: keep `script -q -e -c`, but harden it.** Add `</dev/null` *inside* the wrapped command as defense-in-depth, then runtime-test in the actual Koyeb container. If still failing, fall back to detached `tmux new-session -d` (also documented to work) by adding `tmux` to the Dockerfile.

## What we tried and why it failed

**Approach 1 — direct exec.** Claude Code detects no TTY on stdin/stdout, switches to `--print` mode (the SDK/scripted code path), and `--print` requires either a prompt argument or stdin payload. Output: `no stdin data received in 3s … Input must be provided either through stdin or as a prompt argument when using --print`. Matches issue #40726 (closed as duplicate of #36001).

**Approach 2 — `tail -f /dev/null | claude …`.** Same warning, same error. Piping any input source through stdin still presents Claude Code with a non-TTY stdin, so it still selects the `--print` code path.

**Approach 3 — `script -q -e -c "claude --channels …" /dev/null`.** PTY-allocation via util-linux's `script(1)`. This is the canonical workaround for the no-TTY problem.

## Per sub-question findings

### SQ1 — Correct invocation in non-TTY environment
- No `--headless`, `--daemon`, or `--no-tty` flag exists in the CLI reference.
- `--bare` is for fast scripted `-p` calls only — incompatible with the Telegram channel plugin's claude.ai-only auth.
- `script(1)` (util-linux) PTY-allocation is canonical for `claude` in Docker, per Yieldcode.blog. The `-e` addition (return wrapped exit code) is a strict improvement over the published `script -q -c …` form for supervisor health checks.
- No documented Bun-on-Koyeb-specific `script` issue.
- No `unbuffer` / `expect` recommendation in any Anthropic doc — those solve output-buffering, not the stdin-is-not-a-TTY check.

### SQ2 — Newsletter-watch session pattern
The parent playbook is explicit: newsletter-watch does **not** use `claude --channels` at all in v1. It deploys a Bun stdio subprocess via `.mcp.json` running a custom one-way `brief-trigger` channel. The Bun process is the long-lived foreground; Claude Code is invoked per-request from a GHA cron via webhook, not held open as a daemon.

### SQ3 — Public repos running `claude --channels` headless
- **azdigi.com**: canonical `tmux new -s claude` / `screen -S claude` / systemd recipe for `claude --channels plugin:telegram@claude-plugins-official`.
- **claudefa.st**: confirms tmux/screen as required for keep-alive.
- **Yieldcode.blog**: Docker recipe `docker compose run --rm claude script -q -c "claude --continue" /dev/null`.
- **No public Dockerfile shipping a `claude --channels` daemon** — documented community pattern is tmux on a VPS, not a containerized daemon.

### SQ4 — Anthropic-official position
The Channels doc says: "for an always-on setup you run Claude in a background process **or** persistent terminal" — implying both are valid. But Ink rendering assumes raw-mode-capable stdin (issue #36001 stack trace shows `handleSetRawMode` failing inside Ink). Issues #29116 and #30447 are open feature requests for a real `--headless` flag. **Architectural answer**: if PTY tricks prove unreliable, run a Bun MCP server with `claude/channel` capability over HTTP/SSE per `mcp-use/notification-test` (parent playbook §1).

### SQ5 — Webhook-channel alternative
The Channels reference doc's `webhook.ts` example **still requires `claude --dangerously-load-development-channels server:webhook` as a parent process** that spawns the Bun server as a stdio subprocess. The webhook server alone does not replace the long-lived `claude` parent. The only documented escape hatch is the undocumented HTTP/SSE transport path (parent playbook §1, POSSIBLY TRUE).

## Recommended pattern

```bash
# 9. Hand off to claude --channels via PTY allocation.
log "exec claude --channels (via PTY) — agent=email-triage"
exec script -q -e -c "claude \
    --channels plugin:telegram@claude-plugins-official \
    --agent email-triage \
    --permission-mode bypassPermissions \
    </dev/null" /dev/null
```

Fallback (add `tmux` to apt-get install in the Dockerfile first):

```bash
tmux new-session -d -s claude-triage \
    "claude --channels plugin:telegram@claude-plugins-official \
     --agent email-triage --permission-mode bypassPermissions"
exec tmux wait-for claude-triage-exit
```

## Open NV items

- **Will `script -q -e -c` survive a Koyeb instance restart?** No published soak test on Koyeb specifically. Deploy and watch.
- **Bun 1.3.13 ↔ `script`-allocated PTY interaction.** No reported issues, but PTY-related regressions have happened (paperclipai issue #2911 shows pty-leak on macOS for `claude --print`). Monitor `/dev/pts/*` count over a 7-day soak.
- **Does `claude --channels` exit cleanly if the Telegram plugin polling loop dies (parent issue #53335)?** If yes, the Koyeb supervisor must restart the `script` wrapper, not just claude. Test by killing the plugin subprocess in a test deploy.
- **Undocumented internal env var disabling the stdin/print-mode check?** No published var. May exist internally; would require source-code dump or a maintainer reply on #29116/#30447.

## Sources

- Push events into a running session with channels, code.claude.com Docs (2026-04-29). https://code.claude.com/docs/en/channels — Tier 1.
- Channels reference, code.claude.com Docs (2026-04-29). https://code.claude.com/docs/en/channels-reference — Tier 1.
- CLI reference, code.claude.com Docs (2026-04-29). https://code.claude.com/docs/en/cli-reference — Tier 1.
- Run Claude Code programmatically (formerly "headless mode"), code.claude.com Docs (2026-04-29). https://code.claude.com/docs/en/headless — Tier 1.
- Issue #40726, Channels session crashes in headless/background mode with stdin error. https://github.com/anthropics/claude-code/issues/40726 — Tier 2.
- Issue #36001, CLI crashes in headless/stream-json mode (Ink raw mode error). https://github.com/anthropics/claude-code/issues/36001 — Tier 2.
- Issue #30447, claude remote-control --headless feature request. https://github.com/anthropics/claude-code/issues/30447 — Tier 2.
- Isolating Claude Code, Dmitry Kudryavtsev, yieldcode.blog. https://yieldcode.blog/post/isolating-claude-code/ — Tier 2.
- What is Claude Code Channels? AZDIGI Blog. https://azdigi.com/en/blog/... — Tier 2.
- Claude Code Channels guide, claudefa.st. https://claudefa.st/blog/guide/development/claude-code-channels — Tier 3.
- Parent playbook: `~/.claude/playbooks/claude-code-koyeb-channels/research-report.md` — Tier 1 authoritative.
