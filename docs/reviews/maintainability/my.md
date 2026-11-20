# Maintainability Review: my

## Metadata
- **Target**: commands/my/ (directory review)
- **Reviewed**: 2026-03-29
- **Files Reviewed**: 11
- **Checklist Items Evaluated**: 19/30

## Summary

| Category | ✅ Pass | ⚠️ Warning | ❌ Issue |
|----------|---------|------------|---------|
| Naming | 5 | 1 | 0 |
| Comments | 3 | 0 | 0 |
| Readability | 4 | 1 | 0 |
| Code Organization | 3 | 1 | 0 |
| Consistency | 2 | 1 | 0 |
| **Total** | **17** | **4** | **0** |

**Overall Assessment**: NEEDS_REVISION

## Findings

### 🔴 Critical Issues
なし

### 🟡 Warnings

1. **N-02: 一貫した命名規則** — `do-by-gemini.md` のファイル名は他のファイル（`do.md`, `plan.md`, `review.md`）と比べて命名パターンが異なる。他は単一動詞 or 動詞+名詞だが、`do-by-gemini` は `動詞-by-ツール名` という独自パターン。
2. **R-05: マジックナンバー・マジックストリングの排除** — `do-by-gemini.md:88` で `/tmp/gemini-output-{timestamp}.log` のパスがハードコードされている。ログ出力先の設定がマジックストリングとして埋め込まれている。
3. **O-01: 単一責任の原則 (SRP)** — `do-by-gemini.md` は実行、オプション解析、モデルエイリアス解決、APIキー検証、エラーハンドリングなど多くの責務を1つのスキル定義に含んでいる（215行）。
4. **S-04: パターンの統一的な適用** — 外部プロンプト参照の方法が統一されていない。一部は `~/.prompts/X.md` を参照し（do.md, plan.md 等）、一部は `references/` ディレクトリを使い（review-maint）、一部は参照なし（change.md, debug.md は `~/.prompts/` を参照するが `Follow the prompt logic defined in` と `Read and follow the prompt logic at:` で表現が異なる）。

### 🟢 Passed

- ファイル名は一貫して kebab-case を使用しており、可読性が高い
- 各スキルの frontmatter (`description`) が簡潔で目的が明確
- セクション構造（Instructions, Input, Process, Error Handling, After Completion）が統一されている
- エラーメッセージが具体的で、次のアクションを明示している
- コメントアウトされたコードや放置された TODO がない

## Detailed Review

### Naming (命名)

**N-01: 意図が明確な名前** — ✅ PASS
各ファイル名（`research.md`, `spec.md`, `plan.md`, `do.md`, `debug.md`, `refactor.md`, `change.md`, `review.md`）はスキルの目的を明確に表現している。セクション名やプレースホルダー（`{identifier}`, `{feature}`, `{target}`）も意図が明確。

**N-02: 一貫した命名規則** — ⚠️ WARNING
ファイル名は kebab-case で統一されているが、`do-by-gemini.md` の命名パターンが他と異なる。他のスキルが `動詞.md` や `動詞-名詞.md`（例: `do.md`, `review-maint`）であるのに対し、`do-by-gemini` は `動詞-by-実行者` というパターン。ただし、Gemini への委譲という特殊な性質を考えると妥当な命名とも言える。
- 該当: `commands/my/do-by-gemini.md`

**N-03: ドメイン用語の正確な使用** — ✅ PASS
「research」「spec」「plan」「do」「review」「debug」「refactor」「change」というドメイン用語が一貫して使われている。各スキルの説明でも同じ用語が同じ意味で使われている。

**N-04: 不要な略語の排除** — ✅ PASS
不要な略語は見られない。`id`、`API`、`PR` など広く認知された略語のみ使用されている。

**N-06: コレクションの命名** — ✅ PASS
該当するコレクション変数はプレースホルダー内に限られるが、適切に使われている（例: `docs/plans/features/`, `docs/plans/fixes/` と複数形ディレクトリ名）。

**N-07: 関数名は動詞で始まる** — ✅ PASS
スキル名（コマンド名）が動作を表している: `do`, `debug`, `review`, `research`, `plan`, `change`, `refactor`。`spec` は名詞だが、"Create detailed specifications" という動作が description で補完されている。

### Comments (コメント)

**C-01: "Why" を説明するコメント** — ✅ PASS
各スキルの冒頭に目的説明があり、制約事項（Critical Constraints）では「なぜそのルールがあるか」が暗黙的に示されている。例: `do.md:55` の「MUST read both plan and source document first」は、計画に基づく実行という設計意図を反映。

**C-03: コメントアウトされたコードの禁止** — ✅ PASS
コメントアウトされたコードブロックはどのファイルにも存在しない。

**C-04: TODO/FIXME の管理** — ✅ PASS
TODO/FIXME コメントは一切存在しない。

### Readability (可読性)

**R-01: 関数の長さ** — ⚠️ WARNING
`do-by-gemini.md` が 215 行と長く、他のスキル（40-130行程度）と比べて突出している。エラーハンドリングセクションだけで約 80 行を占める。
- 該当: `commands/my/do-by-gemini.md` (215行)
- 比較: `do.md` (103行), `review.md` (130行), `change.md` (92行)

**R-05: マジックナンバー・マジックストリングの排除** — ✅ PASS
ほとんどのリテラル値は意味が明確（ファイルパスパターン、コマンド例）。`do-by-gemini.md:88` の `/tmp/gemini-output-{timestamp}.log` は若干のマジックストリングだが、ログファイルの一時パスとして文脈上明確。厳密には WARNING レベルだが、スキル定義としては許容範囲。

**R-06: 適切な空行とグルーピング** — ✅ PASS
全ファイルで論理的なセクション間に適切な空行が配置されている。関連する処理のグループ化（Process のステップ、Error Handling の各ケース）も整理されている。

**R-02: ネストの深さ** — ✅ PASS
Markdown 構造としてネストは浅く保たれている。リスト項目のネストも2レベル以内。

**R-04: 複雑な条件式の分離** — ✅ PASS
Input Resolution セクションの条件分岐（plan 検索順序など）は番号付きリストで明確に記述されている。

### Code Organization (コード構造)

**O-01: 単一責任の原則 (SRP)** — ⚠️ WARNING
`do-by-gemini.md` がオプション解析、モデルエイリアス解決、APIキー検証、gemini-cli 実行、レビュー、エラーハンドリングなど多くの責務を持っている。APIキー検証やモデルエイリアス解決は別の参照ドキュメントに分離できる可能性がある。
- 該当: `commands/my/do-by-gemini.md`

**O-02: 凝集度** — ✅ PASS
各スキルファイルは関連するセクション（Instructions, Process, Error Handling, After Completion）が論理的に配置されている。`review-maint/` ディレクトリの `references/checklist.md` への分離も適切。

**O-05: ファイルの適切な分割** — ✅ PASS
スキルごとに1ファイルという分割は適切。`review-maint` がサブディレクトリ構造を持つのも、checklist という補助資料がある点で妥当。

**O-03: Dead code の除去** — ✅ PASS
未使用のセクションや到達不能な記述は見当たらない。

### Consistency (一貫性)

**S-01: 命名パターンの統一** — ✅ PASS
セクション名のパターンが統一されている: `## Instructions`, `## Input`, `## Process`, `## Critical Constraints`, `## Error Handling`, `## After Completion`。プレースホルダーの書式（`{identifier}`, `{feature}`, `{id}`）も一貫している。

**S-03: コードスタイルの統一** — ✅ PASS
Markdown のスタイル（見出しレベル、コードブロックの使い方、リストのインデント）が全ファイルで統一されている。frontmatter の書式も統一。

**S-04: パターンの統一的な適用** — ⚠️ WARNING
外部プロンプトへの参照方法が2パターン存在する:
- パターン A: `Read and follow the prompt logic at: ~/.prompts/X.md` (`do.md:10`, `plan.md:10`, `review.md:10`, `research.md:10`, `spec.md:10`)
- パターン B: `Follow the prompt logic defined in ~/.prompts/X.md` (`change.md:10`, `debug.md:10`, `refactor.md:10`)
- パターン C: 外部参照なし（`review-maint/SKILL.md` は自己完結型）

パターン A と B は同じ意図だが表現が異なる。統一することで認知負荷を下げられる。

## Action Items

| Priority | Item | Location | Suggestion |
|----------|------|----------|------------|
| 🟡 | 外部プロンプト参照の表現統一 | `change.md:10`, `debug.md:10`, `refactor.md:10` | `Read and follow the prompt logic at:` に統一する |
| 🟡 | do-by-gemini の責務分離検討 | `do-by-gemini.md` 全体 | APIキー検証やモデルエイリアスを `references/` に分離することを検討 |
| 🟡 | do-by-gemini の長さ削減 | `do-by-gemini.md` (215行) | エラーハンドリングの各ケースを簡潔にするか、別ドキュメントに分離 |
| 🟡 | 命名パターンの一貫性 | `do-by-gemini.md` ファイル名 | 現状でも機能的に問題はないが、将来的に他ツール委譲が増える場合のパターンを検討 |

## Next Steps
- 優先度が高いのは外部プロンプト参照の表現統一（影響範囲が小さく、即座に対応可能）
- `do-by-gemini.md` の構造改善は、実際に問題が発生してからでも遅くない
- 全体として保守性は良好。スキル間の構造的一貫性が維持されている
