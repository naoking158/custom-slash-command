---
description: "Execute implementation plans (features, fixes, refactors, changes)"
---

# Execution Phase - Unified Implementation

Execute the implementation plan for: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/7_do.md`

## Input Resolution

The `/do` command automatically resolves the plan type:

```
/do {identifier}

1. plans/features/{id}.md exists → Execute new feature
2. plans/fixes/{id}.md exists → Execute bug fix
3. plans/refactors/{id}.md exists → Execute refactoring
4. plans/changes/{id}.md exists → Execute change
5. Multiple exist → Error + require explicit prefix
6. None exist → Error + show guidance
```

## Explicit Prefix Notation

```
/do feature:{name}    → docs/plans/features/{name}.md
/do fix:{id}          → docs/plans/fixes/{id}.md
/do refactor:{target} → docs/plans/refactors/{target}.md
/do change:{feature}  → docs/plans/changes/{feature}.md
```

## Input
Plan identifier: $ARGUMENTS

## Process
1. Resolve the plan location based on identifier or prefix
2. Read the plan document (PRIMARY - follow exactly)
3. Read the source document - spec or analysis (REFERENCE)
4. Verify all prerequisites are met
5. Execute implementation phase by phase
6. Write actual source code to specified files
7. Run verification checks after each phase
8. Report progress after each phase completion

## Critical Constraints
- MUST read both plan and source document first
- Follow the plan step by step - do NOT skip or reorder
- Do NOT add features not in the source document
- Write tests alongside implementation
- Report blockers immediately - do NOT work around them

## Implementation Rules
- Follow project coding conventions
- Include appropriate error handling
- No linting or type errors allowed
- Cover code with tests as specified

## Error Handling

**No plan found:**
```
❌ Error: No plan found for '{identifier}'

📋 To create a plan:

  New Feature:
    /research {name}  → Start with research
    /spec {name}      → Create specification
    /plan {name}      → Create implementation plan

  Maintenance:
    /debug {issue}      → Analyze and plan bug fix
    /refactor {target}  → Analyze and plan refactoring
    /change {feature}   → Analyze and plan behavior change

💡 Tip: Check existing documents with:
    ls docs/plans/
```

**Multiple plans found:**
```
❌ Error: Multiple plans found for '{identifier}'

Please specify flow:
  /do feature:{identifier}
  /do fix:{identifier}
  /do refactor:{identifier}
  /do change:{identifier}
```

## After Completion
Provide final summary with:
- Plan type executed
- Files created/modified count
- Test results
- Acceptance criteria status
- Suggested next steps (code review, QA, deployment)
