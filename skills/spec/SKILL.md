---
description: Create a detailed specification from a research document. Verifies the design against the actual codebase and writes a spec sized to the task. Trigger words: spec, specification, 仕様, 仕様書.
argument-hint: "<identifier>"
context: fork
agent: specifier
---

# Specification Phase

Produce a specification for: **$ARGUMENTS**

You are acting as a software architect. Requirements come from the research
document; implementation context comes from the codebase. Your job is to turn
both into a spec the planning phase can execute without re-deriving decisions.

This skill runs non-interactively: never ask the user questions. Resolve
ambiguities yourself and record each resolution in the spec's `Assumptions`
section.

## Step 1 — Read the research document

- Input: `docs/research/{id}.md` where `{id}` is `$ARGUMENTS`
  (YYYYMMDD-kebab-case identifier, same as the research doc filename).
- If the file does not exist → error stating the exact path checked and
  suggesting `/my:research "<description>"` to create it, then stop.
- Extract: functional/non-functional requirements, constraints, risks,
  recommended approach, open questions, and the recorded **Size (S/M/L)**.
- Open questions the research left unresolved: decide, and log the decision
  under `Assumptions`.

## Step 2 — Determine project type

Before designing anything, classify what kind of surface this project has
(from the research doc's codebase findings plus a quick look at the repo):
web service / API, CLI tool, library, script/tooling, UI, or mixed.

This gates the rest of the spec:

- API endpoint design, OpenAPI-style schemas, and ER diagrams apply **only**
  when the project actually has that surface.
- CLI tools, libraries, and scripts get interface/contract definitions
  appropriate to their type instead (flags and exit codes, public function
  signatures, file formats).
- Mermaid diagrams (sequence/ER/state): include only where a diagram adds
  clarity over prose. Never mandatory.

## Step 3 — Codebase consistency check (required)

The research doc supplies requirements, not implementation reality. Before
finalizing the design, verify it against the actual codebase:

1. Read the files the research doc's Codebase Findings point at (Glob/Grep/Read
   as needed).
2. Confirm the design follows existing conventions (naming, layering, error
   handling) and reuses existing components instead of inventing parallels.
3. Where the design deviates from an existing pattern, say so in the spec and
   give the reason.

A spec that contradicts the codebase's established patterns without stating
why is incomplete.

## Step 4 — Design

Sized by the research doc's **Size**; template sections that do not apply get
one line `N/A: <reason>` — never invented content.

1. **User stories & acceptance criteria** — every acceptance criterion is
   written as observable behavior (something a person or test can run and see
   pass/fail), not intention ("handles errors gracefully" is not an AC;
   "invalid input exits with code 2 and prints the offending flag" is).
2. **Interface contract** — per Step 2's project type: endpoints, CLI
   flags/exit codes, function signatures, or file formats.
3. **Data model** — entities, fields, validation; ER diagram only if relations
   warrant it.
4. **Flows & edge cases** — key interactions, error scenarios with expected
   behavior.
5. **Security & performance** — only what applies; otherwise `N/A: <reason>`.

## Step 5 — Write the document

- Output file: `docs/specs/{id}.md` (create the directory if missing). Keep
  the identifier — including its date prefix — identical to the research doc.
- Structure: follow `${CLAUDE_SKILL_DIR}/template.md`.
- Carry the research doc's Size into the spec's footer.

## Rules

- Write the full content to the file only. Console output is a short summary.
- Every design decision that deviates from research or codebase patterns is
  explained inline.
- Traceability: requirements in the spec map back to the research document.

## Completion

Report (or return, as a subagent):

- `output_path` — the file written
- 2–3 sentence summary of what was specified
- Key design decisions (and any assumptions made)
- Next step: `/my:plan {id}`
