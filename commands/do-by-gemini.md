---
description: "Execute implementation plans using gemini-cli with streaming output and optional review"
---

# Execution Phase - Gemini Delegation

Execute the implementation plan using Gemini: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/9_do_by_gemini.md`

## Command Syntax

```
/do-by-gemini [-m|--model <model>] [--no-review] {identifier}
```

### Options

| Flag | Short | Description | Default |
|------|-------|-------------|---------|
| `--model` | `-m` | Gemini model to use | `gemini-2.5-pro` |
| `--no-review` | - | Skip automatic review after execution | `false` |

### Model Aliases

| Alias | Resolves To |
|-------|-------------|
| `2.5` | `gemini-2.5-pro` |
| `2.5-pro` | `gemini-2.5-pro` |
| `3` | `gemini-3-pro-preview` |
| `3-pro` | `gemini-3-pro-preview` |

## Input Resolution

The `/do-by-gemini` command uses the same resolution logic as `/do`:

```
/do-by-gemini {identifier}

1. plans/features/{id}.md exists → Execute new feature
2. plans/fixes/{id}.md exists → Execute bug fix
3. plans/refactors/{id}.md exists → Execute refactoring
4. plans/changes/{id}.md exists → Execute change
5. Multiple exist → Error + require explicit prefix
6. None exist → Error + show guidance
```

## Explicit Prefix Notation

```
/do-by-gemini feature:{name}    → docs/plans/features/{name}.md
/do-by-gemini fix:{id}          → docs/plans/fixes/{id}.md
/do-by-gemini refactor:{target} → docs/plans/refactors/{target}.md
/do-by-gemini change:{feature}  → docs/plans/changes/{feature}.md
```

## Input
Plan identifier: $ARGUMENTS

## Examples

```bash
# Default model (gemini-2.5-pro) with review
/do-by-gemini user-auth

# Use Gemini 3 Pro
/do-by-gemini -m 3-pro user-auth
/do-by-gemini --model gemini-3-pro-preview user-auth

# Skip automatic review
/do-by-gemini --no-review user-auth

# Combined options
/do-by-gemini -m 3-pro --no-review feature:user-auth
```

## Process
1. Parse options (-m/--model, --no-review)
2. Resolve model alias if provided
3. Check `gemini-cli` availability
4. Resolve the plan location based on identifier or prefix
5. Read the plan document (PRIMARY - follow exactly)
6. Read the source document - spec or analysis (REFERENCE)
7. Construct Gemini prompt with plan and source content
8. Execute with streaming: `gemini [-m model] -p "{prompt}" -y 2>&1 | tee /tmp/gemini-output-{timestamp}.log`
9. Run automatic review (unless --no-review)
10. Report execution and review results

## Critical Constraints
- MUST verify `gemini-cli` is installed before execution
- MUST read both plan and source document first
- Uses YOLO mode (`-y`) for non-interactive execution
- Execution is delegated entirely to Gemini
- Output is streamed in real-time and saved to log file
- Review is performed by Claude Code after execution (unless --no-review)

## Gemini-Specific Notes
- Executor: `gemini-cli` (not Claude Code)
- Mode: Non-interactive (YOLO)
- Output: Real-time streaming + log file
- Attribution: Results clearly marked as Gemini-generated
- Review: Claude Code performs post-execution review
- Prompt passing: File-based (stdin) to avoid encoding issues

### API Key Requirements
- Environment variable: `GEMINI_API_KEY` must be set
- Format: Must start with `AIza`
- Clean: Must not contain invisible Unicode characters
- Validation: Automatically checked before execution

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | API key error (missing, invalid format, or Unicode characters) |
| 2 | Plan file error (not found, empty, or unreadable) |
| 3 | Gemini execution error (auth, network, sandbox) |
| 4 | Timeout |

## Error Handling

**API key not set:**
```
❌ Error: GEMINI_API_KEY is not set

To set up your API key:
  1. Visit https://aistudio.google.com/apikey
  2. Export: export GEMINI_API_KEY="your-key"
```

**API key invalid format:**
```
❌ Error: Invalid API key format

Expected: Key should start with 'AIza'
Fix: Verify you copied the correct Gemini API key
```

**API key contains Unicode characters:**
```
❌ Error: API key contains invisible Unicode characters

This commonly happens when copy-pasting from certain sources.
Fix: Re-export the key, typing the quotes manually:
  export GEMINI_API_KEY='paste-key-here'
```

**gemini-cli not found:**
```
❌ Error: gemini-cli not found

Please install gemini-cli first:
  npm install -g @google/gemini-cli

Or verify it's in your PATH:
  which gemini
```

**Invalid model specified:**
```
❌ Unknown model: '{model}'

Available models:
  gemini-2.5-pro (default)
  gemini-3-pro-preview

Aliases:
  2.5, 2.5-pro → gemini-2.5-pro
  3, 3-pro → gemini-3-pro-preview
```

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
  /do-by-gemini feature:{identifier}
  /do-by-gemini fix:{identifier}
  /do-by-gemini refactor:{identifier}
  /do-by-gemini change:{identifier}
```

## After Completion
Provide final summary with:
- Executor: Gemini (gemini-cli)
- Model used
- Plan type executed
- Files created/modified count
- Review results (if review enabled)
- Test results (if reported by Gemini)
- Suggested next steps (code review, QA, deployment)
