#!/usr/bin/env bash
# pdf-design-gate.sh — PostToolUse/Bash hook.
# Requires: jq
#
# Detects when a Bash command PRODUCES a PDF (Typst, LaTeX, pandoc, weasyprint,
# wkhtmltopdf, prince, headless-Chrome, quarto, soffice) and injects a mandatory
# reminder to grade it with the `pdf-design-evaluator` agent before the PDF is
# treated as final. A hook cannot itself spawn that subagent (the agent-type hook
# would lose its curated rubric), so this is the deterministic *trigger* and Claude
# is the executor — the same defense-in-depth pattern as the voice-check gate.
#
# Loop-safe by design: it matches PDF *generators* only, never *consumers*
# (pdftoppm / pdftotext / pdfinfo / mutool / qpdf …). The evaluator's own pdftoppm
# calls therefore never re-trigger this hook.
#
# Contract: always exit 0. Emit hookSpecificOutput JSON only on a generator match;
# stay silent otherwise so non-PDF Bash calls cost nothing.

if ! command -v jq &>/dev/null; then
  # Without jq we cannot parse stdin or emit safe JSON. Fail open, never block.
  exit 0
fi

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# PDF generators (case-insensitive). Consumers are intentionally absent.
GEN_RE='typst[[:space:]]+(compile|watch)'
GEN_RE+='|(^|[[:space:]])(pdflatex|xelatex|lualatex|latexmk|tectonic|weasyprint|wkhtmltopdf|prince)([[:space:]]|$)'
GEN_RE+='|--print-to-pdf|--convert-to[[:space:]]+pdf|quarto[[:space:]]+render|(^|[[:space:]])(soffice|libreoffice)([[:space:]]|$)'
GEN_RE+='|pandoc[^|]*(\.pdf|--pdf-engine|-t[[:space:]]*pdf)'

printf '%s' "$CMD" | grep -qiE "$GEN_RE" || exit 0

# Best-effort: pull the output .pdf path; else derive it from a .typ stem; else generic.
PDF=$(printf '%s' "$CMD" | grep -oiE "[^[:space:]\"']+\.pdf" | tail -n1)
if [ -z "$PDF" ]; then
  TYP=$(printf '%s' "$CMD" | grep -oiE "[^[:space:]\"']+\.typ" | tail -n1)
  [ -n "$TYP" ] && PDF="${TYP%.typ}.pdf"
fi
[ -z "$PDF" ] && PDF="(the PDF just produced)"

SNIPPET=$(printf '%s' "$CMD" | cut -c1-120)

MSG="PDF PRODUCTION DETECTED (command: ${SNIPPET}). Per the user's standing rule "
MSG+="(CLAUDE.md -> PDF Production), before treating ${PDF} as final you MUST grade it "
MSG+="with the pdf-design-evaluator agent: spawn the Agent tool with subagent_type "
MSG+="\"pdf-design-evaluator\" and PDF_PATH=${PDF}. EXCEPTION: if this is a throwaway or "
MSG+="intermediate recompile during active iteration (not the deliverable), you may defer "
MSG+="and note that the design evaluation is still owed on the final artifact. Do not claim "
MSG+="the PDF is final, done, or shippable until pdf-design-evaluator has graded it."

jq -n --arg ctx "$MSG" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'

exit 0
