---
paths: "**/.git/**,**/COMMIT_EDITMSG,**/.gitmessage"
description: Git commit discipline — one-file-one-commit, conventional commits, never skip hooks.
---

# Git commit discipline

These rules apply whenever you are about to create a commit. The user prefers clean history over fast history.

## The contract

1. **One file per commit by default.** When a change touches `README.md` + a `SKILL.md` + a `settings.json`, that's three commits — not one.
2. **Conventional commit prefixes** — `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`, `init:`. Scope optional: `feat(rpi):`, `fix(hooks):`.
3. **Commit message body answers "why", not "what".** The diff shows what changed; the body explains the motivation.
4. **Co-authorship trailer.** Every commit you make should end with a co-author line naming the model that produced the code. Use the current model version, e.g.:
   ```
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
   Include the specific model name when you know it (e.g. `Claude Sonnet 4.6`) so the trailer stays informative over time.
5. **Never `--amend` a pushed commit.** Create a new commit. Amending rewrites the commit SHA, which diverges any branch that already pulled the original — forcing force-pushes and breaking collaborators (or your own other checkouts).
6. **Never `--no-verify`.** If a pre-commit hook fails, fix the underlying issue; never bypass.
7. **Never `--no-gpg-sign`** unless the user explicitly authorizes it.

## When you may bundle multiple files in one commit

The one-file-one-commit rule has narrow exceptions:

- **Scaffold commit** — first commit on a new branch or a new directory. Bundling the initial scaffolding into one "init:" commit is fine.
- **Lockfile + dependency update** — `package.json` + `package-lock.json` (or `pyproject.toml` + `uv.lock`) are inseparable.
- **Test + production code for the same change** — if a single feature touches `src/foo.ts` and `tests/foo.test.ts`, one commit is acceptable.
- **Rename + content edit** — bundle the rename and the edits-that-needed-the-rename into one commit so history follows correctly.

Outside of these exceptions, default to one commit per file.

## Anti-patterns

- ❌ `git add .` then `git commit -am "stuff"`. Specific paths only.
- ❌ Empty commits to "trigger CI". CI should be triggered properly.
- ❌ `chore: misc fixes` — every commit must name the actual concern.
- ❌ Committing files that may contain secrets (`.env`, `credentials.json`, anything matching the deny-list in `~/.claude/settings.json`). Warn the user instead.
- ❌ Force-pushing to `main` or `master` without an explicit user authorization.

## Before you commit

- Run `git status` to confirm the working tree.
- Run `git diff --staged` to read the exact diff you're about to commit.
- Confirm no files match `*.env*`, `*credentials*`, `*.key`, `*.pem` in the staged set.
- If you ran auto-formatters or generators, stage the formatted output separately so the commit history can be reverted cleanly.
