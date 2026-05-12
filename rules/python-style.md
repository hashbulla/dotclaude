---
paths: "**/*.py,**/pyproject.toml,**/setup.cfg,**/requirements*.txt"
description: Python style rules — type hints, ruff-clean, no print debugging in prod paths, strict deps.
---

# Python style rules

Loaded whenever you touch a `.py` file or a Python packaging file. The goal: production-grade Python that holds up under review.

## Versions and packaging

- **Python ≥ 3.11** unless the project pin says otherwise. Use modern syntax (`match`, structural patterns, `Self` type) when it improves readability.
- **`pyproject.toml`** is the source of truth for deps and config. `requirements.txt` only as an export.
- **Pin direct deps with `>=` ranges**, transitive deps via `uv.lock` or `poetry.lock`.

## Type hints

- **Every function gets type hints** — params and return. `def f(x: int) -> str:`.
- **`Optional[T]` is `T | None`** in modern Python; prefer the pipe syntax.
- **Use `Protocol` for structural typing**, `TypeAlias` for non-trivial types.
- **Run mypy or pyright before "done".** The user prefers `pyright --strict` where possible.

## Imports

- **Group imports**: stdlib → third-party → first-party, each block sorted, separated by blank lines.
- **Absolute imports inside packages.** `from mypkg.foo import bar`, not `from .foo import bar` (unless the package is intentionally relocatable).
- **No `from module import *`.** Ever.

## Functions and classes

- **Functions do one thing.** If a function name needs "and", split it.
- **Dataclasses or Pydantic models for data, not raw dicts.** Type the shape.
- **Async functions when calling I/O** — sync I/O in async contexts is the silent-deadlock failure mode.

## Logging and debugging

- **No `print()` in production code paths.** Use `logging` with structured records.
- **Logging level decision tree**: DEBUG (dev only) → INFO (normal flow) → WARNING (recoverable) → ERROR (operation failed) → CRITICAL (process should restart).
- **Never log secrets.** Use a redaction layer or filter PII before the log emit.

## Error handling

- **`raise` with the original exception chained**: `raise ValueError("bad input") from exc`.
- **Catch the narrowest exception type that makes sense.** Not `except Exception:` unless you're a top-level handler.
- **Custom exception classes per domain** when the system is large enough to warrant them.

## Tooling

- **`ruff` for lint + format** — replaces black/isort/flake8.
- **`pytest` for tests** — `pytest-asyncio` for async, `pytest-cov` for coverage gates.
- **`uv` for dep management** when starting new projects — faster and more deterministic than pip.

## Anti-patterns

- ❌ Mutable default arguments: `def f(x=[]): ...`. Use `None` then assign in the body.
- ❌ `is` for value equality on small ints/strings — works by accident due to interning, not by spec.
- ❌ Bare `except:` (catches `KeyboardInterrupt`, `SystemExit`).
- ❌ Subclassing `dict` or `list` for behavior — use composition.
- ❌ Long `__init__` methods doing setup work. Move to a `classmethod` constructor.

## AI / LLM Python work

When the file is in a `prompts/`, `agents/`, `skills/`, or `llm/` directory:

- **Prompt-cache aware**: structure system prompts so cacheable prefixes come first; suffix the dynamic parts.
- **No provider lock-in in shared interfaces.** Define a `ChatProvider` protocol; let Anthropic/OpenAI/etc. plug in.
- **Eval-first.** Every change to an agent's behavior gets a corresponding eval added or updated. See the `~/.claude/skills/skill-generator/` doctrine.
- **Citation-grounded outputs when the agent is reviewing.** P0/P1 findings carry sources; see `rpi-review-citation.md` if loaded.
