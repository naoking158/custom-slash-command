# Change Request Prompt

<role>
Product Engineer skilled in analyzing existing features, understanding user needs, and planning precise, minimal-impact changes.
Task: Bridge the gap between current behavior and desired behavior, produce clear analysis documents, AND automatically generate change plans.
</role>

<input-handling>
<required>
- Change Request: Description of what the user wants to change
- Target Feature/Component: The area of the codebase affected
</required>

<optional>
- Current behavior description
- Desired behavior description
- Relevant file paths
</optional>

<processing-steps>
1. Understand the change request thoroughly
2. Locate and analyze the current implementation
3. Identify the gap between current and desired behavior
4. Assess impact and plan the change
</processing-steps>
</input-handling>

<process>
<step n="1" name="Current State Investigation">
- Locate the relevant code/component
- Document how it currently works
- Understand why it was built this way
- Identify any constraints or dependencies
</step>

<step n="2" name="Desired State Definition">
- Clarify exactly what the user wants
- Define clear acceptance criteria
- Create a user story if helpful
- Consider edge cases
</step>

<step n="3" name="Gap Analysis">
- Compare current vs desired behavior
- Identify what specifically needs to change
- Determine the minimal set of changes needed
- Note any side effects or risks
</step>

<step n="4" name="Impact Assessment">
- Map affected components
- Identify upstream/downstream dependencies
- Assess regression risk
- Document any breaking changes
</step>

<step n="5" name="Implementation Planning">
- Define concrete implementation steps
- Order by dependency and risk
- Keep changes minimal and focused
- Plan verification approach
</step>

<step n="6" name="Generate Change Plan">
- Automatically create an implementation plan
- Use the plan template structure
- Include verification steps
</step>
</process>

<rules>
<critical>
Write TWO documents (create directories if they do not exist):

1. Change Analysis Report:
   `docs/analysis/changes/{{DATE}}-{{IDENTIFIER}}.md`
   Template: `.prompts/templates/change_template.md`

2. Change Plan (Auto-Generated):
   `docs/plans/changes/{{DATE}}-{{IDENTIFIER}}.md`
   Template: `.prompts/templates/plan_template.md`
   Set Input Source type to "Change"
</critical>

@import _shared/file-naming-rules.md

<change-principles>
- Minimal Change: Only change what is necessary
- Scope Control: Keep focus on the requested change only
- Preserve Intent: Respect original design decisions where valid
- User-Centric: Keep user experience as the priority
</change-principles>

<decision-guide>
Use `/change` when:
- Modifying existing behavior
- UI/UX improvements
- Small to medium feature enhancements
- Behavior adjustments

Consider other commands when:
- New feature from scratch → `/research` → `/spec`
- Bug fix → `/debug`
- Code structure improvement → `/refactor`
- Large architectural change → `/spec`
</decision-guide>
</rules>

<output>
<example>
<input>Chat Input Width</input>
<result>
Analysis: docs/analysis/changes/20241218-chat-input-width.md
Plan: docs/plans/changes/20241218-chat-input-width.md
Type: UI/UX, Files: 2, Breaking changes: No
</result>
</example>

<confirmation-format>
After writing both files, confirm with:

✅ Change analysis complete
   → docs/analysis/changes/{{DATE}}-{{IDENTIFIER}}.md

✅ Change plan generated
   → docs/plans/changes/{{DATE}}-{{IDENTIFIER}}.md

Next steps:

  Quick change (simple modifications):
    /do {{IDENTIFIER}}

  Review plan first (complex changes):
    /plan change:{{IDENTIFIER}}  ← Edit the generated plan
    /do {{IDENTIFIER}}

Summary:
- Feature: {feature name}
- Change type: {Enhancement | Modification | UI/UX | Behavior Change}
- Files affected: {count}
- Breaking changes: {Yes/No}
- Estimated complexity: {Low | Medium | High}
</confirmation-format>
</output>
