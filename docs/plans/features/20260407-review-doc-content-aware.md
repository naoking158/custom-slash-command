# Implementation Plan: Review Document Content-Aware Enhancement

## 1. Overview

`/my:review` コマンドに content-type checklist 機能を追加し、仕様書・計画書レビュー時に文書の種類に応じた「内容品質」評価を自動適用する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260407-review-doc-content-aware.md`

### 1.2 References
- Specification: `docs/specs/20260407-review-doc-content-aware.md`
- Research: `docs/research/20260407-review-doc-content-aware.md`
- Review Prompt: `prompts/8_review.md`
- Review Template: `prompts/templates/review_template.md`
- Existing Checklists: `prompts/templates/checklists/review_*_checklist.md`

### 1.3 Implementation Strategy

4 つのファイルを順次変更する段階的アプローチ:
1. 新規チェックリストファイル 2 つを作成（独立した成果物）
2. レビュープロンプト `8_review.md` に content-type 判定ロジックを追加
3. レビューテンプレート `review_template.md` に content-type セクションを追加
4. 手動テストで全組み合わせを検証

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `prompts/templates/checklists/review_spec_checklist.md` | 仕様書レビューチェックリスト（Completeness, Clarity, Correctness, Verifiability, Traceability） | High |
| `prompts/templates/checklists/review_plan_checklist.md` | 計画書レビューチェックリスト（Structure, Feasibility, Completeness, Clarity, Risk Management） | High |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `prompts/8_review.md` | Step 1 に content-type 判定追加、Step 2 にチェックリスト読み込みテーブル追加、perspective auto-select スキップロジック追加 | High |
| `prompts/templates/review_template.md` | Detailed Findings に content-type セクションを perspective セクションの前に追加 | Medium |

### 2.3 Files to Delete (if any)

なし

---

## 3. Implementation Steps

### Phase 1: Foundation — チェックリストファイルの作成

#### Step 1.1: 仕様書レビューチェックリストの作成
**File:** `prompts/templates/checklists/review_spec_checklist.md`
**Action:** Create

**Details:**
```
- IEEE 830 / ISO/IEC/IEEE 29148 に準拠した仕様書レビュー観点
- 5 カテゴリ: Completeness, Clarity, Correctness, Verifiability, Traceability
- 仕様書 Section 4.1 に記載のチェック項目をそのまま採用
- 既存チェックリスト（review_fe_checklist.md 等）と同じ形式（`- [ ]` 形式）で記述
- 15-25 項目に制限（プロンプトサイズ +500-800 tokens 以内）
```

**Verification:**
- [ ] ファイルが `prompts/templates/checklists/review_spec_checklist.md` に存在する
- [ ] 5 カテゴリすべてが含まれている
- [ ] 項目数が 15-25 の範囲内

#### Step 1.2: 計画書レビューチェックリストの作成
**File:** `prompts/templates/checklists/review_plan_checklist.md`
**Action:** Create

**Details:**
```
- PMBOK / Agile に準拠した計画書レビュー観点
- 5 カテゴリ: Structure, Feasibility, Completeness, Clarity, Risk Management
- 仕様書 Section 4.2 に記載のチェック項目をそのまま採用
- 既存チェックリストと同じ形式で記述
- 15-25 項目に制限
```

**Verification:**
- [ ] ファイルが `prompts/templates/checklists/review_plan_checklist.md` に存在する
- [ ] 5 カテゴリすべてが含まれている
- [ ] 項目数が 15-25 の範囲内

---

### Phase 2: Core Logic — レビュープロンプトの更新

#### Step 2.1: Step 1 (Parse Input) に content-type 判定ロジックを追加
**File:** `prompts/8_review.md`
**Action:** Modify

**Details:**
```
- <step n="1"> 内の手順 5 の後に、手順 6 として content-type 判定を追加
- content-type 判定ルール:
  - target が spec:{id} or auto-detect で spec に解決 → content_type = "spec"
  - target が plan:{id} / plan:fix:{id} / plan:refactor:{id} / plan:change:{id} or auto-detect で plan に解決 → content_type = "plan"
  - それ以外 → content_type = none
- perspective list の決定ロジックを拡張:
  - spec/plan で perspective 未指定の場合: auto-select をスキップし content-type + maint のみ
  - spec/plan で perspective 明示指定の場合: content-type + perspective + maint (standalone ルール適用)
```

**Verification:**
- [ ] Step 1 に content-type 判定の手順が追加されている
- [ ] spec/plan + perspective 未指定時に doc: auto-select がスキップされるロジックが記述されている
- [ ] perspective 明示指定時の組み合わせルールが記述されている

#### Step 2.2: Step 2 (Load Checklist) に content-type チェックリスト読み込みテーブルを追加
**File:** `prompts/8_review.md`
**Action:** Modify

**Details:**
```
- 既存の Perspective → Checklist テーブルの前に Content-Type → Checklist テーブルを追加:
  | Content-Type | Checklist File |
  |--------------|----------------|
  | spec         | .prompts/templates/checklists/review_spec_checklist.md |
  | plan         | .prompts/templates/checklists/review_plan_checklist.md |
  | (none)       | (skip) |

- チェックリスト読み込み順序を明記:
  1. Content-type checklist (if any)
  2. Perspective checklist (if any)
  3. Maint checklist (if auto-applied)

- content-type checklist ファイルが見つからない場合の graceful degradation を記述
```

**Verification:**
- [ ] Content-Type チェックリストテーブルが追加されている
- [ ] 読み込み順序が明記されている
- [ ] graceful degradation の記述がある

#### Step 2.3: Perspective Auto-Select ルールの変更
**File:** `prompts/8_review.md`
**Action:** Modify

**Details:**
```
- Auto-Selection Rules セクションに以下の条件を追加:
  - target が spec/plan の場合、ファイル拡張子ベースの auto-select をスキップ
  - 理由コメント: "spec/plan は内容品質が重要であり doc: チェックリストは不適切"
- perspective list 決定のフロー全体を整理:
  checklist_list = [content_type_checklist, perspective_checklist, maint_if_applicable]
```

**Verification:**
- [ ] spec/plan 時の auto-select スキップロジックが記述されている
- [ ] checklist_list の構成が明確に記述されている

---

### Phase 3: Integration — レビューテンプレートの更新

#### Step 3.1: review_template.md に content-type セクションを追加
**File:** `prompts/templates/review_template.md`
**Action:** Modify

**Details:**
```
- Detailed Findings セクション内の {primary_perspective} セクションの前に
  content-type セクションを追加:

  ### [content-type] {Spec|Plan} Content Review
  （content-type がある場合のみ表示）

  #### ✅ Passed
  - {passed_item}

  #### ⚠️ Warnings
  - **[W001]** {warning_description}
    - **Location**: {file:line}
    - **Suggestion**: {suggestion}

  #### ❌ Issues
  - **[E001]** {issue_description}
    - **Location**: {file:line}
    - **Impact**: {impact}
    - **Recommendation**: {recommendation}

- Metadata セクションの Perspectives に content-type 情報を追加
- Executive Summary テーブルに content-type カテゴリ行を追加
```

**Verification:**
- [ ] content-type セクションが perspective セクションより前に配置されている
- [ ] 条件付き表示（content-type がある場合のみ）の指示がある
- [ ] 既存の perspective / maint セクション構造が維持されている

---

### Phase 4: Testing — 手動検証

#### Step 4.1: 基本動作テスト

**Test Cases:**
- [ ] TC-001: `/my:review spec:20260407-review-doc-content-aware` → spec + maint チェックリストが適用される
- [ ] TC-002: `/my:review plan:20260407-review-doc-content-aware` → plan + maint チェックリストが適用される
- [ ] TC-003: `/my:review plan:fix:user-auth` → plan + maint チェックリストが適用される

#### Step 4.2: Perspective 組み合わせテスト

**Test Cases:**
- [ ] TC-004: `/my:review be:spec:user-auth` → spec + be + maint チェックリストが適用される
- [ ] TC-005: `/my:review security:plan:user-auth` → plan + security（maint なし）
- [ ] TC-006: `/my:review doc:spec:user-auth` → spec + doc + maint の 3 つが適用される

#### Step 4.3: 後方互換性テスト

**Test Cases:**
- [ ] TC-007: `/my:review code:user-auth` → content-type なし、既存通り動作
- [ ] TC-008: `/my:review commit:HEAD` → content-type なし、既存通り動作
- [ ] TC-009: `/my:review 20260407-review-doc-content-aware` (auto-detect → spec) → spec + maint が適用される

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

なし

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `prompts/8_review.md` | Existing | 主要な変更対象 |
| `prompts/templates/review_template.md` | Existing | テンプレート更新 |
| `prompts/templates/checklists/` | Existing | 新規ファイル追加先 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] 仕様書 `docs/specs/20260407-review-doc-content-aware.md` の内容を確認済み
- [ ] 既存チェックリストの形式を把握済み
- [ ] 既存 `8_review.md` の構造を把握済み

### 5.2 Post-Implementation
- [ ] 新規チェックリスト 2 ファイルが正しいパスに存在する
- [ ] `8_review.md` の変更が既存ロジックを壊していない
- [ ] `review_template.md` の変更が既存構造を維持している
- [ ] TC-001 〜 TC-009 すべて PASS

### 5.3 Acceptance Criteria Verification
- [ ] AC: `spec:{id}` 指定時、`review_spec_checklist.md` が自動読み込み（US-001）
- [ ] AC: 仕様書チェックリストが 5 カテゴリで構成（US-001）
- [ ] AC: perspective + content-type 両方適用（US-001）
- [ ] AC: レビューレポートに content-type セクション含む（US-001）
- [ ] AC: `plan:{id}` 系指定時、`review_plan_checklist.md` が自動読み込み（US-002）
- [ ] AC: 計画書チェックリストが 5 カテゴリで構成（US-002）
- [ ] AC: auto-detect 時も content-type が適用される（US-003）
- [ ] AC: code/commit/pr に content-type 適用されない（US-004）
- [ ] AC: 既存 perspective + maint ルールに影響なし（US-004）

---

## 6. Rollback Plan

1. `prompts/templates/checklists/review_spec_checklist.md` を削除
2. `prompts/templates/checklists/review_plan_checklist.md` を削除
3. `prompts/8_review.md` を変更前に `git checkout` で復元
4. `prompts/templates/review_template.md` を変更前に `git checkout` で復元

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 仕様書に記載済みのチェック項目をファイル化するのみ |
| Phase 2: Core Logic | Medium | 既存プロンプトの条件分岐ロジックを正確に拡張する必要あり |
| Phase 3: Integration | Low | テンプレートにセクション追加のみ |
| Phase 4: Testing | Low | 手動実行による確認 |

---
**Created:** 2026-04-07
**Status:** Draft
**Assignee:**
