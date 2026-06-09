---
paths: "**/*.{py,pyi,ts,tsx,js,jsx,mjs,cjs,sh,bash}"
description: Code-generation process discipline — prime via codegraph, spec/TDD non-trivial work, verify before claiming done, review+simplify the diff. Composes with the per-language style rules.
---

# Code generation process discipline

This rule governs *how* code is generated, not its syntax. It is the process layer; the per-language *style* layer lives in [`python-style.md`](python-style.md), [`typescript-style.md`](typescript-style.md), [`shell-scripts.md`](shell-scripts.md) and composes untouched. The *why* and a worked example live in [`../best-practice/code-generation.md`](../best-practice/code-generation.md).

## Scope boundary (do-directly is the default)

The default is **do-directly**. Work is **trivial** — exempt — when it is one of: a typo/string fix, a log line, a single-line or single-obvious-function change, a rename, a comment edit, a throwaway script on stable stdlib, or pure research with no edit. This list **wins on overlap**: a rename that touches three files is still a rename, not a multi-file feature.

The structural signals — introduces new behavior, touches ≥ 2 files, adds/changes ≥ ~20 LOC of logic, alters control flow, integrates an external API / SDK, modifies an existing feature's behavior — are a **backstop**, not an automatic trigger. They fire the discipline only when the change is *also* unfamiliar or risky (you haven't read the code, or getting it wrong is costly). **When unsure, do the smaller thing first and add discipline only if it proves non-trivial** — over-firing taxes every edit; under-firing self-corrects on the retry.

## The contract (MUST / MUST NOT)

- **MUST** prime context via the codegraph MCP before editing non-trivial code in an area not read yet this session.
- **MUST** route net-new features through spec-first (`superpowers:brainstorming` → `writing-plans`, or `/rpi:*` for risk ≥ medium) and TDD — never blind-write a feature.
- **MUST NOT** claim *done / fixed / passing* without running the verifying command and quoting its output.
- **MUST** run `/code-review` then `/simplify` on a *non-trivial* multi-file diff before declaring complete.
- **MUST NOT** apply this ceremony to trivial edits per the boundary above.

## How

1. **Graph context-priming.** `mcp__codegraph__codegraph_context` first; one `codegraph_explore` for the source it surfaces. `codegraph_trace` for "how does X reach Y"; `codegraph_impact` before a refactor. The graph is pre-built and local — per the codegraph MCP server's own guidance, a structure query is a handful of calls where a blind grep/read sweep is dozens.
2. **Spec-first / TDD.** For new work, get a design approved before writing (brainstorming→writing-plans, or RPI). Then test-drive: failing test → minimal impl → green → refactor.
3. **Verification gate.** Evidence before assertion. Run it, paste the relevant output. "Tests pass" without the command output is not a claim, it's a hope (`superpowers:verification-before-completion`).
4. **Anti-slop + passes.** Frontend goes through `impeccable` / `frontend-design` to avoid the generic AI aesthetic. Every multi-file diff gets `/code-review` (correctness) then `/simplify` (reuse, efficiency, altitude) before "done".

**Language fallback.** Python / TS / Bash also load their style rule; the JS family (`.js/.jsx/.mjs/.cjs`) gets this process layer with no dedicated style rule, so infer idiom, naming, and test conventions from the surrounding code. Languages outside this rule's glob (Go, Rust, …) are not auto-loaded — apply the same process discipline by hand when you work in them.

**Inside RPI.** When working in an `rpi/**` feature dir, the RPI reviewer trio (`code-reviewer` + `security-reviewer` + `constitutional-validator`) subsumes the `/code-review` → `/simplify` step. Don't double-run it.

## Anti-patterns

- ❌ Blind grep+read sweep across a large repo when codegraph is connected.
- ❌ Writing a multi-file feature before a design is approved.
- ❌ "Done" / "fixed" with no command output quoted.
- ❌ Running spec/TDD ceremony on a typo or one-line fix (boundary violation, the other direction).
- ❌ Duplicating per-language *style* here — style lives in the style rules; this rule is process only.
- ❌ Re-priming a file already read this session — context is warm.
