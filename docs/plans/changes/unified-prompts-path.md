# Change Plan: Unified Prompts Path

## Overview

Claude Code と gemini-cli のプロンプト参照パスを `~/.prompts/` に統一する。

## Prerequisites

- [ ] gemini-cli で `@{~/.prompts/...}` のチルダ展開が動作することを確認

## Implementation Steps

### Phase 1: gemini-cli Commands Update

**目的**: 相対パスを `~/.prompts/` に変更

#### Step 1.1: research.toml

```diff
- @{../../../.prompts/_shared/roles/research.md}
+ @{~/.prompts/_shared/roles/research.md}
```

**変更箇所** (4箇所):
- `@{../../../.prompts/_shared/roles/research.md}`
- `@{../../../.prompts/_shared/processes/research.md}`
- `@{../../../.prompts/_shared/file-naming-rules.md}`
- `@{../../../.prompts/templates/research_template.md}`

#### Step 1.2: spec.toml

**変更箇所** (4箇所):
- roles/spec.md
- processes/spec.md
- file-naming-rules.md
- templates/spec_template.md

#### Step 1.3: plan.toml

**変更箇所** (4箇所):
- roles/plan.md
- processes/plan.md
- file-naming-rules.md
- templates/plan_template.md

#### Step 1.4: do.toml

**変更箇所** (3箇所):
- roles/do.md
- processes/do.md
- quality-standards.md

#### Step 1.5: debug.toml

**変更箇所** (4箇所):
- roles/debug.md
- processes/debug.md
- file-naming-rules.md
- templates/bug_analysis_template.md

#### Step 1.6: refactor.toml

**変更箇所** (4箇所):
- roles/refactor.md
- processes/refactor.md
- file-naming-rules.md
- templates/refactor_design_template.md

#### Step 1.7: change.toml

**変更箇所** (4箇所):
- roles/change.md
- processes/change.md
- file-naming-rules.md
- templates/change_template.md

#### Step 1.8: review.toml

**変更箇所** (3箇所以上):
- roles/review.md
- processes/review.md
- templates/review_template.md
- templates/checklists/*.md

### Phase 2: README.md Update

**目的**: インストール手順を簡略化

#### Step 2.1: Remove `~/.claude/.prompts` symlink step

```diff
  3. **Create symlinks for Claude Code**

     ```bash
     # Link the commands directory
     ln -sf "$(pwd)/commands" ~/.claude/commands
-
-    # Link to shared prompts
-    ln -sf ~/.prompts ~/.claude/.prompts
     ```
```

#### Step 2.2: Update verification section

```diff
  5. **Verify the setup**

     ```bash
     # Verify shared prompts
     ls -la ~/.prompts

     # Verify Claude Code symlinks
     ls -la ~/.claude/commands
-    ls -la ~/.claude/.prompts

     # Verify gemini-cli symlinks
     ls -la ~/.gemini/commands/sdd
     ```
```

#### Step 2.3: Update uninstall section

```diff
  ### Uninstall

  ```bash
  # Remove shared prompts
  rm ~/.prompts

  # Remove Claude Code symlinks
  rm ~/.claude/commands
- rm ~/.claude/.prompts

  # Remove gemini-cli symlinks
  rm ~/.gemini/commands/sdd
  ```
```

### Phase 3: Verification

#### Step 3.1: Test gemini-cli tilde expansion

```bash
# Create a test prompt and verify
gemini "/sdd:research test tilde expansion"
```

#### Step 3.2: Verify both tools work

```bash
# Claude Code
/research test unified path

# gemini-cli
gemini "/sdd:research test unified path"
```

## Files to Modify

| File | Type | Changes |
|------|------|---------|
| `gemini/commands/sdd/research.toml` | Edit | Update 4 paths |
| `gemini/commands/sdd/spec.toml` | Edit | Update 4 paths |
| `gemini/commands/sdd/plan.toml` | Edit | Update 4 paths |
| `gemini/commands/sdd/do.toml` | Edit | Update 3 paths |
| `gemini/commands/sdd/debug.toml` | Edit | Update 4 paths |
| `gemini/commands/sdd/refactor.toml` | Edit | Update 4 paths |
| `gemini/commands/sdd/change.toml` | Edit | Update 4 paths |
| `gemini/commands/sdd/review.toml` | Edit | Update multiple paths |
| `README.md` | Edit | Remove `~/.claude/.prompts` references |

## Rollback Plan

変更は単純な文字列置換のため、ロールバックは容易：

```bash
# gemini-cli commands: revert to relative paths
sed -i '' 's|@{~/.prompts/|@{../../../.prompts/|g' gemini/commands/sdd/*.toml

# README.md: git checkout
git checkout README.md
```

## Success Metrics

- [ ] `gemini "/sdd:research test"` が正常動作
- [ ] Claude Code `/research test` が正常動作
- [ ] README.md のインストール手順が 1 シンボリックリンク減少
- [ ] 両ツールで一貫した `~/.prompts/` パスを使用
