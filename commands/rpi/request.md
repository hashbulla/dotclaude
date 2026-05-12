---
description: First step of the RPI workflow — interview the user about a feature ask and write a structured rpi/<slug>/REQUEST.md.
model: haiku
allowed-tools: AskUserQuestion, Agent, Read, Write, Glob, Grep
argument-hint: "<feature description in prose>"
---

# `/rpi:request` — capture a feature request

Use this command when the user has an open-ended feature ask that needs structure before research or planning can start. Output: a `REQUEST.md` file under `rpi/<feature-slug>/` that downstream RPI commands consume.

## Inputs

`$ARGUMENTS` — the user's prose description of the feature. May be vague, contradictory, or incomplete. That's expected.

## Workflow

### 1. Parse the feature slug

From `$ARGUMENTS`, infer a kebab-case slug (3-6 words). If ambiguous, ask the user via `AskUserQuestion`.

Examples:
- "Add OAuth2 to the CLI" → `oauth2-cli`
- "Migrate auth from session cookies to JWT" → `auth-session-to-jwt`
- "Make the dashboard load faster" → `dashboard-perf` (and ask for specifics)

### 2. Create the directory

```bash
mkdir -p rpi/<slug>
```

(If `rpi/<slug>/` already exists, ask whether to overwrite or pick a new slug.)

### 3. Hand off to the `requirement-parser` agent

```
Agent(
  subagent_type="requirement-parser",
  description="Parse feature request into REQUEST.md",
  prompt="""
  Feature description from user: $ARGUMENTS

  Working directory: rpi/<slug>/

  Produce rpi/<slug>/REQUEST.md following your agent specification.
  Set the `needs_deep_research`, `risk_level`, and `reversibility` flags
  per your agent's heuristics. Ask the user up to 5 clarifying questions
  via AskUserQuestion if critical fields are ambiguous; do NOT invent.
  """,
  model="haiku"
)
```

### 4. Confirm with the user

After the agent returns, show the produced `REQUEST.md` to the user and ask:

- Is the **Problem** statement accurate?
- Are **Non-goals** complete?
- Is `needs_deep_research = <true|false>` correct given what you know?

If any are no, iterate with the `requirement-parser` agent.

### 5. Offer the next step

End with:

> REQUEST.md is ready at `rpi/<slug>/REQUEST.md`. Next step:
>   `/rpi:research <slug>` — runs feasibility analysis and emits RESEARCH.md.

## Output contract

The command produces exactly one file: `rpi/<slug>/REQUEST.md`. No code changes. No commits.

## When NOT to use this command

- The ask is trivial and already obvious ("fix the typo in README.md line 42"). Just do the work.
- The user is asking a question rather than describing a feature. Answer the question.
- The user has already written a structured request in their own format. Ask whether they want it normalized to RPI format or kept as-is.
