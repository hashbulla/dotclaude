#!/usr/bin/env bash
# sync-newsletter-corpus.sh — refresh the local /deep-research newsletter corpus
# from the producer repo's durable briefs/*.jsonl. Ops glue (network), NOT a
# skill-runtime helper. Env overrides: SRC_REPO, SRC_DIR, CORPUS_DIR.
set -euo pipefail

SRC_REPO="${SRC_REPO:-hashbulla/newsletter-watch-agent}"
SRC_DIR="${SRC_DIR:-$HOME/.claude/deep-research/newsletter-corpus-src}"
CORPUS_DIR="${CORPUS_DIR:-$HOME/.claude/deep-research/newsletter-corpus}"

mkdir -p "$CORPUS_DIR"

if [ -d "$SRC_DIR/.git" ]; then
  # Tolerate an unreachable remote: a transient failure still uses the last-good clone.
  git -C "$SRC_DIR" pull --ff-only --quiet || echo "[sync] pull failed; using existing clone"
else
  # gh-authenticated clone works whether the repo is public or private.
  gh repo clone "$SRC_REPO" "$SRC_DIR" -- --depth 1 2>/dev/null \
    || git clone --depth 1 "https://github.com/$SRC_REPO.git" "$SRC_DIR"
fi

if compgen -G "$SRC_DIR/briefs/*.jsonl" > /dev/null; then
  cp -f "$SRC_DIR"/briefs/*.jsonl "$CORPUS_DIR"/
  echo "[sync] copied $(find "$SRC_DIR/briefs" -maxdepth 1 -name '*.jsonl' | wc -l) month file(s) to $CORPUS_DIR"
else
  echo "[sync] no briefs/*.jsonl in $SRC_REPO yet (producer emit hasn't run); corpus dir left as-is"
fi
