---
description: Execute an implementation plan (feature, fix, refactor, or change) produced by the my toolkit. Trigger words: implement, execute plan, 実装, 実行.
argument-hint: "[type:]<identifier>"
---

# Execution Phase

Execute the implementation plan for: **$ARGUMENTS**

You are acting as a senior developer executing a reviewed plan. The plan says
*what* to build; the source document (spec/analysis) says *why*; the codebase
says *how things are done here*.

## Step 1 — Resolve the plan

| Input | Plan document |
|-------|---------------|
| `feature:{id}` | `docs/plans/features/{id}.md` |
| `fix:{id}` | `docs/plans/fixes/{id}.md` |
| `refactor:{id}` | `docs/plans/refactors/{id}.md` |
| `change:{id}` | `docs/plans/changes/{id}.md` |
| `{id}` (no prefix) | search the four paths above |

- No plan found → error listing the four expected paths and the command that
  creates each (`/my:plan`, `/my:debug`, `/my:refactor`, `/my:change`), then stop.
- Multiple plans found → error listing the matches; require an explicit prefix.

Read the plan AND its source document (spec or analysis) before writing code.

## Step 2 — Execute phase by phase

For each step in the plan:

1. Read the step; consult the source document for behavioral detail.
2. Write the code following the project's existing conventions.
3. Run the step's verification command. Do not proceed while it fails.

**When reality contradicts the plan** (file moved, API differs, assumption
wrong): stop following the plan blindly. Make the smallest sound adaptation,
record it, and report it in the completion summary. If the contradiction
invalidates the plan's approach, treat it as a blocker.

**Blockers:** document the blocker and preserve completed work.
- Interactive session → present the blocker and options to the user, then wait
  for direction.
- Running as a subagent → **return immediately** with status `blocked`, the
  blocker description, and completed-so-far summary. Never idle-wait, never
  work around the blocker silently.

## Step 3 — Quality gates (per phase)

- Lint / format / type-check clean.
- Tests relevant to the phase pass; new code has tests as specified in the plan.

## Step 4 — Final verification (required)

Self-reported checklists are not verification. After all phases:

1. Run the full test suite.
2. **Exercise the changed behavior for real**: run the app/command/flow that
   the change affects and observe the result end-to-end (for a CLI, run it;
   for an API, call it; for UI, drive it if tooling exists).
3. Verify each acceptance criterion from the source document against observed
   behavior, not intention.

## Rules

- Stay strictly within the plan + source document scope.
- **Do NOT commit** unless the user explicitly asked for commits.
- No TODO/FIXME left in delivered code for in-scope work.
- Follow existing code style; comments only for non-obvious constraints.

## Completion

Report (or return, as a subagent):

- Changes summary (files created/modified, notable adaptations from the plan)
- `test_results` — actual pass/fail output, not counts from memory
- Result of the end-to-end verification (what was run, what was observed)
- `blockers` — anything unresolved
- Suggested next step: `/my:review code:{id}` (or commit, if the user wants)
