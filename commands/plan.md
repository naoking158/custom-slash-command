---
description: "Create implementation plans from specs or analyses"
---

# Planning Phase - Implementation Breakdown

Execute the planning phase for: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/3_plan.md`

## Input Resolution

The `/plan` command supports multiple input types via prefix notation:

| Command Pattern | Source Document | Output Location |
|-----------------|-----------------|-----------------|
| `/plan {feature}` | `docs/specs/{feature}.md` | `docs/plans/features/{feature}.md` |
| `/plan fix:{id}` | `docs/analysis/bugs/{id}.md` | `docs/plans/fixes/{id}.md` |
| `/plan refactor:{target}` | `docs/analysis/refactors/{target}.md` | `docs/plans/refactors/{target}.md` |
| `/plan change:{feature}` | `docs/analysis/changes/{feature}.md` | `docs/plans/changes/{feature}.md` |

## Input
Plan identifier: $ARGUMENTS

## Process
1. Parse the input to determine plan type and source document
2. Read the source document (spec or analysis)
3. Read the template at `.prompts/templates/plan_template.md`
4. Analyze the current codebase structure and patterns
5. List all files to create/modify with full paths
6. Break down into implementation phases
7. Define verification steps for each phase
8. Write output to appropriate `docs/plans/{type}/` directory

## File Naming
- Use kebab-case for all file names
- Apply normalization rules

## Critical Constraints
- MUST read the source document first (source of truth)
- Do NOT rely on chat history
- Do NOT output the document content to console
- Each step must be atomic and verifiable

## Error Handling
If source document not found, display guidance:
- For new features: `/research` → `/spec` → `/plan`
- For bugs: `/debug {issue}`
- For refactoring: `/refactor {target}`
- For changes: `/change {feature}`

## After Completion
Provide a brief summary and suggest running `/do {identifier}` next.
