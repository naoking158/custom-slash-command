---
description: "Execute sequential pipeline: research → spec → plan → do (feature) or change → do (change)"
---

# Pipeline Orchestration - Sequential Command Execution

Execute a pipeline for: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/10_pipeline.md`

## Usage

```
/my:pipeline <description_or_identifier> [options]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `description_or_identifier` | string | Yes | - | Feature/change description (new) or existing identifier (`YYYYMMDD-name` format) |
| `--flow` | enum | No | `feature` | Flow type (`feature` / `change`) |
| `--from` | enum | No | varies by flow | Start step (feature: `research`/`spec`/`plan`/`do`, change: `change`/`do`) |
| `--to` | enum | No | varies by flow | End step (feature: `research`/`spec`/`plan`/`do`, change: `change`/`do`) |
| `--only` | enum | No | - | Execute single step only (mutually exclusive with `--from`/`--to`) |
| `--review` | flag | No | `true` | Enable review cycle after each step |
| `--no-review` | flag | No | - | Disable review cycle |

## Input

Pipeline arguments: $ARGUMENTS

## Examples

```bash
# Feature flow: full pipeline (research → plan, with review)
/my:pipeline "issue #444 の解決"

# Feature flow: fast execution without review
/my:pipeline "新機能追加" --no-review

# Feature flow: resume from existing identifier (spec → plan only)
/my:pipeline 20260407-feature-name --from spec --to plan

# Feature flow: single step execution
/my:pipeline 20260407-feature-name --only research

# Change flow: full pipeline (change → do, with review)
/my:pipeline "ダークモードのボタン改善" --flow change

# Change flow: change only (review plan before do)
/my:pipeline "ボタン改善" --flow change --to change

# Change flow: resume from existing change plan
/my:pipeline 20260407-button-contrast --flow change --from do

# Change flow: fast execution without review
/my:pipeline "ボタン改善" --flow change --no-review
```

## Error Handling

**No arguments provided:**
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

## Process

1. Parse arguments and options from $ARGUMENTS
2. Determine identifier (generate or use existing)
3. Validate parameters (flow type, step order, mutual exclusivity)
4. Check input file prerequisites
5. Execute pipeline steps sequentially via subagents
6. Run optional review cycles after each step
7. Display progress and final summary
