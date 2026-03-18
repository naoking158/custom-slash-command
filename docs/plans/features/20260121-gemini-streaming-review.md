# Implementation Plan: Gemini Streaming and Review Integration

## 1. Overview

既存の `/do-by-gemini` コマンドを拡張し、リアルタイムストリーミング出力、自動レビュー連携、およびモデル選択機能を実装する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260121-gemini-streaming-review.md`

### 1.2 References
- Specification: `docs/specs/20260121-gemini-streaming-review.md`
- Research: `docs/research/20260121-gemini-streaming-review.md`
- Base Specification: `docs/specs/20260121-do-by-gemini.md`
- Existing Command: `commands/do-by-gemini.md`
- Existing Prompt: `prompts/9_do_by_gemini.md`

### 1.3 Implementation Strategy

段階的なアプローチで実装を進める:
1. **Phase 1**: コマンドインターフェースの更新（-m/--model、--no-review フラグ）
2. **Phase 2**: モデルエイリアス解決ロジックの実装
3. **Phase 3**: ストリーミング出力対応（tee コマンドによるログ保存）
4. **Phase 4**: 自動レビュー連携と改善サイクル
5. **Phase 5**: レビューテンプレートの作成

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `prompts/templates/gemini-review.md` | Gemini 出力レビュー用テンプレート | High |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `commands/do-by-gemini.md` | -m/--model フラグ、--no-review フラグの追加、UI/UX 更新 | High |
| `prompts/9_do_by_gemini.md` | ストリーミング、レビュー連携、モデル選択ロジックの追加 | High |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (なし) | - |

---

## 3. Implementation Steps

### Phase 1: Command Interface Update

#### Step 1.1: Update Command Definition
**File:** `commands/do-by-gemini.md`
**Action:** Modify

**Details:**
```
- Add -m/--model option documentation
- Add --no-review option documentation
- Update command syntax examples
- Add model alias reference table
- Update error messages for new options
```

**Verification:**
- [ ] Command syntax section includes -m/--model option
- [ ] Command syntax section includes --no-review option
- [ ] Examples show all flag combinations
- [ ] Model alias table is present

---

### Phase 2: Model Alias Resolution

#### Step 2.1: Add Model Configuration Section
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Add <model-configuration> section with alias mapping:
  - 2.5 → gemini-2.5-pro
  - 2.5-pro → gemini-2.5-pro
  - 3 → gemini-3-pro-preview
  - 3-pro → gemini-3-pro-preview
- Add model resolution logic in input-handling
- Add validation for unknown models
- Add preview model warning
```

**Verification:**
- [ ] Model alias table exists in prompt
- [ ] Resolution logic handles all aliases
- [ ] Unknown model error message defined
- [ ] Preview model warning defined

---

### Phase 3: Streaming Output Implementation

#### Step 3.1: Update Execution Process for Streaming
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Update step 5 "Execute with Gemini" to use tee command:
  gemini [-m {model}] -p "{prompt}" -y 2>&1 | tee /tmp/gemini-output-{timestamp}.log
- Add output log path handling
- Update start message format to include model info
- Add progress indicators for streaming output
```

**Verification:**
- [ ] Execution command uses tee for logging
- [ ] Log file path includes timestamp
- [ ] Start message shows selected model
- [ ] Output is captured to log file

#### Step 3.2: Add Streaming UI Elements
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Update <start-format> to include model information
- Add streaming output prefix format ([Gemini] ...)
- Add completion message format
- Add interruption handling message
```

**Verification:**
- [ ] Start format shows model name
- [ ] Output is prefixed appropriately
- [ ] Completion message is clear
- [ ] Interruption scenario is handled

---

### Phase 4: Review Integration

#### Step 4.1: Add Review Phase Process
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Add new step 7 "Review Phase" after execution
- Include logic to check --no-review flag
- Add git diff retrieval for changed files
- Add log file reading for context
- Add review result display format
- Add user choice handling (Accept/Improve/Manual/Details)
```

**Verification:**
- [ ] Review phase is defined as step 7
- [ ] --no-review flag skips review
- [ ] Git diff is captured for review
- [ ] Review results format matches spec

#### Step 4.2: Add Improvement Cycle Logic
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Add improvement cycle tracking (max 3 cycles)
- Add logic for applying fixes
- Add re-review trigger after improvements
- Add cycle limit enforcement message
```

**Verification:**
- [ ] Cycle count is tracked
- [ ] Max 3 cycles enforced
- [ ] Re-review triggers after improvements
- [ ] Limit message is displayed when reached

#### Step 4.3: Add Review Output Format
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Add <review-format> section with:
  - Pass/Warning/Issue summary counts
  - Warning details list
  - Issue details list
  - User action choices [A/I/M/D]
- Add <improvement-format> section for cycle progress
```

**Verification:**
- [ ] Review format shows all severity counts
- [ ] Details are listed per severity
- [ ] User choices are clearly presented
- [ ] Improvement progress is shown during cycles

---

### Phase 5: Review Template

#### Step 5.1: Create Gemini Review Template
**File:** `prompts/templates/gemini-review.md`
**Action:** Create

**Details:**
```
- Create template for reviewing Gemini-generated code
- Include specialized checklist items:
  - Code correctness vs plan
  - Security considerations
  - Error handling completeness
  - Test coverage adequacy
  - Coding style consistency
- Include review result structure
- Include improvement suggestion format
```

**Verification:**
- [ ] Template file exists
- [ ] Checklist covers all review categories
- [ ] Result structure matches spec data models
- [ ] Suggestion format is actionable

---

### Phase 6: Error Handling Updates

#### Step 6.1: Add Model-Related Error Messages
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Add <error-invalid-model> message
- Add <error-model-unavailable> message with fallback option
- Add <error-preview-warning> for preview models
```

**Verification:**
- [ ] Invalid model error shows available models
- [ ] Model unavailable offers fallback
- [ ] Preview warning is informative

#### Step 6.2: Add Streaming/Review Error Messages
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Add <error-output-truncated> message with log path
- Add <error-max-cycles> message for improvement limit
- Add <error-not-git-repo> message for non-git contexts
- Update <error-timeout> with partial review option
```

**Verification:**
- [ ] Truncation message includes log path
- [ ] Max cycles message suggests manual review
- [ ] Non-git warning is clear
- [ ] Timeout allows partial review

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| gemini-cli | latest | Gemini execution (already required) |
| tee | system | Output streaming and logging |
| git | system | Diff for review |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `/review` command | Existing | Review format reference |
| `prompts/8_review.md` | Existing | Review logic reference |
| Review checklists | Existing | May reference for consistency |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [x] Spec document reviewed and approved
- [x] Dependencies identified and available
- [x] Existing files read and understood

### 5.2 Post-Implementation
- [ ] All command options documented correctly
- [ ] All prompt sections added/updated
- [ ] Template file created
- [ ] Error messages complete
- [ ] No linting/formatting errors in markdown

### 5.3 Acceptance Criteria Verification

**US-001: リアルタイム出力ストリーミング**
- [ ] AC-001: Gemini 実行中に出力がリアルタイムで表示される
- [ ] AC-002: ファイル変更時に進捗表示される
- [ ] AC-003: 出力が適切にフォーマットされている
- [ ] AC-004: 出力がログファイルに保存される

**US-002: 実行後自動レビュー**
- [ ] AC-001: 実行完了後に自動レビューが開始される
- [ ] AC-002: 結果が Pass/Warning/Issue に分類される
- [ ] AC-003: 改善提案が含まれる
- [ ] AC-004: --no-review でスキップ可能

**US-003: インタラクティブ改善サイクル**
- [ ] AC-001: Accept/Improve/Manual の選択肢が提示される
- [ ] AC-002: Improve 選択で自動改善が適用される
- [ ] AC-003: 改善後に再レビューが実行される
- [ ] AC-004: 最大3回のサイクル制限が機能する

**US-004: モデル選択**
- [ ] AC-001: -m/--model でモデル指定可能
- [ ] AC-002: デフォルトは gemini-2.5-pro
- [ ] AC-003: エイリアスが正しく解決される
- [ ] AC-004: 選択モデルが実行開始時に表示される
- [ ] AC-005: 無効なモデル指定でエラーが表示される

**US-005: 実行中断サポート**
- [ ] AC-001: Ctrl+C で中断可能
- [ ] AC-002: 中断時に部分変更が報告される
- [ ] AC-003: 中断後でもレビュー実行可能

---

## 6. Rollback Plan

1. Revert changes to `commands/do-by-gemini.md` to previous version
2. Revert changes to `prompts/9_do_by_gemini.md` to previous version
3. Delete `prompts/templates/gemini-review.md` if created
4. Verify original `/do-by-gemini` functionality works

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Command Interface | Low | Documentation updates only |
| Phase 2: Model Alias | Low | Simple mapping logic |
| Phase 3: Streaming | Medium | tee integration, output formatting |
| Phase 4: Review Integration | High | Multi-step workflow, user interaction |
| Phase 5: Review Template | Medium | New file with specialized content |
| Phase 6: Error Handling | Low | Additional error messages |

---

**Created:** 2026-01-21
**Status:** Ready
**Source:** docs/specs/20260121-gemini-streaming-review.md
