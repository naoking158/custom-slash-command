# Change Analysis: Unified Prompts Path

## Request Summary

Claude Code と gemini-cli で一貫したスラッシュコマンドを実現するため、プロンプト参照パスを統一したい。

## Current Behavior

### 1. Claude Code Commands

`commands/*.md` 内での参照方式：
```markdown
Read and follow the prompt logic at: `~/.prompts/1_research.md`
```
- `~/.prompts/` を参照
- `~/.claude/.prompts` はシンボリックリンクとして存在するが、実際のコマンドでは使用されていない

### 2. gemini-cli Commands

`gemini/commands/sdd/*.toml` 内での参照方式：
```toml
@{../../../.prompts/_shared/roles/research.md}
```
- 相対パス `../../../.prompts/` を使用
- `~/.gemini/commands/sdd/` にシンボリックリンクされた場合、`~/.prompts/` を参照

### 3. README.md Installation Instructions

```bash
# Step 2: Create shared prompts symlink
ln -sf "$(pwd)/prompts" ~/.prompts

# Step 3: Claude Code symlinks
ln -sf ~/.prompts ~/.claude/.prompts
```

### 4. Identified Inconsistencies

| 項目 | 問題 |
|------|------|
| `~/.claude/.prompts` | 作成されるが、Claude Code コマンドでは使用されない |
| gemini-cli の相対パス | `../../../.prompts/` はシンボリックリンク先に依存し脆弱 |
| ドキュメント | 2つの異なるパスが存在する理由が不明確 |

## Desired Behavior

### 統一パス: `~/.prompts`

| ツール | 参照方式 | 解決先 |
|--------|----------|--------|
| Claude Code | `~/.prompts/` | 絶対パス |
| gemini-cli | `~/.prompts/` | 絶対パス (ホーム展開) |

### 利点

1. **一貫性**: 両ツールで同じパスを参照
2. **シンプル**: 1つのシンボリックリンクのみ必要
3. **移植性**: プロジェクトの配置場所に依存しない
4. **理解しやすさ**: ドキュメントが簡潔になる

## Gap Analysis

### Changes Required

| ファイル | 変更内容 |
|----------|----------|
| `gemini/commands/sdd/*.toml` | 相対パス → `~/.prompts/` に変更 |
| `README.md` | `~/.claude/.prompts` シンボリックリンク作成手順を削除 |

### Changes NOT Required

| ファイル | 理由 |
|----------|------|
| `commands/*.md` | 既に `~/.prompts/` を使用 |
| `prompts/` 内のファイル | 変更不要 |

## Impact Assessment

### Affected Components

1. **gemini-cli commands** (8 files)
   - `research.toml`, `spec.toml`, `plan.toml`, `do.toml`
   - `debug.toml`, `refactor.toml`, `change.toml`, `review.toml`

2. **Documentation** (1 file)
   - `README.md`

### Regression Risk: Low

- 既存の `~/.prompts` シンボリックリンクがあれば動作
- Claude Code の動作は変わらない
- gemini-cli の相対パス解決が絶対パスに変わるだけ

### Breaking Changes: None

- 既存ユーザーは再インストール不要（`~/.prompts` が既に存在）
- `~/.claude/.prompts` は任意（既存でも問題なし）

## Technical Considerations

### gemini-cli の `@{path}` 構文

gemini-cli v0.23.0+ では `@{path}` 構文でファイル内容をインライン展開。

**確認事項**: `~` (チルダ) がホームディレクトリに展開されるか
- 展開される場合: `@{~/.prompts/...}` で OK
- 展開されない場合: 環境変数 `$HOME` または別のアプローチが必要

### 推奨テスト

```bash
# gemini-cli でチルダ展開をテスト
gemini "/sdd:research test feature"
```

## Acceptance Criteria

- [ ] gemini-cli の全コマンドが `~/.prompts/` を参照
- [ ] README.md から `~/.claude/.prompts` 手順を削除
- [ ] 両ツールで `/research test` が正常動作
- [ ] インストール手順が簡潔になる

## Alternative Approaches Considered

### Option A: 両方 `~/.prompts` に統一 (推奨)

- シンプル、一貫性あり
- 実装コスト低

### Option B: 環境変数 `$PROMPTS_DIR` を使用

- より柔軟
- 設定が複雑になる
- オーバーエンジニアリングの恐れ

### Option C: 各ツール固有のパスを維持

- 現状維持
- 一貫性の問題が残る

**選択: Option A**
