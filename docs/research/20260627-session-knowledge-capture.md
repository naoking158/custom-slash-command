# Research: Session Knowledge Capture & Asset Self-Improvement System

> **Terminology note**: 本ドキュメントで「アセット (assets)」と呼ぶのは、本リポジトリ実在の
> `commands/` / `agents/` / `prompts/` / `rules/` を指す。Anthropic 公式の "Skill" (SKILL.md 形式)
> とは区別する。新たな `skills/` ディレクトリ導入は MVP のスコープ外 (Q4 参照)。

## 1. Overview

Claude Code の各セッション終了時に「そのセッションで得られた知見（学び・パターン・失敗）」を
外部記憶に永続化し、その蓄積をもとに本リポジトリ
(`custom-slash-command`) のアセット (`commands/` / `agents/` / `prompts/` / `rules/`) を
継続的に改善する仕組みを構築する。

ゴールは「セッションをまたいで Claude Code が賢くなり続ける」ためのループを、
本リポジトリのアセット (`commands/`, `agents/`, `prompts/`, `rules/`) と
Claude Code 公式機能 (Hooks, Auto Memory, CLAUDE.md, Skills) の上に最小コストで
重ねること。SDD パイプライン (research → spec → plan → do → review) と同じ
「明示的・ファイル駆動・レビュー可能」という哲学を踏襲する。

本研究は (a) 何をどこに保存するか、(b) いつどう捕捉するか、
(c) 蓄積した知見をどう既存アセットに反映するか、の3軸を検討する。

## 2. Problem Statement

**現状の課題:**

1. **知見が揮発する** — セッションが終わると Claude Code のコンテキストは
   破棄され、`commands/`・`agents/`・`prompts/` を改善する材料 (「なぜそれを
   修正したか」「どんな失敗をしたか」「どんなパターンが効いたか」) が
   永続化されない。
2. **CLAUDE.md / .claude/rules/ への反映が手動** — 同じ訂正を毎セッション
   入力している。Auto Memory はあるが本リポジトリのアセット改善
   (slash command の prompt 改修・新 rule の追加・skill の追加) には繋がらない。
3. **学習ループが閉じていない** — 知見 → アセット改善が「気が向いたら」になっており、
   構造化されていない。

**なぜ重要か:**

- このリポジトリ自体が「Claude Code を継続的に賢く運用するための user 配布物」
  である。自己改善ループが組み込まれていれば、本リポジトリの提供価値が
  「静的なテンプレ」から「使うほど鋭くなる開発支援基盤」に格上げされる。
- 同じ過ちを繰り返さない / 良いパターンを定着させる / 暗黙知を明示化する、
  という効果は SDD パイプラインの品質向上にも直結する。

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [ ] FR-001: **セッション終端でのキャプチャ** — Claude Code セッションの
      終端 (SessionEnd / Stop / PreCompact のいずれか) で「そのセッションの
      知見」を自動で markdown ファイルに書き出せる。
- [ ] FR-002: **構造化スキーマ** — 各知見エントリは section 8.1 で定義する
      canonical schema (YAML frontmatter: `session_id / date / project / categories /
      confidence / recurrence / status` + body sections:
      `Request / Investigated / Learned / Completed / Next Steps / Suggested Actions`)
      に従う。
- [ ] FR-003: **永続化先の二層化** — (a) raw な journal は
      machine-local の `~/.claude/projects/<repo>/memory/journal/` に蓄積し
      (canonical path: section 8.1 参照)、
      (b) 昇格 (promote) 済みの定着ルールは `rules/` または `CLAUDE.md`、
      もしくは新規 `prompts/` に手で反映する。
- [ ] FR-004: **手動キャプチャ用 slash command** — `/my:learn` (仮称) を
      用意し、セッション途中でも明示的に知見を追加できる。
- [ ] FR-005: **レトロスペクティブ用 slash command** — `/my:retro` (仮称) を
      用意し、journal を読み込んで「昇格候補」を提案する (人間が承認して
      `rules/` や `prompts/` に反映)。
- [ ] FR-006: **承認ベースの反映 (proposal-then-approval)** —
      自動でアセット (`commands/`, `prompts/`, `agents/`, `rules/`) を
      書き換えない。常に diff を提示してユーザの承認を得てから apply する。
- [ ] FR-007: **既存 SDD パイプラインに統合** — 知見の昇格は本リポジトリの
      `change` flow (analysis → plan → do) に流し込み可能。
- [ ] FR-008: **検索・参照性** — 蓄積した journal を後から検索できる
      (識別子 grep, カテゴリ tag, 日付範囲)。
- [ ] FR-009: **MEMORY.md インデックス** — Auto Memory と協調し、
      journal のサマリを `~/.claude/projects/<repo>/memory/MEMORY.md`
      もしくはリポジトリ内 `docs/journal/INDEX.md` に反映する。

### 3.2 Non-Functional Requirements

- [ ] NFR-001: **低摩擦** — 既存の `/my:*` ワークフローを邪魔しない。
      キャプチャはバックグラウンドかつ非ブロッキング (Stop hook の場合は
      block しない設定にする)。
- [ ] NFR-002: **可監査性** — すべての知見は plain markdown で人間が
      レビュー・編集・削除できる。バイナリ DB やベクトル DB は MVP では使わない。
- [ ] NFR-003: **冪等性** — 同一セッションを多重キャプチャしない (session_id を
      キーに dedupe)。
- [ ] NFR-004: **ポータビリティ** — 本リポジトリは GitHub 配布物なので、
      個人ローカルにしか存在しない情報 (`~/.claude/projects/...`) と
      リポジトリ commit 対象を明確に分ける。
- [ ] NFR-005: **段階的導入** — Hooks 未設定でも slash command だけで
      最低限の機能 (`/my:learn`, `/my:retro`) は使える。
- [ ] NFR-006: **シェルツールチェーン非依存** — Python/Node の追加依存を
      入れず、bash + `jq` 程度で動かす。

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 本人 (naoki) | セッション終端で知見を書き残す手間を最小化 | High |
| 本人 (naoki) | 同じ訂正を Claude に二度言わなくて済む | High |
| 本人 (naoki) | リポジトリのアセットを継続的に磨ける | High |
| 本リポジトリの利用者 (将来) | 個人のローカル journal をリポジトリに混入させない | High |
| Claude Code セッション (次回起動時) | 過去の学びにアクセスできる | High |
| 本リポジトリの SDD パイプライン | 知見を `change` flow に流せる | Medium |
| レビュアー (自分の将来) | journal のフォーマットが安定していて差分が読める | Medium |

## 5. Technical Investigation

### 5.1 Existing Solutions / Best Practices

**Claude Code 公式機能 (2026 時点):**

1. **Hooks (30+ lifecycle events)** — 主要候補:
   - `SessionEnd` (matcher: clear/resume/logout/prompt_input_exit/other) は
     セッション終端で必ず発火。**block 不可・side-effect 専用**。`reason` と
     `transcript_path` を受け取れるため、transcript 全体を読んで要約を書き出すには最適。
   - `Stop` は「Claude が返答を終えるたび」発火する (=ターン単位)。block 可。
     セッション単位ではなくターン単位なので注意。
   - `PreCompact` はコンテキスト圧縮直前に発火。「圧縮で失われる前にスナップショット」
     を取る用途で、長時間セッションに対して有効。
   - `SessionStart` (matcher: startup/resume/clear/compact) で
     `additionalContext` フィールドに過去 journal の TL;DR を注入できる。

2. **Auto Memory (v2.1.59+)** — `~/.claude/projects/<repo>/memory/` 配下の
   `MEMORY.md` (先頭 200 行 / 25KB が自動 inject) と topic files (オンデマンド)。
   - **長所**: Claude 自身が会話中に勝手に書く。設定不要。
   - **短所**: マシンローカル・per-repo。リポジトリには commit されない。
     `commands/` 等のアセット改修には直接繋がらない。

3. **CLAUDE.md / `.claude/rules/`** — 静的な persistent instruction。
   昇格済み rule の置き場として最適。`paths` frontmatter で scoping 可。

4. **Skills** — オンデマンド読込の手順書。再利用可能なワークフロー単位の
   知見を skill にまとめるのが Anthropic 推奨。

**Community / OSS 事例:**

| プロジェクト | 仕組み | 参考にすべき点 |
|--------------|--------|----------------|
| `claude-mem` | SessionStart/Stop/SessionEnd/PreCompact を駆使し、Stop hook で5項目 (`request/investigated/learned/completed/next_steps`) サマリを生成、Chroma に格納、SessionStart で `additionalContext` 注入 | **Stop hook で生成する5項目スキーマ**は非常に綺麗。本提案でも踏襲。 |
| `TerenceBristol/claude-improve` | `/improve` コマンドが履歴を scan し、9 種の signal (corrections / friction / capability gaps...) を検出、承認制で config 改修 | **承認制ワークフロー**と **9-signal taxonomy** が参考になる。 |
| MindStudio "learnings loop" | `learnings.md` (プロジェクト) + `~/.claude/learnings.md` (グローバル) + `/update-learnings` コマンド + 週次 consolidation | **二層 (project/global) + 週次統合**の構造が良い。MVP に近い。 |
| `self-improving-agent` skill | MEMORY.md + topic files + 5 sub-skills (Remember/Extract/Promote/Review/Status) + 「Recurrence ≥ N で PROMOTE」 | **promotion criteria の明示** (出現回数で昇格判定) が運用上有効。 |
| hookify plugin (本環境にインストール済) | `.claude/hookify.*.local.md` を Stop hook が走査して条件マッチ → メッセージ表示 / block | **markdown frontmatter で hook ルールを宣言**する DX を踏襲できる。 |

**共通する best practices:**

- 「Raw journal (生の観察)」と「Promoted rule (定着した規則)」を二層に分ける。
- 自動で書き換えない。常に proposal → review → approve → apply。
- 5項目程度の固定スキーマでサマリを書く (`request / investigated / learned / completed / next_steps`)。
- セッション開始時に過去の TL;DR を `additionalContext` 経由で注入する。
- 出現回数 (recurrence) を promotion 判定に使う。
- 全部 markdown。バイナリ DB は MVP に不要。

### 5.2 Technology Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **A1. SessionEnd hook (skeleton-only fallback)** — bash + jq だけで `session_id / date / transcript_path` を記録した skeleton ファイルを書き出す。本文 (`Learned` 等) は `/my:learn` または `/my:retro` で人が埋める。 | セッション終端で必ず発火 / block 不可で安全 / 追加 LLM コスト 0 / NFR-006 (bash+jq のみ) 完全準拠 | 本文が空のままだと journal の価値が薄い / 人手依存 | **採用 (MVP 中核)**。Q2 への暫定回答。 |
| **A2. SessionEnd hook + `claude -p` LLM 要約** — A1 に加え hook 内で `claude -p` を spawn し 5 項目スキーマで要約を生成。 | 自動で「中身のある journal」が貯まる / `claude-mem` 同等の体験 | 追加セッションコスト発生 (Constraint 5 の "last resort" に該当) / hook 実行時間が長くなる / `claude -p` 失敗時の fallback 設計が必要 | **Phase 3 以降で採用検討**。MVP では A1 を選び、Q2 / 8.4 Success Signals で必要性を再評価。 |
| B. Stop hook で turn ごとに micro-summary | こまめに記録できる / `additionalContext` で次ターンに反映可 | ターン毎なので雑音が多い / 「セッションの知見」とは粒度が異なる | 補助。要約はやらず「未解決事項のスタブ」だけ吐く程度。 |
| C. PreCompact hook で snapshot | 長時間セッションの圧縮直前に確実に走る | 全セッションで走るわけではない (compact しないと発火しない) | サブで採用 (handover.md 用)。 |
| D. `/my:learn` slash command (手動) | hook なしで成立 / 明示的に知見を選べる | 書き忘れる | **採用**。hook と併用。 |
| E. `/my:retro` slash command (レトロ) | journal → 昇格候補を提案 → `change` flow に流せる | 別途実行が必要 | **採用**。昇格の単一窓口。 |
| F. Auto Memory に全乗っかり | 設定ゼロ | リポジトリにアセット改修として落ちない / マシンローカル | 併用 (補助記憶として使う)。中核には据えない。 |
| G. 外部 SaaS (Mem0/Chroma) | スケール / セマンティック検索 | 外部依存 / NFR-006 違反 | MVP では不採用。 |

**推奨構成:**

```
[SessionEnd hook]  →  生 journal を docs/journal/ または ~/.claude/projects/<repo>/memory/journal/ に追記
       ↓
[/my:learn]        →  セッション中の手動キャプチャ (hook と同じ journal 形式で append)
       ↓
[/my:retro]        →  journal を読んで「昇格候補」を提示 → ユーザ承認
       ↓
[change flow]      →  承認された変更は /my:change → /my:do で rules/, prompts/, commands/ を更新
       ↓
[SessionStart hook] →  最新の TL;DR を additionalContext に注入し、次セッションの Claude が認識
```

### 5.3 Constraints & Dependencies

- **Constraint 1**: 本リポジトリは GitHub 配布物。
  → **Decision (binding, see 8.1)**: 個人 journal は machine-local の
  `~/.claude/projects/<repo>/memory/journal/` に置き、リポジトリ自体には
  「journal フォーマット定義」「`/my:learn`・`/my:retro` の prompt」「`docs/journal/EXAMPLE.md`」
  だけを commit する。`docs/journal/` ディレクトリそのものは作らない (out-of-repo by design)。
  この構造的分離により、秘匿情報のリポジトリ混入を「手続き的チェック」ではなく
  「設計上不可能」にする。
- **Constraint 2**: Claude Code v2.1.59+ で Auto Memory 利用可。MEMORY.md の
  先頭 200 行 / 25KB だけが auto-inject される。
- **Constraint 3**: SessionEnd は exit code に関係なく非ブロッキング。
  失敗してもセッション終了は止められない (ログ確認に注意)。
- **Constraint 4**: Stop hook は exit 2 で blocking error。誤って block すると
  「Claude が止まらない」ループに陥る → MVP では Stop は使わないか、
  使うなら exit 0 を強制する safety net を入れる。
- **Constraint 5**: hook の `transcript_path` は `.claude/projects/<repo>/<session>.jsonl`。
  jq で parse 可能だが、本リポジトリには Python/Node 依存を入れない方針。
  bash + jq でやれる範囲に抑える、または最後の手段として `claude -p` を
  spawn して LLM 要約を作る (claude-mem 方式)。
- **Dependency**: hookify plugin は既にインストール済 (`~/.claude/plugins/marketplaces/...`)
  だが、本提案は hookify を必須にはしない (hookify の Stop hook と競合しないよう、
  別ファイル名・別パスを使う)。
- **Dependency**: 既存の `/my:change` フローを活用するため、changer agent と
  pipeline orchestrator を変更しなくて済む形にする (新 slash command を追加するだけ)。

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| journal にプライバシー / 秘匿情報が混入し、コミットされてしまう | High | Medium | **(1) Structural (primary)**: Constraint 1 / 8.1 の binding decision により journal は machine-local (`~/.claude/projects/<repo>/memory/journal/`) のみに置く。リポジトリ内には journal ファイルそのものを作らない (`docs/journal/` ディレクトリ自体を作らない) ため、誤 commit が構造的に発生しない。**(2) Procedural (defense in depth)**: `/my:retro` の promotion ステップで `scripts/redact.sh` (仮) が以下の具体パターンを scan / mask する — ① API key 系 (`sk-`/`ghp_`/`AKIA` 等の prefix)、② `/Users/<name>/` 配下の絶対パスを `$HOME` に置換、③ `.env` 由来の値 (`*_TOKEN=`/`*_SECRET=`/`*_KEY=` の右辺)、④ 8 桁以上の連続英数字でユーザ定義 deny-list と一致するもの。redaction 失敗時は promotion を block。 |
| Hook が落ちてセッションが妙な挙動になる | Medium | Low | SessionEnd は block 不可なので影響軽微。Stop は MVP で使わない。すべての hook は `exit 0` を強制し stderr のみ debug log に流す。 |
| journal が肥大化して意味のないノイズで埋まる | High | High | (a) 1セッション = 1ファイル / 1 entry に上限。(b) `/my:retro` で月次 prune。(c) **Noise heuristic (MVP)**: SessionEnd hook で transcript を走査し、以下のシグナルが **いずれも 0 件**なら skeleton すら書かず skip する: ① user による correction 系メッセージ (`違う`/`そうじゃない`/`fix`/`wrong` 等のキーワード一致)、② Edit/Write tool 呼び出し、③ `git commit`/`git add` の Bash 実行、④ TodoWrite で `completed` に遷移したタスク。Phase 1 はこの 4 シグナルで開始し、Phase 3 で精度評価。MVP では本リスクを「部分的に受容」し、success signal 8.4 の Signal/Noise 比で再評価する。 |
| 自動でアセットを書き換えてしまい意図しない退行 | Critical | Low | proposal-then-approval を厳守。`/my:retro` は **diff を出すだけ**、apply は `/my:change` → `/my:do` 経由。 |
| 同じ知見が重複登録される | Medium | High | 昇格時に grep で既存 rule との dedupe。session_id を key にした冪等性。 |
| `transcript_path` の jsonl 解析が壊れる (Claude Code のバージョンアップ) | Medium | Medium | スキーマ依存箇所を 1 ファイル (`scripts/parse_transcript.sh` 仮) に集約。壊れたら hook は exit 0 で何もしない fallback。 |
| 本リポジトリ ユーザー (将来の他者) が自分の journal を誤って push | High | Low | README に明記 + `.gitignore` テンプレ + `/my:retro` 内で `git status` を確認する step。 |
| `/my:learn` を毎セッション叩き忘れる | Low | High | SessionEnd hook がフォールバックになる (両方走らせて dedupe)。 |
| Auto Memory と本仕組みが二重記録になる | Low | Medium | 役割分担を明文化 — Auto Memory = Claude が勝手に書く short-term / 本仕組み = 人がレビューする long-term improvement signal。 |

## 7. Open Questions

- [x] Q1: journal の保存先 → **Resolved: machine-local
      `~/.claude/projects/<repo>/memory/journal/` を canonical とする
      (see Constraint 1 / section 8.1)**。リポジトリには `docs/journal/EXAMPLE.md`
      のみ commit する。
- [x] Q2: SessionEnd hook と LLM 要約 → **Resolved: MVP は Option A1
      (skeleton-only, bash+jq) を採用。`claude -p` による LLM 要約 (Option A2)
      は Phase 3 以降に 8.4 Success Signals の値を踏まえて再評価する**
      (see 5.2 options A1/A2)。
- [ ] Q3: 昇格 (promotion) のトリガーは
      (a) recurrence (出現回数) 自動
      (b) 手動 (`/my:retro` のレビューで人が選ぶ)
      (c) 週次 / 月次 cron 的レトロ
      のどれを MVP に据えるか。本提案は (b) を推奨。
- [x] Q4: 改善対象のアセット → **Resolved: 既存の
      `commands/` / `agents/` / `prompts/` / `rules/` を改修対象とする**
      (タイトル・Problem Statement も「アセット」表現に統一済)。
      Anthropic 用語の "Skill" (SKILL.md 形式) の新規導入は MVP スコープ外。
      将来 `skills/` を導入する判断は Phase 4 以降で別研究として扱う。
- [ ] Q5: SessionStart hook で過去 journal の TL;DR を `additionalContext` に
      注入するか。やる場合、トークン消費とのバランスをどう取るか
      (直近 N entries / 関連カテゴリのみ / TL;DR ファイル 1 つだけ load)。
- [ ] Q6: Stop hook を使った turn 単位の "open thread" 検出
      (=次セッションに引き継ぐべき未解決事項) を MVP に入れるか、後回しか。
- [ ] Q7: PreCompact hook で handover snapshot を取る機能は MVP に入れるか。
      `claude-mem` 風の `HANDOVER-YYYY-MM-DD.md` 出力は便利だが、
      コンテキスト圧縮が頻繁でないなら priority は低い。
- [ ] Q8: 知見スキーマに含める `category` の taxonomy をどうするか
      (例: `mistake / pattern / preference / domain-knowledge / open-question`
      の 5 種から始めるなど)。
- [ ] Q9: 本仕組み自体を SDD パイプラインの artifact として扱うか
      (= research / spec / plan / do のフローで自分自身を実装するか)。
- [ ] Q10: `.gitignore` 戦略 — journal をリポジトリに入れる/入れない、
      template 配布のフォーマット、を README に明文化する範囲。

## 8. Recommendations

### 8.1 推奨アーキテクチャ (MVP)

**コンポーネント:**

1. **Journal store** (永続化先)
   - 推奨パス: `~/.claude/projects/<repo>/memory/journal/YYYY-MM-DD-{session_id}.md`
   - MEMORY.md (上記ディレクトリ直下) を Auto Memory と共有 — その INDEX に
     journal のサマリを Claude 自身が追記していく。
   - リポジトリ内には例 (`docs/journal/EXAMPLE.md`) と
     `.gitignore` テンプレを置く。

2. **Schema (markdown + YAML frontmatter)**

   ```markdown
   ---
   session_id: 7a063d83-7e6c-4c7c-a286-f4e07fea48e5
   date: 2026-06-27
   project: custom-slash-command
   categories: [mistake, preference]
   confidence: high
   recurrence: 1
   status: raw   # raw | proposed | promoted | archived
   ---

   ## Request
   <そのセッションでユーザが依頼したこと>

   ## Investigated
   <調べたこと>

   ## Learned
   <学んだこと — promotion 候補の中核>

   ## Completed
   <成果物>

   ## Next Steps / Open Threads
   <次セッションへの引継>

   ## Suggested Actions (promotion candidates)
   - target: rules/ts/ts-error-handling.md
     change: "...パターンを追記"
     rationale: "..."
   ```

3. **Hooks (`.claude/settings.json` または `~/.claude/settings.json`)**
   - `SessionEnd` → journal の skeleton を生成 (時刻・session_id・空テンプレ) し、
     `/my:learn` が呼ばれなかった場合のフォールバックにする。
   - `SessionStart` → 直近 5 entry の `## Learned` セクションを連結して
     `additionalContext` に注入。
   - `PreCompact` (任意) → 同フォルダに `HANDOVER-...md` を吐く。
   - すべて exit 0 を強制し fail-safe にする。

4. **新規 slash commands (本リポジトリにコミット)**
   - `/my:learn [メモ]` — 現在の会話から知見を抽出してテンプレ通りに journal に追記。
   - `/my:retro [--since 7d]` — journal を走査し、recurrence ≥ 2 や `category: mistake`
     を中心に「昇格候補」を一覧化。承認されたものは
     `/my:change "<候補のタイトル>"` を提案して終わる (apply はしない)。
   - 既存の `change` flow に乗ることで `docs/analysis/changes/` と
     `docs/plans/changes/` に痕跡が残り、review もできる。

5. **新規 agent (任意)**
   - `learner` (subagent) — `/my:learn` が裏で叩く。transcript を読んで
     上記スキーマで markdown を生成。tools: Read, Grep, Write。
   - `retrospector` (subagent) — `/my:retro` が裏で叩く。journal を集約し
     提案リストを返す。tools: Read, Glob, Grep, Write。

### 8.2 二層モデル (raw vs. promoted)

| 層 | 場所 | 形式 | ライフサイクル |
|----|------|------|----------------|
| Raw journal | `~/.claude/projects/<repo>/memory/journal/*.md` | per-session markdown | append-only / 月次で archive |
| MEMORY.md インデックス | `~/.claude/projects/<repo>/memory/MEMORY.md` | Auto Memory (200 行) | Claude が随時更新 |
| Promoted rule (永続) | `rules/<lang>/...md` / `CLAUDE.md` / `prompts/_shared/*.md` | リポジトリ内 markdown | `/my:retro` → `/my:change` → review → commit |

### 8.3 段階導入プラン

| Phase | スコープ | 検証ポイント |
|-------|----------|--------------|
| **MVP (Phase 1)** | `/my:learn` + journal schema + `/my:retro` (proposal のみ) | 1 週間使って 5 件 journal が溜まるか / promotion 候補が出てくるか |
| Phase 2 | SessionEnd hook で skeleton fallback / SessionStart hook で `additionalContext` 注入 | 翌セッション開始時に Claude が前回の learned に言及できるか |
| Phase 3 | `retrospector` subagent + pipeline 統合 (`/my:retro` → `/my:change` 自動連携) | 月 1 で実 commit が rules/ に入るか |
| Phase 4 (任意) | PreCompact handover / Stop hook での open-thread 検出 | 長時間セッションの quality 改善 |

### 8.4 Success Signals (measurable KPIs)

Volume-based 指標 (Phase 1 検証ポイントの「5 件 journal が溜まるか」) だけでは
「ノイズ」と「シグナル」を区別できないため、以下の value-based 指標で評価する。

| Indicator | Target (MVP) | 計測方法 |
|-----------|--------------|----------|
| **同一訂正の重複削減** — 同じ correction を Claude に複数セッションにわたって入力する頻度 | 月次で 50% 以上削減 | journal の `category: mistake` エントリを月次集計し、重複テーマを目視カウント |
| **昇格 throughput** — `/my:retro` 経由で `rules/` / `prompts/` / `commands/` に commit された件数 | 月 1 件以上 | `git log --since=1.month rules/ prompts/ commands/` の commit count |
| **Signal/Noise 比** — journal 全体に対する「promotion 候補」となったエントリの割合 | 20% 以上 (低いほど noise が多い) | `/my:retro` 出力の候補数 / 全 journal 件数 |

Phase 1 終了時にこの 3 指標を測定し、20% 未満なら noise 抑制ロジック
(下記 Risk 表 "noise" 行の heuristic) を Phase 2 に前倒しする。

### 8.5 設計原則 (本リポの哲学に整合)

- **Markdown only**: バイナリ DB ・外部 SaaS は導入しない。
- **Proposal-then-approval**: 自動 mutation 禁止。常に diff レビュー。
- **SDD パイプラインに乗せる**: 改修は `/my:change` 経由。痕跡が `docs/` に残る。
- **個人領域 (machine-local) と配布領域 (repo) を分離**: journal はローカル、
  スキーマ・コマンドプロンプトは repo。
- **Hook 故障で人が困らない**: SessionEnd を中核に据え (block 不可)、
  Stop は MVP で使わないか fail-safe を厳守。

## 9. Next Steps

- [ ] Proceed to `/my:spec` phase with:
  - identifier: `20260627-session-knowledge-capture`
  - 焦点: MVP (`/my:learn` + journal schema + `/my:retro`) の機能仕様化
- [ ] 開いている設計判断 (Q1–Q10) のうち、最低限以下を spec までに決める:
  - Q1: journal の保存先 (machine-local 推奨)
  - Q3: promotion トリガー (手動 `/my:retro` 推奨)
  - Q4: skill ターゲット (既存 `commands/`/`agents/`/`prompts/`/`rules/` を改修対象とする)
  - Q8: category taxonomy (5 種から始める)
- [ ] Phase 2 以降の hook 採用は spec の non-MVP 章に記載。

---
**Created:** 2026-06-27
**Status:** Draft
