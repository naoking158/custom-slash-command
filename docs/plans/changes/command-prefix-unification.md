# Change Plan: Command Prefix Unification to `my:`

## Summary
スラッシュコマンドの prefix を `my:` に統一する。Claude Code は prefix なし → `my:` prefix、gemini-cli は `sdd:` → `my:` prefix に変更。

## Plan Details

- **Source Document:** `docs/analysis/changes/command-prefix-unification.md`
- **Type:** Change (名前空間リネーム)
- **Complexity:** Medium
- **Files to Create:** 0
- **Files to Move/Rename:** 17 (9 Claude Code commands + 8 gemini-cli commands)
- **Files to Modify:** 13 (9 prompts + 3 templates + 1 README)

## Prerequisites
- なし（既存のコマンド構造を理解していること）

## Phase 1: Claude Code コマンドファイルの移動

### Step 1.1: `commands/my/` ディレクトリ作成
```
mkdir -p commands/my
```

### Step 1.2: コマンドファイルを `commands/my/` に移動
```
git mv commands/research.md commands/my/research.md
git mv commands/spec.md commands/my/spec.md
git mv commands/plan.md commands/my/plan.md
git mv commands/debug.md commands/my/debug.md
git mv commands/refactor.md commands/my/refactor.md
git mv commands/change.md commands/my/change.md
git mv commands/do.md commands/my/do.md
git mv commands/review.md commands/my/review.md
git mv commands/do-by-gemini.md commands/my/do-by-gemini.md
```

### Step 1.3: コマンドファイル内のクロスリファレンス更新
各ファイル内のコマンド参照を `/my:` prefix 付きに更新。

**`commands/my/research.md`:**
- `/spec` → `/my:spec`

**`commands/my/spec.md`:**
- `/plan` → `/my:plan`

**`commands/my/plan.md`:**
- `/plan ` → `/my:plan `
- `/research` → `/my:research`
- `/spec` → `/my:spec`
- `/debug` → `/my:debug`
- `/refactor` → `/my:refactor`
- `/change` → `/my:change`
- `/do ` → `/my:do `

**`commands/my/debug.md`:**
- `/do ` → `/my:do `
- `/plan ` → `/my:plan `

**`commands/my/refactor.md`:**
- `/do ` → `/my:do `
- `/plan ` → `/my:plan `

**`commands/my/change.md`:**
- `/do ` → `/my:do `
- `/plan ` → `/my:plan `
- `/change ` → `/my:change `

**`commands/my/do.md`:**
- `/do ` → `/my:do `
- `/research` → `/my:research`
- `/spec` → `/my:spec`
- `/plan` → `/my:plan`
- `/debug` → `/my:debug`
- `/refactor` → `/my:refactor`
- `/change` → `/my:change`

**`commands/my/review.md`:**
- `/review ` → `/my:review `

**`commands/my/do-by-gemini.md`:**
- `/do-by-gemini` → `/my:do-by-gemini`
- `/do ` → `/my:do `（`/do-by-gemini` の一部にマッチしないよう注意）
- `/research` → `/my:research`
- `/spec` → `/my:spec`
- `/plan` → `/my:plan`
- `/debug` → `/my:debug`
- `/refactor` → `/my:refactor`
- `/change` → `/my:change`

**Verification:**
- [ ] すべてのファイルが `commands/my/` に存在する
- [ ] `commands/` 直下に `.md` ファイルが残っていない
- [ ] 各ファイル内のコマンド参照がすべて `/my:` prefix 付き

## Phase 2: gemini-cli コマンドディレクトリの変更

### Step 2.1: ディレクトリ名変更
```
git mv gemini/commands/sdd gemini/commands/my
```

### Step 2.2: TOML ファイル内のクロスリファレンス更新
全8ファイルで `/sdd:` → `/my:` に置換。

**対象ファイル:**
- `gemini/commands/my/research.toml`: `/sdd:spec` → `/my:spec`
- `gemini/commands/my/spec.toml`: `/sdd:plan` → `/my:plan`
- `gemini/commands/my/plan.toml`: `/sdd:*` → `/my:*`
- `gemini/commands/my/debug.toml`: `/sdd:*` → `/my:*`
- `gemini/commands/my/refactor.toml`: `/sdd:*` → `/my:*`
- `gemini/commands/my/change.toml`: `/sdd:*` → `/my:*`
- `gemini/commands/my/do.toml`: `/sdd:*` → `/my:*`
- `gemini/commands/my/review.toml`: `/sdd:*` → `/my:*`

**Verification:**
- [ ] `gemini/commands/sdd/` ディレクトリが存在しない
- [ ] `gemini/commands/my/` に全8ファイルが存在する
- [ ] TOML ファイル内に `/sdd:` の参照が残っていない

## Phase 3: プロンプトファイルのクロスリファレンス更新

### Step 3.1: Claude Code プロンプト更新
各プロンプトファイル内のコマンド参照を更新。

**対象ファイル:**
| File | 更新するリファレンス |
|------|-------------------|
| `prompts/1_research.md` | `/spec` → `/my:spec` |
| `prompts/2_spec.md` | `/plan` → `/my:plan` |
| `prompts/3_plan.md` | `/plan`, `/research`, `/spec`, `/debug`, `/refactor`, `/change`, `/do` → all `/my:*` |
| `prompts/4_debug.md` | `/do`, `/plan` → `/my:do`, `/my:plan` |
| `prompts/5_refactor.md` | `/do`, `/plan`, `/refactor` → `/my:do`, `/my:plan`, `/my:refactor` |
| `prompts/6_change.md` | `/do`, `/plan`, `/change`, `/research`, `/spec`, `/debug`, `/refactor` → all `/my:*` |
| `prompts/7_do.md` | `/do`, `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change` → all `/my:*` |
| `prompts/8_review.md` | `/review`, `/do` → `/my:review`, `/my:do` |
| `prompts/9_do_by_gemini.md` | `/do-by-gemini`, `/do`, `/review`, `/research`, `/spec`, `/plan`, `/debug`, `/refactor`, `/change` → all `/my:*` |

### Step 3.2: テンプレートファイル更新
**対象ファイル:**
| File | 更新するリファレンス |
|------|-------------------|
| `prompts/templates/research_template.md` | `/spec` → `/my:spec` |
| `prompts/templates/review_template.md` | `/do`, `/review` → `/my:do`, `/my:review` |
| `prompts/templates/gemini-review.md` | `/do-by-gemini` → `/my:do-by-gemini` |

**Verification:**
- [ ] `prompts/` 内に prefix なしのコマンド参照が残っていない
- [ ] `prompts/templates/` 内に prefix なしのコマンド参照が残っていない

## Phase 4: README.md の更新

### Step 4.1: コマンド一覧テーブルの更新
- Claude Code セクション: `/research` → `/my:research` 等
- gemini-cli セクション: `/sdd:research` → `/my:research` 等

### Step 4.2: インストール手順の更新
- gemini-cli symlink: `sdd` → `my`
  ```bash
  # Before
  ln -sf "$(pwd)/gemini/commands/sdd" ~/.gemini/commands/sdd
  # After
  ln -sf "$(pwd)/gemini/commands/my" ~/.gemini/commands/my
  ```
- Verify手順: `ls -la ~/.gemini/commands/sdd` → `ls -la ~/.gemini/commands/my`
- Uninstall手順: `rm ~/.gemini/commands/sdd` → `rm ~/.gemini/commands/my`

### Step 4.3: 使用例の更新
- Claude Code 使用例: `/research`, `/spec`, `/plan`, `/do`, `/review`, `/debug`, `/refactor`, `/change` → all `/my:*`
- gemini-cli 使用例: `/sdd:*` → `/my:*`

### Step 4.4: ディレクトリ構造の更新
```
# Before
├── commands/
│   ├── research.md
│   ...
├── gemini/
│   └── commands/
│       └── sdd/

# After
├── commands/
│   └── my/
│       ├── research.md
│       ...
├── gemini/
│   └── commands/
│       └── my/
```

### Step 4.5: 出力ディレクトリコメントの更新
- `# /research output` → `# /my:research output` 等

**Verification:**
- [ ] README 内に `/sdd:` の参照が残っていない
- [ ] README 内に prefix なしのスラッシュコマンド参照が残っていない（`/do-by-gemini` 含む）
- [ ] インストール手順が正しい symlink パスを示している

## Phase 5: 検証

### Step 5.1: ファイル構造の確認
```bash
# Claude Code commands
ls commands/my/
# Expected: change.md  debug.md  do-by-gemini.md  do.md  plan.md  refactor.md  research.md  review.md  spec.md

# No .md files in commands/ root
ls commands/*.md 2>/dev/null
# Expected: no output

# gemini-cli commands
ls gemini/commands/my/
# Expected: change.toml  debug.toml  do.toml  plan.toml  refactor.toml  research.toml  review.toml  spec.toml

# No sdd directory
ls gemini/commands/sdd/ 2>/dev/null
# Expected: no output
```

### Step 5.2: クロスリファレンスの整合性確認
```bash
# Ensure no bare /research, /spec, etc. remain (excluding /my: prefixed ones)
# Note: careful regex to avoid matching partial words
grep -rn '\/research\b' commands/ prompts/ gemini/ README.md | grep -v '/my:research'
grep -rn '\/spec\b' commands/ prompts/ gemini/ README.md | grep -v '/my:spec'
grep -rn '\/plan\b' commands/ prompts/ gemini/ README.md | grep -v '/my:plan'
grep -rn '\/sdd:' commands/ prompts/ gemini/ README.md
# All should return empty
```

### Step 5.3: 実動作確認
- [ ] Claude Code で `/my:research test feature` が動作する
- [ ] Claude Code で `/my:do test-feature` が動作する
- [ ] gemini-cli で `/my:research test feature` が動作する（symlink 再設定後）

## Implementation Notes

### 置換時の注意点
1. **`/do` と `/do-by-gemini` の衝突回避**: `/do-by-gemini` を先に置換してから `/do` を置換する（または正確なパターンマッチを使用）
2. **`/review` の内部 prefix**: `/review` コマンドには `spec:`, `plan:`, `code:`, `commit:`, `pr:` 等の引数 prefix があるが、これらはコマンド prefix とは別物なので変更不要
3. **`/plan` の type prefix**: `/plan fix:`, `/plan refactor:`, `/plan change:` の引数 prefix も変更不要
4. **docs/ ディレクトリ**: 過去の成果物のため更新しない

### Rollback Plan
```bash
# Revert all changes
git checkout -- .

# Restore gemini-cli symlink if needed
rm -f ~/.gemini/commands/my
ln -sf "$(pwd)/gemini/commands/sdd" ~/.gemini/commands/sdd
```

## Acceptance Criteria Check

- [ ] AC-001: Claude Code で `/my:*` コマンドが利用可能
- [ ] AC-002: gemini-cli で `/my:*` コマンドが利用可能
- [ ] AC-003: 各コマンド内の next steps で正しい `/my:` prefix が表示される
- [ ] AC-004: README.md が新しいコマンド名を反映している
- [ ] AC-005: インストール手順が新しい symlink パスを反映している
- [ ] AC-006: 旧コマンド名の参照が残存していないこと
