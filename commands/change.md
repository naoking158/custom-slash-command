---
description: "Analyze feature modifications with auto-generated plans"
---

# Change Request - Feature Modification & Auto Plan

Analyze an existing feature and plan a precise change with auto-generated implementation plan.

## Instructions

Follow the prompt logic defined in `~/.prompts/6_change.md`.

## Input

$ARGUMENTS

## Your Task

1. **Investigate Current Behavior**:
   - Locate the relevant code/component
   - Read and understand the current implementation
   - Document how it currently works
   - Identify constraints and dependencies

2. **Define Desired Behavior**:
   - Clarify what the user wants to achieve
   - Create clear acceptance criteria
   - Consider edge cases and user experience

3. **Perform Gap Analysis**:
   - Compare current vs desired behavior
   - Identify the minimal set of changes needed
   - Document what changes and what stays the same

4. **Assess Impact**:
   - Map affected components
   - Identify dependencies
   - Evaluate regression risk
   - Note any breaking changes

5. **Generate TWO Documents**:
   - Change Analysis: `docs/analysis/changes/{feature}.md`
   - Change Plan: `docs/plans/changes/{feature}.md`

## File Naming

Apply normalization rules:
- "Chat Input Width" → `chat-input-width.md`
- "user_profile_avatar" → `user-profile-avatar.md`
- Use a descriptive snake_case name for `{feature}`

## Output Requirement

**DO NOT** output the change request to console.
**MUST** write both files:
- `docs/analysis/changes/{feature}.md` (change template)
- `docs/plans/changes/{feature}.md` (plan template)

## Principles

- **Minimal Change**: Only change what's necessary
- **No Scope Creep**: Don't add unrelated improvements
- **User-Centric**: Prioritize user experience

## After Completion

Display next steps:
```
✅ Change analysis complete
   → docs/analysis/changes/{feature}.md

✅ Change plan generated
   → docs/plans/changes/{feature}.md

📋 Next steps:

  Quick change (simple modifications):
    /do {feature}

  Review plan first (complex changes):
    /plan change:{feature}  ← Edit the generated plan
    /do {feature}
```

## Examples

```
/change チャット入力欄の横幅が伸び続けるのを固定したい
/change ユーザープロフィールのアバター画像を丸形に変更
/change ダークモード時のボタンのコントラストを改善
```
