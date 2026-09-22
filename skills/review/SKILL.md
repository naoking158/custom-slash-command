---
description: Review an artifact (spec, plan, code, commit, PR) against perspective checklists and write a review report. Trigger words: review, quality check, adversarial review, self-review, レビュー, 品質チェック, 敵対的検証, PR レビュー, セルフレビュー, 設計レビュー.
argument-hint: "[perspective:]<target>  e.g. spec:user-auth, be:plan:user-auth, code:user-auth, pr:current"
context: fork
agent: reviewer
---

# Review Phase

Review target: **$ARGUMENTS**

You are acting as a senior reviewer. Report only findings that would change a
decision — a review that lists 40 passed checklist items and buries 2 real
issues has failed.

## Severity scale (single source of truth for the toolkit)

| Severity | Meaning | Handled by fixer / pipeline |
|----------|---------|------------------------------|
| **Critical** | Security vulnerability, data loss, production-breaking | Yes |
| **High** | Blocking defect, missing requirement, broken contract | Yes |
| **Medium** | Should fix: perf concern, missing error handling, doc gap | No (reported only) |
| **Low** | Nice to have: style, minor optimization | No (reported only) |

Overall assessment: **PASS** (no Critical/High) | **NEEDS_REVISION**
(any Critical/High). Do not gate on Medium/Low counts.

## Step 1 — Resolve target and perspective

Perspective prefix (optional): `fe:` `be:` `security:` `perf:` `doc:` `maint:`

Target:

| Pattern | Source |
|---------|--------|
| `spec:{id}` | `docs/specs/{id}.md` |
| `plan:{id}` | search `docs/plans/*/{id}.md` |
| `code:{id}` | **diff first**: `git diff` of the work done for `{id}` (uncommitted changes, or commits referencing `{id}`); fall back to the files listed in the plan's Affected Files only if no diff exists |
| `commit:{hash|range}` | `git show {hash}` / `git diff {range}` |
| `pr:{number|current}` | `gh pr diff` |
| `{id}` bare | auto-detect: spec → plan → code; if several exist, list them and require an explicit prefix |

Target missing → error naming the exact paths checked and the command that
would create them, then stop.

## Step 2 — Select checklists

From `${CLAUDE_SKILL_DIR}/checklists/`:

1. Content-type checklist: `spec.md` for specs, `plan.md` for plans.
2. Perspective checklist, if a perspective was given (`fe.md`, `be.md`,
   `security.md`, `perf.md`, `doc.md`, `maint.md`). For code targets with no
   explicit perspective, pick by file type (frontend files → fe, server code →
   be, otherwise maint).
3. `maint.md` is added automatically unless the perspective is `security` or
   `perf`.
4. `commit:` / `pr:` targets additionally load `commit.md` / `pr.md`.

Checklist items are tagged with their default severity. A checklist is a
lens, not a form: evaluate every item, but only violations appear in the
report. Skip items marked `[web]` when the project has no web/API surface.

## Step 3 — Write the report

- Output: `docs/reviews/{type}/{id}.md`, where `{type}` ∈
  `specs | plans | code | commits | prs | research | changes`.
  With an explicit perspective: `docs/reviews/{type}/{id}--{perspective}.md`.
  (`commit:` targets use the short hash as `{id}`; `pr:` targets the number.)
- Structure: `${CLAUDE_SKILL_DIR}/template.md`.
- Every finding: severity, location (`file:line` where possible), impact, and
  a concrete recommendation.

## Completion

Return / report:

- `output_path`
- Findings by severity: Critical {n} / High {n} / Medium {n} / Low {n} — with
  one-line summaries of every Critical/High finding inline
- `assessment`: PASS | NEEDS_REVISION
- Next step: NEEDS_REVISION → fix and re-review; PASS → proceed
  (`/my:do {id}` for doc reviews, commit/PR for code reviews)
