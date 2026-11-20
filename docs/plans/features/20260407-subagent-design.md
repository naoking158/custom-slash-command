# Implementation Plan: Subagent Design for Command Pipeline

## 1. Overview

6つの主要 subagent（researcher, specifier, planner, implementer, reviewer, fixer）を `.claude/agents/` に定義し、既存 `/my:*` コマンドとの互換性を保ちつつ、コンテキスト分離・最小権限・パイプライン化の基盤を構築する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260407-subagent-design.md`

### 1.2 References
- Specification: `docs/specs/20260407-subagent-design.md`
- Research: `docs/research/20260407-subagent-design.md`
- Related: `docs/research/20260407-pipeline-orchestration.md`

### 1.3 Implementation Strategy
各 subagent を独立した `.claude/agents/{name}.md` ファイルとして定義する。frontmatter で `name`, `description`, `tools`, `model` を宣言し、body に system prompt を記述する。system prompt は既存の `~/.prompts/*.md` への Read 委譲パターンを採用し、プロンプトの重複を排除する。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `.claude/agents/researcher.md` | Research phase subagent definition | P0 |
| `.claude/agents/specifier.md` | Spec phase subagent definition | P0 |
| `.claude/agents/planner.md` | Plan phase subagent definition | P0 |
| `.claude/agents/implementer.md` | Implementation phase subagent definition | P0 |
| `.claude/agents/reviewer.md` | Review phase subagent definition | P0 |
| `.claude/agents/fixer.md` | Review fix phase subagent definition | P0 |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| (none) | - | - |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (none) | - |

---

## 3. Implementation Steps

### Phase 1: Foundation — Directory & Read-Only Agents

Read-only（Edit/Bash なし）の subagent から作成し、基本構造を確立する。

#### Step 1.1: Create agents directory
**File:** `.claude/agents/` (directory)
**Action:** Create

**Details:**
```
- Create .claude/agents/ directory
```

**Verification:**
- [ ] `.claude/agents/` directory exists

#### Step 1.2: Create specifier subagent
**File:** `.claude/agents/specifier.md`
**Action:** Create

**Details:**
```
- frontmatter: name=specifier, tools=Read/Glob/Grep/Write, model=inherit
- description: research ドキュメントから仕様書を生成する。spec, specification, 仕様 に関するタスクに使用。
- body: Read ~/.prompts/2_spec.md を指示し、入力 research doc パスと出力パスを受け取る
- Read template at ~/.prompts/templates/spec_template.md
- Return: output_path, summary, metrics (user_stories_count, data_models_count)
```

**Verification:**
- [ ] frontmatter schema valid (name, description, tools, model)
- [ ] tools に Edit/Bash/WebSearch/WebFetch が含まれないこと
- [ ] body に Read prompt instruction が含まれること

#### Step 1.3: Create reviewer subagent
**File:** `.claude/agents/reviewer.md`
**Action:** Create

**Details:**
```
- frontmatter: name=reviewer, tools=Read/Glob/Grep/Write, model=opus
- description: 成果物（specs, plans, code）を専門的な観点からレビューする。review, レビュー, 品質チェック に関するタスクに使用。
- body: Read ~/.prompts/8_review.md を指示
- Load perspective-specific checklist from ~/.prompts/templates/checklists/
- Evaluate: PASS / WARNING / ISSUE per checklist item
- Output: docs/reviews/{target_type}/{perspective}/{id}.md
- Return: output_path, summary, metrics (pass/warning/issue counts)
```

**Verification:**
- [ ] frontmatter schema valid
- [ ] tools に Edit/Bash が含まれないこと
- [ ] model が opus であること

---

### Phase 2: Core Logic — Agents with Bash/Edit Access

#### Step 2.1: Create researcher subagent
**File:** `.claude/agents/researcher.md`
**Action:** Create

**Details:**
```
- frontmatter: name=researcher, tools=Read/Glob/Grep/Write/Bash/WebSearch/WebFetch, model=inherit
- mcpServers: modular-mcp
- description: 新機能や技術的課題について調査・分析する。research, 調査, リサーチ に関するタスクに使用。
- body: Read ~/.prompts/1_research.md を指示
- Use WebSearch/WebFetch/MCP for external investigation
- Output: docs/research/YYYYMMDD-{id}.md
- Return: output_path, summary, metrics (open_questions_count)
```

**Verification:**
- [ ] frontmatter schema valid
- [ ] tools に WebSearch/WebFetch が含まれること
- [ ] mcpServers に modular-mcp が含まれること

#### Step 2.2: Create planner subagent
**File:** `.claude/agents/planner.md`
**Action:** Create

**Details:**
```
- frontmatter: name=planner, tools=Read/Glob/Grep/Write/Bash, model=inherit
- description: 仕様書や分析ドキュメントから実装計画を作成する。plan, 計画, 実装プラン に関するタスクに使用。
- body: Read ~/.prompts/3_plan.md を指示
- Investigate codebase with Glob, Grep, Bash (tree, wc)
- Break down into phases: Foundation → Core Logic → Integration → Testing
- Output: docs/plans/{type}/{id}.md
- Return: output_path, summary, metrics (phase_count, task_count)
```

**Verification:**
- [ ] frontmatter schema valid
- [ ] tools に Bash が含まれ、Edit が含まれないこと

#### Step 2.3: Create implementer subagent
**File:** `.claude/agents/implementer.md`
**Action:** Create

**Details:**
```
- frontmatter: name=implementer, tools=Read/Glob/Grep/Write/Edit/Bash, model=sonnet
- description: 実装計画に基づいてコードを実装する。implement, 実装, do に関するタスクに使用。
- body: Read ~/.prompts/7_do.md を指示
- Read plan document as input
- Execute phase-by-phase, running lint/test after each phase
- Do NOT make changes outside the plan scope
- Return: summary of changes, test results, blockers (if any)
```

**Verification:**
- [ ] frontmatter schema valid
- [ ] tools に全6ツール（Read/Glob/Grep/Write/Edit/Bash）が含まれること
- [ ] model が sonnet であること

#### Step 2.4: Create fixer subagent
**File:** `.claude/agents/fixer.md`
**Action:** Create

**Details:**
```
- frontmatter: name=fixer, tools=Read/Glob/Grep/Write/Edit, model=sonnet
- description: レビュー指摘に基づいてドキュメントやコードを修正する。fix, 修正, レビュー反映 に関するタスクに使用。
- body:
  1. Read review report and target file(s)
  2. Process only Critical and Medium priority issues
  3. Ignore Low priority issues
  4. Preserve original document structure and style
  5. Return: list of fixes applied, files modified
```

**Verification:**
- [ ] frontmatter schema valid
- [ ] tools に Edit が含まれ、Bash が含まれないこと
- [ ] model が sonnet であること

---

### Phase 3: Integration — Validation & Consistency Check

#### Step 3.1: Validate all agent definitions
**Action:** Verify

**Details:**
```
- All 6 files exist in .claude/agents/
- frontmatter fields (name, description, tools) are present in all files
- Tool permission matrix matches spec Section 7
- Model assignments: researcher=inherit, specifier=inherit, planner=inherit, implementer=sonnet, reviewer=opus, fixer=sonnet
```

**Verification:**
- [ ] `ls .claude/agents/` shows 6 files
- [ ] Each file has valid frontmatter with required fields
- [ ] Tool permissions match the specification matrix exactly
- [ ] Model assignments match spec

#### Step 3.2: Verify prompt file references
**Action:** Verify

**Details:**
```
- researcher references ~/.prompts/1_research.md
- specifier references ~/.prompts/2_spec.md
- planner references ~/.prompts/3_plan.md
- implementer references ~/.prompts/7_do.md
- reviewer references ~/.prompts/8_review.md
- fixer has inline instructions (no external prompt reference)
```

**Verification:**
- [ ] All referenced prompt files exist
- [ ] Paths are consistent between agent body and actual file locations

---

### Phase 4: Testing — Agent Invocation Dry Run

#### Step 4.1: Frontmatter Schema Validation
**File:** All `.claude/agents/*.md`

**Test Cases:**
- [ ] Each file has `name` field matching filename (without .md)
- [ ] Each file has `description` field (non-empty string)
- [ ] Each file has `tools` field with valid tool names only
- [ ] Optional `model` field is one of: inherit, sonnet, opus, haiku
- [ ] Optional `mcpServers` field contains valid server names

#### Step 4.2: Tool Permission Matrix Validation
**File:** All `.claude/agents/*.md`

**Test Cases:**
- [ ] researcher: has WebSearch, WebFetch, Bash; no Edit
- [ ] specifier: no Edit, no Bash, no WebSearch, no WebFetch
- [ ] planner: has Bash; no Edit, no WebSearch, no WebFetch
- [ ] implementer: has Edit, Bash; no WebSearch, no WebFetch
- [ ] reviewer: no Edit, no Bash, no WebSearch, no WebFetch
- [ ] fixer: has Edit; no Bash, no WebSearch, no WebFetch

#### Step 4.3: Standalone Invocation Test (Manual)
**Description:** 各 subagent を手動で Agent ツール経由で呼び出し、正常動作を確認

**Test Cases:**
- [ ] `Agent(subagent_type="researcher", prompt="test")` が起動しプロンプトを読み込む
- [ ] `Agent(subagent_type="specifier", prompt="test")` が起動しプロンプトを読み込む
- [ ] `Agent(subagent_type="planner", prompt="test")` が起動しプロンプトを読み込む
- [ ] `Agent(subagent_type="reviewer", prompt="test")` が起動しプロンプトを読み込む

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| (none) | - | Pure markdown definitions, no external packages |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `~/.prompts/1_research.md` | Exists | researcher が Read する |
| `~/.prompts/2_spec.md` | Exists | specifier が Read する |
| `~/.prompts/3_plan.md` | Exists | planner が Read する |
| `~/.prompts/7_do.md` | Exists | implementer が Read する |
| `~/.prompts/8_review.md` | Exists | reviewer が Read する |
| `~/.prompts/templates/` | Exists | specifier, planner, reviewer が参照 |
| `.claude/settings.local.json` | Exists | MCP server 設定（modular-mcp） |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document reviewed: `docs/specs/20260407-subagent-design.md`
- [ ] All referenced prompt files exist in `~/.prompts/`
- [ ] `.claude/` directory is writable

### 5.2 Post-Implementation
- [ ] 6 agent definition files created in `.claude/agents/`
- [ ] All frontmatter schemas are valid
- [ ] Tool permission matrix matches spec Section 7
- [ ] Model assignments match spec Section 6
- [ ] No linting/formatting errors in markdown

### 5.3 Acceptance Criteria Verification
- [ ] US-001/AC-001: Each subagent defined with independent frontmatter and body
- [ ] US-001/AC-003: Each subagent body instructs Read of corresponding `.prompts/*.md`
- [ ] US-002/AC-001: reviewer tools exclude Edit/Bash
- [ ] US-002/AC-002: specifier tools exclude Bash/WebSearch
- [ ] US-002/AC-003: fixer tools exclude Bash
- [ ] US-003/AC-001: Each subagent usable via `subagent_type` parameter
- [ ] US-003/AC-002: Output paths follow existing directory structure
- [ ] US-003/AC-003: Body instructs return of file path and summary
- [ ] US-004/AC-001: Existing `/my:*` commands remain functional (no modifications)
- [ ] US-005/AC-001: fixer processes Critical/Medium issues
- [ ] US-005/AC-002: fixer ignores Low priority issues
- [ ] US-006/AC-001: Each definition has `model` field
- [ ] US-006/AC-002: `inherit` used for researcher, specifier, planner
- [ ] US-006/AC-003: Specific models set for implementer (sonnet), reviewer (opus), fixer (sonnet)

---

## 6. Rollback Plan

1. Delete `.claude/agents/` directory entirely — no other files are modified
2. Existing `/my:*` commands are unaffected (no modifications made)

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 2 read-only agent files + directory creation |
| Phase 2: Core Logic | Medium | 4 agent files with varied tool/model configs |
| Phase 3: Integration | Low | Validation and cross-reference checks |
| Phase 4: Testing | Low | Manual invocation tests |

---

## 8. Open Design Decisions

以下は spec の Open Items から引き継ぎ。実装時にデフォルト値を採用し、運用後に見直す。

| Item | Default Decision | Rationale |
|------|-----------------|-----------|
| Q1: local vs global agents | `.claude/agents/`（プロジェクトローカル） | プロジェクト固有の設定として管理 |
| Q2: reviewer model | `opus` | Spec の Section 6.5 に従う |
| Q3: fixer cycle limit | 1回（初期） | 複数回サイクルはパイプラインオーケストレーター側で制御 |
| Q4: mgrep skill injection | 対応しない（初期） | skills フィールドは Claude Code agents で未サポートの可能性 |
| Q5: MCP server specification | `mcpServers` frontmatter フィールド使用 | Claude Code agents の標準機能 |
| Q6: `/my:*` → subagent wrapper | 対応しない（初期） | 後方互換性を優先。将来の pipeline-orchestration で検討 |

---
**Created:** 2026-04-07
**Status:** Draft
**Assignee:**
