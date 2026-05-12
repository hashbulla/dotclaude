# /research — Tavily-First Web Research

Execute a structured web research task using the Tavily + Fetch MCP stack.

## Decision Gates

1. **Is this a deep research task?** (multi-source synthesis, broad topic, comprehensive answer needed)
   - YES → Use `mcp__tavily__tavily_research`
     - Broad topic with many subtopics? → Set `model=pro`
     - Narrow question, few sources needed? → Set `model=mini`
     - Unsure? → Set `model=auto` (default)
   - NO → Go to step 2

2. **Is this a library/API documentation lookup?** (how to use X, configure Y, debug Z)
   - YES → Use `mcp__tavily__tavily_skill`
     - Set `library` to the package name (e.g., "nextjs", "celery")
     - Set `language` to the project language (e.g., "python", "typescript")
     - Set `task` to integrate/configure/debug/migrate/understand
   - NO → Go to step 3

3. **Is this a discovery task?** (unknown URLs, need to find information)
   - YES → Use `mcp__tavily__tavily_search`
     - Need speed over depth? → Set `search_depth=fast` or `ultra-fast`
     - Need thoroughness? → Set `search_depth=advanced`
     - Time-sensitive? → Set `time_range` (day/week/month/year) or `start_date`/`end_date`
     - Region-specific? → Set `country` (full name, e.g., "France")
     - Scoped to specific sites? → Set `include_domains` filter
   - NO → Go to step 4

4. **Is this a known-URL extraction?** (have the URL, need the content)
   - Single URL → Use `mcp__fetch__fetch`
   - Multiple URLs → Use `mcp__tavily__tavily_extract`
     - Protected site or LinkedIn? → Set `extract_depth=advanced`

5. **Is this a domain mapping task?** (need to understand site structure)
   - YES → Use `mcp__tavily__tavily_map` first, then extract key pages

6. **Is this a full site audit?** (GTM, SEO, content inventory)
   - YES → Use `mcp__tavily__tavily_crawl`
     - Use `instructions` to describe which page types to return
     - Use `select_paths` to restrict to specific URL patterns

## Routing Priority

```
tavily_research (deep multi-source synthesis)
  → tavily_skill (library/API docs)
    → tavily_search (general web discovery)
      → tavily_extract (batch content from found URLs)
        → fetch (single known URL, raw markdown)
          → WebSearch (fallback only — Tavily unavailable)
```

## Usage

Invoke with a research query or objective:

```
/research What are the latest MCP server patterns for Claude Code in 2025?
/research Extract pricing data from https://example.com/pricing
/research Map the documentation structure of docs.tavily.com
/research How to configure SSE streaming in Next.js App Router
```

The agent will select the appropriate tool(s) based on the decision gates above
and chain them as needed to fulfill the research objective.
