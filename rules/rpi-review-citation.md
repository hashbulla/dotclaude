---
paths: "rpi/**/*,**/rpi/**/*"
description: Citation Grounding rule for RPI reviewers — P0/P1 findings must cite Tavily evidence; never soften.
---

# RPI review citation rule

When loaded (i.e. you're working inside an `rpi/<feature-slug>/` directory), the review trio (`code-reviewer`, `security-reviewer`, `constitutional-validator`) operates under the Citation Grounding contract transplanted from `/critical-harness`.

## The contract

**Non-negotiable for P0 and P1 findings.**

When you flag a finding at severity **P0** (must-fix, blocks merge) or **P1** (high-severity, blocks production), you must attach at least one citation produced via:

- `mcp__tavily__tavily_skill` — for library / API / framework documentation. Set `task` to `understand`, `debug`, `migrate`, `integrate`, or `configure` as appropriate.
- `mcp__tavily__tavily_search` — for vulnerability disclosures (CVE, GHSA), RFCs, security advisories, or vendor blog posts.

**Citation format** (paste this verbatim under the finding):

```
[source: <tool-name>, query: "<exact query you ran>", url: <canonical url>, retrieved: <YYYY-MM-DD>]
```

Multiple citations allowed. One is the minimum for P0/P1.

## What you must NOT do

- ❌ **Soften a finding to dodge the citation requirement.** If you can't cite, downgrade to P2 or P3 instead. The rule has teeth precisely because reviewers tend to soften when challenged.
- ❌ **Cite training knowledge** ("Per the React docs…"). Either you have a URL or you don't have a citation.
- ❌ **Cite the file you're reviewing** as evidence for a flaw in itself. Citations point to *external* authoritative sources.
- ❌ **Use stale citations.** If the retrieval date is more than 90 days old, re-run the search before relying on it.

## P2 and P3 findings

May stay un-cited. These are quality-of-life issues (style, polish, future-proofing) where the bar is "thoughtful reviewer's judgment", not "external evidence."

## Severity calibration

- **P0** — security vulnerability, data loss risk, license violation, broken contract. Citation: CVE, RFC, vendor advisory, OWASP.
- **P1** — performance regression, correctness bug, accessibility violation (WCAG-relevant), violation of project constitution. Citation: benchmark, RFC, accessibility spec, project rule doc.
- **P2** — code-smell, missing test coverage, suboptimal pattern. Citation optional.
- **P3** — style, naming, doc nit. Citation not expected.

## How the rule interacts with the reviewers

`code-reviewer` cites:
- Language spec / RFC / vendor docs for correctness findings.
- Benchmark or perf docs for hot-path findings.

`security-reviewer` cites:
- OWASP top-10 entries.
- CVE / GHSA entries.
- Vendor security advisories.
- RFC sections (e.g. RFC 8252 for OAuth2 native-app patterns).

`constitutional-validator` cites:
- The project's own CLAUDE.md or `.claude/rules/*.md` line that's been violated.
- (Constitutional citations are special — they point inward at the project's own constraints, not outward.)

## Reporter responsibility

The agent that produces the final report (`documentation-analyst-writer` in `/rpi:implement`) is responsible for:

1. Pulling all P0/P1 findings.
2. Verifying every one has a citation.
3. Downgrading any P0/P1 that lacks a citation to P2.
4. Logging the downgrade in the report so the user knows what got softened by the rule.
