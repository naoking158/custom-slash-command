# Implementation Plan: SDD Foundation Improvements

## 1. Overview

SDD Foundation の実装を改善し、symlink ベースのデプロイメントをサポートする。

### 1.1 Input Source
- **Source Type:** Change
- **Source Document:** `docs/analysis/changes/sdd-improvements.md`

### 1.2 Deployment Model

**リポジトリ構造:**
```
custom-slash-command/           # GitHub リポジトリ
├── commands/                   # コマンド定義
├── prompts/                    # プロンプトロジック
│   └── templates/
│       └── checklists/
├── docs/                       # ドキュメント・分析結果 (リポジトリ管理外も可)
└── README.md                   # セットアップ手順
```

**Symlink 配置 (使用時):**
```
~/.claude/
├── commands -> /path/to/custom-slash-command/commands
└── .prompts -> /path/to/custom-slash-command/prompts
```

**重要:** プロンプトファイル内の `.prompts/` パス参照は symlink 名と一致しており、**修正不要**。

### 1.3 Additional Requirements

#### ファイル名抽出ロジック
**現状:** `$ARGUMENTS` がそのままファイル名になる
**要件:** 説明文を渡し、AI がファイル名を抽出する

```
/research ユーザー認証機能を実装したい
→ docs/research/20241217-user-auth.md
```

#### 日付 prefix の追加
**形式:** `YYYYMMDD-{extracted-name}.md`

| Input | Extracted Name | Final Filename |
|-------|----------------|----------------|
| ユーザー認証機能を実装したい | user-auth | 20241217-user-auth.md |
| チャット入力欄の横幅を固定 | chat-input-width | 20241217-chat-input-width.md |
| Fix login button not working | login-button-fix | 20241217-login-button-fix.md |

#### 後続コマンドの引数
**決定:** 日付 prefix 込みのファイル名を明示的に渡す
```
/spec 20241217-user-auth
/plan 20241217-user-auth
/do 20241217-user-auth
```

#### 重複時の挙動
**決定:** 上書き（シンプルに同じ機能の再実行は更新とみなす）

### 1.4 Implementation Strategy

1. 高優先度タスク (機能補完) を先に実施
2. 中優先度タスク (UX改善) を続けて実施
3. 低優先度タスク (細かい統一) はオプショナル

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `README.md` | セットアップ手順、使用方法 | High |
| `commands/research.md` | `/research` コマンド定義 | High |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `commands/spec.md` | Frontmatter 追加 | Low |
| `commands/plan.md` | Frontmatter 追加 | Low |
| `commands/debug.md` | Frontmatter 追加 | Low |
| `commands/refactor.md` | Frontmatter 追加 | Low |
| `commands/change.md` | Frontmatter 追加 | Low |
| `commands/do.md` | Frontmatter 追加 | Low |
| `prompts/1_research.md` | ファイル名抽出・日付prefix・ディレクトリ作成指示追加 | Medium |
| `prompts/2_spec.md` | 日付prefix・ディレクトリ作成指示追加 | Low |
| `prompts/3_plan.md` | 日付prefix・ディレクトリ作成指示追加 | Low |
| `prompts/4_debug.md` | ファイル名抽出・日付prefix・ディレクトリ作成指示追加 | Medium |
| `prompts/5_refactor.md` | ファイル名抽出・日付prefix・ディレクトリ作成指示追加 | Medium |
| `prompts/6_change.md` | ファイル名抽出・日付prefix・ディレクトリ作成指示追加 | Medium |

### 2.3 Files to Delete

| File Path | Reason |
|-----------|--------|
| (なし) | |

---

## 3. Implementation Steps

### Phase 1: Documentation (High Priority)

#### Step 1.1: Create README.md
**File:** `README.md`
**Action:** Create

**Content Structure:**
```markdown
# Custom Slash Commands for Claude Code

## Overview
- SDD (Spec-Driven Development) パイプラインの説明
- 利用可能なコマンド一覧

## Installation
- 前提条件 (Claude Code インストール済み)
- Symlink セットアップ手順
- 確認方法

## Usage
- 各コマンドの簡単な説明
- ワークフロー例

## Directory Structure
- リポジトリ構造の説明
- 出力先ディレクトリの説明
```

**Verification:**
- [ ] README.md が作成されている
- [ ] セットアップ手順が明確に記載されている
- [ ] コマンド一覧が記載されている

---

### Phase 2: Missing Command (High Priority)

#### Step 2.1: Create `/research` command
**File:** `commands/research.md`
**Action:** Create

**Content:**
```markdown
---
description: "Research and analyze requirements for new features"
---

# Research Phase - Requirements Analysis

Execute the research phase for: **$ARGUMENTS**

## Instructions
Read and follow the prompt logic at: `.prompts/1_research.md`

## Input
Feature description: $ARGUMENTS

The user will provide a description (possibly in Japanese or other languages).
You MUST extract a concise, meaningful identifier from the description.

## Process
1. Extract a short English identifier (2-4 words) from the description
2. Analyze the feature request or requirement
3. Research best practices and existing solutions
4. Identify stakeholders and needs
5. Assess risks and constraints
6. Write output to `docs/research/YYYYMMDD-{identifier}.md`

## File Naming
1. Extract identifier from description
2. Apply normalization rules (kebab-case)
3. Add today's date as prefix (YYYYMMDD-)

**Examples:**
| Input | Identifier | Filename |
|-------|------------|----------|
| ユーザー認証機能を実装したい | user-auth | 20241217-user-auth.md |
| チャット入力欄の横幅を固定 | chat-input-width | 20241217-chat-input-width.md |

## Critical Constraints
- Do NOT output the document content to console
- MUST write to file in `docs/research/` directory
- MUST use date prefix in filename

## After Completion
Provide a brief summary and suggest running `/spec YYYYMMDD-{identifier}` next.
```

**Verification:**
- [ ] `commands/research.md` が作成されている
- [ ] frontmatter (description) が設定されている
- [ ] `.prompts/1_research.md` を参照している

---

### Phase 3: Frontmatter Addition (Medium Priority)

#### Step 3.1: Add frontmatter to command files
**Files:** `commands/spec.md`, `commands/plan.md`, `commands/debug.md`, `commands/refactor.md`, `commands/change.md`, `commands/do.md`
**Action:** Modify

**Frontmatter to add (at the beginning of each file):**

| Command | Description |
|---------|-------------|
| spec | Create detailed specifications from research documents |
| plan | Create implementation plans from specs or analyses |
| debug | Analyze bugs and generate fix plans |
| refactor | Analyze code for refactoring with auto-generated plans |
| change | Analyze feature modifications with auto-generated plans |
| do | Execute implementation plans (features, fixes, refactors, changes) |

**Format:**
```yaml
---
description: "{description}"
---
```

**Verification:**
- [ ] 全コマンドファイルに frontmatter が設定されている
- [ ] description が適切に記述されている

---

### Phase 4: File Naming Logic Update (High Priority)

#### Step 4.1: Add file name extraction logic to prompts
**Files:** `prompts/1_research.md`, `prompts/4_debug.md`, `prompts/5_refactor.md`, `prompts/6_change.md`
**Action:** Modify

**追加するセクション (File Naming Convention の前または置換):**
```markdown
## File Name Extraction

The user will provide a description (possibly in Japanese or other languages).
You MUST extract a concise, meaningful identifier from the description.

**Process:**
1. Understand the core concept from the description
2. Create a short English identifier (2-4 words)
3. Apply normalization rules (kebab-case)
4. Add date prefix (YYYYMMDD-)

**Examples:**
| Input | Extracted Name | Final Filename |
|-------|----------------|----------------|
| ユーザー認証機能を実装したい | user-auth | 20241217-user-auth.md |
| チャット入力欄の横幅を固定 | chat-input-width | 20241217-chat-input-width.md |
| Fix login button not working | login-button-fix | 20241217-login-button-fix.md |

**Normalization Rules:**
1. Lowercase all characters
2. Replace spaces, slashes, underscores → hyphens
3. Convert camelCase → kebab-case
4. Collapse multiple hyphens → single hyphen
```

#### Step 4.2: Update date prefix in all prompts
**Files:** `prompts/1_research.md`, `prompts/2_spec.md`, `prompts/3_plan.md`, `prompts/4_debug.md`, `prompts/5_refactor.md`, `prompts/6_change.md`
**Action:** Modify

**変更内容:**
- 出力ファイルパスに `YYYYMMDD-` prefix を追加
- 例: `docs/research/{feature_name}.md` → `docs/research/YYYYMMDD-{identifier}.md`

**Verification:**
- [ ] ファイル名抽出ロジックが追加されている
- [ ] 全出力パスに日付 prefix が含まれている

---

### Phase 5: Directory Creation Instructions (Medium Priority)

#### Step 5.1: Add directory creation guidance to prompts
**Files:** `prompts/1_research.md`, `prompts/2_spec.md`, `prompts/3_plan.md`, `prompts/4_debug.md`, `prompts/5_refactor.md`, `prompts/6_change.md`
**Action:** Modify

**追加する内容 (Output Constraint セクション内):**
```markdown
**Directory Creation:**
If the output directory does not exist, create it before writing the file.
```

**Verification:**
- [ ] 全出力系プロンプトにディレクトリ作成の指示がある

---

### Phase 6: Testing (Verification)

#### Step 5.1: Verify symlink setup
**Action:** Manual verification

**Test Cases:**
- [ ] `ls -la ~/.claude/commands` が symlink を表示する
- [ ] `ls -la ~/.claude/.prompts` が symlink を表示する
- [ ] `ls ~/.claude/commands/` でコマンドファイル一覧が表示される

#### Step 5.2: Verify command availability
**Action:** Manual verification

**Test Cases:**
- [ ] `/research` コマンドが認識される
- [ ] `/spec` コマンドが認識される
- [ ] `/plan` コマンドが認識される
- [ ] `/debug` コマンドが認識される
- [ ] `/refactor` コマンドが認識される
- [ ] `/change` コマンドが認識される
- [ ] `/do` コマンドが認識される
- [ ] `/review` コマンドが認識される

#### Step 5.3: Verify frontmatter display
**Action:** Manual verification

**Test Cases:**
- [ ] 各コマンドの description が補完候補に表示される

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| Claude Code | Latest | CLI ツール |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `~/.claude/` | 存在必須 | Claude Code の設定ディレクトリ |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [x] 分析ドキュメントレビュー完了
- [x] 対象ファイル特定完了
- [x] symlink 運用前提の確認完了

### 5.2 Post-Implementation
- [ ] README.md が作成されている
- [ ] `commands/research.md` が作成されている
- [ ] 全コマンドファイルに frontmatter がある
- [ ] プロンプトにファイル名抽出ロジックがある
- [ ] プロンプトに日付 prefix ロジックがある
- [ ] プロンプトにディレクトリ作成指示がある

### 5.3 Acceptance Criteria Verification
- [ ] AC-001: `/research` コマンドが利用可能
- [ ] AC-002: README.md にセットアップ手順が記載されている
- [ ] AC-003: 全コマンドに description が設定されている
- [ ] AC-004: 説明からファイル名を抽出できる
- [ ] AC-005: ファイル名に日付 prefix が付与される
- [ ] AC-006: ディレクトリ作成指示が追加されている

---

## 6. Rollback Plan

1. Git で変更前の状態にリバート: `git checkout HEAD~1 -- <file>`
2. 新規作成ファイルの削除: `rm README.md commands/research.md`

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Documentation | Medium | README.md 作成 |
| Phase 2: Missing Command | Low | 新規ファイル1つ |
| Phase 3: Frontmatter | Low | 6ファイルに追加 |
| Phase 4: Directory Instructions | Low | 6ファイルに1行追加 |
| Phase 5: Testing | Low | 手動確認 |

**Total:** Low〜Medium

---

## 8. Optional Improvements (Low Priority)

以下は今回のスコープ外だが、将来的に検討:

1. **プレースホルダー統一**: `{feature}` vs `{feature_name}` の統一
2. **言語統一**: チェックリスト (日本語) とプロンプト (英語) の統一
3. **`code:{id}` 解決ロジック明確化**: plan_template の Affected Files セクション参照を明示

---
**Created:** 2024-12-17
**Status:** Ready
**Assignee:** (未定)
