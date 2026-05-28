#!/usr/bin/env bash
# Bootstrap user-scope MCPs into ~/.claude.json on a fresh machine.
#
# ~/.claude.json is the registry the `claude mcp list` command actually reads
# (verified 2026-05-28 — see playbooks/context7/research-report.md and the
# verification trail in commit feat(mcp): wire Context7 ...). It is NOT
# versioned in this repo because it also stores per-machine state (startup
# counts, OAuth tokens, etc.).
#
# Run this once per machine after cloning dotclaude. Idempotent: `claude mcp add`
# fails fast on duplicate names, so re-running on an already-bootstrapped machine
# is harmless except for the printed errors.
#
# Required env vars (export in ~/.zshrc):
#   CONTEXT7_API_KEY   — Upstash Context7 (https://context7.com/dashboard)
#   POSTHOG_API_KEY    — PostHog agent toolkit (set if you use posthog MCP)
#   TAVILY_API_KEY     — Tavily (already wired via remote HTTP MCP, no action here)

set -euo pipefail

green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*" >&2; }

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    red "Missing env: $name. Export it in ~/.zshrc before running this script."
    return 1
  fi
}

green "==> Bootstrapping user-scope MCPs for Claude Code"

# context7 — Upstash docs lookup (authenticated)
if require_env CONTEXT7_API_KEY; then
  green "Registering context7 (authenticated)..."
  claude mcp add --scope user context7 \
    --env CONTEXT7_API_KEY="$CONTEXT7_API_KEY" \
    -- npx -y @upstash/context7-mcp \
    || yellow "  (already registered — skipping)"
fi

# Add more MCPs here as the registry grows. Pattern:
#   if require_env XXX_API_KEY; then
#     claude mcp add --scope user <name> --env XXX_API_KEY="$XXX_API_KEY" -- <command>
#   fi

green "==> Verifying registrations"
claude mcp list | grep -E "context7" || red "context7 not in list — something went wrong"

green "==> Done. Restart Claude Code for any newly-registered MCP to load into a running session."
