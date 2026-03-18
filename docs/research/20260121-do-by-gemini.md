# Research: /do-by-gemini Command

## 1. Overview

`/do-by-gemini` is a variant of the existing `/do` command that delegates implementation execution to Google's `gemini-cli` instead of having Claude Code execute it directly. This allows users to leverage Gemini's capabilities for code implementation while maintaining the same SDD (Spec-Driven Development) pipeline workflow.

## 2. Problem Statement

Currently, all implementation plans in the SDD pipeline are executed by Claude Code via the `/do` command. Users may want to:

- Compare implementation approaches between different AI models
- Utilize Gemini's specific strengths (e.g., different code generation patterns)
- Have flexibility in choosing which AI executes their implementation plans
- Reduce costs by using Gemini for certain tasks

The challenge is to create a seamless variant that maintains the same user experience and workflow while delegating actual execution to `gemini-cli`.

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: Same input resolution logic as `/do` (identifier, prefix notation)
- [x] FR-002: Read plan documents from same locations (`docs/plans/{type}/{identifier}.md`)
- [x] FR-003: Delegate execution to `gemini-cli` with appropriate prompts
- [x] FR-004: Handle `gemini-cli` output and report back to user
- [x] FR-005: Support same error handling patterns (no plan found, multiple plans)
- [x] FR-006: Provide execution summary in consistent format

### 3.2 Non-Functional Requirements

- [x] NFR-001: `gemini-cli` must be installed and available in PATH
- [x] NFR-002: Maintain consistent UX with existing `/do` command
- [x] NFR-003: Clear indication that Gemini is executing (not Claude)
- [x] NFR-004: Reasonable timeout handling for long-running implementations

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| Developer | Execute plans using Gemini AI | High |
| Developer | Same workflow as `/do` command | High |
| Developer | Clear feedback on execution status | Medium |
| Developer | Error recovery if Gemini fails | Medium |

## 5. Technical Investigation

### 5.1 Existing Solutions / Best Practices

**Current `/do` Implementation:**
- Entry point: `commands/do.md`
- Detailed logic: `prompts/7_do.md`
- Uses plan resolution logic with prefix notation
- Phases: Verify Prerequisites → Execute Phase by Phase → Quality Checks → Final Verification

**gemini-cli Capabilities:**
- Available at: `/opt/homebrew/bin/gemini`
- Default model: `gemini-2.5-pro`
- Key flags:
  - `-p, --prompt`: Direct prompt input
  - `-y, --yolo`: Auto-accept all actions (YOLO mode)
  - `-m, --model`: Model selection
  - `-a, --all_files`: Include all files in context
  - `-c, --checkpointing`: Enable file edit checkpointing

### 5.2 Technology Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Shell delegation with `-p` flag | Simple, direct execution | Limited control over output | **Recommended** |
| Interactive mode with stdin | More control | Complex to manage in prompt | Not recommended |
| Wrapper script | Maximum flexibility | Extra maintenance | Consider for v2 |

### 5.3 Constraints & Dependencies

**Dependencies:**
- `gemini-cli` must be installed (`/opt/homebrew/bin/gemini` or in PATH)
- Gemini API credentials must be configured
- Plan documents must follow existing SDD structure

**Constraints:**
- Cannot directly control Gemini's execution flow from Claude
- Output formatting may differ from Claude's
- YOLO mode (`-y`) recommended for non-interactive execution

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| gemini-cli not installed | High | Low | Check availability before execution, provide clear error message |
| Gemini API rate limits | Medium | Medium | Document rate limit handling, suggest retry |
| Different output format | Low | High | Accept variation, focus on functionality over format |
| Long execution timeout | Medium | Medium | Implement timeout handling in bash execution |
| Plan interpretation differences | Medium | Medium | Provide detailed prompt with plan context |

## 7. Open Questions

- [x] Q1: Should we use YOLO mode (`-y`) by default? → **Yes, for non-interactive execution**
- [x] Q2: How to handle partial execution failures? → **Report and let user decide to retry**
- [ ] Q3: Should we support model selection (`-m` flag)? → **Consider as enhancement**
- [ ] Q4: Should checkpointing (`-c`) be enabled by default? → **TBD based on user preference**

## 8. Recommendations

### Primary Approach

Create a `/do-by-gemini` command that:

1. **Reuses `/do` input resolution logic** - Same prefix notation and plan detection
2. **Constructs detailed prompt for Gemini** - Include plan content and source document
3. **Executes via `gemini -p` with YOLO mode** - Non-interactive execution
4. **Reports results in consistent format** - Matches `/do` output structure

### Implementation Structure

```
commands/do-by-gemini.md          # Entry point (similar to do.md)
prompts/9_do_by_gemini.md         # Detailed logic with Gemini delegation
```

### Key Differences from `/do`

| Aspect | `/do` | `/do-by-gemini` |
|--------|-------|-----------------|
| Executor | Claude Code | gemini-cli |
| Execution | Direct code editing | Shell command delegation |
| Output | Real-time progress | Post-execution report |
| Interactivity | Can pause/clarify | Non-interactive (YOLO) |

## 9. Next Steps

- [ ] Proceed to `/spec` phase with: `20260121-do-by-gemini`
- [ ] Design detailed prompt structure for Gemini
- [ ] Define error handling patterns
- [ ] Create test plan for validation

---
**Created:** 2026-01-21
**Status:** Draft
