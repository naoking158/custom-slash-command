# Change Request: SDD Foundation Improvements

## Overview
- **Feature:** SDD Foundation (Spec-Driven Development Custom Slash Commands)
- **Author:** Claude
- **Date:** 2024-12-17
- **Priority:** Medium
- **Type:** Enhancement | Modification

---

## 1. Deployment Model (前提条件)

### 1.1 Symlink-based Deployment

このリポジトリは symlink を使用して `~/.claude/` 配下に配置する運用を前提とする。

**リポジトリ構造:**
```
custom-slash-command/           # GitHub リポジトリ
├── commands/                   # コマンド定義
├── prompts/                    # プロンプトロジック (リポジトリ内は prompts/)
│   └── templates/
│       └── checklists/
└── docs/                       # 出力先 (各プロジェクトで個別)
```

**Symlink 配置:**
```bash
~/.claude/
├── commands -> /path/to/custom-slash-command/commands
└── .prompts -> /path/to/custom-slash-command/prompts
```

**セットアップコマンド例:**
```bash
ln -sf /path/to/custom-slash-command/commands ~/.claude/commands
ln -sf /path/to/custom-slash-command/prompts ~/.claude/.prompts
```

### 1.2 パス参照の評価

| ファイル内パス | Symlink 経由での実際のパス | 状態 |
|---------------|---------------------------|------|
| `.prompts/templates/...` | `~/.claude/.prompts/templates/...` | ✅ 正しい |
| `docs/...` | 各プロジェクトの `docs/...` | ✅ 正しい |

**結論:** プロンプトファイル内の `.prompts/` 参照は symlink 運用を前提としており、**修正不要**。

---

## 2. Current Behavior

### Description
SDD Foundation のファイル群が sdd-plan.md、sdd-refactor-plan-v1.2.md、sdd-review-command-plan.md に基づいて作成されている。

### Location
- **Files:** `prompts/`, `commands/`, `prompts/templates/`
- **Components:** Slash Commands System

### Current Implementation Structure
```
prompts/
├── 1_research.md
├── 2_spec.md
├── 3_plan.md
├── 4_debug.md
├── 5_refactor.md
├── 6_change.md
├── 7_do.md
├── 8_review.md
└── templates/
    ├── research_template.md
    ├── spec_template.md
    ├── plan_template.md
    ├── bug_analysis_template.md
    ├── refactor_design_template.md
    ├── change_template.md
    ├── review_template.md
    └── checklists/
        ├── review_fe_checklist.md
        ├── review_be_checklist.md
        ├── review_security_checklist.md
        ├── review_perf_checklist.md
        ├── review_doc_checklist.md
        ├── review_commit_checklist.md
        └── review_pr_checklist.md

commands/
├── spec.md
├── plan.md
├── debug.md
├── refactor.md
├── change.md
├── do.md
└── review.md
```

---

## 3. Identified Issues & Improvements

### 3.1 Missing Command: `/research` [HIGH]

**現状:** 設計書では `/research` コマンドが定義されているが、`commands/research.md` が存在しない。

**影響:** 新機能フローの最初のステップが欠落。

**推奨:** `commands/research.md` を追加。

---

### 3.2 Symlink セットアップ手順の欠如 [HIGH]

**現状:** symlink を使った配置方法がドキュメント化されていない。

**影響:** 新規ユーザーがセットアップできない。

**推奨:** README.md または SETUP.md にセットアップ手順を追加。

---

### 3.3 コマンドファイルの説明 (frontmatter) 不足 [MEDIUM]

**現状:** `review.md` のみ frontmatter が設定されている。他のコマンドファイルには description がない。

**例 (`review.md:1-3`):**
```markdown
---
description: "Review artifacts (specs, plans, code) with specialized perspectives"
---
```

**影響:** Claude Code の補完で各コマンドの説明が表示されない。

**推奨:** 全コマンドファイルに frontmatter (description) を追加。

---

### 3.4 出力先ディレクトリの自動作成不足 [MEDIUM]

**現状:** プロンプトは出力先ディレクトリ (`docs/research/`, `docs/specs/` 等) が存在することを前提としているが、初回実行時にはディレクトリが存在しない。

**推奨:** 各プロンプトに「ディレクトリが存在しない場合は作成する」指示を追加。

---

### 3.5 テンプレートのプレースホルダー表記不統一 [LOW]

**現状:** `{feature}` vs `{feature_name}` vs `{id}` の表記揺れ。

**推奨:** 全テンプレートで `{feature}` に統一。

---

### 3.6 チェックリストとプロンプトの言語不統一 [LOW]

**現状:** チェックリストは日本語、プロンプトは英語。

**推奨:** 出力言語をプロジェクト設定で制御できるようにするか、統一するか検討。

---

### 3.7 `/review` コマンドの `code:{id}` ターゲット解決ロジック [LOW]

**現状:** `code:{id}` の場合の具体的なパース方法が未定義。

**推奨:** plan_template.md の「Affected Files」セクションを明示的に参照するよう指定。

---

## 4. Gap Analysis (Symlink 前提での再評価)

### What Needs to Change

| Aspect | Current | Desired | Priority | 備考 |
|--------|---------|---------|----------|------|
| `/research` コマンド | 未作成 | 作成 | High | |
| セットアップ手順 | 未作成 | README追加 | High | 新規 |
| パス参照 | `.prompts/` | `.prompts/` | - | ✅ 正しい (修正不要) |
| Frontmatter | review.md のみ | 全コマンド | Medium | |
| ディレクトリ作成 | 未指示 | 指示追加 | Medium | |
| プレースホルダー | 不統一 | 統一 | Low | |
| 言語統一 | 混在 | 検討 | Low | |

---

## 5. Impact Analysis

### Affected Components

| Component | Impact | Description |
|-----------|--------|-------------|
| `commands/` | 新規追加・修正 | research.md 追加、全ファイルに frontmatter 追加 |
| `prompts/` | 軽微な修正 | ディレクトリ作成指示追加 |
| `README.md` | 新規作成 | セットアップ手順 |
| `prompts/templates/` | 軽微な修正 | プレースホルダー統一 (オプション) |

### Dependencies
- **Upstream:** なし
- **Downstream:** symlink 経由で `~/.claude/` から参照される

### Breaking Changes
- [x] None expected (後方互換性維持)

### Risk Assessment
- **Regression Risk:** Low
- **User Impact:** Low (改善のみ、既存機能の破壊なし)

---

## 6. Summary of Recommendations

### 高優先度
1. `commands/research.md` の作成
2. README.md に symlink セットアップ手順を追加

### 中優先度
3. 全コマンドファイルに frontmatter (description) 追加
4. プロンプトに出力ディレクトリ自動作成の指示追加

### 低優先度
5. テンプレートのプレースホルダー表記統一
6. 言語統一の検討

---

## 7. References
- Design Document: `~/.claude/plans/sdd-plan.md`
- Refactor Plan: `~/.claude/plans/sdd-refactor-plan-v1.2.md`
- Review Command Plan: `~/.claude/plans/sdd-review-command-plan.md`
