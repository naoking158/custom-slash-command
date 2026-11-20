# Change Analysis: Review Multi-Perspective with Maint Default

## Current Behavior

`/my:review` command は単一の perspective のみサポート:

- 明示指定: `security:code:payment` → security チェックリストのみ
- 自動選択: ファイルパターンで1つの perspective を選択
- `maint:` は明示指定時のみ適用

### Auto-Selection Rules (現状)

| Pattern | Perspective |
|---------|-------------|
| `.jsx`, `.tsx`, `.vue`, `.svelte`, CSS | `fe:` |
| `.py`, `.go`, `.java`, `.rs`, API routes | `be:` |
| Auth, crypto, input handling | `security:` |
| Database queries, algorithms, loops | `perf:` |
| Markdown, README, docstrings | `doc:` |
| (no match) | 未定義 |

### 単一 perspective 前提の箇所

| File | 箇所 | 影響 |
|------|------|------|
| `prompts/8_review.md` L19 | `(none) → Auto-select based on target content` | perspective 説明 |
| `prompts/8_review.md` L103 | `Extract perspective prefix (if any)` | パース処理（単数形） |
| `prompts/8_review.md` L109-128 | Load Checklist step | 1つのチェックリスト読み込み |
| `prompts/8_review.md` L146 | `{PERSPECTIVE}` in output path | 出力パス |
| `prompts/8_review.md` L152-163 | output-locations テーブル | パスに `{{PERSPECTIVE}}` |
| `prompts/_shared/processes/review.md` L22-26 | Auto-Selection Rules | 同上 |
| `prompts/templates/review_template.md` L5 | `**Perspective**: {perspective}` | テンプレート |

## Desired Behavior

複数の perspective を同時適用できるようにする。特に `maint:` をベースラインとして自動付与:

### Perspective 組み合わせルール

| 条件 | 適用される perspectives |
|------|------------------------|
| `security:` 明示 | `security` のみ |
| `perf:` 明示 | `perf` のみ |
| `fe:` 明示 | `fe` + `maint` |
| `be:` 明示 | `be` + `maint` |
| `doc:` 明示 | `doc` + `maint` |
| `maint:` 明示 | `maint` のみ |
| 自動選択で fe/be/doc にマッチ | (マッチした perspective) + `maint` |
| 自動選択で security/perf にマッチ | (マッチした perspective) のみ |
| どれにもマッチしない | `maint` のみ |

**理由**: `security:` と `perf:` は専門的な観点であり、maint チェックリストとの重複が少ない。`fe:`, `be:`, `doc:` は maint（命名・可読性・一貫性）と相補的。

## Acceptance Criteria

- [ ] `fe:`, `be:`, `doc:` 指定時に `maint` チェックリストも自動適用される
- [ ] `security:`, `perf:` 指定時は単一 perspective のまま
- [ ] `maint:` 単独指定は従来通り動作
- [ ] 自動選択のフォールバックで `maint` が適用される
- [ ] レポートに複数 perspective のチェック結果がセクション別に含まれる
- [ ] 出力パスが複数 perspective に対応している

## Gap Analysis

### What Changes

1. **Perspective 解釈ロジック** (`prompts/8_review.md`):
   - Parse Input step: 単数 → 複数 perspective のリスト化
   - Load Checklist step: 複数チェックリスト読み込み + maint 自動付与ルール
   - Auto-Selection Rules: フォールバックルール追加

2. **出力パス規則** (`prompts/8_review.md`):
   - `{{PERSPECTIVE}}` → `{{PRIMARY_PERSPECTIVE}}` (例: `be+maint` → `be` をプライマリとして使用)

3. **レポートテンプレート** (`prompts/templates/review_template.md`):
   - `**Perspective**: {perspective}` → `**Perspectives**: {perspectives}` (カンマ区切り)
   - Detailed Findings セクションを perspective ごとにグループ化

4. **共有プロセス定義** (`prompts/_shared/processes/review.md`):
   - Auto-Selection Rules 更新 + maint 自動付与ルール追記

### What Stays the Same

- 全チェックリストファイルの内容
- ターゲット解決ロジック（spec/plan/code/commit/pr）
- 評価基準（PASS/WARNING/ISSUE）
- 全体評価ロジック（PASS/NEEDS_REVISION/FAIL）
- エラーメッセージ

## Impact Assessment

- **Scope**: 3 files (`prompts/8_review.md`, `prompts/_shared/processes/review.md`, `prompts/templates/review_template.md`)
- **Breaking Changes**: 出力パスの `{{PERSPECTIVE}}` 解釈が変わるが、既存レビュー結果のファイルパスには影響なし（プライマリ perspective を使用するため）
- **Regression Risk**: Low. 既存の単一 perspective 指定は同じ動作（security/perf は単独、maint は単独）
- **Complexity**: Medium. prompt のテキスト変更のみだが、ロジック記述箇所が複数ある
