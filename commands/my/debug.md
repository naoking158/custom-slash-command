---
description: "Analyze bugs and generate fix plans"
---

# Debug Analysis - Bug Investigation & Auto Plan

Analyze the bug and produce a comprehensive analysis report with auto-generated fix plan.

## Instructions

Follow the prompt logic defined in `~/.prompts/4_debug.md`.

## Input

$ARGUMENTS

## Your Task

1. **Understand the Bug**: Parse the provided bug description, error logs, and any referenced files.

2. **Investigate**:
   - If specific files are mentioned, read them to understand the context
   - If error logs are provided, trace the stack to identify the source
   - Identify the root cause of the issue

3. **Analyze Impact**:
   - Determine which components are affected
   - Assess user and business impact
   - Evaluate data integrity risks

4. **Propose Solution**:
   - Describe the fix approach
   - List files that need modification
   - Assess regression risk

5. **Generate TWO Documents**:
   - Bug Analysis: `docs/analysis/bugs/{id}.md`
   - Fix Plan: `docs/plans/fixes/{id}.md`

## File Naming

Apply normalization rules:
- "ISSUE 123" → `issue-123.md`
- "auth_bug" → `auth-bug.md`
- If no ID provided, use timestamp: `YYYYMMDD-HHMMSS`

## Output Requirement

**DO NOT** output the analysis to console.
**MUST** write both files:
- `docs/analysis/bugs/{id}.md` (analysis template)
- `docs/plans/fixes/{id}.md` (plan template)

## After Completion

Display next steps:
```
✅ Bug analysis complete
   → docs/analysis/bugs/{id}.md

✅ Fix plan generated
   → docs/plans/fixes/{id}.md

📋 Next steps:

  Quick fix (simple bugs):
    /my:do {id}

  Review plan first (complex bugs):
    /my:plan fix:{id}  ← Edit the generated plan
    /my:do {id}
```
