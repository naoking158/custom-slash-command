# Pipeline Orchestration Prompt

<role>
Expert Pipeline Orchestrator responsible for coordinating sequential execution of
feature flow (research → spec → plan → do) or change flow (change → do)
with optional review cycles using specialized subagents.
Each step runs in an isolated context via the Agent tool to prevent context pollution.
</role>

<input-handling>

## 1. Parameter Parsing

Parse the raw input string to extract:

1. **feature_description_or_identifier**: The first non-option argument
   - Matches `YYYYMMDD-*` pattern → existing identifier
   - Otherwise → new feature description → generate identifier

2. **Options** (parsed from remaining arguments):
   - `--flow <type>`: Flow type (feature/change), default=feature
   - `--from <step>`: Start step, default varies by flow
   - `--to <step>`: End step, default varies by flow
   - `--only <step>`: Single step execution (mutually exclusive with --from/--to)
   - `--review`: Enable review cycle (default)
   - `--no-review`: Disable review cycle

## 2. Validation Rules

### Flow-specific step order (lowest to highest):
- **feature** flow: research < spec < plan < do
- **change** flow: change < do

### Flow-specific defaults:
| Flow | --from default | --to default |
|------|----------------|--------------|
| feature | research | plan |
| change | change | do |

### Validation checks:
- If `--flow` value is not `feature` or `change`
  → Error: "❌ Invalid flow type: '{value}'. Valid flows: feature, change"
- If `--only` is specified, `--from` and `--to` must NOT be specified
  → Error: "❌ --only cannot be used with --from/--to"
- If `--from` step is after `--to` step in order
  → Error: "❌ --from must be before --to"
- If step is not valid for the specified flow
  → Error: "❌ Step '{step}' is not valid for {flow} flow. Valid steps: {valid_steps}"
- If no arguments provided
  → Show usage and examples

## 3. Identifier Generation (for new features)

When the input is a feature description (not an existing identifier):
- Format: `YYYYMMDD-{kebab-case-name}`
- Use today's date for YYYYMMDD
- Extract English keywords from the description
- Normalize to lowercase alphanumeric and hyphens only
- Example: "ユーザー認証機能" → `20260407-user-auth`

## 4. Input File Pre-validation

When `--from` is NOT the first step of the flow, verify the previous step's output exists:

### Feature flow:
| from value | Required input file |
|------------|---------------------|
| spec | `docs/research/{id}.md` |
| plan | `docs/specs/{id}.md` |
| do | `docs/plans/features/{id}.md` |

### Change flow:
| from value | Required input file |
|------------|---------------------|
| do | `docs/plans/changes/{id}.md` |

If missing:
```
❌ Error: Required input file not found: {path}
   Run `/my:{previous_step} {id}` first.
```

</input-handling>

<pipeline-definition>

## Feature Flow Step Definitions

| Step | Subagent Type | Input | Output |
|------|---------------|-------|--------|
| research | researcher | feature_description | docs/research/{id}.md |
| spec | specifier | docs/research/{id}.md | docs/specs/{id}.md |
| plan | planner | docs/specs/{id}.md | docs/plans/features/{id}.md |
| do | implementer | docs/plans/features/{id}.md | (code changes) |

## Change Flow Step Definitions

| Step | Subagent Type | Input | Output |
|------|---------------|-------|--------|
| change | changer | change_description | docs/analysis/changes/{id}.md + docs/plans/changes/{id}.md |
| do | implementer | docs/plans/changes/{id}.md | (code changes) |

## Review Cycle (after each step, when --review is enabled)

| Sub-step | Subagent Type | Input | Output |
|----------|---------------|-------|--------|
| review | reviewer | docs/{type_path}/{id}.md | docs/reviews/{type}/{id}.md |
| fix | fixer | review + target | target file updated |

Review cycle rules:
- Maximum 1 cycle per step
- Fixer runs only if reviewer reports Critical or Medium issues
- Low-priority-only or no-issues → skip fixer
- For change flow, review target is `docs/plans/changes/{id}.md`

</pipeline-definition>

<execution-flow>

## Execution Procedure

After parsing and validation, execute the following:

### Step 1: Filter Target Steps

Determine which steps to execute based on flow type, --from, --to, --only:
- Select step candidates based on flow type:
  - feature: [research, spec, plan, do]
  - change: [change, do]
- If --only: execute only that single step
- Otherwise: execute all steps from --from to --to (inclusive)

### Step 2: Display Overwrite Warning

Check if any output files already exist for the target steps.
If so, display the list of files that will be overwritten before proceeding.

### Step 3: Sequential Execution

For each target step (in order):

**a. Display progress:**
```
🔄 [{current}/{total}] Running: {step_name}...
```

**b. Launch subagent via Agent tool:**

Use the Agent tool with the appropriate `subagent_type` parameter.
Pass a prompt containing ONLY file paths and identifier — never pass file contents.

**c. Verify output:**
After subagent completes, verify the output file exists (except for `do` step).
For the `change` step, verify BOTH output files exist:
- `docs/analysis/changes/{id}.md`
- `docs/plans/changes/{id}.md`

If either is missing:
```
❌ Error: change step did not produce expected output: {missing_path}
```

**d. Display completion:**
```
✅ [{current}/{total}] {step_name} completed → {output_path}
```

**e. Review cycle (if --review enabled and step is not `do`):**

i. Launch reviewer subagent:
```
📝 Reviewing {step_name} output...
```

ii. Read the review output and check for Critical/Medium issues.

iii. If Critical/Medium issues found, launch fixer subagent:
```
🔧 Applying fixes (Critical/Medium)...
```

iv. If no Critical/Medium issues:
```
✓ No fixes needed
```

### Step 4: Pipeline Completion

Display final summary based on flow type:

**Feature flow:**
```
═══════════════════════════════════════
🎉 Pipeline completed: {id}
═══════════════════════════════════════

Artifacts:
- Research: docs/research/{id}.md
- Spec: docs/specs/{id}.md
- Plan: docs/plans/features/{id}.md
(if review enabled)
- Reviews: docs/reviews/research/{id}.md, docs/reviews/specs/{id}.md, ...

Next step: /my:do {id}
```

**Change flow:**
```
═══════════════════════════════════════
🎉 Pipeline completed: {id}
═══════════════════════════════════════

Artifacts:
- Analysis: docs/analysis/changes/{id}.md
- Plan: docs/plans/changes/{id}.md
(if review enabled)
- Review: docs/reviews/changes/{id}.md

Next step: Code review
```

Only list artifacts that were actually created in this run.
If --to includes `do`, suggest code review instead of next step command.

</execution-flow>

<subagent-prompts>

## Prompt Templates for Each Subagent

### researcher
```
subagent_type: researcher
prompt:
  "Feature description: '{feature_description}'
   Identifier: {id}
   Output file: docs/research/{id}.md
   Today's date: {date}"
```

### specifier
```
subagent_type: specifier
prompt:
  "Feature name: {id}
   Research document: docs/research/{id}.md
   Output file: docs/specs/{id}.md"
```

### planner
```
subagent_type: planner
prompt:
  "Feature name: {id}
   Spec document: docs/specs/{id}.md
   Output file: docs/plans/features/{id}.md"
```

### implementer (feature flow)
```
subagent_type: implementer
prompt:
  "Feature name: {id}
   Plan document: docs/plans/features/{id}.md"
```

### changer
```
subagent_type: changer
prompt:
  "Change description: '{change_description}'
   Identifier: {id}
   Output analysis: docs/analysis/changes/{id}.md
   Output plan: docs/plans/changes/{id}.md
   Today's date: {date}"
```

### implementer (change flow)
```
subagent_type: implementer
prompt:
  "Feature name: {id}
   Plan document: docs/plans/changes/{id}.md"
```

### reviewer
```
subagent_type: reviewer
prompt:
  "Review target: {step_type}:{id}
   Source file: docs/{type_path}/{id}.md
   Output file: docs/reviews/{type}/{id}.md"
```

### reviewer (change plan)
```
subagent_type: reviewer
prompt:
  "Review target: change_plan:{id}
   Source file: docs/plans/changes/{id}.md
   Output file: docs/reviews/changes/{id}.md"
```

### fixer
```
subagent_type: fixer
prompt:
  "Review file: docs/reviews/{type}/{id}.md
   Target file: docs/{type_path}/{id}.md
   Apply critical and medium priority feedback only."
```

</subagent-prompts>

<error-handling>

## Error Scenarios

### 1. Missing input file
```
❌ Error: Required input file not found: {path}
   Run `/my:{previous_step} {id}` first.
```

### 2. Subagent failure
When a subagent fails or its expected output file is not created:
```
❌ Error: {step_name} failed.
   Completed artifacts are preserved.
   Resume with: /my:pipeline {id} [--flow {flow}] --from {failed_step}
```
Stop the pipeline immediately. Do not continue to the next step.

### 3. Parameter errors
- Invalid flow type:
  ```
  ❌ Invalid flow type: '{value}'. Valid flows: feature, change
  ```
- Invalid step for flow:
  ```
  ❌ Step '{step}' is not valid for {flow} flow. Valid steps: {valid_steps}
  ```
- `--from` after `--to`:
  ```
  ❌ --from must be before --to in the pipeline order
  ```
- `--only` with `--from`/`--to`:
  ```
  ❌ --only cannot be used with --from/--to
  ```
- No arguments:
  ```
  ❌ Error: No arguments provided.

  Usage: /my:pipeline <description_or_identifier> [options]

  Options:
    --flow <type>    Flow type (feature/change), default: feature
    --from <step>    Start step, default: varies by flow
    --to <step>      End step, default: varies by flow
    --only <step>    Execute single step only
    --review         Enable review cycle (default)
    --no-review      Disable review cycle

  Examples:
    /my:pipeline "新機能の追加"
    /my:pipeline "ボタン改善" --flow change
    /my:pipeline 20260407-feature --from spec --to plan
    /my:pipeline 20260407-fix --flow change --from do
    /my:pipeline "高速実行" --no-review
  ```

### 4. Change step output missing
```
❌ Error: change step did not produce expected output: {missing_path}
```

</error-handling>

<rules>

## Critical Rules

- Each subagent MUST be launched via the Agent tool (for context isolation)
- Pass ONLY file paths and identifier to subagents — NEVER pass file contents
- The parent session retains ONLY the summary returned by each subagent
- Do NOT modify any existing `/my:*` commands or their prompt files
- If output files already exist, display the overwrite targets before execution
- Execute steps strictly in order — never parallelize pipeline steps
- If a step fails, preserve all completed artifacts and stop immediately

</rules>
