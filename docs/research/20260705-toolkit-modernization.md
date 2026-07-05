# Research: Toolkit Modernization — 現状課題の分析と再設計案

- **Date:** 2026-07-05
- **Status:** Draft (design proposal)
- **Scope:** リポジトリ全体(commands / agents / prompts / rules / scripts)の構造再設計
- **Companion:** プロンプト・エージェントの**内容**(指示品質)の改善点は [20260705-prompt-content-review.md](20260705-prompt-content-review.md)。P2(skills 化)の書き起こし時に併せて反映する

---

## 1. Executive Summary

このリポジトリは 3 世代の設計方針(静的 SDD コマンド群 → prompt-optimization による DRY 化 → learn/retro 知識ループ)が積み重なった結果、**DRY 化が中途半端に終わった状態で凍結**しており、約 130 ファイルのうちかなりの割合がデッドコードまたは重複になっている。

一方、2026 年現在の Claude Code は、このリポジトリが手作りしてきた仕組みの多く(プロンプトの外部参照、コンテキスト分離、条件付きルールロード、配布)を **ネイティブ機能として提供している**:

| このリポジトリの手作り機構 | 現在のネイティブ機能 |
|---|---|
| `commands/*.md` → `~/.prompts/N_*.md` 参照の 2 層構造 | **Skills** (`SKILL.md` + 同ディレクトリの supporting files、progressive disclosure) |
| pipeline 専用の subagent によるコンテキスト分離 | Skill frontmatter の **`context: fork`** / subagent frontmatter の **`skills:` プリロード** |
| 孤立した `rules/`(言語別ルール 28 ファイル) | **`.claude/rules/` + `paths:` frontmatter** による対象ファイル連動の自動ロード |
| `install.sh` による symlink 配布 | **Plugin** (`.claude-plugin/plugin.json`、skills/agents/hooks を同梱) |
| `/my:learn` の手動起動 | **`SessionEnd` hook** による自動キャプチャ |

**提案の骨子: 「commands + prompts の 3 層構造」を「skills の 1 層構造」に畳み込み、リポジトリ全体を plugin としてパッケージし直す。** 役割定義の単一ソース化により、デッドコード 17 ファイル超を削除し、agents は skill をプリロードする薄いシェルに縮退させる。

---

## 2. 現状の課題

### 2.1 [Critical] DRY 化の未完遂 — `_shared/` の大半がデッドコード

`docs/plans/features/20241218-prompt-optimization.md` の計画は「共有コンテンツを `prompts/_shared/` に抽出し、各プロンプトから参照する」だったが、**抽出だけ行われ、参照への切り替えは phases 1–8 で実施されなかった**。

- `_shared/roles/{research,spec,plan,do,debug,refactor,change,review}.md` — **8 ファイル未参照**
- `_shared/processes/`(同 8 phase 分)— **8 ファイル未参照**(内容は `1_research.md`〜`8_review.md` にほぼ逐語で重複)
- `_shared/placeholders.md` — 未参照。しかも規定(`{{DOUBLE_BRACE}}` 必須)はリポジトリ全体で違反されている(`{id}`, `{feature}` 等の single-brace が主流)
- 参照しているのは `11_learn.md` / `12_retro.md` のみで、しかも `@import <path>` という **Claude Code に存在しない構文**を使っている(正規は bare `@path`。かつこれらのプロンプトは Read tool 経由でロードされるため import 自体が機械的に解決されない — モデルの解釈頼み)

### 2.2 [Critical] 役割定義が 3 箇所に重複

各 phase の「役割」が (1) `agents/*.md` 本文の prose、(2) numbered prompt の `<role>` タグ、(3) `_shared/roles/*.md` の 3 箇所に存在する。更新時に 3 箇所の同期が必要で、実際にレビュー出力パスのような齟齬(後述 2.5)が発生している。

### 2.3 [High] `rules/` 28 ファイル(約 4,900 行)が完全に孤立

- どの command / agent / prompt からも参照されていない
- `install.sh` は rules を `~/.claude/` に配置しない
- README の構成図にも載っていない
- 唯一の言及は `/my:retro` の重複検出 glob(昇格**先**としてのみ存在)

つまり知識ループの「昇格先」だけがあり、**昇格した知識が実行時に使われる経路がない**。現在の Claude Code には `paths:` frontmatter 付きルール(対象ファイル編集時のみ自動ロード)というまさにこの用途のネイティブ機構がある。

### 2.4 [High] `install.sh` が `~/.claude` の名前空間を専有する

`~/.claude/commands` と `~/.claude/agents` を**ディレクトリごと** symlink するため、このリポジトリ外の個人 command / agent を一切置けない。他ツールやプロジェクトとの共存性がない。Plugin 化すれば名前空間は `plugin-name:` で分離され、この問題は消滅する。

### 2.5 [Medium] 規約の不整合(同期切れの実害)

| 項目 | 不整合の内容 |
|---|---|
| レビュー出力パス | `agents/reviewer.md`、`8_review.md`、`commands/my/review.md`、`10_pipeline.md`、README で **4〜5 通りの規約**が併存(perspective サブディレクトリの有無等) |
| 言語 | command description は英語、agent description は日本語、docs は初期英語・近年日本語、英語コマンド例に日本語コメント混在 |
| `model` 指定 | agents で `sonnet`×4 / `opus`×1 / `inherit`×2、根拠のドキュメントなし |
| command→prompt 参照文言 | "Read and follow…" と "Follow…defined in" の 2 変種 |
| 共有機構 | inline 展開(phases 1–8)と `@import`(learn/retro)の 2 方式併存 |
| その他 | `10_pipeline.md:393` に対応する開きタグのない `</output>`、README 構成図から `rules/` と `docs/` が欠落 |

### 2.6 [Medium] command 本文と numbered prompt の間の重複

`do.md` の解決テーブル・エラー文言・制約は `7_do.md` にも書かれている(review も同様)。skills に移行すれば SKILL.md 1 ファイルに畳める。

### 2.7 [Low] ネイティブ機能との重複・未活用

- 単発コマンド(`/my:research` 等)は main session で inline 実行されるためコンテキストを汚染する。pipeline 経由のときだけ分離される、という非対称がある(`context: fork` で解消可能)
- `/my:learn` は完全手動。`SessionEnd` hook でセッション終了時に自動キャプチャ(または促し)ができる
- 軽量タスクにはネイティブ plan mode / Ultraplan が既にあり、SDD パイプラインとの使い分け指針がない

---

## 3. プラットフォーム前提(2026-07 時点の要点)

出典: code.claude.com/docs(skills.md / sub-agents.md / plugins.md / hooks.md / memory.md)

1. **Skills が custom slash commands の後継。** `skills/<name>/SKILL.md` + 同ディレクトリの supporting files(テンプレート、チェックリスト、スクリプト)。`/name` でユーザ起動、`description` マッチでモデル自動起動。主要 frontmatter: `description`, `disable-model-invocation`, `allowed-tools`, `model`, `effort`, **`context: fork`**(隔離 subagent で実行), `agent`(fork 時の agent type), `argument-hint`, `paths`(対象ファイル連動ロード), `hooks`。`$ARGUMENTS`, `${CLAUDE_SKILL_DIR}` 等の置換と `` !`cmd` `` による動的コンテキスト注入が使える。`commands/` も引き続き動作するが skills が推奨。
2. **Subagents の拡張。** frontmatter に `skills:`(skill 本文のプリロード)、`memory: user|project|local`(セッション横断の永続メモリ)、`permissionMode`, `maxTurns`, `hooks`, `background` 等。
3. **Plugin。** `.claude-plugin/plugin.json` + `skills/` + `agents/` + `hooks/hooks.json` + `bin/` を一括配布。marketplace 経由の versioned 配布、名前空間分離(`/plugin-name:skill`)。ローカルディレクトリからのインストールも可能なので個人開発の反復にも使える。
4. **Rules。** `.claude/rules/*.md`(ユーザスコープは `~/.claude/rules/`)に `paths:` frontmatter を付けると、マッチするファイルを扱うときだけ自動ロードされる。Skill の `paths:` でも同等のことができ、こちらは plugin に同梱可能。
5. **Hooks。** `SessionEnd`, `PreCompact`/`PostCompact`, `SubagentStop`, `TaskCompleted` 等。`type: command|prompt|agent` の 3 実行形態。
6. **ネイティブ計画機能。** plan mode(read-only 探索→計画承認)、Ultraplan、Workflows(決定的なマルチエージェント・オーケストレーション)、auto memory。

---

## 4. 再設計案(Target Architecture)

### 4.1 全体像 — Plugin 化 + Skills 一本化

```
claude-toolkit/                      # リポジトリ = plugin
├── .claude-plugin/
│   └── plugin.json                  # name: "my" (namespace /my:* を温存)
├── skills/
│   ├── research/
│   │   ├── SKILL.md                 # 旧 commands/my/research.md + prompts/1_research.md を統合
│   │   └── template.md              # 旧 prompts/templates/research_template.md
│   ├── spec/        …同型…
│   ├── plan/        …同型…
│   ├── do/          …同型…
│   ├── debug/       …同型…
│   ├── refactor/    …同型…
│   ├── change/      …同型…
│   ├── review/
│   │   ├── SKILL.md
│   │   └── checklists/              # 旧 prompts/templates/checklists/ (10 ファイル)
│   ├── pipeline/
│   │   └── SKILL.md                 # 旧 10_pipeline.md。オーケストレーションのみ
│   ├── learn/
│   │   └── SKILL.md
│   ├── retro/
│   │   ├── SKILL.md
│   │   └── scripts/redact.sh        # redact.denylist も同居
│   └── rules-{go,rails,react,typescript}/
│       ├── SKILL.md                 # paths: ["**/*.go"] 等で自動ロード制御
│       └── references/*.md          # 旧 rules/<lang>/*.md
├── agents/                          # 薄いシェル化(§4.3)
│   ├── researcher.md                # frontmatter: skills: [research] のみで本文最小化
│   └── …
├── hooks/
│   └── hooks.json                   # SessionEnd → learn 促し(§4.5)
├── scripts/
│   └── install.sh                   # 縮退: plugin 登録 + 移行チェックのみ
├── docs/                            # SDD 成果物(現状維持)
└── tests/                           # bats(現状維持 + skill 構造の lint)
```

**消えるもの:** `~/.prompts` symlink、`prompts/` ディレクトリ全体(numbered prompts、`_shared/` 24 ファイル、`templates/`)、`commands/`、`~/.claude/commands|agents` のディレクトリ専有。

### 4.2 Skill への畳み込み(単一ソース化)

各 phase につき **SKILL.md 1 ファイルが唯一の定義**になる:

- 旧 command 本文(引数処理・使用例)+ 旧 numbered prompt(`<role>`/`<process>`/`<rules>`)を統合。現状この 2 つは内容が重複しているので、統合すればむしろ短くなる
- テンプレート・チェックリストは skill ディレクトリ内に置き、`${CLAUDE_SKILL_DIR}/template.md` で参照(progressive disclosure — SKILL.md 本文には「出力は template.md の構造に従う」とだけ書く)
- `_shared/file-naming-rules.md` と `output-constraints.md` の内容は短いので各 SKILL.md に数行で inline する(3 層参照を復活させない)。`quality-standards.md` は review skill にのみ同梱
- frontmatter 例(research):

```yaml
---
description: Research and analyze requirements for new features. 調査・リサーチ。
argument-hint: "<feature description>"
context: fork          # main session を汚染しない
agent: researcher      # 実行 agent(WebSearch 等のツール構成を継承)
---
```

- **分析系(research / debug / refactor / change / review)は `context: fork`** で単発実行時もコンテキスト分離する(pipeline 経由と非対称だった問題の解消)。**do(実装)は inline のまま**(ユーザが編集の様子を見て介入できることが重要)
- モデルに勝手に起動されたくない skill(pipeline, learn, retro)には `disable-model-invocation: true`

### 4.3 Agents は「skill をプリロードする薄いシェル」に縮退

役割 prose を agent 本文に書くのをやめ、frontmatter の `skills:` で対応する skill をプリロードする:

```yaml
---
name: researcher
description: Research features and technical topics. 調査・リサーチ用。
tools: Read, Glob, Grep, Write, Bash, WebSearch, WebFetch
model: inherit
skills:
  - research
---
Follow the preloaded `research` skill. Return: output_path, summary, open questions count.
```

- これで役割定義の 3 重複が解消(SKILL.md が単一ソース、agent は tool 構成 + return format のみ)
- `model` は全 agent **`inherit` に統一**し、重い phase だけ理由コメント付きで上書き(現状の sonnet/opus/inherit 混在に根拠がないため)
- reviewer に `memory: project` を付与し、指摘の再発パターンを蓄積させる(learn/retro ループの補完)

### 4.4 Pipeline — 現行アーキテクチャ維持 + 規約統一

**file-based state passing(`docs/` を介した受け渡し、subagent にはパスのみ渡す)は現在でも正しい設計なので維持する。** 変更点:

- `10_pipeline.md` → `skills/pipeline/SKILL.md` へ移設、`disable-model-invocation: true`
- レビュー出力パスを **`docs/reviews/{type}/{id}.md`(perspective 指定時は `{id}--{perspective}.md`)に一本化**し、reviewer agent / review skill / pipeline / README の全記述を揃える
- 将来オプション: Workflows(決定的オーケストレーション)への移植。step 順序・検証・review cycle のような決定的制御フローは workflow script の方が確実だが、可搬性(全環境で利用可とは限らない)を確認してから。まずは skill 化のみ行い、workflow 版は別 issue とする

### 4.5 rules/ の配線 — skill の `paths:` で自動ロード

`rules/<lang>/*.md` → `skills/rules-<lang>/` に移設し、frontmatter で対象ファイルに連動させる:

```yaml
---
description: Go coding rules (error handling, concurrency, interfaces, testing).
paths: ["**/*.go"]
user-invocable: false
---
Rule index: read the relevant file from references/ when applicable.
- references/error-handling.md — error wrapping, sentinel errors
- references/concurrency.md — goroutine lifecycle, channels
…
```

- SKILL.md は**索引のみ**(数十行)とし、個別ルール本文は `references/` に置いて必要時に読む(progressive disclosure でコンテキスト消費を最小化)
- これで学習ループが閉じる: journal → retro → rules への昇格 → **編集時に自動適用**
- 代替案として `~/.claude/rules/` + `paths:` frontmatter への配置もあるが、plugin に同梱できる skill 方式を主案とする

### 4.6 learn/retro — hook による自動化を追加

- 現行の journal store(`~/.claude/projects/<repo>/memory/journal/`)と redact 機構は維持
- `hooks/hooks.json` に `SessionEnd` hook を追加し、セッション終了時に journal 候補のキャプチャを促す(`type: prompt` で「このセッションに記録すべき学びはあるか」を判定 → あれば learn 相当の追記)。完全自動化はノイズ増のリスクがあるため、まず「促し」から始めて調整する
- retro の toolkit repo 解決(`lib/toolkit.sh`)は、plugin 化後は plugin のインストールパスから解決できるようになるため、`~/.claude/commands` symlink 依存のロジックを書き換える

### 4.7 配布 — install.sh の縮退

- plugin として local install(開発中)/ marketplace(配布)で導入
- `install.sh` は (a) plugin 登録の wrapper、(b) 旧 symlink(`~/.prompts`, `~/.claude/commands`, `~/.claude/agents`)の検出・掃除(移行支援)、のみに縮退
- bats テストは新構造の lint(全 SKILL.md の frontmatter 検査、パス規約検査)に転用

### 4.8 規約の統一

| 項目 | 決定 |
|---|---|
| description | 英語主文 + 日本語トリガーキーワード併記(モデルの自動起動マッチ精度と日本語入力の両立)。command/agent/skill すべて同形式 |
| プレースホルダ | `{id}` 等の single-brace に統一(実態追認)。`placeholders.md` は削除 |
| 本文言語 | 指示文は英語、ユーザ向け例・エラーメッセージは日本語可、で統一 |
| ドキュメント | README を新構造で書き直し(rules・docs を構成図に含める) |

---

## 5. 移行計画

依存関係順。各 phase は独立にマージ可能。

| Phase | 内容 | 概算規模 |
|---|---|---|
| **P1: 掃除** | デッドコード削除(`_shared/roles|processes` の未参照 16 ファイル、`placeholders.md`)、`10_pipeline.md:393` の stray tag 修正、レビュー出力パス統一、言語・文言統一 | 小(削除中心・挙動不変) |
| **P2: Skills 化** | `commands/my/*.md` + `prompts/N_*.md` → `skills/*/SKILL.md` 統合。templates/checklists を skill ディレクトリへ移設。分析系に `context: fork` 付与。`~/.prompts` 依存の除去 | 大(本丸) |
| **P3: Agents 縮退** | agents を `skills:` プリロード方式に書き換え、`model: inherit` 統一、reviewer に `memory: project` | 小 |
| **P4: Plugin 化** | `.claude-plugin/plugin.json` 追加、install.sh 縮退、`lib/toolkit.sh` の解決ロジック更新、README 全面改訂 | 中 |
| **P5: rules 配線** | `rules/` → `skills/rules-*/`(索引 + references 構造へ再編) | 中 |
| **P6: hook 自動化** | `SessionEnd` hook による learn 促し、効果を見て調整 | 小 |

**P1 は無条件で実施してよい**(削除と整合性修正のみで挙動が変わらない)。P2 以降は使用感に影響するため、P2 完了時点で数日並行運用(旧 commands を残したまま skills を試す — 両方式は共存可能)してから旧構造を削除するのが安全。

## 6. リスクと未確定事項

1. **skill 名の衝突・名前空間:** plugin 名を `my` にすれば `/my:research` が温存できる想定だが、plugin 名の制約(予約語等)は P4 着手時に要確認。変わる場合は移行コストは呼び名の変更のみ
2. **`context: fork` の副作用:** fork された skill は main の会話文脈を持たない。research のように `$ARGUMENTS` だけで自己完結する phase は問題ないが、会話の流れを前提に使っていた場合は挙動が変わる。P2 で phase ごとに fork の要否を個別判断する
3. **`paths:` によるルールロードの実効性:** ルール skill が「編集時に本当に参照されるか」は references の索引の書き方に依存する。P5 で 1 言語(TypeScript)だけ先行導入して精度を確認してから残りを展開する
4. **Workflows への pipeline 移植**は環境可搬性が未確認のため本計画から除外(別 issue)
5. **既存 docs/ 成果物のパス規約**(レビューパス統一)は過去ファイルを移動しない — 新規出力のみ新規約

## 7. References

- 本リポジトリ分析: §2 の各指摘は 2026-07-05 時点の tree に基づく
- Claude Code docs: skills.md / sub-agents.md / plugins.md / hooks.md, hooks-guide.md / memory.md / permission-modes.md / workflows.md(code.claude.com/docs, 2026-07-04 更新版で確認)
- 過去の方針文書: `docs/analysis/changes/sdd-improvements.md`(symlink 配布の起源)、`docs/plans/features/20241218-prompt-optimization.md`(未完の DRY 化)、`docs/specs/20260627-session-knowledge-capture.md`(learn/retro ループ)
