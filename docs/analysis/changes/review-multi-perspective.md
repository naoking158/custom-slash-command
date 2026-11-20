# Change Analysis: Review Multi-Perspective Support

## Current Behavior

`/my:review` command supports multiple perspectives (`be`, `fe`, `security`, `perf`, `doc`, `maint`), but the output file path is determined **only by target type and identifier**, not by perspective.

### Output Path Construction (current)

```
docs/reviews/{target_type}/{IDENTIFIER}.md
```

Example:
- `/my:review be:plan:user-auth` → `docs/reviews/plans/features/user-auth.md`
- `/my:review maint:plan:user-auth` → `docs/reviews/plans/features/user-auth.md` (overwrites!)

### Affected File

- `prompts/8_review.md` (lines 146, 153-163): output-locations table

### Actual Observed Behavior

Existing review outputs are stored in `docs/reviews/maintainability/` which suggests the AI agent interprets the prompt inconsistently - sometimes using perspective, sometimes target_type for the directory. This inconsistency itself is part of the problem.

## Desired Behavior

Multiple perspectives can coexist for the same artifact. Each perspective's review is stored in a separate file.

### Acceptance Criteria

1. Running `/my:review be:plan:user-auth` then `/my:review maint:plan:user-auth` produces **two separate files**
2. Output path includes both target type and perspective
3. Confirmation message clearly shows which perspective was used
4. Existing review workflow (single perspective) continues to work seamlessly

## Gap Analysis

### What Changes

| Component | Current | Desired |
|-----------|---------|---------|
| Output path pattern | `docs/reviews/{target_type}/{IDENTIFIER}.md` | `docs/reviews/{target_type}/{PERSPECTIVE}/{IDENTIFIER}.md` |
| Output-locations table (8_review.md:153-163) | No perspective in path | Perspective included in path |
| Step 4 path instruction (8_review.md:146) | `docs/reviews/{target_type}/{{IDENTIFIER}}.md` | `docs/reviews/{target_type}/{PERSPECTIVE}/{{IDENTIFIER}}.md` |

### What Stays the Same

- Input parsing logic (perspectives, targets, identifiers)
- Checklist loading mechanism
- Review execution process
- Report template format (`review_template.md`)
- Severity levels and review principles
- Confirmation format structure

## Impact Assessment

### Affected Components

1. `prompts/8_review.md` - Output path definitions (primary change)

### Dependencies

- `prompts/templates/review_template.md` - No change needed (already includes perspective in metadata)

### Regression Risk

- **Low**: Change is limited to output path construction in prompt instructions
- Existing reviews in `docs/reviews/maintainability/` will not be affected (already use a perspective-based path)

### Breaking Changes

- Output file locations change. Existing reviews stored under old paths won't be automatically migrated, but this is acceptable as reviews are point-in-time artifacts.
