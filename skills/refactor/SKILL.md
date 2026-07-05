---
description: Analyze code for refactoring and auto-generate a safe, incremental refactor plan with baseline tests, risk classification, and rollback. Trigger words: refactor, リファクタリング.
argument-hint: "<target module/files> [goals]"
---

# Refactor Phase

Analyze for refactoring: **$ARGUMENTS**

You are acting as a software architect specializing in safe refactoring.
Behavior must not change; the only proof of that is tests that were green
before you started and are still green after every step.

## Step 0 — Size the task

- **S** — rename/extract within 1–2 files. Keep both documents lean; fill
  template sections that do not apply with one line `N/A: <reason>`.
- **M** — restructure a module. Default path.
- **L** — cross-cutting architectural change. Full template; consider
  whether `/my:research` should precede this.

## Step 1 — Clarify (interactive only)

If the target or goals are ambiguous (which files, what "cleaner" means,
compatibility requirements), ask the user **at most 3** clarifying questions.
When running non-interactively (as a subagent / in a pipeline), do NOT ask:
record your assumptions in the analysis document's `Assumptions` section and
continue.

## Step 2 — Establish the baseline (before designing anything)

1. Identify and **run the existing test suite** covering the target.
2. Record the result in the analysis (`Baseline Test Status`): command run,
   green/red, coverage of the target.
3. If tests are red or absent for the target, the **first step of the plan**
   is capturing current behavior in tests — no restructuring before that.

## Step 3 — Current state analysis

Read the target files. Document structure, code smells, pain points, and
dependencies (internal and external) **with concrete file paths**. Map the
impact radius of potential changes.

## Step 4 — Target design and migration strategy

- Define the improved structure and interfaces; preserve backward
  compatibility where required.
- Break the migration into incremental steps, each **atomic and reversible**,
  ordered by dependency and safety.
- Classify each step's risk: **Critical / High / Medium / Low** (the toolkit
  scale from `skills/review/SKILL.md`).
- **List breaking changes explicitly** — API, data format, configuration.
  "None" must be stated, not implied.
- Define **stop conditions**: observations during execution that mean halt
  and reassess (e.g. baseline test fails unexpectedly, hidden coupling found).
- Document the rollback procedure.

**Safety checklist** — the plan is not finished until all hold:
- [ ] All existing tests are identified
- [ ] New tests are planned to capture current behavior
- [ ] Rollback procedure is documented
- [ ] Breaking changes are explicitly listed
- [ ] Dependencies are mapped and considered
- [ ] Each step is atomic and reversible

## Step 5 — Write the documents

Write TWO documents (create directories if missing):

1. **Analysis**: `docs/analysis/refactors/{YYYYMMDD}-{identifier}.md`,
   structured per `${CLAUDE_SKILL_DIR}/template.md`.
2. **Refactor plan** (auto-generated):
   `docs/plans/refactors/{YYYYMMDD}-{identifier}.md`, structured per
   `${CLAUDE_SKILL_DIR}/../plan/template.md` with source type "Refactor".

- Identifier: extract 2–4 English words from the target, kebab-case, prefix
  with YYYYMMDD (e.g. "決済処理のリファクタ" → `20260705-payment-processor`).
- Every plan step MUST have an executable verification command (at minimum:
  the baseline test suite stays green).
- If an output file already exists: interactive → tell the user and ask
  before overwriting; as a subagent → append `-2` to the identifier.

## Rules

- Write full content to files; console gets a short summary.
- No behavior changes hidden inside a refactor — if one is unavoidable, it
  is a listed breaking change, never a silent side effect.

## Completion

Report to the user (or return, when running as a subagent):

- Both paths: analysis and refactor plan
- Overall risk level (Critical / High / Medium / Low)
- Breaking changes: Yes (list them inline) / No
- Baseline test status (green / red / absent → capture-first plan)
- Next step: `/my:do {identifier}` (for higher-risk refactors, review and
  edit `docs/plans/refactors/{YYYYMMDD}-{identifier}.md` first)
