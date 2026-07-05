---
description: Research and analyze requirements for a new feature. Investigates the existing codebase first, then external sources, and writes a research document. Trigger words: research, requirements analysis, 調査, リサーチ, 要件分析.
argument-hint: "<feature description>"
---

# Research Phase

Produce a research document for: **$ARGUMENTS**

You are acting as a technical analyst. Your job is to ground the request in the
existing codebase, gather the minimum external knowledge needed, and leave a
document the spec phase can build on without re-investigating.

## Step 0 — Size the task

Classify the request before doing anything:

- **S (small)** — behavior tweak, isolated fix, ≤2 files likely touched.
  Recommend `/my:change "$ARGUMENTS"` instead and stop (research + spec is
  overkill). Proceed only if the user explicitly wants research.
- **M (medium)** — new capability within existing architecture. Default path.
- **L (large)** — new subsystem or architectural change. Full template.

For M, template sections that do not apply are filled with a single line
`N/A: <reason>` instead of invented content.

## Step 1 — Clarify (interactive only)

If the request is ambiguous in a way that changes the research direction, ask
the user **at most 3** clarifying questions before starting.
When running non-interactively (as a subagent / in a pipeline), do NOT ask:
state your assumptions explicitly in the document's `Assumptions` section and
continue.

## Step 2 — Codebase investigation (required)

Before any external research:

1. Locate the modules, files, and conventions the feature would touch
   (Glob/Grep/Read).
2. Identify reusable components, existing patterns to follow, and prior art in
   the repo (similar features, related docs under `docs/`).
3. Record findings in the `Codebase Findings` section **with concrete file
   paths**. A research document with an empty Codebase Findings section is
   incomplete.

## Step 3 — External research (only if needed)

Use WebSearch/WebFetch only for knowledge the codebase cannot answer
(library choices, protocol details, best practices for unfamiliar domains).
Cite URLs for every external claim. Skip this step entirely for
codebase-internal work — do not pad the document with generic best practices.

## Step 4 — Analyze

- Functional / non-functional requirements, prioritized.
- Constraints, dependencies, risks with mitigations.
- Open questions that must be answered before or during spec.

## Step 5 — Write the document

- Output file: `docs/research/{YYYYMMDD}-{identifier}.md` (create the
  directory if missing).
- Identifier: extract 2–4 English words from the description, kebab-case
  (e.g. "ユーザー認証機能" → `user-auth`). Date = today.
- Structure: follow `${CLAUDE_SKILL_DIR}/template.md`.
- If the output file already exists, tell the user and ask before overwriting
  (non-interactive: append `-2` to the identifier instead).

## Rules

- Write the full content to the file only. Console output is a short summary.
- Quality bar: every codebase claim carries a file path; every external claim
  carries a URL; open questions are specific enough to be answerable.

## Completion

Report to the user (or return, when running as a subagent):

- `output_path` — the file written
- 2–3 sentence summary of key findings and the recommended approach
- Open questions, listed inline (do not bury them in the file only)
- Next step: `/my:spec {identifier}`
