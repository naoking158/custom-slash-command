---
description: "Review artifacts (specs, plans, code) with specialized perspectives"
---

# Review Phase - Quality Gate

Review the artifact: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/8_review.md`

## Input Resolution

The `/review` command automatically resolves perspective and target:

```
/review [perspective:]<target>

Perspectives (optional prefix):
  fe:        → Frontend (accessibility, responsive, components)
  be:        → Backend (API design, error handling, scalability)
  security:  → Security (OWASP Top 10, auth, crypto)
  perf:      → Performance (algorithms, caching, queries)
  doc:       → Documentation (completeness, accuracy, clarity)
  (none)     → Auto-select based on artifact content

Targets:
  spec:{id}           → docs/specs/{id}.md
  plan:{id}           → docs/plans/features/{id}.md
  plan:fix:{id}       → docs/plans/fixes/{id}.md
  plan:refactor:{id}  → docs/plans/refactors/{id}.md
  plan:change:{id}    → docs/plans/changes/{id}.md
  code:{id}           → Files referenced in plan
  commit:{hash}       → git show {hash} (特定コミット)
  commit:HEAD         → git show HEAD (最新コミット)
  commit:{range}      → git diff {range} (コミット範囲)
  pr:{number}         → gh pr diff {number} (PR番号指定)
  pr:current          → gh pr view + diff (現在ブランチのPR)
  {id}                → Auto-detect from existing artifacts
```

## Examples

```bash
# Specification review
/review spec:user-auth

# Backend review of plan
/review be:plan:user-auth

# Frontend review of implementation
/review fe:code:user-auth

# Security review of payment code
/review security:code:payment

# Auto-detect (checks specs → plans → code)
/review user-auth

# === Commit レビュー ===
# 特定コミットをレビュー
/review commit:abc1234

# 最新コミットをレビュー
/review commit:HEAD

# 直近3コミットをレビュー
/review commit:HEAD~3..HEAD

# セキュリティ観点でコミットレビュー
/review security:commit:abc1234

# === PR レビュー ===
# PR #123 をレビュー
/review pr:123

# 現在のブランチのPRをレビュー
/review pr:current

# バックエンド観点でPRレビュー
/review be:pr:123
```

## Input
Artifact identifier: $ARGUMENTS

## Process
1. Parse perspective prefix and target from input
2. Resolve input file(s) based on target type
3. Load appropriate checklist from `.prompts/templates/checklists/`
4. Review each checklist item against the artifact
5. Generate structured review report
6. Write report to `docs/reviews/{type}/{id}.md`
7. Display summary with next steps

## Critical Constraints
- MUST read input artifact before reviewing
- Evaluate ALL applicable checklist items
- Provide SPECIFIC, ACTIONABLE feedback
- Include file:line references where applicable
- Write review report to correct output location

## Review Standards
- Be constructive and educational
- Prioritize: 🔴 Critical → 🟡 Medium → 🟢 Low
- Explain the "why" behind each recommendation
- Consider project context and constraints

## Output Locations

| Target | Output Location |
|--------|-----------------|
| `spec:{id}` | `docs/reviews/specs/{id}.md` |
| `plan:{id}` | `docs/reviews/plans/features/{id}.md` |
| `plan:fix:{id}` | `docs/reviews/plans/fixes/{id}.md` |
| `plan:refactor:{id}` | `docs/reviews/plans/refactors/{id}.md` |
| `plan:change:{id}` | `docs/reviews/plans/changes/{id}.md` |
| `code:{id}` | `docs/reviews/code/{type}/{id}.md` |
| `commit:{hash}` | `docs/reviews/commits/{hash-short}.md` |
| `commit:{range}` | `docs/reviews/commits/{range-safe}.md` |
| `pr:{number}` | `docs/reviews/prs/{number}.md` |
| `pr:current` | `docs/reviews/prs/{number}.md` |

## After Completion
Provide summary with:
- Pass/Warning/Issue counts
- Overall assessment (PASS/NEEDS_REVISION/FAIL)
- Actionable next steps based on assessment
