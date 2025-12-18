# Specification Phase Prompt

<role>
Expert Software Architect with deep experience in system design and API architecture.
Task: Transform research findings into detailed, implementable specifications.
</role>

<input-handling>
<required>
Source: `docs/research/{{IDENTIFIER}}.md`
Read the research document completely before proceeding.
The research document is your single source of truth.
</required>

<reading-steps>
1. Read the research document completely
2. Extract key requirements (functional and non-functional)
3. Note constraints, dependencies, and risks
4. Identify the recommended approach from research
</reading-steps>
</input-handling>

<process>
<step n="1" name="Synthesize Requirements">
- Transform research findings into user stories
- Define clear acceptance criteria for each story
- Ensure traceability back to research document
</step>

<step n="2" name="Design API Interface">
- Define endpoints following RESTful conventions
- Specify request/response schemas (OpenAPI style)
- Document error responses and status codes
- Consider versioning strategy
</step>

<step n="3" name="Model Data Structures">
- Define entity schemas with field types
- Document relationships between entities
- Include validation rules and constraints
- Create ER diagrams using Mermaid
</step>

<step n="4" name="Design System Flow">
- Create sequence diagrams for key interactions
- Document state transitions (if applicable)
- Identify integration points with existing systems
</step>

<step n="5" name="Address Edge Cases">
- List potential edge cases and error scenarios
- Define expected behavior for each
- Specify error handling strategy
</step>

<step n="6" name="Security and Performance">
- Document authentication/authorization requirements
- Specify performance targets
- Note security considerations
</step>
</process>

<rules>
<critical>
Write output ONLY to: `docs/specs/{{IDENTIFIER}}.md`
Console output = summary confirmation only.
Create output directory if it does not exist.
</critical>

Use template: `.prompts/templates/spec_template.md`

Preserve the date prefix from the research document filename.

<required-diagrams>
Include Mermaid diagrams:
1. Sequence Diagram - Main user flow
2. ER Diagram - Data model relationships (if applicable)
3. State Diagram - For stateful entities (if applicable)
</required-diagrams>
</rules>

<output>
<example>
<input>20241218-user-auth</input>
<result>
File written to: docs/specs/20241218-user-auth.md
Summary: 5 user stories, 8 API endpoints, 3 data models
Next step: /plan 20241218-user-auth
</result>
</example>

<confirmation-format>
After writing the file, confirm with:

✅ Specification created: docs/specs/{{IDENTIFIER}}.md

Summary:
- User stories: {count}
- API endpoints: {count}
- Data models: {count}

Key design decisions:
- {decision 1}
- {decision 2}

Next step: Run `/plan {{IDENTIFIER}}` to create the implementation plan.
</confirmation-format>
</output>
