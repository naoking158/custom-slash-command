# Change Analysis: Command Prefix Unification to `my:`

## Date
2026-03-02

## Change Request
スラッシュコマンドの名前の prefix を `my:` で統一したい

## Current Behavior

### Claude Code commands (`commands/` → `~/.claude/commands/`)
コマンドファイルが `commands/` 直下に配置されており、prefix なしで利用される。

| File | Command Name |
|------|-------------|
| `commands/research.md` | `/research` |
| `commands/spec.md` | `/spec` |
| `commands/plan.md` | `/plan` |
| `commands/debug.md` | `/debug` |
| `commands/refactor.md` | `/refactor` |
| `commands/change.md` | `/change` |
| `commands/do.md` | `/do` |
| `commands/review.md` | `/review` |
| `commands/do-by-gemini.md` | `/do-by-gemini` |

### gemini-cli commands (`gemini/commands/sdd/` → `~/.gemini/commands/sdd/`)
コマンドファイルが `sdd/` ディレクトリに配置されており、`/sdd:` prefix で利用される。

| File | Command Name |
|------|-------------|
| `gemini/commands/sdd/research.toml` | `/sdd:research` |
| `gemini/commands/sdd/spec.toml` | `/sdd:spec` |
| `gemini/commands/sdd/plan.toml` | `/sdd:plan` |
| `gemini/commands/sdd/debug.toml` | `/sdd:debug` |
| `gemini/commands/sdd/refactor.toml` | `/sdd:refactor` |
| `gemini/commands/sdd/change.toml` | `/sdd:change` |
| `gemini/commands/sdd/do.toml` | `/sdd:do` |
| `gemini/commands/sdd/review.toml` | `/sdd:review` |

### 名前空間の不一致
- Claude Code: prefix なし (`/research`, `/do` 等)
- gemini-cli: `/sdd:` prefix (`/sdd:research`, `/sdd:do` 等)
- 2つのツール間でコマンド名が異なり、ワークフロー切り替え時に混乱が生じる

## Desired Behavior

### 統一された `my:` prefix
両ツールで同じ `my:` prefix を使用:

| Command | Claude Code | gemini-cli |
|---------|-------------|------------|
| Research | `/my:research` | `/my:research` |
| Spec | `/my:spec` | `/my:spec` |
| Plan | `/my:plan` | `/my:plan` |
| Debug | `/my:debug` | `/my:debug` |
| Refactor | `/my:refactor` | `/my:refactor` |
| Change | `/my:change` | `/my:change` |
| Do | `/my:do` | `/my:do` |
| Review | `/my:review` | `/my:review` |
| Do by Gemini | `/my:do-by-gemini` | N/A |

### 名前空間の仕組み
- **Claude Code**: `commands/my/` サブディレクトリにファイルを配置 → `/my:*` として認識
- **gemini-cli**: `gemini/commands/my/` ディレクトリにファイルを配置 → `/my:*` として認識

## Gap Analysis

### ディレクトリ構造の変更

| 変更内容 | 現状 | 変更後 |
|---------|------|--------|
| Claude Code コマンド配置 | `commands/*.md` | `commands/my/*.md` |
| gemini-cli コマンド配置 | `gemini/commands/sdd/*.toml` | `gemini/commands/my/*.toml` |
| symlink (Claude Code) | `commands` → `~/.claude/commands` | 変更なし |
| symlink (gemini-cli) | `gemini/commands/sdd` → `~/.gemini/commands/sdd` | `gemini/commands/my` → `~/.gemini/commands/my` |

### コマンド内クロスリファレンスの更新

コマンドファイル内で他のコマンドを参照している箇所が多数存在:

**Claude Code command files (`commands/my/*.md`):**
- `research.md`: `/spec` → `/my:spec` (1箇所)
- `spec.md`: `/plan` → `/my:plan` (1箇所)
- `plan.md`: `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change`, `/do` → すべて `/my:` prefix (8箇所)
- `debug.md`: `/do`, `/plan` → `/my:do`, `/my:plan` (3箇所)
- `refactor.md`: `/do`, `/plan` → `/my:do`, `/my:plan` (3箇所)
- `change.md`: `/do`, `/plan`, `/change` → `/my:do`, `/my:plan`, `/my:change` (5箇所)
- `do.md`: `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change`, `/do` → すべて `/my:` prefix (14箇所)
- `review.md`: `/review` → `/my:review` (15箇所以上)
- `do-by-gemini.md`: `/do-by-gemini`, `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change` → すべて `/my:` prefix (20箇所以上)

**Prompt files (`prompts/*.md`):**
- `1_research.md`: `/spec` → `/my:spec`
- `2_spec.md`: `/plan` → `/my:plan`
- `3_plan.md`: `/plan`, `/research`, `/spec`, `/debug`, `/refactor`, `/change`, `/do` → すべて更新
- `4_debug.md`: `/do`, `/plan` → 更新
- `5_refactor.md`: `/do`, `/plan` → 更新
- `6_change.md`: `/do`, `/plan`, `/research`, `/spec`, `/debug`, `/refactor`, `/change` → 更新
- `7_do.md`: `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change`, `/do` → 更新
- `8_review.md`: `/review`, `/do` → 更新
- `9_do_by_gemini.md`: `/do-by-gemini`, `/review`, `/do`, `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change` → 更新

**gemini-cli TOML files (`gemini/commands/my/*.toml`):**
- 全8ファイルの `/sdd:` → `/my:` 置換

**Template files (`prompts/templates/`):**
- `research_template.md`: `/spec` → `/my:spec`
- `review_template.md`: `/do`, `/review` → `/my:do`, `/my:review`
- `gemini-review.md`: `/do-by-gemini` → `/my:do-by-gemini`

**README.md:**
- Claude Code セクション: `/research`, `/spec`, etc. → `/my:research`, `/my:spec`, etc.
- gemini-cli セクション: `/sdd:*` → `/my:*`
- インストール手順: symlink パスの更新
- 使用例: すべてのコマンド名の更新
- ディレクトリ構造: 更新

### 変更しないもの

- `prompts/_shared/` 以下: コマンド名の直接参照なし（ロジックのみ）
- `docs/` 以下の既存ドキュメント: 過去の決定を記録した歴史的成果物のため、変更不要
- プロンプトのロジック自体: 変更なし
- 出力ディレクトリ構造 (`docs/research/`, `docs/specs/`, etc.): 変更なし

## Impact Assessment

### 影響を受けるコンポーネント

| コンポーネント | 影響度 | 変更種別 |
|--------------|-------|---------|
| `commands/*.md` (9ファイル) | High | ファイル移動 + 内容更新 |
| `gemini/commands/sdd/*.toml` (8ファイル) | High | ディレクトリ名変更 + 内容更新 |
| `prompts/*.md` (9ファイル) | Medium | 内容更新（クロスリファレンス） |
| `prompts/templates/*.md` (3ファイル) | Low | 内容更新（クロスリファレンス） |
| `README.md` | Medium | 内容更新（多数のコマンド名参照） |
| symlinks | Medium | gemini-cli 側の再設定が必要 |

### 依存関係
- **symlink**: `~/.claude/commands` は変更不要（`commands/` 全体がリンクされているため、`my/` サブディレクトリは自動的に認識される）
- **symlink**: `~/.gemini/commands/sdd` → 削除して `~/.gemini/commands/my` に再作成が必要
- **gemini-cli settings.json**: `context.includeDirectories` の変更は不要

### リグレッションリスク
- **High**: 既存 symlink を利用しているユーザーは再設定が必要（gemini-cli 側）
- **Medium**: コマンド名の変更により既存のワークフロー記憶・ドキュメントと不一致が生じる
- **Low**: プロンプトロジック自体は変更しないためAI出力品質への影響なし

### Breaking Changes
- **全コマンド名の変更**: `/research` → `/my:research` 等、すべてのコマンド名が変わる
- **gemini-cli symlink**: `/sdd:*` → `/my:*` への移行で symlink の再作成が必要
- **マッスルメモリー**: ユーザーが覚えているコマンド名がすべて変わる

## Acceptance Criteria

- [ ] AC-001: Claude Code で `/my:research`, `/my:spec`, `/my:plan`, `/my:debug`, `/my:refactor`, `/my:change`, `/my:do`, `/my:review`, `/my:do-by-gemini` が利用可能
- [ ] AC-002: gemini-cli で `/my:research`, `/my:spec`, `/my:plan`, `/my:debug`, `/my:refactor`, `/my:change`, `/my:do`, `/my:review` が利用可能
- [ ] AC-003: 各コマンド内の next steps やエラーメッセージで正しい `/my:` prefix が表示される
- [ ] AC-004: README.md が新しいコマンド名を反映している
- [ ] AC-005: インストール手順が新しい symlink パスを反映している
- [ ] AC-006: 旧コマンド（prefix なし、`/sdd:` prefix）が残存していないこと

## References
- README.md: 現在のコマンド一覧とインストール手順
- Claude Code docs: https://docs.anthropic.com/en/docs/claude-code/slash-commands
