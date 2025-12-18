---
description: "Analyze code for refactoring with auto-generated plans"
---

# Refactor Analysis - Code Restructuring & Auto Plan

Create a safe and comprehensive refactoring analysis with auto-generated plan.

## Instructions

Follow the prompt logic defined in `~/.prompts/5_refactor.md`.

## Input

$ARGUMENTS

## Your Task

1. **Analyze Current State**:
   - Read the target source files
   - Identify code smells and complexity issues
   - Map dependencies and impact radius
   - Document the current architecture

2. **Design Target State**:
   - Define the improved structure
   - Plan cleaner interfaces and abstractions
   - Ensure backward compatibility considerations
   - Create before/after architecture diagrams

3. **Plan Migration**:
   - Break down into incremental, safe steps
   - Order steps by dependency and risk
   - Define rollback procedures for each step
   - Identify checkpoints

4. **Design Testing Strategy**:
   - Identify existing test coverage
   - Plan new tests to lock current behavior
   - Design regression verification
   - Create success criteria

5. **Generate TWO Documents**:
   - Refactor Analysis: `docs/analysis/refactors/{target}.md`
   - Refactor Plan: `docs/plans/refactors/{target}.md`

## File Naming

Apply normalization rules:
- "User/Service" → `user-service.md`
- "auth_module" → `auth-module.md`
- Use the module/component name as `{target}`

## Output Requirement

**DO NOT** output the plan to console.
**MUST** write both files:
- `docs/analysis/refactors/{target}.md` (refactor design template)
- `docs/plans/refactors/{target}.md` (plan template)

## Safety First

- Each step must be independently deployable
- Include rollback strategy for every change
- Classify risk level for each step
- Document all breaking changes explicitly

## After Completion

Display next steps:
```
✅ Refactor analysis complete
   → docs/analysis/refactors/{target}.md

✅ Refactor plan generated
   → docs/plans/refactors/{target}.md

📋 Next steps:

  Quick refactor (low risk):
    /do {target}

  Review plan first (complex refactoring):
    /plan refactor:{target}  ← Edit the generated plan
    /do {target}
```
