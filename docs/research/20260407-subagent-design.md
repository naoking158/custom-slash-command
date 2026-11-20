# Research: Subagent Design for Command Pipeline

## 1. Overview

既存コマンド群（research, spec, plan, do, review）を支える subagent の完全設計。各コマンドが Agent ツール経由で独立したコンテキストで実行されることを前提に、必要十分な subagent セットを定義する。

**関連ドキュメント:** `docs/research/20260407-pipeline-orchestration.md`（パイプライン全体設計）

## 2. Problem Statement

現在の `/my:*` コマンドは、呼び出し元の親セッション内で直接実行される。これにより：

1. **コンテキスト汚染**: 連続実行時に前コマンドのトークンが残り、品質低下・トークン浪費が発生
2. **ツール権限の粗さ**: 全コマンドが同一権限で動作し、最小権限の原則が守られない
3. **再利用性の欠如**: コマンド間で共通の能力（レビュー、コード分析等）が重複定義される
4. **パイプライン化の前提条件**: `pipeline` コマンドを実現するには、各ステップを独立 subagent として分離する必要がある

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: 5つの主要コマンド（research, spec, plan, do, review）それぞれに対応する subagent を定義
- [x] FR-002: 各 subagent が適切なツールセットのみを持つ（最小権限の原則）
- [x] FR-003: 既存の `.prompts/*.md` プロンプトを subagent から Read して利用（DRY 原則）
- [x] FR-004: レビュー結果を反映する修正用 subagent（fixer）を定義
- [x] FR-005: 各 subagent が既存のディレクトリ構造（`docs/research/`, `docs/specs/` 等）に準拠した出力
- [x] FR-006: subagent は単独利用（既存 `/my:*` コマンドから直接）でもパイプライン利用でも動作
- [x] FR-007: gemini-grounded-search 等の MCP サーバーを必要な subagent にスコープ指定可能

### 3.2 Non-Functional Requirements

- [x] NFR-001: subagent 定義は薄いラッパーに留め、プロンプト本体の保守は `.prompts/*.md` に集約
- [x] NFR-002: 各 subagent のモデル選択を独立して設定可能（タスク特性に応じた最適化）
- [x] NFR-003: subagent 追加・変更時に既存コマンドへの影響を最小化
- [x] NFR-004: subagent 定義ファイルの命名・構造が直感的で一貫性がある

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 開発者（自分） | 各コマンドを独立コンテキストで実行し、トークン消費と品質を最適化したい | High |
| 開発者（自分） | パイプライン実行時に各ステップを subagent に委譲できるようにしたい | High |
| 開発者（自分） | subagent ごとにモデルを切り替えてコスト最適化したい | Medium |
| 開発者（自分） | 必要に応じて debug, refactor, change 用の subagent を後から追加できるようにしたい | Medium |

## 5. Technical Investigation

### 5.1 現状のコマンド体系と要件分析

各コマンドの役割、必要ツール、参照プロンプトを整理：

| Command | Role | 主な入力 | 主な出力 | 必要ツール | 参照プロンプト |
|---------|------|---------|---------|-----------|--------------|
| research | Technical Analyst | ユーザー記述（自然言語） | `docs/research/YYYYMMDD-{id}.md` | Read, Glob, Grep, Write, WebSearch, WebFetch, Bash | `1_research.md` |
| spec | Software Architect | research ドキュメント | `docs/specs/{id}.md` | Read, Glob, Grep, Write | `2_spec.md` |
| plan | Tech Lead | spec or analysis ドキュメント | `docs/plans/{type}/{id}.md` | Read, Glob, Grep, Write, Bash | `3_plan.md` |
| do | Senior Developer | plan + source ドキュメント | ソースコード変更 | Read, Glob, Grep, Write, Edit, Bash | `7_do.md` |
| review | Senior Reviewer | 任意の成果物 | `docs/reviews/{type}/{id}.md` | Read, Glob, Grep, Write | `8_review.md` |

### 5.2 Subagent 設計方針

#### A. 命名規則

```
.claude/agents/
  {role-name}.md    # kebab-case, 役割を端的に表す名前
```

#### B. プロンプト構成の原則

各 subagent の markdown body（system prompt）は以下の構成：

```markdown
---
name: {name}
description: {description for auto-delegation}
tools: {comma-separated tool list}
model: {model or inherit}
---

# Role
{1-2 sentences about the role}

## Instructions
1. Read prompt at `~/.prompts/{N}_{command}.md` and follow it exactly
2. Read template at `~/.prompts/templates/{template}.md`
3. {task-specific instructions}
4. Write output to the specified path
5. Return a brief summary
```

#### C. ツール割り当て戦略

最小権限の原則に基づき、各 subagent に必要最小限のツールを付与：

| Tool | researcher | specifier | planner | implementer | reviewer | fixer |
|------|-----------|-----------|---------|-------------|----------|-------|
| Read | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Glob | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Grep | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Write | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edit | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| Bash | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| WebSearch | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| WebFetch | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

**根拠:**
- **researcher**: 外部調査が必要（WebSearch, WebFetch）、gemini-grounded-search 実行に Bash が必要
- **specifier**: 既存 research ドキュメントの読み取りと仕様書の生成のみ。外部通信不要
- **planner**: コードベース調査に Bash（`tree`, `wc` 等）が有用。外部通信不要
- **implementer**: コード変更が主任務。Edit 必須、テスト実行に Bash 必須
- **reviewer**: 読み取りとレポート生成のみ。コード変更やコマンド実行は不要
- **fixer**: レビュー指摘の反映のみ。対象ファイルの Read と Edit/Write で完結

#### D. モデル選択戦略

| Agent | 推奨モデル | 理由 |
|-------|----------|------|
| researcher | opus or inherit | 深い分析と幅広い知識が必要 |
| specifier | inherit | 技術設計は高い推論能力が必要 |
| planner | inherit | コードベース理解とタスク分解に推論力が必要 |
| implementer | inherit | コード生成品質を最大化 |
| reviewer | sonnet | チェックリストベースの評価は構造的。sonnet で十分かつコスト削減 |
| fixer | sonnet | 指摘内容の反映は比較的単純な作業 |

**注意:** モデル選択は実運用でのチューニング項目。初期は全て `inherit` で統一し、運用データに基づいて最適化する。

### 5.3 Subagent 詳細設計

#### 1. researcher

```yaml
name: researcher
description: >
  Research and analyze requirements for new features.
  Investigates best practices, existing solutions, and produces
  comprehensive research documents.
tools: Read, Glob, Grep, Write, Bash, WebSearch, WebFetch
model: inherit
mcpServers: modular-mcp  # gemini-grounded-search 等
```

**System Prompt 要点:**
- `~/.prompts/1_research.md` の指示に従う
- 外部調査に gemini-grounded-search（MCP 経由）を活用可能
- 出力: `docs/research/YYYYMMDD-{id}.md`
- 返却: ファイルパスと要約（key findings, open questions count）

#### 2. specifier

```yaml
name: specifier
description: >
  Create detailed technical specifications from research documents.
  Designs API interfaces, data models, and system flows with
  Mermaid diagrams.
tools: Read, Glob, Grep, Write
model: inherit
```

**System Prompt 要点:**
- `~/.prompts/2_spec.md` の指示に従う
- research ドキュメントを入力として読み取り
- Mermaid 図（sequence, ER, state）を必ず含める
- 出力: `docs/specs/{id}.md`

#### 3. planner

```yaml
name: planner
description: >
  Create actionable implementation plans from specifications.
  Breaks down features into atomic, verifiable steps with
  dependency ordering and file change lists.
tools: Read, Glob, Grep, Write, Bash
model: inherit
```

**System Prompt 要点:**
- `~/.prompts/3_plan.md` の指示に従う
- コードベースの調査（Glob, Grep, Bash）を行い影響範囲を特定
- フェーズ分割: Foundation → Core Logic → Integration → Testing
- 出力: `docs/plans/{type}/{id}.md`

#### 4. implementer

```yaml
name: implementer
description: >
  Execute implementation plans precisely, writing production-ready code.
  Follows plans phase-by-phase, runs verification checks, and
  reports progress.
tools: Read, Glob, Grep, Write, Edit, Bash
model: inherit
```

**System Prompt 要点:**
- `~/.prompts/7_do.md` の指示に従う
- plan に従いフェーズごとに実行
- 各フェーズ後に lint/test 実行（Bash）
- plan にない変更を加えない
- ブロッカー発生時は明確に報告

#### 5. reviewer

```yaml
name: reviewer
description: >
  Review artifacts (specs, plans, code, commits) with perspective-specific
  checklists. Supports frontend, backend, security, performance,
  documentation, and maintainability perspectives.
tools: Read, Glob, Grep, Write
model: inherit
```

**System Prompt 要点:**
- `~/.prompts/8_review.md` の指示に従う
- perspective 指定に基づきチェックリスト（`~/.prompts/templates/checklists/`）をロード
- 評価結果: PASS / WARNING / ISSUE
- 出力: `docs/reviews/{target_type}/{perspective}/{id}.md`

#### 6. fixer

```yaml
name: fixer
description: >
  Apply review feedback to documents and code.
  Reads review reports, identifies critical and medium issues,
  and applies fixes to the target files.
tools: Read, Write, Edit
model: sonnet
```

**System Prompt 要点:**
- レビュー報告書と対象ファイルを読み取り
- Critical/Medium 優先度の指摘のみ対象
- 元のドキュメント構造・スタイルを維持
- Low 優先度は無視（過度な修正を防止）
- 修正箇所のサマリーを返却

### 5.4 拡張 Subagent（将来追加候補）

現在の5コマンドに加え、debug, refactor, change コマンド用の subagent も後から追加可能。設計方針は同一：

| Future Agent | 対応コマンド | 参照プロンプト | 優先度 |
|--------------|------------|--------------|--------|
| debugger | `/my:debug` | `4_debug.md` | Low（単独使用が多い） |
| refactorer | `/my:refactor` | `5_refactor.md` | Low（単独使用が多い） |
| change-analyzer | `/my:change` | `6_change.md` | Low（単独使用が多い） |
| gemini-executor | `/my:do-by-gemini` | `9_do_by_gemini.md` | Medium（パイプラインに統合可能） |

### 5.5 ディレクトリ構造

```
.claude/agents/
├── researcher.md       # research フェーズ
├── specifier.md        # spec フェーズ
├── planner.md          # plan フェーズ
├── implementer.md      # do フェーズ
├── reviewer.md         # review フェーズ
└── fixer.md            # review 修正フェーズ
```

### 5.6 既存コマンドとの統合方針

**方針: 既存コマンドは変更せず、subagent を追加する**

既存の `/my:research` 等のコマンドは引き続き親セッション内で直接実行される。subagent は以下のユースケースで使用：

1. **`/my:pipeline` からの呼び出し**: パイプラインオーケストレーターが Agent ツール経由で起動
2. **明示的な Agent 委譲**: ユーザーが「researcher subagent を使って調査して」と指示した場合
3. **自動委譲**: Claude Code が description に基づいて自動的に適切な subagent に委譲

将来的には `/my:research` コマンド自体を subagent 呼び出しに変更することも可能だが、初期段階では並行運用とする。

### 5.7 Constraints & Dependencies

**制約:**
1. subagent はネスト不可（subagent 内から他の subagent を起動できない）
2. subagent の system prompt 内で `@import` や `@include` は使えない → Read ツールで動的に読み込む
3. subagent 定義ファイルは `.claude/agents/` に配置が必要（プロジェクトローカル or `~/.claude/agents/` グローバル）
4. skills フィールドで skill を注入可能だが、mgrep 等のカスタム skill の互換性は要確認

**依存:**
1. Claude Code の subagent 機能（`.claude/agents/` サポート）
2. 既存の `~/.prompts/*.md` プロンプト群
3. 既存の `~/.prompts/templates/` テンプレート群
4. `modular-mcp` MCP サーバー（researcher の gemini-grounded-search 用）

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| subagent 内でのプロンプト Read 失敗 | High | Low | 絶対パス（`~/.prompts/`）使用。親セッションで事前存在チェック |
| tools フィールドの制限が不足・過剰 | Medium | Medium | 初期は最小権限で開始し、運用で調整。不足時は inherit にフォールバック |
| model 指定によるコスト増 | Medium | Low | 初期は inherit 統一。reviewer/fixer のみ sonnet 検討 |
| 既存コマンドとの競合 | Low | Low | subagent は `/my:pipeline` 経由でのみ使用。既存コマンドは変更なし |
| MCP サーバーのスコープ設定ミス | Medium | Medium | 必要な subagent（researcher）にのみ mcpServers を指定 |
| subagent 定義の配置場所の選択 | Low | Low | プロジェクトローカル `.claude/agents/` を推奨（他プロジェクトに影響しない） |

## 7. Open Questions

- [ ] Q1: subagent 定義をプロジェクトローカル（`.claude/agents/`）に置くか、グローバル（`~/.claude/agents/`）に置くか？汎用性を考えるとグローバルだが、プロジェクト固有のパスに依存する部分がある
- [ ] Q2: reviewer の model は初期から sonnet にすべきか、inherit で始めて後から最適化すべきか？
- [ ] Q3: fixer subagent の修正サイクル上限（1回 vs 最大3回）はどうするか？
- [ ] Q4: skills フィールドで mgrep skill を注入すべきか？（Grep の代替として）
- [ ] Q5: subagent 内で gemini-grounded-search を使う場合、MCP サーバー名の正確な指定方法は？
- [ ] Q6: 将来的に `/my:research` 自体を subagent 呼び出しにラップすべきか？（既存コマンドの subagent 化）

## 8. Recommendations

### 推奨アプローチ

**6つの subagent を `.claude/agents/` に作成:**

1. **researcher** — 要件調査・分析。WebSearch/WebFetch/MCP でリサーチ能力を持つ
2. **specifier** — research → spec 変換。読み取り+書き込みのみの安全設計
3. **planner** — spec → plan 変換。コードベース調査能力付き
4. **implementer** — plan → code 実行。フルツールアクセス
5. **reviewer** — 成果物レビュー。読み取り専用（Write はレポート出力のみ）
6. **fixer** — レビュー指摘反映。最小ツールセット（Read + Edit + Write）

### 設計原則

1. **DRY**: subagent body は薄いラッパー。プロンプト本体は `.prompts/*.md` を Read
2. **最小権限**: 各 subagent に必要最小限のツールのみ付与
3. **段階的最適化**: 初期は model: inherit。運用データに基づき sonnet/opus を使い分け
4. **プロジェクトローカル**: `.claude/agents/` に配置（グローバルは後で検討）

## 9. Next Steps

- [ ] Proceed to `/my:spec` phase with: `20260407-subagent-design`

---
**Created:** 2026-04-07
**Status:** Draft
