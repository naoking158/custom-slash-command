# Implementation Plan: gemini-cli Shared Prompts Architecture

## 1. Overview

gemini-cli 向けのカスタムスラッシュコマンド（/sdd:*）を作成し、Claude Code の既存コマンドと同じプロンプトロジックを共有するアーキテクチャを実装する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260121-gemini-cli-shared-prompts.md`

### 1.2 References
- Specification: `docs/specs/20260121-gemini-cli-shared-prompts.md`
- Research: `docs/research/20260121-gemini-cli-shared-prompts.md`

### 1.3 Implementation Strategy

既存の Claude Code プロンプト（`prompts/*.md`）から役割定義（Role）と処理手順（Process）を共有モジュールとして抽出し、gemini-cli 用の TOML コマンドから `@{path}` 構文で参照する。これにより、一箇所の変更で両ツールに反映される DRY な構造を実現する。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `prompts/_shared/roles/research.md` | リサーチャー役割定義 | High |
| `prompts/_shared/roles/spec.md` | アーキテクト役割定義 | High |
| `prompts/_shared/roles/plan.md` | プランナー役割定義 | High |
| `prompts/_shared/roles/do.md` | 実装者役割定義 | High |
| `prompts/_shared/roles/debug.md` | デバッガー役割定義 | Medium |
| `prompts/_shared/roles/refactor.md` | リファクタ役割定義 | Medium |
| `prompts/_shared/roles/change.md` | 変更分析役割定義 | Medium |
| `prompts/_shared/roles/review.md` | レビュアー役割定義 | Medium |
| `prompts/_shared/processes/research.md` | リサーチ手順 | High |
| `prompts/_shared/processes/spec.md` | 仕様策定手順 | High |
| `prompts/_shared/processes/plan.md` | 計画策定手順 | High |
| `prompts/_shared/processes/do.md` | 実装手順 | High |
| `prompts/_shared/processes/debug.md` | デバッグ手順 | Medium |
| `prompts/_shared/processes/refactor.md` | リファクタ手順 | Medium |
| `prompts/_shared/processes/change.md` | 変更分析手順 | Medium |
| `prompts/_shared/processes/review.md` | レビュー手順 | Medium |
| `gemini/commands/sdd/research.toml` | gemini-cli /sdd:research コマンド | High |
| `gemini/commands/sdd/spec.toml` | gemini-cli /sdd:spec コマンド | High |
| `gemini/commands/sdd/plan.toml` | gemini-cli /sdd:plan コマンド | High |
| `gemini/commands/sdd/do.toml` | gemini-cli /sdd:do コマンド | High |
| `gemini/commands/sdd/debug.toml` | gemini-cli /sdd:debug コマンド | Medium |
| `gemini/commands/sdd/refactor.toml` | gemini-cli /sdd:refactor コマンド | Medium |
| `gemini/commands/sdd/change.toml` | gemini-cli /sdd:change コマンド | Medium |
| `gemini/commands/sdd/review.toml` | gemini-cli /sdd:review コマンド | Medium |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `prompts/1_research.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/2_spec.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/3_plan.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/7_do.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/4_debug.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/5_refactor.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/6_change.md` | `@import` を使用して共有モジュールを参照 | Low |
| `prompts/8_review.md` | `@import` を使用して共有モジュールを参照 | Low |
| `README.md` | gemini-cli セットアップ手順を追加 | Low |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (None) | 既存ファイルは保持し、リファクタリングのみ |

---

## 3. Implementation Steps

### Phase 1: Foundation - 共有プロンプトモジュールの作成

#### Step 1.1: 役割定義モジュールの作成（コアコマンド）
**Files:**
- `prompts/_shared/roles/research.md`
- `prompts/_shared/roles/spec.md`
- `prompts/_shared/roles/plan.md`
- `prompts/_shared/roles/do.md`

**Action:** Create

**Details:**
```
- 既存プロンプトの <role> セクションを抽出
- ツール非依存の形式（$ARGUMENTS, {{args}} などを含まない）で記述
- 各ファイルには役割説明と専門性のみを含める
```

**Verification:**
- [ ] 各ファイルが存在し、Markdown として valid である
- [ ] ツール固有の構文が含まれていない

#### Step 1.2: 処理手順モジュールの作成（コアコマンド）
**Files:**
- `prompts/_shared/processes/research.md`
- `prompts/_shared/processes/spec.md`
- `prompts/_shared/processes/plan.md`
- `prompts/_shared/processes/do.md`

**Action:** Create

**Details:**
```
- 既存プロンプトの <process> セクションを抽出
- ステップ番号と名前を保持
- 各ステップの詳細説明を含める
- ツール非依存の形式で記述
```

**Verification:**
- [ ] 各ファイルが存在し、Markdown として valid である
- [ ] ステップが論理的順序で記述されている

---

### Phase 2: Core Logic - gemini-cli コアコマンドの実装

#### Step 2.1: research.toml の作成
**File:** `gemini/commands/sdd/research.toml`
**Action:** Create

**Details:**
```toml
description = "Research and analyze requirements for new features"
prompt = """
@{../../../prompts/_shared/roles/research.md}

## Task
Analyze the following feature request and produce a comprehensive research document.

Feature: {{args}}

@{../../../prompts/_shared/processes/research.md}

## File Naming Rules
@{../../../prompts/_shared/file-naming-rules.md}

## Output Template
@{../../../prompts/templates/research_template.md}

## Output
Write research document to: docs/research/YYYYMMDD-{identifier}.md
Use today's date for YYYYMMDD prefix.
Extract identifier from the feature name using kebab-case.
"""
```

**Verification:**
- [ ] TOML 構文が valid である
- [ ] @{path} パスが正しく解決される

#### Step 2.2: spec.toml の作成
**File:** `gemini/commands/sdd/spec.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- {{args}} で入力を受け取る
- 出力先を docs/specs/ に設定
```

**Verification:**
- [ ] TOML 構文が valid である
- [ ] @{path} パスが正しく解決される

#### Step 2.3: plan.toml の作成
**File:** `gemini/commands/sdd/plan.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- {{args}} で入力を受け取る
- 出力先を docs/plans/features/ に設定
```

**Verification:**
- [ ] TOML 構文が valid である
- [ ] @{path} パスが正しく解決される

#### Step 2.4: do.toml の作成
**File:** `gemini/commands/sdd/do.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- {{args}} で入力を受け取る
- 複数の plan タイプ（features/fixes/refactors/changes）に対応
```

**Verification:**
- [ ] TOML 構文が valid である
- [ ] @{path} パスが正しく解決される

---

### Phase 3: Extended Commands - 拡張コマンドの実装

#### Step 3.1: 役割定義モジュールの作成（拡張コマンド）
**Files:**
- `prompts/_shared/roles/debug.md`
- `prompts/_shared/roles/refactor.md`
- `prompts/_shared/roles/change.md`
- `prompts/_shared/roles/review.md`

**Action:** Create

**Details:**
```
- 既存の debug, refactor, change, review プロンプトから <role> を抽出
- ツール非依存の形式で記述
```

**Verification:**
- [ ] 各ファイルが存在する
- [ ] ツール固有の構文が含まれていない

#### Step 3.2: 処理手順モジュールの作成（拡張コマンド）
**Files:**
- `prompts/_shared/processes/debug.md`
- `prompts/_shared/processes/refactor.md`
- `prompts/_shared/processes/change.md`
- `prompts/_shared/processes/review.md`

**Action:** Create

**Details:**
```
- 既存プロンプトの <process> セクションを抽出
- ツール非依存の形式で記述
```

**Verification:**
- [ ] 各ファイルが存在する
- [ ] ステップが論理的順序で記述されている

#### Step 3.3: debug.toml の作成
**File:** `gemini/commands/sdd/debug.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- 分析レポートと修正計画の両方を出力するよう指示
```

**Verification:**
- [ ] TOML 構文が valid である

#### Step 3.4: refactor.toml の作成
**File:** `gemini/commands/sdd/refactor.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- 分析レポートとリファクタ計画の両方を出力するよう指示
```

**Verification:**
- [ ] TOML 構文が valid である

#### Step 3.5: change.toml の作成
**File:** `gemini/commands/sdd/change.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- 変更分析と変更計画の両方を出力するよう指示
```

**Verification:**
- [ ] TOML 構文が valid である

#### Step 3.6: review.toml の作成
**File:** `gemini/commands/sdd/review.toml`
**Action:** Create

**Details:**
```
- description と prompt を定義
- 共有モジュールを @{path} で参照
- 複数のレビュー視点（fe, be, security, perf, doc）に対応
```

**Verification:**
- [ ] TOML 構文が valid である

---

### Phase 4: Integration - Claude Code プロンプトの更新

#### Step 4.1: 既存プロンプトのリファクタリング
**Files:**
- `prompts/1_research.md`
- `prompts/2_spec.md`
- `prompts/3_plan.md`
- `prompts/7_do.md`
- `prompts/4_debug.md`
- `prompts/5_refactor.md`
- `prompts/6_change.md`
- `prompts/8_review.md`

**Action:** Modify

**Details:**
```
- <role> セクションを @import _shared/roles/{command}.md に置換
- <process> セクションを @import _shared/processes/{command}.md に置換
- ツール固有のセクション（<rules>, <output> など）はそのまま保持
```

**Verification:**
- [ ] 既存の Claude Code コマンドが正常に動作する
- [ ] @import ディレクティブが正しく解決される

---

### Phase 5: Documentation - ドキュメント更新

#### Step 5.1: README.md の更新
**File:** `README.md`
**Action:** Modify

**Details:**
```
- gemini-cli セットアップ手順を追加
- シンボリックリンクのコマンドを記載
- /sdd:* コマンドの使用例を追加
```

**Verification:**
- [ ] セットアップ手順が明確に記載されている
- [ ] コマンド例が正確である

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| gemini-cli | v0.23.0+ | @{path} 構文のサポートに必要 |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `prompts/_shared/file-naming-rules.md` | Exists | 既存の共有モジュール |
| `prompts/templates/*.md` | Exists | 出力テンプレート群 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document reviewed and approved
- [ ] gemini-cli がインストールされている
- [ ] リポジトリ構造が理解されている

### 5.2 Post-Implementation
- [ ] すべての共有モジュールが作成されている
- [ ] すべての TOML コマンドが作成されている
- [ ] Claude Code コマンドが正常に動作する
- [ ] gemini-cli コマンドが正常に動作する
- [ ] README が更新されている

### 5.3 Acceptance Criteria Verification

**US-001: gemini-cli で SDD ワークフローを実行**
- [ ] AC-001: `/sdd:research {feature}` で docs/research/{date}-{feature}.md にリサーチドキュメントを生成できる
- [ ] AC-002: `/sdd:spec {feature}` で docs/specs/{date}-{feature}.md に仕様書を生成できる
- [ ] AC-003: `/sdd:plan {feature}` で docs/plans/{date}-{feature}.md に実装計画を生成できる
- [ ] AC-004: `/sdd:do {feature}` で計画に基づいた実装を開始できる

**US-002: 共通プロンプトロジックの共有**
- [ ] AC-001: 役割定義（Role）が prompts/_shared/roles/ に共通化されている
- [ ] AC-002: 処理手順（Process）が prompts/_shared/processes/ に共通化されている
- [ ] AC-003: ファイル命名規則が prompts/_shared/file-naming-rules.md に共通化されている
- [ ] AC-004: 出力テンプレートが prompts/templates/ に共通化されている

**US-003: 簡単なセットアップ**
- [ ] AC-001: シンボリックリンク1コマンドでインストールが完了する
- [ ] AC-002: インストール後すぐに /sdd:* コマンドが使用可能になる
- [ ] AC-003: README に明確なインストール手順が記載されている

**US-004: 拡張コマンドの利用**
- [ ] AC-001: `/sdd:debug {issue}` でデバッグ分析を実行できる
- [ ] AC-002: `/sdd:refactor {scope}` でリファクタリング計画を作成できる
- [ ] AC-003: `/sdd:change {request}` で変更要求を分析できる
- [ ] AC-004: `/sdd:review {artifact}` でレビューを実行できる

---

## 6. Rollback Plan

問題発生時の対応手順:

1. **共有モジュールの問題**: 既存の Claude Code プロンプトから @import を削除し、元のインライン形式に戻す
2. **gemini-cli コマンドの問題**: `~/.gemini/commands/sdd` シンボリックリンクを削除
3. **全体のロールバック**: git revert で変更をすべて元に戻す

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 既存コンテンツの抽出・整理 |
| Phase 2: Core Logic | Medium | TOML 構文の習熟が必要 |
| Phase 3: Extended Commands | Medium | コアコマンドの pattern を踏襲 |
| Phase 4: Integration | Low | @import の置換のみ |
| Phase 5: Documentation | Low | README 更新のみ |

---
**Created:** 2026-01-21
**Status:** Ready
**Assignee:**
