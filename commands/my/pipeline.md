---
description: "Execute sequential pipeline: research → spec → plan → do"
---

# Pipeline Orchestration - Sequential Command Execution

Execute a pipeline for: **$ARGUMENTS**

## Instructions

Read and follow the prompt logic at: `~/.prompts/10_pipeline.md`

## Usage

```
/my:pipeline <feature_description_or_identifier> [options]
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `feature_description_or_identifier` | string | Yes | - | Feature description (new) or existing identifier (`YYYYMMDD-name` format) |
| `--from` | enum | No | `research` | Start step (`research` / `spec` / `plan` / `do`) |
| `--to` | enum | No | `plan` | End step (`research` / `spec` / `plan` / `do`) |
| `--only` | enum | No | - | Execute single step only (mutually exclusive with `--from`/`--to`) |
| `--review` | flag | No | `true` | Enable review cycle after each step |
| `--no-review` | flag | No | - | Disable review cycle |

## Input

Pipeline arguments: $ARGUMENTS

## Examples

```bash
# Full pipeline (research → plan, with review)
/my:pipeline "issue #444 の解決"

# Fast execution without review
/my:pipeline "新機能追加" --no-review

# Resume from existing identifier (spec → plan only)
/my:pipeline 20260407-feature-name --from spec --to plan

# Single step execution
/my:pipeline 20260407-feature-name --only research
```

## Error Handling

**No arguments provided:**
```
❌ Error: No arguments provided.

Usage: /my:pipeline <feature_description_or_identifier> [options]

Examples:
  /my:pipeline "新機能の追加"
  /my:pipeline 20260407-feature-name --from spec --to plan
  /my:pipeline 20260407-feature-name --only research
  /my:pipeline "高速実行" --no-review
```

## Process

1. Parse arguments and options from $ARGUMENTS
2. Determine identifier (generate or use existing)
3. Validate parameters (step order, mutual exclusivity)
4. Check input file prerequisites
5. Execute pipeline steps sequentially via subagents
6. Run optional review cycles after each step
7. Display progress and final summary
