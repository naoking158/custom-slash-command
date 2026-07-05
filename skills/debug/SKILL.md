---
description: Analyze a bug by reproducing it first, trace the root cause, and auto-generate a fix plan with a mandatory regression test. Trigger words: debug, bug analysis, デバッグ, バグ解析.
argument-hint: "<bug description>"
---

# Debug Phase

Analyze the bug: **$ARGUMENTS**

You are acting as a senior debugging engineer. The discipline is
**reproduce first, then diagnose**: a root cause that was never observed
failing is a hypothesis, not a finding, and must be labeled as one.

## Severity scale

The toolkit-wide scale (defined in `skills/review/SKILL.md`) — no other scale:

| Severity | Meaning |
|----------|---------|
| **Critical** | Security vulnerability, data loss, production-breaking |
| **High** | Blocking defect, missing requirement, broken contract |
| **Medium** | Should fix: perf concern, missing error handling, doc gap |
| **Low** | Nice to have: style, minor optimization |

## Step 1 — Clarify (interactive only)

If the bug report is ambiguous (what was expected, exact steps to trigger it,
environment), ask the user **at most 3** clarifying questions before starting.
When running non-interactively (as a subagent / in a pipeline), do NOT ask:
state your assumptions in the analysis document's `Assumptions` section and
continue.

## Step 2 — Reproduce (required, before any root-cause work)

1. **Attempt to actually reproduce the bug**: run the failing command, test,
   or flow and observe the failure yourself. Reading the report is not
   reproduction.
2. If reproduced and the repo has a test setup: **write a failing test that
   captures the bug BEFORE investigating the root cause**. Record its path in
   the analysis.
3. If reproduction is impossible (environment-specific, no access, timing):
   say so explicitly in the analysis, record what was attempted, and label
   the root cause and the fix plan as **HYPOTHESIS**.

## Step 3 — Root cause

Trace from the reproduced failure (or, for hypotheses, the best available
evidence) from symptom to source: exact file(s) and line(s), and *why* the
bug occurs — not just where. Cite concrete file paths.

## Step 4 — Impact and severity

Affected components, user impact, data-integrity risk. Assign one severity
from the scale above.

## Step 5 — Write the documents

Write TWO documents (create directories if missing):

1. **Analysis**: `docs/analysis/bugs/{YYYYMMDD}-{identifier}.md`, structured
   per `${CLAUDE_SKILL_DIR}/template.md`.
2. **Fix plan** (auto-generated): `docs/plans/fixes/{YYYYMMDD}-{identifier}.md`,
   structured per `${CLAUDE_SKILL_DIR}/../plan/template.md` with source type
   "Fix".

- Identifier: extract 2–4 English words from the description, kebab-case,
  prefix with YYYYMMDD (e.g. "ログインボタンが効かない" → `20260705-login-button-fix`).
- Every plan step MUST have an executable verification command.
- The plan MUST include a regression test step (promote the Step 2 failing
  test, or add one as part of the fix).
- If an output file already exists: interactive → tell the user and ask
  before overwriting; as a subagent → append `-2` to the identifier.

## Rules

- Write full content to files; console gets a short summary.
- No fabricated reproduction: only report commands you actually ran and
  output you actually observed.

## Completion

Report to the user (or return, when running as a subagent):

- Both paths: analysis and fix plan
- Severity
- Root cause in one or two sentences — or the hypothesis, plus why the bug
  could not be reproduced
- Next step: `/my:do {identifier}` (for complex fixes, review and edit
  `docs/plans/fixes/{YYYYMMDD}-{identifier}.md` first, then run `/my:do`)
