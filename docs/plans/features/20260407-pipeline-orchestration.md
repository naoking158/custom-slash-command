# Implementation Plan: Pipeline Orchestration for Sequential Command Execution

## 1. Overview

`/my:pipeline` コマンドを実装し、research → spec → plan → do の一連のフローを subagent ベースで逐次実行する。各ステップは Agent ツール経由で独立したコンテキストで実行され、identifier を介してステップ間のファイル引き渡しを行う。オプションでレビュー＆修正サイクルを各ステップ後に挟む機能も提供する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260407-pipeline-orchestration.md`

### 1.2 References
- Specification: `docs/specs/20260407-pipeline-orchestration.md`
- Research: `docs/research/20260407-pipeline-orchestration.md`
- Related Plan: `docs/plans/features/20260407-subagent-design.md` (Phase 1 実装済み)
- Subagent Definitions: `agents/` ディレクトリ（6 agents 実装済み）

### 1.3 Implementation Strategy

2 つの成果物を作成する:
1. **`commands/my/pipeline.md`** — スラッシュコマンド定義。ユーザー入力のパースと `~/.prompts/10_pipeline.md` への委譲を行う
2. **`prompts/10_pipeline.md`** — パイプラインオーケストレーションの本体ロジック。パラメータ解析、ステップ構築、subagent 逐次呼び出し、進捗表示、エラーハンドリングを記述

既存の `/my:*` コマンドは一切変更しない。subagent 定義ファイル（`agents/*.md`）も Phase 1 で実装済みのためそのまま利用する。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `commands/my/pipeline.md` | `/my:pipeline` スラッシュコマンド定義 | P0 |
| `prompts/10_pipeline.md` | パイプラインオーケストレーションロジック（プロンプト本体） | P0 |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| (none) | - | - |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (none) | - |

---

## 3. Implementation Steps

### Phase 1: Foundation — コマンド定義ファイル

#### Step 1.1: Create `/my:pipeline` command definition
**File:** `commands/my/pipeline.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: description="Execute sequential pipeline: research → spec → plan → do"
- 既存コマンド（do.md, review.md）と同じ構造パターンに準拠
- $ARGUMENTS を受け取り ~/.prompts/10_pipeline.md に委譲
- コマンドの Usage、Parameters、Examples セクションを記述:
  - /my:pipeline <feature_description_or_identifier> [options]
  - --from: 開始ステップ (research/spec/plan/do)、default=research
  - --to: 終了ステップ (research/spec/plan/do)、default=plan
  - --only: 単一ステップ実行（--from/--to と排他）
  - --review / --no-review: レビューサイクル有効/無効、default=--review
- Error Handling セクション: 引数なし時のガイダンス
- 実行例を 4 パターン記載（フル実行、部分実行、既存 identifier からの再開、単一ステップ）
```

**Verification:**
- [ ] YAML frontmatter に `description` フィールドがある
- [ ] `~/.prompts/10_pipeline.md` への Read 指示がある
- [ ] パラメータ定義（--from, --to, --only, --review, --no-review）が記載されている
- [ ] 既存コマンド（do.md, review.md）と構造が一貫している

---

### Phase 2: Core Logic — オーケストレーションプロンプト

#### Step 2.1: Create pipeline orchestration prompt
**File:** `prompts/10_pipeline.md`
**Action:** Create

**Details:**

プロンプトは以下のセクション構成とする:

```
<role>
  Expert Pipeline Orchestrator
  Task: Coordinate sequential execution of research → spec → plan → do
        with optional review cycles using specialized subagents
</role>

<input-handling>
  1. パラメータ解析
     - feature_description_or_identifier の判定
       - YYYYMMDD-* パターン → 既存 identifier
       - それ以外 → 新規 feature description → identifier を自動生成
     - --from / --to / --only の解析とバリデーション
       - step order: research < spec < plan < do
       - --only は --from/--to と排他
       - --from が --to より後 → エラー
     - --review / --no-review の解析（default: --review）

  2. identifier 生成ルール（新規の場合）
     - 形式: YYYYMMDD-{kebab-case-name}
     - 日本語入力 → 英語キーワードを抽出
     - 英数字とハイフンのみに正規化

  3. 入力ファイル事前検証
     - --from が research 以外の場合、前ステップの出力ファイルの存在を確認
       - from=spec → docs/research/{id}.md が必要
       - from=plan → docs/specs/{id}.md が必要
       - from=do → docs/plans/features/{id}.md が必要
     - 不足時はエラーメッセージ + 必要なコマンド提示
</input-handling>

<pipeline-definition>
  ステップ定義テーブル:

  | Step | Subagent | Input | Output | Prompt |
  |------|----------|-------|--------|--------|
  | research | researcher | feature_description | docs/research/{id}.md | |
  | spec | specifier | docs/research/{id}.md | docs/specs/{id}.md | |
  | plan | planner | docs/specs/{id}.md | docs/plans/features/{id}.md | |
  | do | implementer | docs/plans/features/{id}.md | (code changes) | |

  レビューサイクル（各ステップ後、--review 有効時）:
  | Sub-step | Subagent | Input | Output |
  |----------|----------|-------|--------|
  | review | reviewer | docs/{type}/{id}.md | docs/reviews/{type}/{id}.md |
  | fix | fixer | review + target | target file updated |
</pipeline-definition>

<execution-flow>
  1. 実行対象ステップのフィルタリング（from/to/only に基づく）
  2. 各ステップについて逐次実行:
     a. 進捗表示: [N/M] Running: {step_name}
     b. Agent ツールで subagent を起動
        - subagent_type: 対応する agent 名
        - prompt: 入力パス、出力パス、identifier、today's date を含む
     c. subagent 完了後:
        - 出力ファイルの存在確認
        - 進捗表示: ✅ {step_name} completed → {output_path}
     d. レビューサイクル（--review 有効時）:
        i. Agent(reviewer): source file を review
        ii. レビュー結果に Critical/Medium 指摘があれば:
            Agent(fixer): review + target を渡して修正
        iii. 指摘なしまたは Low のみ → fixer スキップ
  3. パイプライン完了後:
     - 全成果物の一覧表示
     - 次のステップの提案
</execution-flow>

<subagent-prompts>
  各 subagent への prompt テンプレート:

  researcher:
    "Feature description: '{feature_description}'
     Output file: docs/research/{id}.md
     Today's date: {date}"

  specifier:
    "Feature name: {id}
     Research document: docs/research/{id}.md
     Output file: docs/specs/{id}.md"

  planner:
    "Feature name: {id}
     Spec document: docs/specs/{id}.md
     Output file: docs/plans/features/{id}.md"

  implementer:
    "Feature name: {id}
     Plan document: docs/plans/features/{id}.md"

  reviewer:
    "Review target: {step_type}:{id}
     Source file: docs/{type_path}/{id}.md
     Output file: docs/reviews/{type}/{id}.md"

  fixer:
    "Review file: docs/reviews/{type}/{id}.md
     Target file: docs/{type_path}/{id}.md
     Apply critical and medium priority feedback only."
</subagent-prompts>

<progress-format>
  各ステップ開始時:
    "🔄 [{current}/{total}] Running: {step_name}..."

  各ステップ完了時:
    "✅ [{current}/{total}] {step_name} completed → {output_path}"

  レビューサイクル:
    "  📝 Reviewing {step_name} output..."
    "  🔧 Applying fixes (Critical/Medium)..." or "  ✓ No fixes needed"

  パイプライン完了:
    "
    ═══════════════════════════════════════
    🎉 Pipeline completed: {id}
    ═══════════════════════════════════════

    Artifacts:
    - Research: docs/research/{id}.md
    - Spec: docs/specs/{id}.md
    - Plan: docs/plans/features/{id}.md
    (レビュー有の場合)
    - Reviews: docs/reviews/research/{id}.md, ...

    Next step: /my:do {id}
    "
</progress-format>

<error-handling>
  1. 入力ファイル不足:
     "❌ Error: Required input file not found: {path}
      Run `/my:{previous_step} {id}` first."

  2. subagent 失敗:
     "❌ Error: {step_name} failed.
      Completed artifacts are preserved.
      Resume with: /my:pipeline {id} --from {failed_step}"

  3. パラメータエラー:
     - --from > --to: "❌ --from must be before --to"
     - --only + --from/--to: "❌ --only cannot be used with --from/--to"
     - 引数なし: Usage + 実行例を表示
</error-handling>

<rules>
  <critical>
  - 各 subagent は Agent ツール経由で起動する（コンテキスト分離のため）
  - subagent への prompt にはファイルパスと identifier のみ渡す（コンテンツは渡さない）
  - 親セッションでは subagent のサマリーのみ保持する
  - 既存の /my:* コマンドは一切変更しない
  - 上書き対象ファイルがある場合、実行前に対象パスを表示する
  </critical>
</rules>
```

**Verification:**
- [ ] `<role>` セクションが定義されている
- [ ] `<input-handling>` でパラメータ解析・バリデーションが網羅されている
- [ ] `<pipeline-definition>` で 4 ステップ + レビューサイクルが定義されている
- [ ] `<execution-flow>` で逐次実行ロジックが記述されている
- [ ] `<subagent-prompts>` で全 6 subagent への prompt テンプレートがある
- [ ] `<progress-format>` で進捗表示フォーマットが定義されている
- [ ] `<error-handling>` で 3 種類のエラーケースが網羅されている
- [ ] `<rules>` にコンテキスト分離の制約が明記されている

---

### Phase 3: Integration — コマンド連携と一貫性検証

#### Step 3.1: Validate command-prompt linkage
**Action:** Verify

**Details:**
```
- commands/my/pipeline.md が ~/.prompts/10_pipeline.md を参照している
- prompts/10_pipeline.md が agents/ 内の全 6 subagent を参照している
- subagent 名が agents/ のファイル名と一致している:
  researcher, specifier, planner, implementer, reviewer, fixer
```

**Verification:**
- [ ] `commands/my/pipeline.md` 内の参照パスが正しい
- [ ] `prompts/10_pipeline.md` 内の subagent 名が `agents/*.md` と一致
- [ ] 出力パス規約が既存コマンドと一致（docs/research/, docs/specs/, docs/plans/features/）

#### Step 3.2: Validate parameter handling consistency
**Action:** Verify

**Details:**
```
- --from / --to のステップ順序: research < spec < plan < do
- --only と --from/--to の排他制御
- --review のデフォルト値が true
- identifier の YYYYMMDD-{name} 形式が既存コマンドと一致
- 入力ファイルパスの解決が既存コマンドの規約に準拠
```

**Verification:**
- [ ] ステップ順序定義が spec Section 4.4 と一致
- [ ] 排他制御のエラーメッセージが定義されている
- [ ] デフォルト値が spec と一致（from=research, to=plan, review=true）

#### Step 3.3: Verify symlink setup
**Action:** Verify

**Details:**
```
- ~/.claude/commands が commands/ ディレクトリを指すシンボリックリンクであること
- これにより /my:pipeline コマンドが Claude Code から認識されること
```

**Verification:**
- [ ] `~/.claude/commands/my/pipeline.md` が参照可能

---

### Phase 4: Testing — 動作確認

#### Step 4.1: Command recognition test
**Description:** `/my:pipeline` が Claude Code のコマンド一覧に表示されることを確認

**Test Cases:**
- [ ] `/my:pipeline` がタブ補完またはコマンド一覧に表示される
- [ ] `description` が正しく表示される

#### Step 4.2: Parameter parsing dry run
**Description:** 各パラメータパターンが正しく解釈されることを確認

**Test Cases:**
- [ ] `/my:pipeline "新機能の追加"` → identifier 自動生成、from=research, to=plan, review=true
- [ ] `/my:pipeline 20260407-feature --from spec --to plan` → 既存 identifier、spec→plan 実行
- [ ] `/my:pipeline 20260407-feature --only research` → research のみ実行
- [ ] `/my:pipeline 20260407-feature --no-review` → レビューサイクルなし
- [ ] `/my:pipeline 20260407-feature --from plan --to research` → エラー（順序逆転）
- [ ] `/my:pipeline 20260407-feature --only spec --from research` → エラー（排他）

#### Step 4.3: Full pipeline E2E test (manual)
**Description:** 小さな feature でフルパイプラインを実行し、全成果物を確認

**Test Cases:**
- [ ] `/my:pipeline "テスト機能" --to plan --no-review` で research → spec → plan が実行される
- [ ] 各ステップで `docs/research/`, `docs/specs/`, `docs/plans/features/` にファイルが生成される
- [ ] 進捗表示が `[1/3]`, `[2/3]`, `[3/3]` と表示される
- [ ] 完了時に全成果物の一覧が表示される

#### Step 4.4: Partial execution test (manual)
**Description:** 部分実行と再開の動作確認

**Test Cases:**
- [ ] 既存の research ファイルがある状態で `--from spec --to plan` が正常動作する
- [ ] `--from spec` 指定時に research ファイルがない場合にエラーが出る
- [ ] エラーメッセージに適切な再開方法が表示される

#### Step 4.5: Review cycle test (manual)
**Description:** レビューサイクルの動作確認

**Test Cases:**
- [ ] `--review` 指定時に各ステップ後に reviewer → fixer が実行される
- [ ] レビュー結果が `docs/reviews/` に出力される
- [ ] Critical/Medium 指摘時に fixer が修正を適用する
- [ ] 指摘なし時に fixer がスキップされる

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| (none) | - | Pure markdown definitions, no external packages |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `agents/researcher.md` | ✅ 実装済み | research ステップで使用 |
| `agents/specifier.md` | ✅ 実装済み | spec ステップで使用 |
| `agents/planner.md` | ✅ 実装済み | plan ステップで使用 |
| `agents/implementer.md` | ✅ 実装済み | do ステップで使用 |
| `agents/reviewer.md` | ✅ 実装済み | review サイクルで使用 |
| `agents/fixer.md` | ✅ 実装済み | fix サイクルで使用 |
| `~/.prompts/1_research.md` | ✅ Exists | researcher が Read |
| `~/.prompts/2_spec.md` | ✅ Exists | specifier が Read |
| `~/.prompts/3_plan.md` | ✅ Exists | planner が Read |
| `~/.prompts/7_do.md` | ✅ Exists | implementer が Read |
| `~/.prompts/8_review.md` | ✅ Exists | reviewer が Read |
| `~/.claude/commands` symlink | ✅ Exists | commands/ → ~/.claude/commands |
| `~/.claude/agents` symlinks | ✅ Exists | agents/ → ~/.claude/agents/ |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document reviewed: `docs/specs/20260407-pipeline-orchestration.md`
- [ ] 全 6 subagent 定義ファイルが `agents/` に存在
- [ ] `~/.claude/commands` シンボリックリンクが有効
- [ ] `~/.claude/agents` シンボリックリンクが有効

### 5.2 Post-Implementation
- [ ] `commands/my/pipeline.md` が作成されている
- [ ] `prompts/10_pipeline.md` が作成されている
- [ ] 既存コマンド（research, spec, plan, do, review）が変更されていない
- [ ] Markdown 構文エラーがない

### 5.3 Acceptance Criteria Verification
- [ ] US-001/AC-001: `/my:pipeline "機能名"` で research → spec → plan が順次実行される
- [ ] US-001/AC-002: 各成果物が規定のディレクトリに出力される
- [ ] US-001/AC-003: 前ステップの出力が次ステップに自動引き渡しされる
- [ ] US-002/AC-001: `--from spec --to plan` で spec と plan のみ実行される
- [ ] US-002/AC-002: `--only research` で research のみ実行される
- [ ] US-002/AC-003: `--from` 指定時に入力ファイルの存在を事前検証
- [ ] US-003/AC-001: `--review` で各ステップ後に reviewer → fixer が実行される
- [ ] US-003/AC-002: `--no-review` でレビューがスキップされる
- [ ] US-003/AC-003: デフォルトがレビューあり
- [ ] US-003/AC-004: レビュー結果が `docs/reviews/{type}/{id}.md` に出力される
- [ ] US-003/AC-005: 修正は Critical/Medium のみ対象
- [ ] US-004/AC-001: 各ステップが Agent ツール経由で実行される
- [ ] US-004/AC-002: 独立したコンテキストウィンドウで実行される
- [ ] US-004/AC-003: 親セッションにはサマリーのみ返却される
- [ ] US-005/AC-001: ステップ開始時に進捗が表示される
- [ ] US-005/AC-002: 完了時に成果物パスが表示される
- [ ] US-005/AC-003: 全完了時に成果物一覧が表示される
- [ ] US-006/AC-001: 既存 `/my:*` コマンドが変更なしで動作する

---

## 6. Rollback Plan

1. `commands/my/pipeline.md` を削除
2. `prompts/10_pipeline.md` を削除
3. 既存ファイルは一切変更していないため、上記 2 ファイルの削除のみで完全に元に戻る

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 1 コマンド定義ファイル（既存パターン踏襲） |
| Phase 2: Core Logic | Medium | オーケストレーションプロンプト（最大の成果物） |
| Phase 3: Integration | Low | 参照整合性の検証のみ |
| Phase 4: Testing | Medium | 手動 E2E テスト（複数パターン） |

---

## 8. Open Design Decisions

spec の Open Items から引き継ぎ。実装時にデフォルト値を採用し、運用後に見直す。

| Item | Default Decision | Rationale |
|------|-----------------|-----------|
| レビューサイクル最大回数 | 1 回 | 初期実装はシンプルに。将来設定可能にする |
| `do` をデフォルトパイプラインに含めるか | 含めない（--to=plan がデフォルト） | コード変更は確認後が安全 |
| subagent ごとの model 指定 | agents/ の frontmatter に従う | pipeline 側では override しない |
| 実行前ユーザー確認 | なし（即実行） | コマンド引数で意図を明示しているため |
| identifier 自動生成の詳細 | LLM に英語キーワード抽出を委ねる | 正規化ルールのみプロンプトに記載 |

---
**Created:** 2026-04-07
**Status:** Draft
**Assignee:**
