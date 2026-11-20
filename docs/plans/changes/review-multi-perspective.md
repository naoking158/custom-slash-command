# Change Plan: Review Multi-Perspective Support

## Overview

Update the review command prompt to include perspective in output file paths, enabling multiple review perspectives to coexist for the same artifact.

## Changes

### 1. Update output-locations table in `prompts/8_review.md`

**File**: `prompts/8_review.md` (lines 146, 153-163)

**Current** (line 146):
```
2. Write report to: `docs/reviews/{target_type}/{{IDENTIFIER}}.md`
```

**New**:
```
2. Write report to: `docs/reviews/{target_type}/{PERSPECTIVE}/{{IDENTIFIER}}.md`
```

**Current** (lines 153-163):
```markdown
| Target | Output Location |
|--------|-----------------|
| `spec:{{IDENTIFIER}}` | `docs/reviews/specs/{{IDENTIFIER}}.md` |
| `plan:{{IDENTIFIER}}` | `docs/reviews/plans/features/{{IDENTIFIER}}.md` |
| `plan:fix:{{IDENTIFIER}}` | `docs/reviews/plans/fixes/{{IDENTIFIER}}.md` |
| `plan:refactor:{{IDENTIFIER}}` | `docs/reviews/plans/refactors/{{IDENTIFIER}}.md` |
| `plan:change:{{IDENTIFIER}}` | `docs/reviews/plans/changes/{{IDENTIFIER}}.md` |
| `code:{{IDENTIFIER}}` | `docs/reviews/code/{type}/{{IDENTIFIER}}.md` |
| `commit:{{HASH}}` | `docs/reviews/commits/{{HASH_SHORT}}.md` |
| `pr:{{NUMBER}}` | `docs/reviews/prs/{{NUMBER}}.md` |
```

**New**:
```markdown
| Target | Output Location |
|--------|-----------------|
| `spec:{{IDENTIFIER}}` | `docs/reviews/specs/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:{{IDENTIFIER}}` | `docs/reviews/plans/features/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:fix:{{IDENTIFIER}}` | `docs/reviews/plans/fixes/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:refactor:{{IDENTIFIER}}` | `docs/reviews/plans/refactors/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:change:{{IDENTIFIER}}` | `docs/reviews/plans/changes/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `code:{{IDENTIFIER}}` | `docs/reviews/code/{type}/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `commit:{{HASH}}` | `docs/reviews/commits/{{PERSPECTIVE}}/{{HASH_SHORT}}.md` |
| `pr:{{NUMBER}}` | `docs/reviews/prs/{{PERSPECTIVE}}/{{NUMBER}}.md` |
```

Where `{{PERSPECTIVE}}` is one of: `fe`, `be`, `security`, `perf`, `doc`, `maint`, `commit`, `pr`.

For auto-selected perspectives, use the resolved perspective name.

## Verification

1. Run `/my:review be:plan:{some-plan}` - confirm output at `docs/reviews/plans/features/be/{id}.md`
2. Run `/my:review maint:plan:{some-plan}` - confirm output at `docs/reviews/plans/features/maint/{id}.md`
3. Verify both files exist (no overwrite)
4. Verify report metadata shows correct perspective

## Notes

- This is a prompt-only change (no code files modified)
- The review_template.md already includes perspective in metadata, so no template changes needed
