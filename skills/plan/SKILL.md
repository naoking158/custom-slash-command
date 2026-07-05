---
description: Create an implementation plan from a spec or analysis document. Surveys the codebase, breaks work into verifiable steps, and sizes the plan to the task. Trigger words: plan, implementation plan, 計画, 実装プラン.
argument-hint: "[fix:|refactor:|change:]<identifier>"
context: fork
agent: planner
---

# Planning Phase

Produce an implementation plan for: **$ARGUMENTS**

You are acting as a tech lead. The source document says *what* and *why*; the
codebase says *how things are done here*; the plan you write must let the
execution phase proceed step by step without re-deriving decisions.

This skill runs non-interactively: never ask the user questions. Resolve
ambiguities yourself and record each resolution in the plan's assumptions
(under Implementation Strategy).

## Step 1 — Resolve the source document

Identifiers are YYYYMMDD-kebab-case, matching the source doc filename.

| Input | Source document | Output plan |
|-------|-----------------|-------------|
| `{id}` (no prefix) | `docs/specs/{id}.md` | `docs/plans/features/{id}.md` |
| `fix:{id}` | `docs/analysis/bugs/{id}.md` | `docs/plans/fixes/{id}.md` |
| `refactor:{id}` | `docs/analysis/refactors/{id}.md` | `docs/plans/refactors/{id}.md` |
| `change:{id}` | `docs/analysis/changes/{id}.md` | `docs/plans/changes/{id}.md` |

If the source document is missing, emit this error and stop:

```
Error: Source document not found

For '{id}', expected one of:
  - docs/specs/{id}.md            → create with /my:research then /my:spec
  - docs/analysis/bugs/{id}.md    → create with /my:debug
  - docs/analysis/refactors/{id}.md → create with /my:refactor
  - docs/analysis/changes/{id}.md → create with /my:change
```

Read the source document completely. Note the recorded **Size (S/M/L)**,
acceptance criteria, constraints, and integration points.

## Step 2 — Survey the codebase (required)

Before writing any step:

1. Locate every file the plan will touch (Glob/Grep/Read); confirm current
   contents rather than trusting the source doc's snapshot.
2. Note architecture patterns, coding conventions, and reusable components
   the steps must follow.
3. Identify the project's real test/lint/build commands — these become the
   verification commands in Step 4.

## Step 3 — Size the plan

The plan's size is proportional to the task's Size:

- **S** — plan ≤ ~100 lines; a single phase is usually enough.
- **M** — collapse the 4-phase structure (Foundation / Core / Integration /
  Testing) into whatever fewer phases actually fit.
- **L** — full template.

Template sections that do not apply get one line `N/A: <reason>` — never
invented content.

## Step 4 — Write the steps

Each step must be:

- **Atomic** — completable in one sitting, touching named files (full paths).
- **Ordered** — dependencies respected.
- **Verifiable with a real command** — every implementation step carries an
  executable verification command (e.g. `npm test -- src/auth.test.ts`,
  `bats tests/install.bats`, `go build ./...`). "Check 1" or "verify it
  works" is not verification. This is a hard quality bar: a plan with a step
  lacking a runnable command is not done.

Also cover: files to create/modify/delete, new external dependencies, and a
mapping of every acceptance criterion in the source doc to the step(s) that
satisfy it (template §5.3).

## Step 5 — Write the document

- Output file: per the resolution table (create the directory if missing).
  Keep the identifier identical to the source document.
- Structure: follow `${CLAUDE_SKILL_DIR}/template.md`.
- Carry the Size into the plan's footer.

## Rules

- Write the full content to the file only. Console output is a short summary.
- Stay within the source document's scope; flag scope questions as assumptions
  rather than expanding the plan.

## Completion

Report (or return, as a subagent):

- `output_path` — the file written
- 2–3 sentence summary of the approach
- Phase overview (one line per phase)
- New external dependencies, if any
- Next step: `/my:do {id}` (prefix with `fix:`/`refactor:`/`change:` to match)
