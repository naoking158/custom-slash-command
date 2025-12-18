---
description: "Research and analyze requirements for new features"
---

# Research Phase - Requirements Analysis

Execute the research phase for: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/1_research.md`

## Input

Feature description: $ARGUMENTS

The user will provide a description (possibly in Japanese or other languages).
You MUST extract a concise, meaningful identifier from the description.

## Process

1. Extract a short English identifier (2-4 words) from the description
2. Analyze the feature request or requirement
3. Research best practices and existing solutions
4. Identify stakeholders and needs
5. Assess risks and constraints
6. Write output to `docs/research/YYYYMMDD-{identifier}.md`

## File Naming

1. Extract identifier from description
2. Apply normalization rules (kebab-case)
3. Add today's date as prefix (YYYYMMDD-)

**Examples:**
| Input | Identifier | Filename |
|-------|------------|----------|
| user authentication feature | user-auth | 20241217-user-auth.md |
| fix chat input width | chat-input-width | 20241217-chat-input-width.md |

## Critical Constraints

- Do NOT output the document content to console
- MUST write to file in `docs/research/` directory
- MUST use date prefix in filename
- Create the directory if it does not exist

## After Completion

Provide a brief summary and suggest running `/spec YYYYMMDD-{identifier}` next.
