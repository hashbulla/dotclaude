#!/usr/bin/env bash
# test-sync-newsletter-corpus.sh — exercises the copy path against a local fixture
# "remote" so no real network/clone is needed.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fixture: a local git repo standing in for the producer, with one month file.
SRC_DIR="$TMP/src"
mkdir -p "$SRC_DIR/briefs"
git -C "$SRC_DIR" init -q
printf '%s\n' '{"date":"2026-06-20","bucket":"ai-engineering","kind":"top","headline":"X","source":"The Batch","url":"https://x.dev/a"}' > "$SRC_DIR/briefs/2026-06.jsonl"
git -C "$SRC_DIR" add -A && git -C "$SRC_DIR" -c user.email=t@t -c user.name=t commit -qm seed

CORPUS_DIR="$TMP/corpus"
SRC_DIR="$SRC_DIR" CORPUS_DIR="$CORPUS_DIR" bash "$HERE/sync-newsletter-corpus.sh"

test -f "$CORPUS_DIR/2026-06.jsonl" || { echo "FAIL: month file not copied"; exit 1; }
grep -q "The Batch" "$CORPUS_DIR/2026-06.jsonl" || { echo "FAIL: content mismatch"; exit 1; }
echo "PASS: sync copies briefs/*.jsonl into the corpus dir"
