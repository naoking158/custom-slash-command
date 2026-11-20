# Implementation Plan: Pipeline Change Flow Integration

## 1. Overview

`/my:pipeline` コマンドに `--flow change` オプションを追加し、既存の feature フロー（`research -> spec -> plan -> do`）に加えて change フロー（`change -> do`）をサポートする。これにより change フローもパイプラインで一括実行でき、レビューサイクルの自動適用やエラーハンドリングの恩恵を受けられる。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260407-pipeline-change-flow.md`

### 1.2 References
- Specification: `docs/specs/20260407-pipeline-change-flow.md`
- Research: `docs/research/20260407-pipeline-change-flow.md`
- Pipeline Orchestration Plan: `docs/plans/features/20260407-pipeline-orchestration.md`
- Pipeline Prompt: `~/.prompts/10_pipeline.md`
- Change Command Prompt: `~/.prompts/6_change.md`

### 1.3 Implementation Strategy

3 つの成果物を作成・修正する:
1. **`agents/changer.md`** (新規) -- change subagent 定義。`~/.prompts/6_change.md` を読み込んで実行する
2. **`~/.prompts/10_pipeline.md`** (修正) -- パイプラインオーケストレーション本体に `--flow` オプション、change フロー step 定義、事前検証拡張を追記
3. **`commands/my/pipeline.md`** (修正) -- `--flow` パラメータのドキュメントと Examples を追加

既存の `/my:change`、`/my:do` コマンドおよびそのプロンプトファイル（`6_change.md`、`7_do.md`）は一切変更しない。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `agents/changer.md` | change subagent 定義（`~/.prompts/6_change.md` を Read して実行） | P0 |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `~/.prompts/10_pipeline.md` | `--flow` オプション追加、change フロー step 定義、事前検証拡張、changer subagent prompt テンプレート追加、完了時成果物表示の change 対応、エラーハンドリング追加 | pipeline のみ |
| `commands/my/pipeline.md` | `--flow` パラメータのドキュメント追加、change フロー用の Examples 追加 | pipeline のみ |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (none) | - |

---

## 3. Implementation Steps

### Phase 1: Foundation -- changer subagent 定義

#### Step 1.1: Create `agents/changer.md`
**File:** `agents/changer.md`
**Action:** Create

**Details:**
```
- YAML frontmatter:
  - name: changer
  - description: "変更リクエストを分析して change plan を生成する。change, 変更分析 に関するタスクに使用。"
  - tools: Read, Glob, Grep, Write, Edit, Bash
  - model: sonnet
- Body:
  - Instructions: Read the prompt file at `~/.prompts/6_change.md` and follow it exactly.
  - Constraints: 出力パスを明示的に渡された値に従うこと
  - Return Format:
    - output_analysis: docs/analysis/changes/{id}.md のパス
    - output_plan: docs/plans/changes/{id}.md のパス
    - summary: 変更内容のサマリー（1-3 文）
```

**Verification:**
- [ ] YAML frontmatter に `name`, `description`, `tools`, `model` フィールドがある
- [ ] `~/.prompts/6_change.md` への Read 指示がある
- [ ] 既存 subagent（`agents/implementer.md` 等）と構造が一貫している
- [ ] Return Format に `output_analysis`, `output_plan`, `summary` が定義されている

---

### Phase 2: Core Logic -- パイプラインプロンプトの拡張

#### Step 2.1: Add `--flow` option to Parameter Parsing section
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (Section 1: Parameter Parsing)

**Details:**
```
Options リストに以下を追加:
- `--flow <feature|change>`: フロータイプ、default=feature

解析ロジック:
- --flow が未指定 → デフォルトで feature
- --flow に feature, change 以外の値 → エラー:
  "Invalid flow type: '{value}'. Valid flows: feature, change"
```

**Verification:**
- [ ] `--flow` オプションが Options リストに追加されている
- [ ] デフォルト値が `feature` と明記されている
- [ ] 不正値に対するエラーメッセージが定義されている

#### Step 2.2: Add flow-aware Validation Rules
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (Section 2: Validation Rules)

**Details:**
```
既存のバリデーションルールを flow-aware に拡張:

1. フロー別の step order 定義を追加:
   - feature flow: research < spec < plan < do
   - change flow: change < do

2. フロー別の有効ステップバリデーション:
   - --flow change で --from/--to に change, do 以外を指定した場合:
     → Error: "Step '{step}' is not valid for change flow. Valid steps: change, do"
   - --flow feature で --from/--to に change を指定した場合:
     → Error: "Step 'change' is not valid for feature flow. Valid steps: research, spec, plan, do"

3. --from/--to のデフォルト値をフロー別に設定:
   - feature flow: from=research, to=plan
   - change flow: from=change, to=do
```

**Verification:**
- [ ] change フローの step order `change < do` が定義されている
- [ ] 無効なステップ指定時のエラーメッセージに有効ステップ一覧が含まれる
- [ ] フロー別のデフォルト値が明記されている

#### Step 2.3: Extend Input File Pre-validation for change flow
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (Section 4: Input File Pre-validation)

**Details:**
```
既存の Pre-validation テーブルに change フロー用のエントリを追加:

| Flow | from value | Required input file |
|------|------------|---------------------|
| feature | spec | docs/research/{id}.md |
| feature | plan | docs/specs/{id}.md |
| feature | do | docs/plans/features/{id}.md |
| change | do | docs/plans/changes/{id}.md |

change フローで from=do かつ docs/plans/changes/{id}.md が存在しない場合:
→ Error: "Required input file not found: docs/plans/changes/{id}.md
   Run `/my:change {id}` first."
```

**Verification:**
- [ ] change フローの pre-validation ルールが追加されている
- [ ] エラーメッセージに `/my:change` が案内されている

#### Step 2.4: Add change flow step definitions to Pipeline Definition
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (`<pipeline-definition>` section)

**Details:**
```
既存の feature フロー step 定義テーブルの後に change フロー定義を追加:

## Change Flow Step Definitions

| Step | Subagent Type | Input | Output |
|------|---------------|-------|--------|
| change | changer | change_description | docs/analysis/changes/{id}.md + docs/plans/changes/{id}.md |
| do | implementer | docs/plans/changes/{id}.md | (code changes) |

Review Cycle (change フロー、change ステップ後):
| Sub-step | Subagent Type | Input | Output |
|----------|---------------|-------|--------|
| review | reviewer | docs/plans/changes/{id}.md | docs/reviews/changes/{id}.md |
| fix | fixer | review + docs/plans/changes/{id}.md | docs/plans/changes/{id}.md updated |
```

**Verification:**
- [ ] change フローの step 定義テーブルが追加されている
- [ ] changer subagent の出力が 2 ファイル（analysis + plan）と明記されている
- [ ] change フロー固有のレビューサイクルが定義されている

#### Step 2.5: Add changer subagent prompt template
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (`<subagent-prompts>` section)

**Details:**
```
既存の subagent prompt テンプレートに changer を追加:

### changer
subagent_type: changer
prompt:
  "Change description: '{change_description}'
   Identifier: {id}
   Output analysis: docs/analysis/changes/{id}.md
   Output plan: docs/plans/changes/{id}.md
   Today's date: {date}"

implementer (change フロー用) の prompt テンプレートも追記:
### implementer (change flow)
subagent_type: implementer
prompt:
  "Feature name: {id}
   Plan document: docs/plans/changes/{id}.md"

reviewer (change plan 用) の prompt テンプレート:
### reviewer (change plan)
subagent_type: reviewer
prompt:
  "Review target: change_plan:{id}
   Source file: docs/plans/changes/{id}.md
   Output file: docs/reviews/changes/{id}.md"

fixer (change plan 用) の prompt テンプレート:
### fixer (change plan)
subagent_type: fixer
prompt:
  "Review file: docs/reviews/changes/{id}.md
   Target file: docs/plans/changes/{id}.md
   Apply critical and medium priority feedback only."
```

**Verification:**
- [ ] changer subagent の prompt テンプレートに change_description, id, output paths, date が含まれる
- [ ] implementer (change flow) が `docs/plans/changes/{id}.md` を参照している
- [ ] reviewer/fixer が `docs/reviews/changes/{id}.md` を参照している

#### Step 2.6: Extend execution flow for change flow
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (`<execution-flow>` section)

**Details:**
```
Step 1 (Filter Target Steps) を flow-aware に拡張:
- flow_type に基づいて step 候補リストを切り替える:
  - feature: [research, spec, plan, do]
  - change: [change, do]
- --from/--to/--only でフィルタリング

Step 3 (Sequential Execution) に change ステップの出力検証を追加:
- change ステップ完了後:
  - docs/analysis/changes/{id}.md の存在確認
  - docs/plans/changes/{id}.md の存在確認
  - どちらかが欠如 → エラー:
    "change step did not produce expected output: {missing_path}"

Step 4 (Pipeline Completion) に change フロー用の成果物表示を追加:
- change フローの場合:
  ═══════════════════════════════════════
  Pipeline completed: {id}
  ═══════════════════════════════════════

  Artifacts:
  - Analysis: docs/analysis/changes/{id}.md
  - Plan: docs/plans/changes/{id}.md
  (if review enabled)
  - Review: docs/reviews/changes/{id}.md

  (if --to includes do)
  Next step: Code review
  (else)
  Next step: /my:do {id}
```

**Verification:**
- [ ] step 候補リストが flow_type に基づいて分岐している
- [ ] change ステップの出力が 2 ファイル分検証されている
- [ ] 完了サマリーに change 固有のパスが含まれている

#### Step 2.7: Add change flow error handling
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (`<error-handling>` section)

**Details:**
```
既存のエラーシナリオに以下を追加:

4. Invalid flow type:
   "Invalid flow type: '{value}'. Valid flows: feature, change"

5. Invalid step for flow:
   "Step '{step}' is not valid for {flow} flow. Valid steps: {valid_steps}"

6. changer subagent failure:
   "change failed.
    Completed artifacts are preserved.
    Resume with: /my:pipeline {id} --flow change --from change"

7. change output missing:
   "change step did not produce expected output: {missing_path}"
```

**Verification:**
- [ ] 4 つの新規エラーシナリオが定義されている
- [ ] resume コマンドに `--flow change` が含まれている

#### Step 2.8: Update usage/no-arguments error message
**File:** `~/.prompts/10_pipeline.md`
**Action:** Modify (`<error-handling>` section, no-arguments error)

**Details:**
```
既存の Usage 表示に --flow オプションを追加:

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
```

**Verification:**
- [ ] `--flow` オプションが Usage に記載されている
- [ ] change フローの Example が含まれている

---

### Phase 3: Integration -- コマンド定義の更新と一貫性検証

#### Step 3.1: Update `commands/my/pipeline.md`
**File:** `commands/my/pipeline.md`
**Action:** Modify

**Details:**
```
1. YAML frontmatter の description を更新:
   "Execute sequential pipeline: research -> spec -> plan -> do (feature) or change -> do (change)"

2. Parameters テーブルに --flow を追加:
   | `--flow` | enum | No | `feature` | Flow type (`feature` / `change`) |

3. Examples セクションに change フロー例を追加:
   # Change flow (change -> do, with review)
   /my:pipeline "ダークモードのボタン改善" --flow change

   # Change only (review plan before do)
   /my:pipeline "ボタン改善" --flow change --to change

   # Resume from existing change plan
   /my:pipeline 20260407-button-contrast --flow change --from do

   # Fast change without review
   /my:pipeline "ボタン改善" --flow change --no-review

4. Error Handling セクションの Usage 表示に --flow を追加
```

**Verification:**
- [ ] `--flow` パラメータが Parameters テーブルに追加されている
- [ ] change フローの Examples が 4 パターン記載されている
- [ ] Error Handling の Usage に `--flow` が含まれている
- [ ] 既存の feature フロー Examples が保持されている

#### Step 3.2: Validate cross-file references
**Action:** Verify

**Details:**
```
- agents/changer.md が ~/.prompts/6_change.md を参照している
- ~/.prompts/10_pipeline.md が agents/changer.md (subagent_type: changer) を参照している
- commands/my/pipeline.md が ~/.prompts/10_pipeline.md を参照している
- implementer subagent が docs/plans/changes/{id}.md を解決可能
  (7_do.md の plan type resolution に plans/changes/ が含まれている)
- reviewer/fixer subagent の出力パスが docs/reviews/changes/{id}.md
```

**Verification:**
- [ ] changer subagent の name が `10_pipeline.md` 内の subagent_type と一致
- [ ] `7_do.md` に `plans/changes/{id}.md` の resolution ロジックが既存であることを確認
- [ ] 出力パス規約が一貫している（`docs/analysis/changes/`, `docs/plans/changes/`, `docs/reviews/changes/`）

#### Step 3.3: Validate backward compatibility
**Action:** Verify

**Details:**
```
- --flow 未指定時のデフォルトが feature であること
- feature フローの step 定義・バリデーション・事前検証・エラーメッセージが変更されていないこと
- 既存の /my:change, /my:do コマンドが変更されていないこと
- agents/implementer.md, agents/reviewer.md, agents/fixer.md が変更されていないこと
```

**Verification:**
- [ ] `--flow` 未指定 → feature フロー（既存動作と同一）
- [ ] `~/.prompts/6_change.md` が変更されていない
- [ ] `~/.prompts/7_do.md` が変更されていない
- [ ] `commands/my/change.md` が変更されていない
- [ ] `commands/my/do.md` が変更されていない
- [ ] `agents/implementer.md` が変更されていない

---

### Phase 4: Testing -- 動作確認

#### Step 4.1: Parameter parsing tests
**Description:** `--flow` パラメータと change フロー固有のバリデーションの確認

**Test Cases:**
- [ ] `/my:pipeline "変更内容" --flow change` → flow=change, from=change, to=do, review=true
- [ ] `/my:pipeline "変更内容" --flow change --to change` → change のみ実行
- [ ] `/my:pipeline 20260407-fix --flow change --from do` → do のみ実行（plan 存在チェック）
- [ ] `/my:pipeline "変更内容" --flow change --no-review` → review=false
- [ ] `/my:pipeline "新機能"` → flow=feature（デフォルト）、既存動作維持
- [ ] `/my:pipeline "変更" --flow invalid` → エラー: "Invalid flow type"
- [ ] `/my:pipeline "変更" --flow change --from spec` → エラー: "Step 'spec' is not valid for change flow"
- [ ] `/my:pipeline "変更" --flow change --from do --to change` → エラー: "--from must be before --to"

#### Step 4.2: Change flow E2E test (manual)
**Description:** change フローのフルパイプライン実行

**Test Cases:**
- [ ] `/my:pipeline "テスト変更" --flow change --no-review` で change -> do が実行される
- [ ] change ステップで `docs/analysis/changes/{id}.md` と `docs/plans/changes/{id}.md` が生成される
- [ ] do ステップで `docs/plans/changes/{id}.md` を入力として実装が実行される
- [ ] 進捗表示が `[1/2]`, `[2/2]` と表示される
- [ ] 完了時に change 固有の成果物一覧が表示される

#### Step 4.3: Change flow partial execution test (manual)
**Description:** change フローの部分実行

**Test Cases:**
- [ ] `--flow change --to change` で change のみ実行、do はスキップされる
- [ ] `--flow change --from do` で既存 change plan から do のみ実行される
- [ ] `--flow change --from do` で plan が存在しない場合にエラーが出る
- [ ] エラーメッセージに `/my:change {id}` が案内される

#### Step 4.4: Change flow review cycle test (manual)
**Description:** change plan に対するレビューサイクルの動作確認

**Test Cases:**
- [ ] `--flow change --review` で change ステップ後に reviewer -> fixer が実行される
- [ ] レビュー対象が `docs/plans/changes/{id}.md` であること
- [ ] レビュー結果が `docs/reviews/changes/{id}.md` に出力される
- [ ] Critical/Medium 指摘時に fixer が `docs/plans/changes/{id}.md` を修正する
- [ ] `--flow change --no-review` でレビューがスキップされる

#### Step 4.5: Feature flow regression test (manual)
**Description:** 既存の feature フローが壊れていないことの確認

**Test Cases:**
- [ ] `/my:pipeline "テスト機能" --to plan --no-review` が従来通り動作する
- [ ] `--flow` 未指定時に feature フローがデフォルトで使用される
- [ ] feature フローの --from/--to バリデーションが変更されていない

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| (none) | - | Pure markdown definitions, no external packages |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `agents/researcher.md` | Exists | feature フローで使用（変更なし） |
| `agents/specifier.md` | Exists | feature フローで使用（変更なし） |
| `agents/planner.md` | Exists | feature フローで使用（変更なし） |
| `agents/implementer.md` | Exists | do ステップで使用（変更なし） |
| `agents/reviewer.md` | Exists | review サイクルで使用（変更なし） |
| `agents/fixer.md` | Exists | fix サイクルで使用（変更なし） |
| `~/.prompts/6_change.md` | Exists | changer subagent が Read（変更なし） |
| `~/.prompts/7_do.md` | Exists | implementer が Read、`plans/changes/` resolution 実装済み（変更なし） |
| `~/.prompts/10_pipeline.md` | Exists | 本計画で修正 |
| `commands/my/pipeline.md` | Exists | 本計画で修正 |
| `~/.claude/agents` symlinks | Exists | 新規 `agents/changer.md` に対する symlink 追加が必要 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document reviewed: `docs/specs/20260407-pipeline-change-flow.md`
- [ ] 既存 subagent 定義ファイルが `agents/` に存在（6 files）
- [ ] `~/.prompts/10_pipeline.md` の現在の内容を確認
- [ ] `commands/my/pipeline.md` の現在の内容を確認

### 5.2 Post-Implementation
- [ ] `agents/changer.md` が作成されている
- [ ] `~/.prompts/10_pipeline.md` が更新されている
- [ ] `commands/my/pipeline.md` が更新されている
- [ ] 既存コマンド（change, do, research, spec, plan, review）が変更されていない
- [ ] 既存 subagent 定義（implementer, reviewer, fixer, researcher, specifier, planner）が変更されていない

### 5.3 Acceptance Criteria Verification
- [ ] US-001/AC-001: `--flow change` で change -> do が順次実行される
- [ ] US-001/AC-002: change ステップで analysis + plan が生成される
- [ ] US-001/AC-003: do ステップで change plan を入力として実装が実行される
- [ ] US-002/AC-001: `--to change` で change のみ実行される
- [ ] US-002/AC-002: `--from do` で既存 plan から do のみ実行される
- [ ] US-002/AC-003: `--from do` 時に plan の存在を事前検証する
- [ ] US-003/AC-001: `--review` で change 後に reviewer -> fixer が実行される
- [ ] US-003/AC-002: レビュー対象が `docs/plans/changes/{id}.md`
- [ ] US-003/AC-003: レビュー結果が `docs/reviews/changes/{id}.md` に出力される
- [ ] US-003/AC-004: `--no-review` でレビューがスキップされる
- [ ] US-004/AC-001: `--flow` 未指定時は feature フローがデフォルト
- [ ] US-004/AC-002: 既存 feature フローの動作に変更がない
- [ ] US-004/AC-003: 既存 `/my:change`, `/my:do` が変更なしで動作する
- [ ] US-005/AC-001: 各ステップ開始時に進捗表示される
- [ ] US-005/AC-002: 完了時に change 固有の成果物パスが表示される
- [ ] US-006/AC-001: 無効なステップ指定でエラーになる
- [ ] US-006/AC-002: 有効ステップは change と do のみ
- [ ] US-006/AC-003: エラーメッセージに有効ステップ一覧が含まれる

---

## 6. Rollback Plan

1. `agents/changer.md` を削除
2. `~/.prompts/10_pipeline.md` を変更前の状態に戻す（git checkout）
3. `commands/my/pipeline.md` を変更前の状態に戻す（git checkout）
4. `~/.claude/agents/changer.md` symlink を削除

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 1 agent 定義ファイル（既存パターン踏襲、~20行） |
| Phase 2: Core Logic | Medium | `10_pipeline.md` への追記（~80行の追加・修正） |
| Phase 3: Integration | Low | `pipeline.md` の更新 + 参照整合性検証 |
| Phase 4: Testing | Medium | 手動 E2E テスト（8 パラメータパターン + 3 E2E シナリオ） |

---

## 8. Open Design Decisions

spec の Open Items から引き継ぎ。実装時にデフォルト値を採用し、運用後に見直す。

| Item | Default Decision | Rationale |
|------|-----------------|-----------|
| `--flow` オプション名 (Q1) | `--flow` を採用 | research で推奨、`--mode`/`--type` より意図が明確 |
| `change -> plan -> do` フロー (Q2) | サポートしない | `--review` による自動改善で代替。change が plan を自動生成するため不要 |
| changer の description (Q3) | "変更リクエストを分析して change plan を生成する" | Agent tool routing に十分な情報量 |
| `--flow fix/refactor` の将来拡張 (Q4) | 今回は対象外 | flow_type を enum にしておき拡張可能にする |

---
**Created:** 2026-04-07
**Status:** Draft
**Assignee:**
