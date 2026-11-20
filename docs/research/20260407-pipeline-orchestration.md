# Research: Pipeline Orchestration for Sequential Command Execution

## 1. Overview

コマンド（`/my:research`, `/my:spec`, `/my:plan`, `/my:review` 等）を子セッションで逐次的に実行し、各ステップの出力を次のステップに引き渡すパイプラインオーケストレーション機能の調査。

**要件概要:**
- research → review → spec → review → plan → review → do のようなパイプライン実行
- 各コマンドはクリーンな子セッションで実行
- 単発実行も連続実行も可能
- 任意のステップからの開始・終了を指定可能
- レビュー付き/なしの選択が可能

## 2. Problem Statement

現在の `/my:*` コマンド群は個別に手動実行する必要があり、以下の課題がある：

1. **手動ファイル名引き渡し**: 各コマンドの出力ファイル名を手動でコピーして次のコマンドに渡す必要がある
2. **コンテキスト汚染**: 同一セッションで連続実行すると、前のコマンドのコンテキストが残り、トークン消費が増大し品質が低下する
3. **レビューサイクルの手間**: research → review → 修正 → spec → review → 修正 のループを毎回手動で回す必要がある
4. **再開困難**: パイプラインの途中で中断した場合、どこまで完了したか追跡が困難

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: パイプライン定義 — コマンドの実行順序を定義できる（research → spec → plan → do）
- [x] FR-002: 部分実行 — パイプラインの任意のステップから開始し、任意のステップで終了できる（`--from spec --to plan`）
- [x] FR-003: レビュー統合 — 各ステップにオプションでレビューを付加できる（`--review` / `--no-review`）
- [x] FR-004: 子セッション実行 — 各コマンドは独立した subagent（Agent ツール）で実行され、クリーンなコンテキストを持つ
- [x] FR-005: ファイル名自動引き渡し — 前のステップの出力ファイル名を自動的に次のステップの入力に渡す
- [x] FR-006: レビュー結果に基づく修正 — レビューで指摘された内容を自動的に反映する修正ステップ
- [x] FR-007: 進捗表示 — パイプライン全体の進捗状況を表示する
- [x] FR-008: 単発実行互換 — 既存の `/my:*` コマンドの単発実行と完全互換

### 3.2 Non-Functional Requirements

- [x] NFR-001: 各子セッションはクリーンなコンテキストで実行される（前セッションのコンテキスト汚染なし）
- [x] NFR-002: パイプライン全体の実行時間が個別実行の合計と大きく乖離しない
- [x] NFR-003: 中間成果物（research.md, spec.md 等）は既存のディレクトリ構造に準拠
- [x] NFR-004: エラー発生時に適切にハンドリングし、中間成果物は保持される
- [x] NFR-005: 既存コマンド（`/my:research`, `/my:spec` 等）の変更を最小限にする

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 開発者（自分） | research → do までの一連のフローを一発で実行したい | High |
| 開発者（自分） | レビュー付き/なしを選択してパイプラインの品質とスピードを調整したい | High |
| 開発者（自分） | 途中のステップから再開したい（spec だけやり直す等） | Medium |
| 開発者（自分） | 各ステップの成果物を確認・修正できる余地を残したい | Medium |

## 5. Technical Investigation

### 5.1 Existing Solutions / Best Practices

#### A. Claude Code Subagent（`.claude/agents/`）

Claude Code は `.claude/agents/` ディレクトリにMarkdown + YAML frontmatter でカスタム subagent を定義できる：

```markdown
---
name: researcher
description: Research and analyze requirements for new features
tools: Read, Glob, Grep, Write, Bash, WebSearch, WebFetch
model: inherit
---

You are an expert technical analyst...
(system prompt here)
```

**subagent の主要な特性:**
- 各 subagent は**独立したコンテキストウィンドウ**で実行される → コンテキスト汚染なし
- `tools` フィールドでツールアクセスを制限可能
- `model` フィールドで subagent ごとに異なるモデルを指定可能
- `skills` フィールドで skill content を注入可能
- `mcpServers` フィールドで MCP サーバーをスコープ化可能
- 親セッションの Agent ツール経由で起動し、結果が親に返却される

**重要な制約:**
- **subagent は他の subagent を起動できない**（ネスト不可）
- → パイプラインオーケストレーターは親セッションが担い、各ステップを subagent に順に委譲する

#### B. Agent ツールによるオーケストレーション

親セッション（`/my:pipeline` コマンド）が Agent ツールを使って各 subagent を順次呼び出す：

```
Parent (/my:pipeline)
  ├─ Agent(researcher) → "research this feature" → returns findings
  ├─ Agent(reviewer)   → "review the research"   → returns review
  ├─ Agent(fixer)      → "fix based on review"   → updates document
  ├─ Agent(specifier)  → "create spec from research" → returns spec
  ├─ Agent(reviewer)   → "review the spec"       → returns review
  ├─ Agent(fixer)      → "fix based on review"   → updates document
  └─ Agent(planner)    → "create plan from spec" → returns plan
```

#### C. 比較: Subagent vs `claude -p` vs Hooks

| 観点 | Subagent (Agent ツール) | `claude -p` (Bash) | Hooks |
|------|------------------------|--------------------|----|
| コンテキスト分離 | ✅ 独立ウィンドウ | ✅ 完全分離 | ❌ 共有 |
| MCP サーバー | ✅ 継承 or スコープ | △ 明示設定必要 | ✅ 継承 |
| ツール制限 | ✅ `tools` フィールド | ✅ `--allowedTools` | ❌ |
| スラッシュコマンド | ❌ 直接不可 | ❌ 直接不可 | ❌ |
| 結果の受け渡し | ✅ 自然に親に返る | △ JSON パース必要 | ❌ |
| 実装の複雑さ | ✅ シンプル | △ シェルエスケープ等 | ✗ 複雑 |
| デバッグ | ✅ Claude Code 内 | △ ログファイル | ✗ 困難 |

### 5.2 Technology Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **A: Subagent + `/my:pipeline` コマンド** | コンテキスト分離、MCP 継承、自然な結果受け渡し、Claude Code 内で完結、subagent 実装済み | subagent のネスト不可 | **推奨** |
| **B: `claude -p` + `/my:pipeline` コマンド** | 完全なセッション分離 | スラッシュコマンド不可、シェルエスケープ、MCP 設定の引き渡し | 代替案 |
| **C: Agent SDK (Python/TypeScript)** | 完全なプログラマティック制御 | 外部依存、セットアップコスト高 | 将来検討 |
| **D: Hooks ベース** | 自動トリガー | チェーン制御困難 | 非推奨 |

### 5.3 推奨アーキテクチャ: Option A — Subagent + `/my:pipeline`

```
┌────────────────────────────────────────────────────────┐
│ 親セッション: /my:pipeline                               │
│                                                         │
│  1. パイプライン定義のパース                               │
│     (--from, --to, --review/--no-review)                │
│                                                         │
│  2. ステップ実行ループ                                    │
│     ┌──────────────────────────────────────────┐        │
│     │ Agent(researcher) — 独立コンテキスト         │        │
│     │ - ~/.prompts/1_research.md を読み実行      │        │
│     │ - docs/research/YYYYMMDD-{id}.md に出力    │        │
│     │ → 親に結果サマリー返却                      │        │
│     └──────────────────────────────────────────┘        │
│                                                         │
│  3. (optional) レビュー & 修正                            │
│     ┌──────────────────────────────────────────┐        │
│     │ Agent(reviewer) — 独立コンテキスト           │        │
│     │ - 成果物を読んでレビュー                    │        │
│     │ - docs/reviews/{type}/{id}.md に出力       │        │
│     └──────────────────────────────────────────┘        │
│     ┌──────────────────────────────────────────┐        │
│     │ Agent(fixer) — 独立コンテキスト              │        │
│     │ - レビュー指摘を元のドキュメントに反映       │        │
│     └──────────────────────────────────────────┘        │
│                                                         │
│  4. 次ステップへ（identifier 引き渡し）                    │
│  5. 最終サマリー表示                                      │
└────────────────────────────────────────────────────────┘
```

### 5.4 Subagent 定義（実装済み）

subagent 定義ファイルはリポジトリの `agents/` ディレクトリに実装済み。利用時はシンボリックリンクで `~/.claude/agents/` に配置する：

```bash
# セットアップ（各ファイルを個別にシンボリックリンク）
ln -s /path/to/custom-slash-command/agents/researcher.md ~/.claude/agents/researcher.md
ln -s /path/to/custom-slash-command/agents/specifier.md  ~/.claude/agents/specifier.md
ln -s /path/to/custom-slash-command/agents/planner.md    ~/.claude/agents/planner.md
ln -s /path/to/custom-slash-command/agents/implementer.md ~/.claude/agents/implementer.md
ln -s /path/to/custom-slash-command/agents/reviewer.md   ~/.claude/agents/reviewer.md
ln -s /path/to/custom-slash-command/agents/fixer.md      ~/.claude/agents/fixer.md
```

| Agent Name | Description | 元プロンプト | 配置場所 |
|------------|-------------|------------|---------|
| `researcher` | Research and analyze requirements | `~/.prompts/1_research.md` | `agents/researcher.md` |
| `specifier` | Create detailed specs from research | `~/.prompts/2_spec.md` | `agents/specifier.md` |
| `planner` | Create implementation plans from specs | `~/.prompts/3_plan.md` | `agents/planner.md` |
| `implementer` | Execute implementation plans | `~/.prompts/7_do.md` | `agents/implementer.md` |
| `reviewer` | Review artifacts with checklists | `~/.prompts/8_review.md` | `agents/reviewer.md` |
| `fixer` | Apply review feedback to documents | (新規) | `agents/fixer.md` |

**設計方針:**
- subagent 定義はリポジトリの `agents/` ディレクトリで管理し、`~/.claude/agents/` へシンボリックリンクで配置（Git 管理可能・全プロジェクトで利用可能）
- 各 subagent の system prompt に、対応する `.prompts/*.md` の内容を **Read して実行する指示** を記述
- プロンプトの内容自体は subagent 定義に埋め込まず、実行時に Read させる（DRY 原則）

### 5.5 コマンド設計案

```bash
# フルパイプライン実行（research → plan まで、レビュー付き）
/my:pipeline "issue #444 の解決" --from research --to plan --review

# レビューなしの高速実行
/my:pipeline "新機能追加" --from research --to do --no-review

# spec から plan のみ実行（既存 research がある前提）
/my:pipeline 20260407-feature-name --from spec --to plan

# 単一ステップ実行（既存コマンドと同等）
/my:pipeline 20260407-feature-name --only research

# デフォルト：research → plan（レビューあり、do は含まない）
/my:pipeline "新しいAPIエンドポイント"
```

### 5.6 ステップ定義とデータフロー

```
Pipeline Steps (ordered):
  research  → docs/research/YYYYMMDD-{id}.md
  spec      → docs/specs/YYYYMMDD-{id}.md           (input: research output)
  plan      → docs/plans/features/YYYYMMDD-{id}.md   (input: spec output)
  do        → 実際のコード変更                          (input: plan output)

Optional Review cycle at each step:
  review    → docs/reviews/{type}/{id}.md
  fix       → 元のドキュメントを更新（Edit）

Data flow between steps:
  親セッション（/my:pipeline）が identifier を管理し、
  各 subagent 起動時に入力ファイルパスと出力ファイルパスを明示的に指示する
```

### 5.7 Subagent 起動時のプロンプト構成

親セッション（`/my:pipeline`）から各 subagent を起動する際のプロンプト例：

```
# researcher subagent へ
"Feature description: 'issue #444 の解決'
Output file: docs/research/20260407-issue-444.md
Today's date: 2026-04-07"

# reviewer subagent へ
"Review target: research:20260407-issue-444
Source file: docs/research/20260407-issue-444.md
Output file: docs/reviews/research/20260407-issue-444.md"

# fixer subagent へ
"Review file: docs/reviews/research/20260407-issue-444.md
Target file: docs/research/20260407-issue-444.md
Apply critical and medium priority feedback only."

# specifier subagent へ
"Feature name: 20260407-issue-444
Research document: docs/research/20260407-issue-444.md
Output file: docs/specs/20260407-issue-444.md"
```

### 5.8 Constraints & Dependencies

**制約:**
1. subagent は他の subagent を起動できない → パイプラインの全オーケストレーションは親セッションが担当
2. 各 subagent の system prompt に `.prompts/*.md` を Read させる間接参照方式のため、プロンプト読み込みに1ターン消費
3. 親セッション自体のコンテキストは各 subagent の結果サマリーで消費される（ただし subagent 内の詳細は含まない）
4. subagent の `tools` フィールドで MCP ツールを指定する場合、MCP サーバー名を知っている必要がある

**依存:**
1. Claude Code CLI v2.1+ がインストールされていること（subagent 機能のサポート）
2. `agents/*.md` が `~/.claude/agents/` にシンボリックリンクで配置されていること
3. 既存の `~/.prompts/*.md` ファイル群
4. 既存の `docs/` ディレクトリ構造

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| subagent のネスト不可 | Medium | Confirmed | 親セッション（`/my:pipeline`）が全オーケストレーションを担当する設計で回避 |
| subagent 内でのプロンプト読み込み失敗 | Medium | Low | `.prompts/*.md` のパスを絶対パスで指定。存在チェックを親セッション側で事前実行 |
| 親セッションのコンテキスト消費 | Medium | Medium | subagent からの返却は要約のみに制限。不要な詳細は subagent 内で完結 |
| レビュー→修正サイクルの品質 | Medium | Medium | 修正サイクルは1回をデフォルトとし、Critical/Medium のみ修正対象 |
| パイプライン途中の失敗 | High | Low | 各ステップの成果物はファイルに永続化。`--from` オプションで途中再開可能 |
| subagent 定義ファイルの保守コスト | Low | Medium | プロンプト本体は `.prompts/*.md` に維持（DRY）。subagent 定義は薄いラッパーに留める |
| 各 subagent で必要な MCP ツールの管理 | Low | Low | `mcpServers` フィールドで必要なサーバーのみスコープ化。デフォルトは親から継承 |

## 7. Open Questions

- [x] Q1: 親セッションは Agent ツール vs `claude -p` のどちらを使うべきか？ → **Agent ツール（subagent）を採用**。コンテキスト分離、MCP 継承、自然な結果受け渡しの利点が大きい
- [x] Q2: subagent 定義のプロンプトに `.prompts/*.md` の内容を埋め込むか、Read させるか？ → **Read させる**（DRY 原則。プロンプト更新時に subagent 定義の更新が不要）
- [ ] Q3: レビュー→修正サイクルの最大回数は何回が適切か？（推奨: 1回）
- [ ] Q4: `do` ステップをパイプラインに含めるべきか？（コード変更は確認後の方が安全）
- [ ] Q5: 各 subagent に `model` を個別指定すべきか？（例: reviewer は sonnet で十分、researcher は opus が望ましい等）
- [x] Q6: subagent 定義を本プロジェクト（custom-slash-command）に置くか、`~/.claude/agents/` に置くか？ → **リポジトリの `agents/` で管理し、`~/.claude/agents/` にシンボリックリンクで配置**（Git 管理可能かつ全プロジェクトで利用可能）
- [ ] Q7: `/my:pipeline` コマンドの実行前にユーザー確認（パイプライン内容のプレビュー）を挟むべきか？

## 8. Recommendations

### 推奨アプローチ: Subagent + `/my:pipeline` コマンド

1. **Subagent 定義ファイル群** をリポジトリの `agents/` に実装済み（researcher, specifier, planner, implementer, reviewer, fixer の6つ）。`~/.claude/agents/` にシンボリックリンクで配置して利用
2. **新コマンド `/my:pipeline`** を作成し、親セッションが Agent ツール経由で各 subagent を順次実行する
3. **`.prompts/*.md` を Read させる間接参照方式** を採用（DRY 原則。既存プロンプトの変更不要）
4. **identifier ベースのデータフロー** を採用し、ステップ間のファイル引き渡しを管理
5. **レビューサイクルは 1 回** をデフォルトとし、Critical/Medium のみ修正対象

### 実装優先順位

1. **Phase 1**: ~~subagent 定義ファイルの作成（6ファイル）~~ → **実装済み** (`agents/` ディレクトリ)
2. **Phase 2**: `/my:pipeline` コマンドの作成（基本パイプライン: research → spec → plan）
3. **Phase 3**: レビュー統合（各ステップ後の reviewer + fixer サイクル）
4. **Phase 4**: 高度なオプション（`--model`, `--by-gemini`, `do` ステップ統合等）

### 成果物一覧

```
agents/                          # リポジトリで管理（~/.claude/agents/ にシンボリックリンクで配置）
  researcher.md                  # research フェーズ用 subagent ✅ 実装済み
  specifier.md                   # spec フェーズ用 subagent ✅ 実装済み
  planner.md                     # plan フェーズ用 subagent ✅ 実装済み
  implementer.md                 # do フェーズ用 subagent ✅ 実装済み
  reviewer.md                    # review フェーズ用 subagent ✅ 実装済み
  fixer.md                       # review 修正フェーズ用 subagent ✅ 実装済み

commands/my/
  pipeline.md                    # /my:pipeline コマンド定義（未実装）

prompts/
  10_pipeline.md                 # pipeline オーケストレーションロジック（未実装）
```

## 9. Next Steps

- [ ] Proceed to `/my:spec` phase with: `20260407-pipeline-orchestration`

---
**Created:** 2026-04-07
**Status:** Draft
