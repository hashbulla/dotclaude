#!/usr/bin/env bash
# =============================================================================
# dotclaude self-update — worker
# =============================================================================
# Pulls every git-backed skill clone that is symlinked into ~/.claude, and
# upgrades the pipx-installed scrapling MCP. Best-effort and idempotent:
# a dirty/divergent/offline repo is SKIPPED, never merged or stashed.
#
# Covers update layers 3 (first-party skills), 4 (third-party skills) and the
# pipx slice of layer 5 (MCP servers). Layer 1 (CC binary) auto-updates
# natively; layer 2 (plugins) is left to Claude Code's marketplace sweep;
# uvx/npx -y MCP servers float on every run. The dotclaude repo itself is
# intentionally NOT pulled (it is frequently dirty → would always be skipped).
#
# Normally launched detached by hooks/scripts/hooks.py on SessionStart, at most
# once per SELF_UPDATE_INTERVAL_HOURS. Safe to run by hand.
#
# Env:
#   SELF_UPDATE_FORCE=1            bypass the throttle (run now)
#   SELF_UPDATE_INTERVAL_HOURS=N   throttle window in hours (default 24)

set -euo pipefail

cd "$(dirname "$0")/.."
DOTCLAUDE="$(pwd)"

THROTTLE="$DOTCLAUDE/.last-self-update"
LOG_FILE="$DOTCLAUDE/hooks/logs/self-update.log"
INTERVAL_HOURS="${SELF_UPDATE_INTERVAL_HOURS:-24}"

mkdir -p "$(dirname "$LOG_FILE")"

# ---------- helpers ----------

log() {
  printf '%s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE"
}

now_epoch() { date -u +%s; }

file_mtime() {
  # GNU then BSD stat; 0 if absent.
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# ---------- throttle (this script is the authority) ----------

if [ -z "${SELF_UPDATE_FORCE:-}" ] && [ -f "$THROTTLE" ]; then
  last="$(file_mtime "$THROTTLE")"
  age=$(( $(now_epoch) - last ))
  if [ "$last" -gt 0 ] && [ "$age" -lt $(( INTERVAL_HOURS * 3600 )) ]; then
    exit 0
  fi
fi

# Claim the slot immediately so a second concurrent run bails on the throttle.
date -u +%Y-%m-%dT%H:%M:%S.000Z > "$THROTTLE"

log "── self-update run (pid $$, interval ${INTERVAL_HOURS}h${SELF_UPDATE_FORCE:+, forced}) ──"

# ---------- pull one git root, safely ----------

pull_one() {
  local root="$1"
  local name branch
  name="$(basename "$root")"

  if [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]; then
    log "SKIP (dirty)    $name  ($root)"
    return 0
  fi
  if ! branch="$(git -C "$root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    log "SKIP (detached) $name  ($root)"
    return 0
  fi
  if git -C "$root" pull --ff-only --quiet 2>/dev/null; then
    log "OK              $name  ($branch)"
  else
    log "SKIP (non-ff/offline) $name  ($branch)"
  fi
}

# ---------- enumerate symlinked git roots (skills 3+4) ----------

roots="$(
  { find skills -maxdepth 1 -type l 2>/dev/null
    find agents -maxdepth 1 -type l 2>/dev/null
  } | while IFS= read -r link; do
        tgt="$(readlink -f "$link" 2>/dev/null)" || continue
        [ -n "$tgt" ] || continue
        if [ -d "$tgt" ]; then dir="$tgt"; else dir="$(dirname "$tgt")"; fi
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true
      done | sort -u
)"

count=0
while IFS= read -r root; do
  [ -n "$root" ] || continue
  pull_one "$root"
  count=$(( count + 1 ))
done <<< "$roots"
log "skill clones processed: $count"

# ---------- scrapling (pipx slice of layer 5) ----------

if command -v pipx >/dev/null 2>&1; then
  if pipx upgrade scrapling >/dev/null 2>&1; then
    log "OK              scrapling (pipx)"
  else
    log "SKIP            scrapling (pipx: already current or not installed)"
  fi
else
  log "SKIP            scrapling (pipx not found)"
fi

log "── done ──"
