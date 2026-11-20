# Change Analysis: Maintainability Checklist - Linguistic Correctness Check

## Date
2026-03-29

## Change Request
review_maint_checklist.md を改善し、コメントや命名が論理的・言語的に破綻していないかもチェックできるようにしたい。日本語の「てにをは」の誤り、言語問わず構文の崩れや目的語の不一致など。

## Current Behavior

### 対象ファイル
`prompts/templates/checklists/review_maint_checklist.md`

### 現在のセクション構成
1. **Naming (命名)** — 変数名・関数名の明瞭さ、規則の統一、ドメイン用語の正確性など（7項目）
2. **Comments (コメント)** — Why の説明、コードとの一致、docstring の有無など（6項目）
3. **Readability (可読性)** — 関数長、ネスト深度、Guard clause など（6項目）
4. **Code Organization (コード構造)** — SRP、凝集度、Dead code など（5項目）
5. **Consistency (一貫性)** — 命名パターン、エラーハンドリング、コードスタイルの統一（5項目）

### 現在カバーされていない観点
- 命名が「文法的に正しいか」（例: `getUserData` は OK だが `getDataUser` は語順が不自然）
- コメント文の「文法的な正しさ」（てにをは、主語と述語の対応、目的語の欠落）
- 識別子内の単語の結合が意味的に正しいか（例: `isUserDelete` → `isUserDeleted`）
- コメントが自然言語として意味をなすか（構文崩れ、主述のねじれ）

## Desired Behavior

### 追加したいチェック観点
命名とコメントの各セクションに「言語的・論理的正しさ」の項目を追加する。

#### Naming セクションへの追加
- 識別子の語順が自然か（英語の語順: 動詞+目的語+修飾語）
- 時制・態（active/passive）が状態を正しく反映しているか（`isDeleted` vs `isDelete`）
- 単語の組み合わせが意味的に整合しているか（`createUser` は OK、`createData` は曖昧）

#### Comments セクションへの追加
- コメント文が文法的に正しいか（日本語: てにをは、主述の対応 / 英語: 文構造の崩れ）
- 主語・目的語が明示されており、指示対象が曖昧でないか
- コメントの説明対象とコードの実体が論理的に対応しているか（例: 「ユーザーを削除する」と書いてあるが実際は無効化）

## Gap Analysis

### 変更が必要な箇所
- `review_maint_checklist.md` の Naming セクション: 3項目追加
- `review_maint_checklist.md` の Comments セクション: 3項目追加

### 変更不要な箇所
- Readability, Code Organization, Consistency セクション: 変更なし
- review プロセス (`_shared/processes/review.md`): 変更なし（チェックリストの追加のみで対応可能）
- 他のチェックリスト (fe, be, security, perf, doc): 変更なし

## Impact Assessment

### 影響範囲
- **直接影響**: `review_maint_checklist.md` のみ
- **間接影響**: `/my:review maint:` 実行時のレビュー結果が追加項目分だけ詳細化される

### リスク
- **低**: チェックリストへの項目追加のみで、プロセスやロジックの変更はない
- **懸念**: 項目が増えすぎるとレビューが冗長になる可能性 → 既存セクション内に自然に統合することで緩和

### 破壊的変更
- なし
