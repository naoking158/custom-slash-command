# Maintainability Review: 8_review

## Metadata
- **Target**: prompts/8_review.md
- **Reviewed**: 2026-03-29
- **Files Reviewed**: 1
- **Checklist Items Evaluated**: 17/30

## Summary

| Category | ✅ Pass | ⚠️ Warning | ❌ Issue |
|----------|---------|------------|---------|
| Naming | 4 | 0 | 0 |
| Comments | 1 | 1 | 0 |
| Readability | 1 | 1 | 0 |
| Code Organization | 2 | 1 | 0 |
| Consistency | 4 | 2 | 0 |
| **Total** | **12** | **5** | **0** |

**Overall Assessment**: NEEDS_REVISION

## Findings

### 🔴 Critical Issues
なし

### 🟡 Warnings
1. **C-02 (古いコメントの検出)**: `<step n="2">` の checklist ファイルパスが `.prompts/templates/checklists/` を参照しているが、プロジェクト構造上このパスが実際に存在するか不明。他の prompt ファイル（7_do.md 等）と照合すると、パスの規則が異なる可能性がある (8_review.md:109-126)
2. **R-05 (マジックストリング)**: Auto-Selection Rules セクション (行123-127) でファイル拡張子がハードコードされている (`.jsx`, `.tsx`, `.vue`, `.svelte` 等)。再利用性を考えると、共通定義への参照が望ましい
3. **O-02 (凝集度)**: `<rules>` セクション内に `<output-locations>`, `<severity-levels>`, `<review-principles>`, `<review-criteria>` と性質の異なる4つのサブセクションが混在している (行149-199)。severity-levels はレビュープロセスの一部であり、rules とは別の関心事
4. **S-01 (命名パターンの統一)**: エラーテンプレートの命名が `<error-no-target>`, `<error-multiple-targets>`, `<error-commit-not-found>`, `<error-pr-not-found>` と、単数/複数 (`target` vs `targets`) や語順パターン (`no-target` vs `commit-not-found`) が統一されていない (行49-97)
5. **S-04 (パターンの統一的な適用)**: Target の指定方法について、`spec:{{IDENTIFIER}}` のように `:` 区切りのものと `commit:{{HASH}}` のように `:` 区切りだが異なるテンプレート変数を使うものが混在している。これは機能的には問題ないが、`{{IDENTIFIER}}` と `{{HASH}}`/`{{NUMBER}}` の使い分けの基準が文書内で明示されていない (行21-32)

### 🟢 Passed
- テンプレート変数名 (`{{IDENTIFIER}}`, `{{HASH}}`, `{{NUMBER}}`) は目的が明確で理解しやすい
- XML タグによるセクション構造が論理的にグループ化されている
- ドメイン用語 (perspective, target, checklist, artifact) が一貫して使われている
- プロセスのステップが明確に番号付けされ、順序立てて記述されている
- 各テーブルのフォーマットが統一されている
- 出力フォーマットが具体的な例とともに定義されている

## Detailed Review

### Naming (命名)

**N-01: 意図が明確な名前** — ✅ PASS
テンプレート変数 `{{IDENTIFIER}}`, `{{HASH}}`, `{{NUMBER}}`, `{{HASH_SHORT}}` はすべて目的が明確。`IDENTIFIER` はやや汎用的だが、文脈から十分理解可能。

**N-02: 一貫した命名規則** — ✅ PASS
テンプレート変数はすべて `{{UPPER_SNAKE_CASE}}`、XML タグは `kebab-case`、コマンド名は `kebab-case` で統一されている。

**N-03: ドメイン用語の正確な使用** — ✅ PASS
「perspective」「target」「artifact」「checklist」といったドメイン用語が文書全体で一貫して使用されている。同じ概念に複数の名前は使われていない。

**N-04: 不要な略語の排除** — ✅ PASS
`fe`, `be`, `perf`, `doc` は perspective のプレフィックスとして使われており、CLI のショートカットとして合理的。文書内での説明で正式名称が併記されている。

**N-05: Boolean の命名** — N/A
本ファイルに Boolean 変数は存在しない。

**N-06: コレクションの命名** — N/A
本ファイルにコレクション変数は存在しない。

**N-07: 関数名は動詞で始まる** — N/A
本ファイルに関数定義は存在しない。

### Comments (コメント)

**C-01: "Why" を説明するコメント** — ✅ PASS
各セクションが「なぜこのルールがあるか」を暗黙的に構造で示している。`<review-principles>` セクション (行183-189) で「Be Specific: Vague feedback is not actionable」のように理由が説明されている。

**C-02: 古いコメントの検出** — ⚠️ WARNING
`<step n="2">` (行109-126) で参照している checklist ファイルパス `.prompts/templates/checklists/review_fe_checklist.md` 等が、実際のプロジェクト構造と一致しているか確認が必要。他の prompt ファイルではこのパス構造を使っていない。ファイル名を正確に保つか、相対パスの基準を明記すべき。
- 場所: `prompts/8_review.md:112-118`

**C-03: コメントアウトされたコードの禁止** — N/A
コメントアウトされたコードは存在しない。

**C-04: TODO/FIXME の管理** — N/A
TODO/FIXME は存在しない。

**C-05: 公開 API のドキュメンテーション** — N/A
本ファイルは API コードではなくプロンプト定義ファイル。

**C-06: 自明なコードへの過剰コメント回避** — N/A
プロンプト定義であり、コードコメントの概念は該当しない。

### Readability (可読性)

**R-01: 関数の長さ** — N/A
関数定義は存在しない。

**R-02: ネストの深さ** — N/A
プログラミングにおけるネストは存在しない。

**R-03: Guard clause パターンの使用** — N/A
制御フロー構造は存在しない。

**R-04: 複雑な条件式の分離** — N/A
条件式は存在しない。

**R-05: マジックナンバー・マジックストリングの排除** — ⚠️ WARNING
Auto-Selection Rules (行123-127) でファイル拡張子がハードコードされている。これらの拡張子リストが他の prompt ファイルや設定で重複管理されている場合、変更時に不整合が生じる可能性がある。共通定義ファイルや `_shared` ディレクトリへの外出しを検討すべき。
- 場所: `prompts/8_review.md:123-127`

**R-06: 適切な空行とグルーピング** — ✅ PASS
XML タグとMarkdown 見出しにより論理的なブロックが明確に区切られている。空行の使い方も一貫している。

### Code Organization (コード構造)

**O-01: 単一責任の原則 (SRP)** — ✅ PASS
ファイル全体が「レビュープロセスの定義」という単一の責務に集中している。入力解析、実行、出力という構成要素はすべてレビュープロセスの一部。

**O-02: 凝集度** — ⚠️ WARNING
`<rules>` セクション (行149-199) に `<output-locations>`, `<severity-levels>`, `<review-principles>`, `<review-criteria>` が混在している。特に `<severity-levels>` (行163-180) はレビューの判定基準であり、`<process>` の `<step n="3">` や `<step n="4">` により密接に関連する。`<rules>` から分離するか、`<process>` 内で参照する形が望ましい。
- 場所: `prompts/8_review.md:149-199`

**O-03: Dead code の除去** — ✅ PASS
未使用の定義や到達不能なセクションは見当たらない。すべてのセクションがプロセスのいずれかのステップで参照される。

**O-04: import の整理** — N/A
import は存在しない。

**O-05: ファイルの適切な分割** — N/A
229行で、プロンプト定義ファイルとしては妥当なサイズ。他の sibling ファイルも同程度の規模。

### Consistency (一貫性)

**S-01: 命名パターンの統一** — ⚠️ WARNING
エラーテンプレートの XML タグ名に不統一がある:
- `<error-no-target>` (行49): 「no + 名詞」パターン
- `<error-multiple-targets>` (行71): 「形容詞 + 名詞複数形」パターン
- `<error-commit-not-found>` (行82): 「名詞 + not-found」パターン
- `<error-pr-not-found>` (行90): 「名詞 + not-found」パターン

統一案: `<error-target-missing>`, `<error-target-ambiguous>`, `<error-commit-missing>`, `<error-pr-missing>` のように「名詞 + 状態」パターンに統一する。
- 場所: `prompts/8_review.md:49,71,82,90`

**S-02: エラーハンドリングパターンの統一** — ✅ PASS
すべてのエラーテンプレートが「Error メッセージ → 説明 → Tips/ヒント」という同一のフォーマットに従っている。

**S-03: コードスタイルの統一** — ✅ PASS
Markdown の書式（見出しレベル、テーブル構造、リスト形式）が文書全体で統一されている。XML タグの開閉も一貫している。

**S-04: パターンの統一的な適用** — ⚠️ WARNING
ターゲット指定でテンプレート変数の使い分けが暗黙的:
- `spec:{{IDENTIFIER}}`, `plan:{{IDENTIFIER}}`, `code:{{IDENTIFIER}}` → `{{IDENTIFIER}}`
- `commit:{{HASH}}` → `{{HASH}}`
- `pr:{{NUMBER}}` → `{{NUMBER}}`

いずれも「ターゲットを一意に特定する文字列」であるが、なぜ異なるテンプレート変数名を使うのかの説明がない。型の違い（文字列 vs ハッシュ vs 数値）を示唆しているなら、その旨を明記すべき。
- 場所: `prompts/8_review.md:21-32`

**S-05: 戻り値・引数パターンの統一** — ✅ PASS
出力ロケーションテーブル (行151-161) で各ターゲットタイプに対する出力先が明確に定義されており、パターンが一貫している。

## Action Items

| Priority | Item | Location | Suggestion |
|----------|------|----------|------------|
| 🟡 | エラーテンプレートの命名統一 | prompts/8_review.md:49,71,82,90 | `<error-{noun}-{state}>` パターンに統一 (例: `error-target-missing`, `error-target-ambiguous`) |
| 🟡 | checklist パス参照の検証 | prompts/8_review.md:112-118 | 実際のファイルパスと一致しているか確認し、不一致なら修正 |
| 🟡 | テンプレート変数の使い分け説明 | prompts/8_review.md:21-32 | `{{IDENTIFIER}}` vs `{{HASH}}` vs `{{NUMBER}}` の区別基準を明記 |
| 🟡 | Auto-Selection Rules の拡張子リスト | prompts/8_review.md:123-127 | `_shared` ディレクトリへの外出しを検討 |
| 🟡 | `<rules>` セクションの再構成 | prompts/8_review.md:149-199 | `<severity-levels>` を `<process>` に近い位置に移動、または参照構造を明確化 |

## Next Steps
- 上記 Warning 項目のうち、特に checklist パスの参照検証 (C-02) を優先的に確認。パスが不正な場合、レビュー実行時にチェックリストが読み込めない可能性がある
- エラーテンプレートの命名統一 (S-01) は他の prompt ファイル (1_research.md 〜 9_do_by_gemini.md) と横断的に実施することを推奨
- 残りの Warning は次回の改善サイクルで対応可能
