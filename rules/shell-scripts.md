---
paths: "**/*.sh,**/*.bash,**/.bashrc,**/.zshrc"
description: Shell script discipline — strict mode, quoting, shellcheck-clean, no silent failures.
---

# Shell script rules

Bash and POSIX sh are easy to write badly. These rules apply to every `.sh` / `.bash` file and every multi-line Bash hook.

## The non-negotiables

Every script starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `-e` — exit on any non-zero return.
- `-u` — undefined variables are errors.
- `-o pipefail` — pipelines fail when any stage fails, not just the last.

If you genuinely need a command to be allowed to fail, opt out *explicitly*:

```bash
some_optional_step || true
```

Never globally drop `set -e` just because one line was inconvenient.

## Quoting

- **Always quote variable expansions.** `"$var"`, `"${array[@]}"`, `"$@"`. Even when you "know" the value has no spaces.
- **Use `${var}` braces in compound expressions**: `"${prefix}_suffix"`, not `"$prefix_suffix"` (which evaluates `$prefix_suffix`).
- **Single quotes for literal strings.** `'$VAR'` won't interpolate; `"$VAR"` will.
- **Heredocs**: quote the delimiter to prevent interpolation when you don't want it.
  ```bash
  cat <<'EOF'   # no interpolation
  $VAR is literal
  EOF
  ```

## Function design

- **`local` every variable inside a function** — Bash variables are global by default and will leak.
- **Return values via stdout or exit codes, not via shared variables.** Capture with `$(func)` or `if func; then`.
- **Functions live above the first call site** — Bash is interpreted top-down.

## Error handling

- **Trap on EXIT for cleanup** — `trap 'rm -rf "$tmpdir"' EXIT`.
- **Check tool availability** before depending on it:
  ```bash
  command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }
  ```
- **Never swallow errors silently.** `cmd 2>/dev/null` only when the failure is genuinely a non-event.

## Cross-platform concerns

- **`#!/usr/bin/env bash`** rather than `#!/bin/bash` — works on macOS and Linux.
- **GNU vs BSD utilities differ**: `sed -i ''` on macOS, `sed -i` on GNU. Use `awk` or `perl -i` if you need portability.
- **Audio playback** chain (used in our hooks): try `paplay` → `aplay` → `ffplay` → `mpg123` on Linux, `afplay` on macOS, `winsound` on Windows.

## Lint discipline

Before considering a shell script done:

- Run `shellcheck path/to/script.sh`. Fix every warning, or `# shellcheck disable=SCxxxx` *with a comment* explaining why.
- Run `bash -n path/to/script.sh` to catch syntax errors without executing.

## Anti-patterns

- ❌ `for file in $(ls *.txt)` — use `for file in *.txt` (handles spaces).
- ❌ `if [ $var = "foo" ]` — use `[[ "$var" = "foo" ]]` or `[ "$var" = "foo" ]` (quote the var).
- ❌ `cd somedir; do_something` — use `(cd somedir && do_something)` or `cd somedir || exit 1; do_something`.
- ❌ Parsing `ls` output. Use `find`, globs, or `[[ -e "$file" ]]`.
- ❌ `eval` on user-controlled strings.
