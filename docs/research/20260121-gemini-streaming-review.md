# Research: Gemini Streaming and Review Integration

## 1. Overview

Enhancement to the existing `/do-by-gemini` command to provide:
1. **Real-time visibility** - Stream Gemini execution output as it happens
2. **Interactive review** - Claude Code `/review` integration for post-execution improvements
3. **Collaborative refinement** - Dialog between Claude and Gemini results
4. **Model selection** - Support for different Gemini models including Gemini 3 Pro

## 2. Problem Statement

The current `/do-by-gemini` implementation has two significant UX issues:

### 2.1 Lack of Visibility During Execution

When Gemini is executing, users see only:
```
⏺ Bash(gemini -p "...") timeout: 10m 0s
  ⎿  Running in the background (↓ to manage)

⏺ Gemini CLI がバックグラウンドで実行されています。進捗を確認します。

  Task Output b5ee61b
  Execute implementation plan using gemini-cli in YOLO mode
     Waiting for task (esc to give additional instructions)

✳ Gusting… (ctrl+c to interrupt · 12m 6s · ↓ 1.2k tokens)
```

**Problems:**
- No visibility into what Gemini is actually doing
- Cannot assess progress or identify issues early
- Long wait times without feedback create anxiety
- Difficult to decide whether to wait or interrupt

### 2.2 No Post-Execution Review/Improvement Cycle

After Gemini completes:
- Results are presented as final output
- No structured review of generated code
- No mechanism for Claude to analyze and suggest improvements
- User must manually review all changes

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [ ] FR-001: Stream Gemini output in real-time during execution
- [ ] FR-002: Display progress indicators (files created/modified, phases completed)
- [ ] FR-003: Automatically trigger `/review` on completion
- [ ] FR-004: Support interactive improvement cycles (Claude reviews → suggests fixes → user confirms → Gemini/Claude implements)
- [ ] FR-005: Preserve Gemini output log for review context
- [ ] FR-006: Allow user to pause/resume streaming view
- [ ] FR-007: Support model selection via command option (e.g., `--model gemini-3-pro-preview`)
- [ ] FR-008: Default to `gemini-2.5-pro`, allow override to `gemini-3-pro-preview` or other models

### 3.2 Non-Functional Requirements

- [ ] NFR-001: Minimal latency in output streaming (< 1 second delay)
- [ ] NFR-002: Output must be readable (not overwhelming)
- [ ] NFR-003: Memory efficient for long-running executions
- [ ] NFR-004: Graceful handling of execution interruption

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| Developer | See what Gemini is doing in real-time | High |
| Developer | Review and improve Gemini's output | High |
| Developer | Understand progress during long executions | High |
| Developer | Ability to interrupt and redirect if going wrong | Medium |
| Developer | Seamless handoff between Gemini and Claude | Medium |
| Developer | Use latest Gemini models (e.g., Gemini 3 Pro) | High |
| Developer | Easy model switching without complex syntax | Medium |

## 5. Technical Investigation

### 5.1 Real-time Output Streaming Options

**Option A: Foreground Execution with Live Output**

Current approach uses background execution:
```bash
gemini -p "{prompt}" -y  # runs in background via Task tool
```

Alternative - foreground with streaming:
```bash
gemini -p "{prompt}" -y  # runs in foreground, output streams directly
```

| Aspect | Background | Foreground |
|--------|------------|------------|
| Output visibility | None during execution | Real-time |
| User control | Can do other things | Must wait |
| Timeout handling | Built-in | Manual interruption |
| Implementation | Current approach | Requires change |

**Option B: Log File Tailing**

Write output to file and tail:
```bash
gemini -p "{prompt}" -y > /tmp/gemini-output.log 2>&1 &
tail -f /tmp/gemini-output.log
```

| Pros | Cons |
|------|------|
| Real-time visibility | Extra complexity |
| Can process output | Requires cleanup |
| Background + visibility | Timing issues |

**Option C: Script Wrapper (tee-based)**

Use tee to capture and display:
```bash
gemini -p "{prompt}" -y 2>&1 | tee /tmp/gemini-output.log
```

| Pros | Cons |
|------|------|
| Simple implementation | Foreground only |
| Captures full output | No timeout control |
| Standard Unix approach | - |

### 5.2 Claude Code Execution Mechanisms

Based on Claude Code capabilities:

**Bash Tool Options:**
- `run_in_background: true` - Background execution, output later
- `run_in_background: false` - Foreground, streaming output
- `timeout` parameter - Up to 600000ms (10 minutes)

**Task Tool with TaskOutput:**
- Can check output periodically
- Non-blocking check with `block: false`
- Read output file from background process

**Recommended Approach:**
Use foreground Bash execution with output streaming for visibility, with periodic progress summaries.

### 5.3 Review Integration Options

**Option 1: Automatic Post-Execution Review**

After Gemini completes:
1. Capture Gemini output
2. Get git diff of changes
3. Automatically invoke `/review code:{identifier}`
4. Present review findings to user
5. Offer improvement suggestions

**Option 2: Manual Review Trigger**

After Gemini completes:
1. Show summary and suggest: "Run `/review` for detailed analysis"
2. User explicitly invokes review
3. Claude performs review

**Option 3: Interactive Improvement Loop**

```
┌────────────────────────────────────────────────────────────────┐
│                    Gemini Execution                            │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│                Claude Code Review                              │
│  - Analyze changed files                                       │
│  - Check against spec/plan                                     │
│  - Identify issues and improvements                            │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│              User Decision Point                               │
│  [Accept as-is] [Request improvements] [Manual fix]            │
└───────────────────────────┬────────────────────────────────────┘
                            │ (if improvements requested)
                            ▼
┌────────────────────────────────────────────────────────────────┐
│         Claude/Gemini Implements Fixes                         │
│  - Apply suggested improvements                                │
│  - Re-run review                                               │
└────────────────────────────────────────────────────────────────┘
```

**Recommendation:** Option 3 (Interactive Improvement Loop)

### 5.4 Model Selection Options

**Available Models (gemini-cli `-m` flag):**

| Model ID | Description | Use Case |
|----------|-------------|----------|
| `gemini-2.5-pro` | Current default | General purpose, stable |
| `gemini-3-pro-preview` | Gemini 3 Pro (preview) | Latest capabilities, experimental |

**Command Syntax Options:**

**Option A: Inline Flag**
```bash
/do-by-gemini --model gemini-3-pro-preview {identifier}
/do-by-gemini -m gemini-3-pro-preview {identifier}
```

**Option B: Prefix Notation**
```bash
/do-by-gemini @gemini-3-pro {identifier}
/do-by-gemini @3pro {identifier}
```

**Option C: Separate Command**
```bash
/do-by-gemini3 {identifier}  # Always uses gemini-3-pro-preview
```

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Inline Flag | Familiar CLI pattern, explicit | Longer command | **Recommended** |
| Prefix Notation | Compact | New syntax to learn | Consider |
| Separate Command | Simple | Command proliferation | Not recommended |

**Implementation:**

When model is specified, pass to gemini-cli:
```bash
gemini -m gemini-3-pro-preview -p "{prompt}" -y
```

**Model Aliases (for convenience):**

| Alias | Resolves To |
|-------|-------------|
| `2.5` or `2.5-pro` | `gemini-2.5-pro` |
| `3` or `3-pro` | `gemini-3-pro-preview` |

### 5.5 Constraints & Dependencies

**Dependencies:**
- gemini-cli installation
- Claude Code Bash tool streaming capability
- Existing `/review` command infrastructure
- Git for change detection

**Constraints:**
- Gemini output format is not controllable
- Long-running executions may produce large output
- Review cycle adds time to overall process

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Overwhelming output volume | Medium | High | Summarize/filter output, show only key events |
| Review adds significant time | Medium | Medium | Make review optional or configurable |
| Output parsing complexity | Medium | Medium | Focus on structured sections, fallback to raw |
| Gemini/Claude recommendations conflict | Low | Medium | Clear attribution, user decides |
| Timeout during long executions | High | Low | Configurable timeout, checkpoint support |
| Preview model instability | Medium | Medium | Default to stable model, warn on preview usage |
| Model not available/deprecated | Medium | Low | Fallback to default, clear error message |

## 7. Open Questions

- [ ] Q1: Should the review be automatic or opt-in? → **Recommend: Automatic with skip option**
- [ ] Q2: Which executor handles improvements (Claude or Gemini)? → **Recommend: Claude, with Gemini fallback**
- [ ] Q3: How to handle partial success (some files ok, some issues)? → **TBD**
- [ ] Q4: Should we support structured output from Gemini (JSON mode)? → **Consider for v2**
- [ ] Q5: How deep should review go (quick check vs thorough)? → **TBD based on user preference**
- [ ] Q6: What should be the default model? → **Recommend: `gemini-2.5-pro` (stable)**
- [ ] Q7: Should model preference be configurable globally? → **Consider config file option**

## 8. Recommendations

### Primary Approach

Implement a two-phase enhancement:

**Phase 1: Real-time Visibility**
1. Switch from background to foreground execution
2. Stream Gemini output directly to user
3. Add progress parsing (file created, phase completed, etc.)
4. Implement output capture for review context

**Phase 2: Review Integration**
1. After completion, auto-trigger code review
2. Present findings with actionable suggestions
3. Implement improvement request workflow
4. Claude applies improvements (with Gemini fallback option)

**Phase 3: Model Selection**
1. Add `-m` / `--model` flag support
2. Implement model aliases (`3-pro` → `gemini-3-pro-preview`)
3. Display selected model in execution header
4. Consider global config for default model preference

### Implementation Structure

```
# New/modified files
commands/do-by-gemini.md           # Update: add review integration
prompts/9_do_by_gemini.md          # Update: streaming + review flow
prompts/templates/gemini-review.md # New: review template for Gemini output
```

### Proposed Workflow

```
/do-by-gemini [-m model] {identifier}

Examples:
  /do-by-gemini user-auth                    # Uses default (gemini-2.5-pro)
  /do-by-gemini -m 3-pro user-auth           # Uses gemini-3-pro-preview
  /do-by-gemini --model gemini-3-pro-preview user-auth
```

```
/do-by-gemini -m 3-pro {identifier}
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│ 🚀 Starting Gemini Execution                                     │
│ 📄 Plan: docs/plans/features/{identifier}.md                     │
│ 🤖 Executor: gemini-cli (YOLO mode)                              │
│ 🧠 Model: gemini-3-pro-preview                                   │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼ (streaming output)
┌──────────────────────────────────────────────────────────────────┐
│ [Gemini] Reading plan...                                         │
│ [Gemini] Creating src/components/UserAuth.tsx...                 │
│ [Gemini] Writing authentication logic...                         │
│ [Gemini] Creating tests...                                       │
│ [Gemini] Running verification...                                 │
│ ✅ Gemini execution complete                                     │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│ 🔍 Claude Code Review                                            │
│                                                                  │
│ Analyzing changes made by Gemini...                              │
│                                                                  │
│ ✅ Pass: 15 items                                                │
│ ⚠️ Warnings: 3 items                                             │
│   - Missing error boundary in UserAuth.tsx:42                    │
│   - Consider adding input validation in login handler            │
│   - Test coverage could be improved for edge cases               │
│ ❌ Issues: 1 item                                                │
│   - Security: Password not hashed before storage                 │
│                                                                  │
│ [A] Accept as-is  [I] Improve  [M] Manual fix  [D] Details       │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼ (if "Improve" selected)
┌──────────────────────────────────────────────────────────────────┐
│ 🔧 Applying Improvements                                         │
│                                                                  │
│ - Adding error boundary to UserAuth.tsx                          │
│ - Implementing password hashing                                  │
│ - Adding input validation                                        │
│                                                                  │
│ ✅ Improvements applied                                          │
│                                                                  │
│ Re-running review...                                             │
│ ✅ All checks pass                                               │
└──────────────────────────────────────────────────────────────────┘
```

## 9. Next Steps

- [ ] Proceed to `/spec` phase with: `20260121-gemini-streaming-review`
- [ ] Define detailed output format specifications
- [ ] Design review integration protocol
- [ ] Create test scenarios for validation
- [ ] Consider user preference configuration

---
**Created:** 2026-01-21
**Status:** Draft
