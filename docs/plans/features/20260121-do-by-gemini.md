# Implementation Plan: /do-by-gemini Command

## 1. Overview

`/do-by-gemini` コマンドは、既存の `/do` コマンドと同じ入力解決ロジックを使用しつつ、実装計画の実行を `gemini-cli` に委譲する機能を提供します。これにより、ユーザーは異なる AI モデルでの実装アプローチを試すことができます。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260121-do-by-gemini.md`

### 1.2 References
- Specification: `docs/specs/20260121-do-by-gemini.md`
- Research: `docs/research/20260121-do-by-gemini.md`
- Related Command: `commands/do.md`
- Related Prompt: `prompts/7_do.md`

### 1.3 Implementation Strategy
既存の `/do` コマンドのパターンを踏襲し、以下の構成で実装します：
1. コマンドエントリーポイント（`commands/do-by-gemini.md`）
2. 実行ロジックプロンプト（`prompts/9_do_by_gemini.md`）

既存の入力解決ロジックを再利用し、`gemini-cli` への委譲部分を新規実装します。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `commands/do-by-gemini.md` | Slash command entry point | High |
| `prompts/9_do_by_gemini.md` | Detailed execution logic for Gemini delegation | High |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| なし | - | - |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| なし | - |

---

## 3. Implementation Steps

### Phase 1: Foundation - Command Entry Point

#### Step 1.1: Create Command Entry Point
**File:** `commands/do-by-gemini.md`
**Action:** Create

**Details:**
```
- YAML frontmatter with description
- Command title and purpose
- Reference to prompt file (~/.prompts/9_do_by_gemini.md)
- Input resolution documentation (same as /do)
- Prefix notation documentation
- Process overview
- Error handling templates
- Gemini-specific constraints
```

**Verification:**
- [ ] File exists at `commands/do-by-gemini.md`
- [ ] YAML frontmatter is valid
- [ ] Input resolution logic matches `/do` command
- [ ] References correct prompt path

---

### Phase 2: Core Logic - Execution Prompt

#### Step 2.1: Create Gemini Execution Prompt
**File:** `prompts/9_do_by_gemini.md`
**Action:** Create

**Details:**
```
- Role definition for execution context
- Input handling section with resolution logic
- gemini-cli availability check logic
- Plan document resolution (same as 7_do.md)
- Gemini prompt construction template
- Execution command pattern: gemini -p "{prompt}" -y
- Error handling for all scenarios:
  - gemini-cli not found
  - Plan not found
  - Multiple plans found
  - Empty plan content
  - Execution timeout
  - Gemini API error
- Progress reporting format
- Final output format (Gemini attribution)
```

**Verification:**
- [ ] File exists at `prompts/9_do_by_gemini.md`
- [ ] Contains gemini-cli availability check
- [ ] Contains plan resolution logic
- [ ] Contains prompt construction template
- [ ] Contains all error handling scenarios
- [ ] Output format includes Gemini attribution

---

### Phase 3: Integration - Validation

#### Step 3.1: Validate Command Registration
**File:** N/A (manual verification)
**Action:** Verify

**Details:**
```
- Verify command is discoverable via Claude Code
- Check that symlink/reference works correctly
- Validate prompt path resolution
```

**Verification:**
- [ ] Command appears in slash command list (if applicable)
- [ ] Prompt file path resolves correctly

#### Step 3.2: Validate Input Resolution
**File:** N/A (manual verification)
**Action:** Verify

**Details:**
```
- Test with existing plan identifier
- Test with prefix notation (feature:, fix:, etc.)
- Test with non-existent identifier (error case)
- Test with ambiguous identifier (multiple plans exist)
```

**Verification:**
- [ ] Simple identifier resolves correctly
- [ ] Prefix notation works for all types
- [ ] Error messages match specification

---

### Phase 4: Testing - Dry Run Validation

#### Step 4.1: Syntax and Structure Tests
**File:** Manual validation

**Test Cases:**
- [ ] Test case 1: Command file parses without YAML errors
- [ ] Test case 2: Prompt file structure matches existing patterns
- [ ] Test case 3: All placeholder tokens are valid (`{{IDENTIFIER}}` etc.)

#### Step 4.2: Integration Validation
**File:** Manual validation

**Test Cases:**
- [ ] Test case 1: `/do-by-gemini 20241218-prompt-optimization` (existing plan)
- [ ] Test case 2: `/do-by-gemini feature:20241218-prompt-optimization` (prefix)
- [ ] Test case 3: `/do-by-gemini nonexistent` (error case)

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| gemini-cli | Any | Required for execution delegation |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `prompts/7_do.md` | Existing | Reference for input resolution pattern |
| `commands/do.md` | Existing | Reference for command structure |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [x] Spec document reviewed and approved
- [x] Dependencies identified and available
- [x] Environment set up

### 5.2 Post-Implementation
- [ ] All created files have valid syntax
- [ ] Command follows existing patterns
- [ ] Documentation is consistent with `/do`
- [ ] Error messages match specification

### 5.3 Acceptance Criteria Verification
- [ ] AC-001: `/do-by-gemini {identifier}` で Plan を指定できる
- [ ] AC-002: 指定された Plan ドキュメントが正しく読み込まれる
- [ ] AC-003: `gemini-cli` が Plan 内容を含むプロンプトで実行される
- [ ] AC-004: 実行結果が一貫したフォーマットで報告される
- [ ] AC-005: 自動タイプ解決が動作する
- [ ] AC-006: プレフィックス記法がサポートされる
- [ ] AC-007: `gemini-cli` 未インストール時にエラー表示
- [ ] AC-008: 実行開始/完了時に Gemini 使用を明示

---

## 6. Rollback Plan

1. `commands/do-by-gemini.md` を削除
2. `prompts/9_do_by_gemini.md` を削除
3. 既存機能への影響なし（新規追加のみのため）

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 既存パターンの踏襲 |
| Phase 2: Core Logic | Medium | Gemini 固有のロジック追加 |
| Phase 3: Integration | Low | 手動検証のみ |
| Phase 4: Testing | Low | Dry run テスト |

---

## 8. Implementation Notes

### 8.1 Prompt Construction Template
Gemini に渡すプロンプトは以下の構造とします：

```
You are an expert developer executing an implementation plan.

## Plan Document
{plan_content}

## Source Document (Reference)
{source_document_content}

## Instructions
1. Follow the plan step by step - do NOT skip or reorder
2. Write actual source code to specified files
3. Run verification checks after each phase
4. Do NOT add features not in the source document
5. Write tests alongside implementation

## Constraints
- Follow project coding conventions
- Include appropriate error handling
- No linting or type errors allowed
- Cover code with tests as specified

Execute this plan now.
```

### 8.2 CLI Invocation Pattern
```bash
gemini -p "{constructed_prompt}" -y
```

- `-p`: Direct prompt input
- `-y`: YOLO mode (auto-accept all actions)

---
**Created:** 2026-01-21
**Status:** Ready
**Assignee:** -
