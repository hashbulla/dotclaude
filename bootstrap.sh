#!/usr/bin/env bash
# =============================================================================
# dotclaude bootstrap
# =============================================================================
# Idempotent setup for a fresh machine. Run from ~/.claude/ after `git clone`.
#
# What it does:
#   1. Checks host dependencies (jq, python3, paplay, gh, git).
#   2. Seeds local-only files from .example templates.
#   3. Installs first-party skills declared in skills.manifest.toml.
#   4. Detects dangling symlinks and prints repair commands.
#   5. Verifies the hook dispatcher imports + sound tree is reachable.
#   6. Reports status.
#
# Re-running is safe: every step checks before acting.

set -euo pipefail

cd "$(dirname "$0")"
DOTCLAUDE="$(pwd)"

# ---------- helpers ----------

c_green='\033[0;32m'
c_yellow='\033[0;33m'
c_red='\033[0;31m'
c_dim='\033[0;90m'
c_off='\033[0m'

say()  { printf "${c_green}  ✓${c_off} %s\n" "$*"; }
warn() { printf "${c_yellow}  ⚠${c_off} %s\n" "$*" >&2; }
fail() { printf "${c_red}  ✗${c_off} %s\n" "$*" >&2; }
note() { printf "${c_dim}    %s${c_off}\n" "$*"; }

header() {
  printf "\n${c_green}━━━ %s ━━━${c_off}\n" "$*"
}

# ---------- 1. host dependencies ----------

header "1/5 Host dependencies"

REQUIRED=("git" "jq" "python3")
AUDIO_PLAYERS=("paplay" "aplay" "mpg123" "ffplay" "afplay")

MISSING_REQ=()
for cmd in "${REQUIRED[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    say "found: $cmd"
  else
    fail "missing required: $cmd"
    MISSING_REQ+=("$cmd")
  fi
done

# Need at least one audio player on macOS/Linux, or run silent
HAS_AUDIO=0
for cmd in "${AUDIO_PLAYERS[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    say "audio player: $cmd"
    HAS_AUDIO=1
    break
  fi
done
[ "$HAS_AUDIO" -eq 0 ] && warn "no audio player found; hooks will run silently (or set SOUNDS_DISABLED=1)"

if command -v gh >/dev/null 2>&1; then
  say "gh CLI: present"
else
  warn "gh CLI not found; skill installation falls back to git over SSH/HTTPS"
fi

if [ ${#MISSING_REQ[@]} -gt 0 ]; then
  fail "Install missing required deps and re-run bootstrap."
  exit 1
fi

# ---------- 2. local-only file templates ----------

header "2/5 Local templates"

seed() {
  local tpl="$1"
  local real="$2"
  if [ -f "$real" ]; then
    note "$real already exists — skipped"
  elif [ -f "$tpl" ]; then
    cp "$tpl" "$real"
    say "seeded $real from $tpl"
    note "→ edit $real with your real values"
  else
    warn "template missing: $tpl"
  fi
}

seed "identity.example.md" "identity.md"
seed "profile.example.md" "profile.md"
seed ".env.example" ".env.local"
seed "settings.example.local.json" "settings.local.json"
seed "hooks/config/hooks-config.local.example.json" "hooks/config/hooks-config.local.json"

chmod 600 .env.local 2>/dev/null || true

# ---------- 3. install first-party skills ----------

header "3/5 First-party skills (from skills.manifest.toml)"

install_skill() {
  local name="$1"
  local repo="$2"
  local clone_to="$3"
  local symlink_target="$4"
  local symlink_source="$5"  # relative to clone_to, default "."

  clone_to="${clone_to/#\~/$HOME}"
  symlink_target="${symlink_target/#\~/$HOME}"
  symlink_source="${symlink_source:-.}"

  # Clone if missing
  if [ ! -d "$clone_to/.git" ]; then
    say "cloning $name → $clone_to"
    mkdir -p "$(dirname "$clone_to")"
    if ! git clone "$repo" "$clone_to" 2>/dev/null; then
      warn "clone failed: $repo (no access? offline? skipping)"
      return 0
    fi
  else
    note "$name already cloned at $clone_to"
  fi

  # Symlink if missing or stale
  local symlink_actual_target
  symlink_actual_target="$clone_to/$symlink_source"
  symlink_actual_target="$(realpath "$symlink_actual_target" 2>/dev/null || echo "$symlink_actual_target")"

  if [ -L "$symlink_target" ]; then
    local existing
    existing="$(readlink "$symlink_target")"
    if [ "$existing" = "$symlink_actual_target" ]; then
      note "$name symlink already correct"
      return 0
    fi
    warn "$name symlink points to wrong target: $existing — fixing"
    rm "$symlink_target"
  elif [ -e "$symlink_target" ]; then
    warn "$symlink_target exists and is not a symlink — manual review needed; skipping"
    return 0
  fi

  ln -sfn "$symlink_actual_target" "$symlink_target"
  say "$name symlinked: $symlink_target → $symlink_actual_target"
}

# Parse skills.manifest.toml with a simple awk extractor (no toml dep needed)
# Tolerant: skips skills that fail to clone (e.g., private repos when offline).

MANIFEST="skills.manifest.toml"
if [ ! -f "$MANIFEST" ]; then
  warn "$MANIFEST not found; skipping skill installation"
else
  # shellcheck disable=SC2016
  awk '
    /^\[skill\./ { name = $0; sub(/^\[skill\./, "", name); sub(/\]$/, "", name); skill=name; next }
    /^repo[ \t]*=/ { gsub(/^repo[ \t]*=[ \t]*"|"[ \t]*$/, ""); print skill "|repo|" $0; next }
    /^clone_to[ \t]*=/ { gsub(/^clone_to[ \t]*=[ \t]*"|"[ \t]*$/, ""); print skill "|clone_to|" $0; next }
    /^symlink_target[ \t]*=/ { gsub(/^symlink_target[ \t]*=[ \t]*"|"[ \t]*$/, ""); print skill "|symlink_target|" $0; next }
    /^symlink_source[ \t]*=/ { gsub(/^symlink_source[ \t]*=[ \t]*"|"[ \t]*$/, ""); print skill "|symlink_source|" $0; next }
  ' "$MANIFEST" > /tmp/dotclaude-manifest-parse.txt

  # Group by skill name and call install_skill
  current=""
  declare -A R C T S
  while IFS='|' read -r skill key value; do
    case "$key" in
      repo)            R[$skill]="$value" ;;
      clone_to)        C[$skill]="$value" ;;
      symlink_target)  T[$skill]="$value" ;;
      symlink_source)  S[$skill]="$value" ;;
    esac
  done < /tmp/dotclaude-manifest-parse.txt

  for skill in "${!R[@]}"; do
    install_skill "$skill" "${R[$skill]}" "${C[$skill]}" "${T[$skill]}" "${S[$skill]:-}"
  done
  rm -f /tmp/dotclaude-manifest-parse.txt
fi

# ---------- 4. dangling symlinks ----------

header "4/5 Dangling symlink detector"

dangling_count=0
while IFS= read -r broken; do
  warn "dangling: $broken → $(readlink "$broken")"
  dangling_count=$((dangling_count + 1))
done < <(find . -maxdepth 4 -type l 2>/dev/null | while read -r l; do
  if [ ! -e "$l" ]; then
    echo "$l"
  fi
done)

if [ "$dangling_count" -eq 0 ]; then
  say "no dangling symlinks"
else
  warn "$dangling_count dangling symlink(s) — see skills/EXTERNAL.md and agents/EXTERNAL.md for repair steps"
fi

# ---------- 5. hook dispatcher + sound tree ----------

header "5/5 Hook system"

if python3 hooks/scripts/hooks.py --dry-run 2>&1 | grep -q '^OK'; then
  say "hook dispatcher imports + sound tree reachable"
else
  fail "hook dispatcher dry-run failed"
  python3 hooks/scripts/hooks.py --dry-run 2>&1 | sed 's/^/    /'
fi

# ---------- summary ----------

header "Done"
note "Next: source .env.local (or use direnv) so settings.json env interpolation works."
note "  set -a; source ~/.claude/.env.local; set +a"
note "Then launch:  claude"
