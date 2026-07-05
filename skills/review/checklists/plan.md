# Plan Review Checklist

Purpose: verify an implementation plan is well-structured, feasible, complete, and specific enough for another developer to execute.
Report violations only; severity tags are defaults, adjust with justification.

## Structure
- [M] Tasks are decomposed to appropriate granularity (1 task = 1 clear deliverable)
- [H] Dependencies between tasks are explicitly stated
- [H] Implementation order is consistent with dependencies
- [M] If phases exist, completion criteria are defined for each phase

## Feasibility
- [H] Technical approach for each task is specific (not just "implement" but "implement X using Y")
- [H] Integration points with existing codebase are identified
- [M] Required external dependencies (libraries, APIs, etc.) are documented
- [M] Technical risks are identified with mitigation strategies

## Completeness
- [H] Error handling tasks are included
- [H] Test implementation tasks are included
- [M] Rollback strategy or failure response is documented
- [H] Acceptance criteria (completion conditions) are defined
- [M] Target file paths for changes are specified

## Clarity
- [H] Each step description is specific enough for another developer to implement
- [M] Ambiguous instructions ("handle as needed", "if necessary") are eliminated
- [M] Changes are described with "what", "where", and "how"

## Risk Management
- [H] Breaking changes are identified
- [H] Impact on backward compatibility is assessed
- [M] Performance impact is considered
- [M] Incremental deploy/migration strategy exists (if needed)
