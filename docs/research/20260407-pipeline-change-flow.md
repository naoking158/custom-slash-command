# Research: Pipeline Change Flow Integration

## 1. Overview

現在の `/my:pipeline` コマンドは `research → spec → plan → do` の線形フローのみをサポートしている。一方、難易度の低いタスク向けに `/my:change` コマンドが存在し、`change → do` または `change → plan → do` というフローで使われる。本調査は、change フローを pipeline コマンドに組み込むための変更点を調査する。

**要件概要:**
- `change → do` (シンプル: 自動生成プランで即実行)
- `change → plan → do` (プランを精査してから実行)
- 既存の `research → spec → plan → do` フローを維持

---

## 2. Problem Statement

現在の課題:

1. **フロー分岐の不統一**: feature フローは `/my:pipeline` で一括実行できるが、change フローは手動で `/my:change` → `/my:do` と実行する必要がある
2. **`plan` ステップの意味の曖昧さ**: 現在の pipeline における `plan` ステップは `docs/plans/features/{id}.md` を生成する planner subagent を使う。しかし change フローでは `/my:change` が `docs/plans/changes/{id}.md` を自動生成するため、pipeline の `plan` ステップとは異なる
3. **`do` への入力パスの差異**: feature フローでは `docs/plans/features/{id}.md`、change フローでは `docs/plans/changes/{id}.md` が入力となる。現在の pipeline の事前検証ロジック（Input File Pre-validation）は feature パスのみを想定している

---

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [ ] FR-001: `--flow change` オプション（または同等の指定方法）で change フローを選択できる
- [ ] FR-002: `change → do` フロー: change subagent を実行後、implementer subagent に `docs/plans/changes/{id}.md` を渡して実行
- [ ] FR-003: `change → plan → do` フロー: change 後に plan サブステップを挟み、`docs/plans/changes/{id}.md` の内容を精査・調整できる形を提供する
- [ ] FR-004: 事前検証ロジックを change フロー用に拡張: `--from do` かつ change フロー指定時は `docs/plans/changes/{id}.md` の存在を確認する
- [ ] FR-005: pipeline 完了時の成果物一覧表示に change フロー固有のパス（`docs/analysis/changes/`, `docs/plans/changes/`）を含める
- [ ] FR-006: 既存の feature フロー（`research → spec → plan → do`）は一切変更しない

### 3.2 Non-Functional Requirements

- [ ] NFR-001: change subagent は既存の `/my:change` コマンドと同一の動作をする（`~/.prompts/6_change.md` を使用）
- [ ] NFR-002: 既存コマンド（`/my:change`, `/my:do`）を変更しない
- [ ] NFR-003: オプション構文は既存の `--from`, `--to` と一貫性を保つ
- [ ] NFR-004: `docs/plans/changes/{id}.md` を読む implementer は既存の `7_do.md` の plan type resolution で自動的に change タイプを解決できるため、追加実装が不要

---

## 4. Current Architecture Analysis

### 4.1 change フローの成果物パス

`/my:change` を実行すると 2 つのドキュメントが生成される:

| ドキュメント | パス |
|---|---|
| Change Analysis | `docs/analysis/changes/{DATE}-{IDENTIFIER}.md` |
| Change Plan (自動生成) | `docs/plans/changes/{DATE}-{IDENTIFIER}.md` |

これは feature フローの `docs/plans/features/{id}.md` と**ディレクトリ構造が異なる**。

### 4.2 現在の pipeline の step 定義

```
| Step     | Input                        | Output                        |
|----------|------------------------------|-------------------------------|
| research | feature_description          | docs/research/{id}.md         |
| spec     | docs/research/{id}.md        | docs/specs/{id}.md            |
| plan     | docs/specs/{id}.md           | docs/plans/features/{id}.md   |
| do       | docs/plans/features/{id}.md  | (code changes)                |
```

change フローを組み込むには、step 定義に `change` を追加し、`do` の入力ファイル解決ロジックをフロー依存にする必要がある。

### 4.3 implementer subagent との互換性

`agents/implementer.md` は `~/.prompts/7_do.md` に従う。`7_do.md` には以下の resolution logic が既に実装されている:

```
1. plans/features/{id}.md exists → Execute new feature
2. plans/fixes/{id}.md exists    → Execute bug fix
3. plans/refactors/{id}.md       → Execute refactoring
4. plans/changes/{id}.md exists  → Execute change
```

つまり implementer に `docs/plans/changes/{id}.md` が存在する状態で `{id}` を渡せば、**追加変更なしで change タイプとして実行できる**。ただし pipeline として呼び出す際は明示的に `change:{id}` または plan パスを渡すことが望ましい。

### 4.4 `change → plan → do` フローの「plan」の意味

`/my:change` は実行時点で `docs/plans/changes/{id}.md` を自動生成する。そのため、change フローにおける「plan サブステップ」は **新規プランの生成ではなく、自動生成済みプランのレビュー・調整の機会**を意味する。

選択肢:
- **A. インタラクティブな中断**: change 実行後にユーザーに確認を求め、プランを編集してから do を実行
- **B. reviewer/fixer サイクルで代替**: `--review` フラグで change 後に reviewer → fixer を走らせ、プランを自動改善してから do へ
- **C. `--interactive` フラグを追加**: change → do の間で一時停止し、ユーザーにプラン確認を促す

---

## 5. Technical Investigation

### 5.1 Option A: `--flow change` の導入

pipeline コマンドに `--flow <feature|change>` オプションを追加する。

```
/my:pipeline "ダークモードのボタン改善" --flow change
/my:pipeline "ダークモードのボタン改善" --flow change --to do
/my:pipeline 20260407-button-contrast --flow change --from do
```

**step 定義の変更案:**

```
change フロー:
| Step   | Subagent      | Input                          | Output                         |
|--------|---------------|--------------------------------|--------------------------------|
| change | changer       | feature_description (変更内容)  | docs/analysis/changes/{id}.md  |
|        |               |                                | docs/plans/changes/{id}.md     |
| do     | implementer   | docs/plans/changes/{id}.md     | (code changes)                 |
```

**必要な変更:**
1. `~/.prompts/10_pipeline.md`: `--flow` オプションの追加、change フローの step 定義、事前検証ロジックの拡張
2. `commands/my/pipeline.md`: `--flow` パラメータのドキュメント追加
3. `agents/changer.md` (新規作成): `~/.prompts/6_change.md` を読み込む change subagent

### 5.2 Option B: `change` を step として追加し、`--from change` で開始

既存の `--from` / `--to` の枠組みに `change` を step として組み込む。ただし change は feature フローの step と独立したフローを形成する。

```
step order: research < spec < plan < do
                                  ↑
change (独立フロー: change < do)
```

**問題点**: `change` と `research/spec/plan` は独立したフロー上にあるため、`--from change --to plan` のような無意味な組み合わせが生じる。step order の一元管理が困難になる。

**結論**: Option A の方が概念的に明確。

### 5.3 `change → plan → do` における plan サブステップの扱い

`/my:change` は既に change plan を自動生成するため、pipeline での `plan` ステップは不要。代わりに以下の対応が考えられる:

- `--review` フラグで change plan を reviewer/fixer にかける → 自動的にプラン品質を向上させる
- `change → do` がデフォルト。プランを手動で編集したい場合は pipeline を使わず手動実行

**推奨**: `--review` を利用したプラン改善を change フローのデフォルトとする。`change → do` が最短フロー、`--review` ありで `change → (review plan → fix plan) → do` となる。

---

## 6. Impact Assessment

### 6.1 変更が必要なファイル

| ファイル | 変更内容 | 影響範囲 |
|---|---|---|
| `~/.prompts/10_pipeline.md` | `--flow` オプション追加、change フロー step 定義、事前検証拡張 | pipeline のみ |
| `commands/my/pipeline.md` | `--flow` パラメータのドキュメント・Examples 追加 | pipeline のみ |
| `agents/changer.md` (新規) | change subagent の作成 | pipeline からのみ呼ばれる |

### 6.2 変更不要なファイル

| ファイル | 理由 |
|---|---|
| `~/.prompts/6_change.md` | changer subagent が Read するだけ |
| `~/.prompts/7_do.md` | change plan の resolution が既に実装済み |
| `agents/implementer.md` | 変更不要（`plans/changes/{id}.md` は既にサポート済み） |
| `commands/my/change.md` | pipeline 外の単発実行はそのまま維持 |
| `commands/my/do.md` | 変更不要 |

### 6.3 後方互換性

- 既存の feature フロー（`--flow feature` または デフォルト）は動作変更なし
- `--flow` 未指定時はデフォルトで feature フロー（現状の動作を維持）

---

## 7. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| `--flow` オプション未指定時の動作変更 | High | Low | デフォルト値を `feature` にして後方互換を維持 |
| `change` subagent の output path が不一致 | Medium | Medium | changer subagent に出力パスを明示的に渡す |
| `change → plan → do` フローの「plan」概念の混乱 | Medium | High | `change → plan → do` は提供せず、`--review` で代替することを明記する |
| review cycle で change plan が正しく改善されない | Low | Low | reviewer に change plan 向けの指示を渡す |

---

## 8. Open Questions

- [ ] Q1: `--flow` オプション名は適切か。`--mode change` や `--type change` の方が直感的か。
- [ ] Q2: `change → plan → do` フローをサポートするか、`--review` による自動改善のみとするか。ユーザーのニーズ（「プランを精査してから実行したい」）に対して `--review` で十分か。
- [ ] Q3: change フローの `--from` / `--to` で指定できるステップを `change` と `do` のみに制限するか、任意の組み合わせを許容するか。
- [ ] Q4: `changer` subagent の `description` フィールドに何を記述するか（Agent tool routing への影響）。
- [ ] Q5: 既存の `docs/plans/changes/` と `docs/analysis/changes/` の成果物が存在する場合（つまり `--from do` で再開する場合）、上書き警告をどう表示するか。

---

## 9. Recommendations

### 推奨実装方針

1. **`--flow <feature|change>` オプションを `10_pipeline.md` に追加する**
   - デフォルトは `feature`（後方互換維持）
   - `--flow change` 指定時は change フロー step 定義を使用

2. **change フローの step は `change` と `do` の 2 ステップのみ**
   - `change → do` がデフォルト
   - `--to change` で change のみ実行も可能
   - `change → plan → do` は提供しない（混乱を避けるため）

3. **`agents/changer.md` を新規作成**
   - `~/.prompts/6_change.md` を Read して実行する
   - 出力: `docs/analysis/changes/{id}.md` + `docs/plans/changes/{id}.md`

4. **review cycle は change plan にも適用**
   - change ステップ後に `--review` が有効な場合、`docs/plans/changes/{id}.md` をレビュー対象とする
   - reviewer に `type=change_plan` を渡すか、既存の plan checklist を流用する

5. **事前検証ロジックの拡張**
   - `--flow change --from do` の場合、`docs/plans/changes/{id}.md` の存在を確認

### 変更規模の見積もり

- **小〜中規模の変更**: `10_pipeline.md` への追記（〜50行）、`commands/my/pipeline.md` への追記（〜10行）、`agents/changer.md` の新規作成（〜20行）
- 既存コマンドへの変更なし

---

## 10. Next Steps

- [ ] `/my:spec 20260407-pipeline-change-flow` で仕様書を作成
- [ ] `agents/changer.md` の設計を確定（Q4 を解決）
- [ ] Q2（`change → plan → do` の必要性）をユーザーと確認

---
**Created:** 2026-04-07
**Status:** Draft
