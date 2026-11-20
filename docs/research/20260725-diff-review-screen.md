# Research: 解説つき diff レビュー画面

## 1. Overview

`/my:review` の diff 系ターゲット (`code:` / `commit:` / `pr:`) に対して、
**解説つきの単一 HTML レビュー画面**を生成し、その画面上で

- 変更の意図をグループ単位で読む
- グループごとに「確認して承認」を進める
- LLM の指摘を採用 / 却下でトリアージする
- 任意の箇所に人間のコメントを書く
- 採用した指摘＋人間コメントを 1 つの Markdown にまとめて元の作業セッションへ貼り戻す

までを完結させる機能を追加する。

設計の土台は catnose99 (@catnose99) が X で公開している実践。本人のポスト原文と
スクリーンショット 2 枚を一次情報として採取した (§6)。

## 2. Problem Statement

現状の `/my:review` は `docs/reviews/{type}/{id}.md` を書くだけで終わる。
差分が大きいときに次の 4 つが同時に起きる。

1. **読解コストが指摘の質を上回る** — md は severity 順に指摘が並ぶだけで、
   diff の文脈に貼り付いていない。「その指摘がどのコードのことか」を確認するために
   エディタと md を往復する必要があり、差分が 100 ファイル規模になると
   レビューが実質スキップされる。
2. **変更の意図が伝わらない** — `git diff` はファイル順に並ぶので、
   「rename とそれに伴う import 修正」のような 1 つの意図が複数ファイルに散り、
   レビュアーは毎回意図を再構築させられる。
3. **人間の判断が構造化されない** — 指摘の採用 / 却下や、レビュアーが気づいた
   別の懸念を記録する場所がない。`agents/fixer.md` は md の Critical/High を
   機械的に当てるだけで、人間が「これは却下」と判断する余地がない。
4. **plan ありきのレビューは忖度する** — plan と一緒に差分を渡すと、
   微妙な実装でも「plan に則っているから妥当」と結論しやすい。

## 3. Assumptions

本ドキュメントの調査中にユーザーと合意した決定事項。仕様ではこれを前提とする。

- **A1. 出力方式は自前の単一 HTML テンプレ + JSON 埋め込み**。
  `skills/review/assets/` に静的な HTML テンプレ (CSS/JS 内包) を同梱し、
  レビュー結果 JSON を埋め込んで `docs/reviews/{type}/{id}.html` を生成する。
  既存の `building-html-artifacts` スキル (社内配布のプラグイン) の engine 再利用および
  ローカルサーバ型アプリは採用しない (比較は §6.3)。
- **A2. 適用範囲は diff 系ターゲットのみ** (`code:` / `commit:` / `pr:`)。
  `spec:` / `plan:` / `prd:` / `pspec:` の doc レビューは現状の md 出力を変えない。
- **A3. 忖度対策の 2 段階レビューを仕様に入れる** (既定で有効、オプトアウトではない)。
- **A4. 対象はローカルの単独レビュー**。生成 HTML を他人と共有したり、
  コメントをサーバに保存する要件はない (状態は localStorage)。

## 4. Codebase Findings

### 4.1 Affected Areas

| Area | Files / Modules | Notes |
|------|-----------------|-------|
| review スキル本体 | `skills/review/SKILL.md` | Step 2/3 に 2 段階レビューと HTML 生成を追加。diff 系と doc 系で分岐する |
| md レポート雛形 | `skills/review/template.md` | 現状の出力形式。JSON からの生成に切り替えるか、併存させるかを仕様で決める |
| 画面テンプレ (新規) | `skills/review/assets/review-screen.html` | 静的テンプレ。JSON 埋め込み位置のマーカーを持つ |
| ビルドスクリプト (新規) | `skills/review/scripts/` | 先例は `skills/retro/scripts/redact.sh` — **skill-local scripts はすでに確立した規約** |
| reviewer agent | `agents/reviewer.md` | 戻り値契約に `screen_path` を追加。2 段階レビューのサブエージェント起動元 |
| pipeline | `skills/pipeline/SKILL.md` | 現在 review 対象は非 `do` ステップのみ。diff レビューは pipeline 外なので影響は小 |
| fixer | `agents/fixer.md` | 「review report を読む」契約。md を読み続ける前提を崩さないこと |
| テスト | `tests/` | `bats` 4 スイート (`install` / `redact` / `hooks` / `toolkit`)。新規スクリプトは同形式で追加 |

### 4.2 Existing Patterns & Reusable Components

- **skill-local assets の参照は `${CLAUDE_SKILL_DIR}`** —
  `skills/review/SKILL.md:50` が `${CLAUDE_SKILL_DIR}/checklists/`、
  `:73` が `${CLAUDE_SKILL_DIR}/template.md` を参照している。新規テンプレ／
  スクリプトも同じ書き方で参照でき、インストーラ (`scripts/install.sh` の
  単一 symlink 方式) への変更は不要。
- **skill-local scripts の先例** — `skills/retro/scripts/redact.sh` と
  `redact.denylist`。スキルに属する実行可能物はスキル配下に置く。
- **`jq` はすでにツールキットの依存** — `scripts/hooks/prompt-capture.sh`、
  `scripts/hooks/session-end.sh`、`skills/retro/SKILL.md` が使用。
  JSON 生成・整形に新規依存を持ち込まずに使える。
- **利用可能なランタイム** — bash / awk / git / `jq 1.8.2` は確定。
  `python3 3.9.6` (system) と `node v25` も手元にはあるが、
  リポジトリはこれまで両方に依存していない。**bash + awk + jq に収めれば
  依存追加ゼロ**。
- **命名規約** — 出力は `YYYYMMDD-{kebab-case-identifier}`、
  プレースホルダは単一波括弧 `{id}` (README「Design rules the repo follows」)。
- **出力先規約** — `docs/reviews/{type}/{id}.md`、
  perspective 付きは `{id}--{perspective}.md`。`{type}` は
  `specs | plans | code | commits | prs | research | changes | prd | product-specs`
  (`skills/review/SKILL.md:69-72`、未コミット差分で PdM 分が追加済み)。
- **severity は 4 段** Critical / High / Medium / Low、判定は PASS /
  NEEDS_REVISION、fixer と pipeline が動くのは Critical/High のみ
  (`skills/review/SKILL.md:16-26`)。画面のリスク表示はこの語彙を流用し、
  catnose の「要注意 / 注意 / 低リスク」を独自に増やさない。
- **forked skill は質問しない** — review は `context: fork` / `agent: reviewer`
  で、README の設計規則どおり質問せず Assumptions に記録する。画面生成も
  対話を挟めない前提で設計する必要がある。
- **リポジトリに HTML/JS 資産は現状ゼロ** (`find . -name '*.html' -o -name '*.js'`
  が空)。本機能が最初の 1 つになるので、置き場所と検証方法を仕様で明示する。

## 5. Requirements Analysis

### 5.1 Functional Requirements

- [ ] FR-001: diff 系ターゲットのレビューで、`docs/reviews/{type}/{id}.html`
      (単一自己完結ファイル) を生成する。`file://` で開ける。
- [ ] FR-002: 差分を**意図ごとの変更グループ**に分割する。ファイル横断でよい
      (例: rename + 関連 import 修正 = 1 グループ)。
- [ ] FR-003: 画面の表示順は**ファイル順ではなくリスク順**。
- [ ] FR-004: 各グループに「意図」の解説を付ける。意図がつかめない場合は
      **要改善としてマークする** (解説を捏造しない)。
- [ ] FR-005: diff 表示は hunk 単位。各 hunk に**安定した ID** を持たせ、
      指摘から参照できる。
- [ ] FR-006: **2 段階レビュー**。Pass 1 は plan を渡さないサブエージェントが
      差分のみをレビュー。Pass 2 で plan と照合。Pass 1 の指摘は Pass 2 で
      **削除せず**、「plan 上は意図的だが実装として改善を求める」注記を付けて残す。
- [ ] FR-007: グループ単位の「確認して承認」チェックと、ヘッダの承認進捗表示。
- [ ] FR-008: 指摘ごとの**トリアージ** (採用 / 却下 / 未判定)。
- [ ] FR-009: 画面上の任意の対象 (グループ / hunk / 指摘) に**人間のコメント**を付与。
- [ ] FR-010: 採用した指摘 + 人間コメントを 1 つの Markdown に組み立て、
      クリップボードへコピーできる。元の作業セッションへそのまま貼れる形式。
- [ ] FR-011: 承認 / トリアージ / コメントの状態はリロードしても復元される。
- [ ] FR-012: 既存の md レポート (`{id}.md`) は引き続き生成される
      (fixer と pipeline の入力契約を壊さない)。
- [ ] FR-013: doc 系ターゲットの挙動は不変。

### 5.2 Non-Functional Requirements

- [ ] NFR-001: **依存追加ゼロ** — bash / awk / git / jq のみ。
      Node・Python・pnpm・ネットワークを要求しない。
- [ ] NFR-002: **生成物は単一ファイル**。外部 CSS/JS/フォント/CDN を参照しない
      (`file://` で完全に動く)。
- [ ] NFR-003: **LLM が生成するのは判断だけ** — hunk の本文や行番号のような
      機械的に導けるデータを LLM に出力させない (トークン浪費と欠落の防止)。
- [ ] NFR-004: 100 ファイル / 250 hunk 規模の差分でブラウザが実用的に開ける。
- [ ] NFR-005: スクリプトは `bats` でテストできる (既存 4 スイートと同形式)。
- [ ] NFR-006: 生成 HTML はレビュー成果物であり、機密を外部送信しない
      (localStorage のみ、テレメトリなし)。

## 6. External Research

### 6.1 一次情報: catnose99 の開発フロー

出典: https://x.com/catnose99/status/2080568062563201436 (2026-07-24)

> 最近の開発の進め方
>
> ① Fableでplan作る（plans/xxx.md に配置）
> ② CodexかCCで実装
> ③ Codexで解説つきレビュー用画面を作ってもらって確認（自作のやつ）
> ④ 修正・動作確認とか
> ⑤ planの内容をそのままコミットメッセージに入れてコミット。planファイルを消す

`③` が本ドキュメントの対象。plan 駆動 (`①`) → 実装 (`②`) → **画面でレビュー**
(`③`) → 修正 (`④`) という位置づけであり、`/my:plan` → `/my:do` →
`/my:review code:` という既存フローとそのまま対応する。

### 6.2 一次情報: 実装方針とレビュールール

出典: https://x.com/catnose99/status/2080650223551156411 (2026-07-24)
(@ono_shunsuke の「これやりたいメモ」への返信 / 引用)

> 今のところ、レビュールール + 出力画面テンプレをまとめたスキルにしています
>
> 差分が大きいときに明示的に呼ぶイメージ
>
> ポイント
> ・差分を意図ごとにグループ分け
> （例: rename + 関連するimportの修正  = 1グループ）
>
> ・表示はファイル順ではなくリスク順に
>
> ・diff表示上に解説をつけてもらう。改善点・意図がつかめない場合は要改善としてマーク
>
> ・忖度対策のためにレビューを2段階に分ける
> （「このplanの実装をレビューして」だと微妙な実装でも「planに則っている」という理由でスルーしてしまいがち）
> 1回目はplanを知らないサブエージェントが差分だけレビュー
> 2回目はplanと照らし合わせてチェック。planを読まないと分からないような指摘はそのまま残す
>
> ・LLMの指摘 + 人間がレポート上でつけたコメントを最後にまとめてコピペする導線
> →元作業のセッションへそのまま投げられるように
>
> ちなみに最初はCodex App Serverでレビュー用のアプリ作ろうとしたけど、そんなことやってる場合じゃない気がしてやめた

設計上重要な点が 3 つある。

1. **形態は「スキル」** = レビュールール + 出力画面テンプレ。専用アプリではない。
   本人が App Server 実装を**明示的に断念**している。→ A1 の裏付け。
2. **呼び出しは明示的** — 「差分が大きいときに明示的に呼ぶ」。常時 ON ではない。
3. **2 段階レビューの理由が具体的** — plan を渡すと「plan に則っている」で
   スルーする。Pass 1 を plan-blind にするのは順序ではなく**情報の遮断**が本質。

### 6.2.1 返信スレッドでの本人補足

**生成物の形式 (最重要)** — https://x.com/catnose99/status/2080859838658257186 /
https://x.com/catnose99/status/2080869818987868444

> Q (@ichgoorenge): 「レビュー用画面というのはhtmlファイルなどでしょうか？それをブラウザで確認する感じでしょうか？」
>
> A (@catnose99): 「はい、htmlベースです
> それをCodexのアプリ内ブラウザで確認しています」
>
> Q: 「css も同じファイルに含めている感じでしょうか？」
>
> A: 「はい、ただそのあたりの実装はCodex任せなので、あまり自分では意識してないです」

**CSS も同梱した単一 HTML であることが一次情報で確定した**。React アプリでも
常駐サーバでもない。§6.4 の Option A は推測ではなく本人の実装と一致する。
なお「実装は Codex 任せ」と述べているので、**HTML の組み立て方自体は
本人も設計していない**。ここは本仕様で独自に詰める余地 (= テンプレ固定化) がある。

**グループ分けの粒度** — https://x.com/catnose99/status/2080643380321910797

> 「大きめの変更がどかっと来たときに便利ですね
> 差分を種類別にグループ分け & それぞれに解説や注意点を付けてもらう形になっています」

「意図ごと」(§6.2) と「種類別」(ここ) の両方の言い方をしている。**解説だけでなく
「注意点」も付ける**点が追加情報。

**この画面が存在する前提** — https://x.com/catnose99/status/2080624289859223576

> Q (@P4523677124155): 「プランをIssueとして作って、それを関連付けたPR出す形の進め方ってどう思いますか？」
>
> A (@catnose99): 「めっちゃいいと思います！
> 自分が今はあまりGitHubを開かない運用なので1番楽な形に落ち着いてますが
> チームでちゃんとやるなら自分もその方針にするかも」

つまりこの画面は **GitHub の PR 画面をほぼ使わない個人開発ワークフローの代替**
として成立している。`pr:` ターゲットで PR 画面と二重になる可能性は
設計時に意識する必要がある (§8 Q3)。

### 6.3 一次情報: 画面のスクリーンショット

**(a) 変更グループ一覧 + 詳細**
出典画像: https://pbs.twimg.com/media/HN-l_w1aUAAe4JY.jpg
(§6.1 のポストの添付, 1712×1224)

読み取れた構造:

- sticky header: `DIFF REVIEW` / タイトル「app/system URL整理の未ステージ差分レビュー」 /
  統計チップ `107 files / 268 hunks +1468 −812` / 進捗バー / `承認 0/7` / `?` ヘルプ
- セクションは連番 + ラベル形式 (`02 / 変更グループ詳細`)
- グループ一覧の各行: タイトル / 1 行要約 / タグ (`refactor` `docs`) /
  hunk 数 (`96 hunks`) / リスクバッジ (`注意` `低リスク`) / 指摘数 (`指摘 1`) /
  左端にリスク色のアクセントバー
- グループ詳細カード: リスクバッジ (`要注意`) + グループ名 +
  `意図:` の解説段落 + 右上に `☐ 確認して承認` チェックボックス
- その下に hunk: `h079  webapp/src/lib/auth.subdomain.test.ts  @@ -1,10 +1,13`、
  旧/新の 2 列行番号、`+`/`−` ガター、追加=緑 / 削除=赤の行背景、
  語単位のハイライト (`vi.mock` の一部が濃色)

`承認 0/7` はグループ数が 7 であることを示す = **承認の単位はグループ**。
hunk ID は差分全体で通し番号 (`h079`)。

**(b) フィードバック組み立て**
出典画像: https://pbs.twimg.com/media/HN_0WYGaoAAfpPD.jpg
(§6.2 のポストの添付, 1199×908)

読み取れた構造:

- セクション `05 / フィードバック組み立て`
- トリアージのカウントチップ: `採用 2` / `却下 0` / `未判定 8` / `コメント 0`
- 説明文「採用された指摘と追加コメントを、元の作業エージェントに渡す markdown にまとめます。」
- ボタン `フィードバックを生成` / `クリップボードにコピー`
- 生成される Markdown の実物 (原文):

  ```markdown
  # レビューフィードバック

  ## 依頼

  - 以下の指摘が忖度なしで妥当かどうか精査してください。妥当でないものは指摘してください
  - 対応方針に迷う点があれば、実装前に確認してください。

  ### 1. [警告] 省略可能な別フラグが context-only 処理の抜けを隠します
  - 場所: apps/web/src/app/api/[[...route]]/routes/ai-route-message-utils.ts（新L109〜）[h010]
  - 変更グループの意図: 不正な context-only リクエストを早期に拒否し、同じ判定を言語決定とメッセージ生成へ渡す。
  - 備考: plan 上は意図的な変更だが、実装として改善を求める
  - 指摘: （…本文…）
  - 改善案: isContextOnly を必須引数にし、route の受け渡しテストも追加すると意図を型で守れます。
  ```

このフォーマットは仕様上そのまま流用できる。特に

- **`## 依頼` セクションで「忖度なしで妥当かどうか精査してください」と指示する**
  (貼り戻し先のエージェントが無批判に修正を始めるのを防ぐ)
- **`場所` に hunk ID (`[h010]`) を併記**して画面とテキストを相互参照可能にする
- **`備考: plan 上は意図的な変更だが、実装として改善を求める`** =
  §6.2 の「Pass 1 の指摘をそのまま残す」の具体的な表現

の 3 点が設計に直結する。

なお `05` が最終セクションであることから、セクションは 5 つ前後
(01 一覧 / 02 詳細 / … / 05 フィードバック) と推測される。`03` `04` の中身は
**公開されていないことが確認できた** — 公開スクリーンショットはこの 2 枚のみで
(各ポストの添付画像は 1 枚ずつ、alt text なし)、`03` `04` に言及した投稿・返信も
存在しない (§8 Q1)。よって本仕様では推測に頼らず自前の要件から導出する。

### 6.3.1 スキル本体は非公開

`github.com/catnose99` の全リポジトリ (34 件) と Gist、および
GitHub コード検索 (`変更グループ詳細 フィードバック組み立て` /
`DIFF REVIEW 変更グループ`) にレビュー用スキルは存在しない。
「テンプレートを使い回しているのか」という質問
(https://x.com/eitarox/status/2080877913101279437) にも 2026-07-25 時点で
回答がない。**参照できるのは上記の 2 ポストとスクリーンショット 2 枚が全て**で、
実装は本仕様で独自に設計する必要がある。

なお 2 枚のスクリーンショットは対象リポジトリが異なる
(`webapp/src/lib/auth.subdomain.test.ts` 系 と
`apps/web/src/app/api/[[...route]]/routes/...` 系) ため、**同一スキルを複数
プロジェクトで再利用している**と考えられる (本人の明言はなく推測)。
スキル化する = プロジェクト非依存にする、という要件の裏付けになる。

### 6.3.2 初出は 2026-07-24

catnose99 のタイムライン 2026-05-18〜07-25 の 305 投稿を全文走査したが、
このレビュー画面・2 段階レビューに言及した先行ポストは存在しない。
7-24 の 2 件が初出であり、**参照可能な一次情報はこれで打ち止め**。

### 6.4 出力方式の比較

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **A. 自前の単一 HTML テンプレ + JSON 埋め込み** | 依存ゼロ / `file://` で開く / テンプレ固定なので LLM が UI を毎回書かず品質が安定 / **catnose の実装と一致 (「htmlベース」「css も同じファイル」と本人明言、§6.2.1)** | diff 描画・コメント UI・localStorage を自前実装 (初期コスト) | **採用** (A1) |
| B. `building-html-artifacts` の html-docs engine 再利用 | 💬 コメント基盤・localStorage・プロンプト生成が既製 | 対象リポジトリに `html-docs/` を scaffold (mise + pnpm install) / diff・hunk・トリアージ用ブロックは新規実装 / **他プラグインの engine-template 改変が必要** / `my` が外部プラグインに依存 | 却下 |
| C. ローカルサーバ型アプリ (difit 系) | 自由度最大 / 大規模差分の遅延ロードが可能 | 常駐プロセス / 別リポジトリ相当の実装量 / catnose 本人が同種の試み (Codex App Server) を明示的に断念 | 却下 |

B の engine (`~/.claude/plugins/.../building-html-artifacts/engine-template/`) は
`src/components/annotate-layer.tsx` `comment-pill.tsx` `comment-popover.tsx`
`prompt-dialog.tsx` `blocks/annotatable.tsx` を持ち、
「💬 コメント → localStorage → 『プロンプトを表示』で Markdown 化 → Claude Code に貼り戻す」
というループが完成している。**この UX モデルは A でも踏襲する**が、
実装は取り込まず、diff 特化の軽量版を自前で持つ。

### 6.5 先行 OSS: difit

https://github.com/yoshiko-pg/difit (★3,014 / TypeScript / MIT / 2025-06-29 作成、
旧名 ReviewIt)。ローカルに Express サーバを立て、`git diff` を GitHub の
「Files changed」風 UI (React / Vite / Tailwind / Prism) で表示する。
`npx difit` で即起動。

本ドキュメントの設計に直接関係する機能:

- 行 / 範囲コメントを付け、**「Copy Prompt」で `src/…/Button.tsx:L42-L48` 形式の
  文脈付きプロンプトを生成**する。コメントは localStorage に永続化。
  → 「コメント → プロンプト化 → エージェントに貼る」導線は
  building-html-artifacts と difit の両方が採っている**確立したパターン**。
- `--pr` で GitHub PR のインラインスレッドを取り込む。
- 生成物 / lock ファイルを自動折りたたみ。
- `npx skills add yoshiko-pg/difit` で 2 スキルを提供 —
  `difit` (実装後に人間のレビューを依頼) と
  `difit-review` (AI の指摘をコメントとしてプリロードして起動)。
  → **AI の指摘を差分上に載せる**という発想自体は difit にもある。

catnose 版との構造的な違い:

| | catnose の DIFF REVIEW | difit |
|---|---|---|
| 成果物 | 毎回生成する単一 HTML (CSS 同梱・サーバ不要) | ローカルサーバ + React SPA (常設ツール) |
| 差分の並び | **意図ごとのグループ + リスク順** | ファイル順 (GitHub 準拠) |
| 解説 | **AI が diff 上に意図 / 注意点 / リスクを埋め込む** | なし (生 diff を表示) |
| レビュー主体 | **LLM が 1 次レビュー (plan 非開示の 2 段階)** + 人間がトリアージ | 人間がコメント (AI 連携はスキル経由) |
| 出口 | 採用指摘 + 人間コメントを Markdown 化 | Copy Prompt でプロンプト化 |
| 配布 | 非公開 (本人用スキル) | OSS (MIT / ★3k) |

**difit を採用しない理由**は常駐サーバではなく、
**「意図ごとのグループ化 + リスク順 + AI の解説」という中核が difit には無い**
ことにある。差分を GitHub 風に見せる部分は difit で足りるが、本機能の価値は
そこではなく「大きな差分を意図の単位で読めるようにする」ことなので、
既存 OSS への置き換えは成立しない。

なお catnose が断念した Codex App Server は、Codex を自作 UI に埋め込むための
双方向 JSON-RPC API (https://openai.com/ja-JP/index/unlocking-the-codex-harness/)。
専用 UI を作れば difit 相当のものになる立ち位置だが、そこまでやらず
「AI に HTML を吐かせる」に落とした、というのが一連の投稿の趣旨である。

## 7. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| LLM が hunk 本文や行番号を JSON に書き出そうとしてトークンが破裂 / 欠落する | High | High | 差分本文は**スクリプトが機械的に埋め込む**。LLM は hunk ID を参照するだけ (NFR-003) |
| LLM が付ける hunk ID とスクリプトの採番がずれ、指摘が別のコードを指す | High | Medium | 採番規則を「`git diff` 出力順に `^@@` 行へ通し番号」の 1 つに固定。スクリプトが hunk マップ (TSV) を出力し、レビュアーはそれを読んでから指摘を書く。`bats` で `grep -c '^@@'` と件数一致を検証 |
| 差分本文中の `</script` で HTML が壊れる | High | Medium | ペイロードは `<script type="application/json">` 1 ブロックに集約し、`jq` で JSON 文字列化した後 `</` → `<\/` へ置換 (JSON として妥当なエスケープ) |
| Pass 2 が Pass 1 の指摘を「plan 通りだから」と削除してしまう | High | Medium | Pass 2 の入力に Pass 1 の指摘 JSON を渡し、**削除禁止・注記のみ許可**を契約として明記。件数が減っていたらエラー扱い |
| 2 段階でレビューコストが約 2 倍 | Medium | High | 明示呼び出し前提 (catnose も「差分が大きいときに明示的に呼ぶ」)。既定は 2 段階だが、差分が小さいときは Pass 1 のみで完了する条件を仕様で定める |
| 大規模差分で単一 HTML が重くなる | Medium | Medium | hunk は既定折りたたみ、グループ単位で遅延展開。生成後にファイルサイズを報告 |
| md と HTML で指摘内容が食い違う | Medium | Medium | JSON を単一ソースにし、md も同じ JSON から生成する |
| localStorage のキーが衝突し別レビューの状態を読む | Low | Low | キーに `{id}` + 差分のハッシュを含める。差分が変わったら状態を破棄 |

## 8. Open Questions

- [x] Q1: catnose の画面の `03` `04` セクションが何か。
      → **調査済み・入手不能で確定** (§6.3.1)。公開スクショは 2 枚のみ、
      スキルも非公開、言及した投稿もなし。本仕様では推測に頼らず
      `03 指摘一覧` / `04 plan 照合` を自前の要件 (FR-006/008) から導出して定義する。
- [ ] Q2: 承認状態を「レビュー済みの記録」として `docs/` にコミットしたいか、
      ブラウザローカルで消えてよいか。→ A4 より後者を既定とし、
      Markdown 書き出しを唯一の永続化経路とする。
- [ ] Q3: `pr:` ターゲットで、生成した Markdown を GitHub の PR コメントとして
      投稿する導線を持たせるか。→ 初版はスコープ外 (クリップボードのみ)。
- [ ] Q4: 差分の「リスク」判定基準を checklist に成文化するか、
      レビュアーの裁量に委ねるか。→ 既存の severity 4 段を流用し、
      グループのリスクは「そのグループに含まれる最高 severity + 影響範囲」で導出する。

## 9. Recommendations

推奨アプローチ: **「機械的なデータ」と「判断」を分離した 3 層構成**。

```
[1] 抽出 (スクリプト / 決定的)
    git diff → hunk マップ TSV (h001.. / file / @@ header) + 統計
[2] 判断 (レビュアー / 2 パス)
    Pass 1: plan-blind、差分のみ → 素の指摘
    Pass 2: 差分 + plan + Pass1 の指摘 → 変更グループ・意図解説・リスク・plan 照合
    出力: review JSON (グループ / 指摘 / hunk ID 参照のみ)
[3] 組み立て (スクリプト / 決定的)
    テンプレ HTML + 生の diff + review JSON → {id}.html
    review JSON → {id}.md (既存フォーマット)
```

この分離が効く理由:

- LLM の出力量が**差分サイズに比例しない** (判断の量にのみ比例する)。
  100 ファイルの差分でも review JSON は数十 KB で収まる。
- 画面の見た目とインタラクションが**テンプレに固定される**ので、
  レビューごとに UI 品質が揺れない。
- 各層が独立に検証できる (層 1・3 は `bats`、層 2 は出力 JSON のスキーマ検証)。

catnose の実践から取り入れる点 / 変える点:

| 取り入れる | 変える |
|-----------|--------|
| 意図ごとのグループ分け・リスク順表示・diff 上の解説・要改善マーク | リスク語彙は独自の「要注意/注意/低リスク」ではなく**既存の Critical/High/Medium/Low** に統一 |
| 2 段階レビュー (plan-blind → plan 照合、Pass 1 の指摘は残す) | Pass 1 の指摘削除禁止を**契約として機械検証** |
| 採用/却下トリアージ + 人間コメント → Markdown 組み立て → コピー | 差分本文を LLM に出力させず**スクリプトが埋め込む** (catnose 側の実装詳細は不明) |
| `## 依頼` に「忖度なしで妥当か精査」を入れる Markdown 形式・hunk ID 併記 | md レポートを JSON から生成し、HTML との食い違いを構造的に防ぐ |

## 10. Next Steps

- [ ] Proceed to `/my:spec 20260725-diff-review-screen`

---
**Size:** L
**Created:** 2026-07-25
**Status:** Draft
