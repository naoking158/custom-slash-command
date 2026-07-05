---
description: Analyze a modification to existing behavior and auto-generate a minimal change plan. Trigger words: change, 変更, 改善.
argument-hint: "<change description>"
---

# Change Phase

Analyze the change request: **$ARGUMENTS**

You are acting as a product engineer planning a precise, minimal-impact
change: bridge the gap between current and desired behavior, nothing more.

## Step 0 — Is this the right skill?

| Situation | Use |
|-----------|-----|
| Modify existing behavior, UI/UX improvement, small–medium enhancement | `/my:change` (this skill) |
| New feature from scratch | `/my:research` → `/my:spec` |
| Large architectural change | `/my:research` → `/my:spec` |
| Bug fix (something is broken) | `/my:debug` |
| Code structure improvement, behavior unchanged | `/my:refactor` |

If another skill clearly fits better, say so and recommend it before
proceeding. S-sized tasks are exactly what this skill is for: the generated
plan stays lean (≤100 lines), and analysis sections that do not apply are
one line `N/A: <reason>`.

## Step 1 — Clarify (interactive only)

If the request is ambiguous (which component, what the desired behavior
looks like, how strict compatibility is), ask the user **at most 3**
clarifying questions before starting. When running non-interactively (as a
subagent / in a pipeline), do NOT ask: record your assumptions in the
analysis document's `Assumptions` section and continue.

## Step 2 — Investigate current behavior (required)

Locate the relevant code and read it. Document how it currently works, why
it was built that way, and its constraints — **citing concrete file paths**
for every claim. An analysis whose Current Behavior section has no file
paths is incomplete.

## Step 3 — Define desired behavior

State exactly what should change, as observable acceptance criteria.
Consider edge cases and existing users of the current behavior.

## Step 4 — Gap and impact analysis

- Compare current vs desired; identify the **minimal set of changes**.
- Map affected components and upstream/downstream dependencies.
- State breaking changes explicitly — "None" must be said, not implied.

**Change principles**: minimal change (only what is necessary), scope
control (no unrelated improvements), preserve intent (respect original
design decisions where valid), user-centric (experience over elegance).

## Step 5 — Write the documents

Write TWO documents (create directories if missing):

1. **Analysis**: `docs/analysis/changes/{YYYYMMDD}-{identifier}.md`,
   structured per `${CLAUDE_SKILL_DIR}/template.md`.
2. **Change plan** (auto-generated):
   `docs/plans/changes/{YYYYMMDD}-{identifier}.md`, structured per
   `${CLAUDE_SKILL_DIR}/../plan/template.md` with source type "Change".

- Identifier: extract 2–4 English words from the description, kebab-case,
  prefix with YYYYMMDD (e.g. "チャット入力欄の横幅を固定" → `20260705-chat-input-width`).
- Every plan step MUST have an executable verification command.
- If an output file already exists: interactive → tell the user and ask
  before overwriting; as a subagent → append `-2` to the identifier.

## Rules

- Write full content to files; console gets a short summary.
- Stay strictly on the requested change — defer discovered improvements to
  a note in the analysis, not to the plan.

## Completion

Report to the user (or return, when running as a subagent):

- Both paths: analysis and change plan
- Change type: Enhancement | Modification | UI/UX | Behavior Change
- Breaking changes: Yes (list them inline) / No
- Next step: `/my:do {identifier}` (for complex changes, review and edit
  `docs/plans/changes/{YYYYMMDD}-{identifier}.md` first)
