---
description: "Create detailed specifications from research documents"
---

# Specification Phase - Detailed Design

Execute the specification phase for: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/2_spec.md`

## Input
Feature name: $ARGUMENTS
Research document: `docs/research/{feature}.md`

## Process
1. Read the research document at `docs/research/$ARGUMENTS.md`
2. Read the template at `.prompts/templates/spec_template.md`
3. Transform research into detailed specifications
4. Create user stories with acceptance criteria
5. Design API interfaces and data models
6. Include Mermaid diagrams (sequence, ER, state)
7. Write output to `docs/specs/{feature_name}.md`

## File Naming
- Use the same feature name as the research document
- Apply normalization rules (kebab-case)

## Critical Constraints
- MUST read the research document first (source of truth)
- Do NOT rely on chat history
- Do NOT output the document content to console
- MUST write to file in `docs/specs/` directory
- MUST include at least one Mermaid diagram

## After Completion
Provide a brief summary and suggest running `/plan {feature_name}` next.
