# Review: プロンプト・エージェント内容の品質改善点

- **Date:** 2026-07-05
- **Scope:** `prompts/1〜12_*.md`、`agents/*.md`、`templates/`、`checklists/` の**指示内容そのもの**の品質
- **Companion:** 構造再設計は [20260705-toolkit-modernization.md](20260705-toolkit-modernization.md)。本書の修正は skills 移行(P2)時に SKILL.md へ反映するのが効率的

---

## A. 実害のあるバグ級

### A-1. Severity 語彙が 3 系統あり、reviewer → fixer 連携が壊れている [Critical]

| 出典 | 使っている語彙 |
|---|---|
| `8_review.md:212-228` / `review_template.md:73-77` | **High** / Medium / Low |
| `agents/fixer.md`("Process only **Critical** and Medium")/ `10_pipeline.md:111-113` | **Critical** / Medium / Low |
| `4_debug.md:71-76` | Critical / High / Medium / Low(4 段階) |

reviewer は High と出力し、fixer と pipeline は Critical を探す。**blocking 指摘が「Critical が無い」として fixer にスキップされ得る**(review cycle の空振り)。さらに review には ✅/⚠️/❌ 分類と PASS/NEEDS_REVISION/FAIL 判定もあり、計 3 つの尺度が併存。

**改善:** 全アセット共通の 1 スケール(Critical / High / Medium / Low + 「fixer は Critical・High を処理」)を quality-standards として定義し、8_review / review_template / fixer / pipeline / 4_debug を揃える。

### A-2. `7_do.md` の blocker 処理が subagent 実行と矛盾 [High]

`7_do.md:125-133` は blocker 時に「Wait for resolution before proceeding」と指示するが、pipeline から implementer subagent として走る場合、subagent はユーザに聞けず**待つ = ハング相当**。`agents/implementer.md` の「Report blockers immediately」と方針も食い違う。

**改善:** 「blocker を記録し、部分的成果を保全して **blocker ステータスを返して終了**」に統一。対話実行時のみ「ユーザに確認」の分岐を明記。

### A-3. `2_spec.md` がコードベース調査を事実上禁止 [High]

`2_spec.md:12`「The research document is your single source of truth」。research 段階にコードベース調査ステップがない(A-4)ため、**既存コードを一度も見ずに仕様が書かれる**パイプラインになっている。仕様が実装現実(既存の規約・再利用可能な部品・アーキテクチャ)から遊離する。

**改善:** spec に「既存コードとの整合確認」ステップを追加し、single source of truth の文言を「要求の出典は research、実装文脈はコードベース」に修正。

## B. 内容の質を下げる構造的な癖

### B-1. Research にコードベース調査がない [High]

`1_research.md` の Step 2 は「industry best practices」「technology options」と**一般論・Web 調査のみ**。既存リポジトリのどこに接続するのか(関連モジュール、既存パターン、再利用物)が research 成果物に出てこない。

**改善:** Step「Codebase Investigation」を必須化(調査したファイルパスの引用を必須)。`research_template.md` に "Codebase Findings" セクションを追加。Web 調査は「外部知識が必要な場合」に条件化。

### B-2. Web/REST API 前提のハードコード [High]

- `2_spec.md` Step 2 が「RESTful endpoints」「OpenAPI schemas」を無条件に要求、Mermaid 3 種(sequence/ER/state)を必須指定
- `review_be_checklist.md` は Web バックエンド固有(HTTP ステータス、N+1 等)

CLI・ライブラリ・シェルスクリプト(このリポジトリ自身が好例)では無意味な指示で、モデルは無理に「API」をでっち上げるか黙って無視するかになる。

**改善:** 冒頭に「プロジェクト種別の判定」を置き、API 設計・ER 図等は「該当する場合のみ」に条件化。checklist は Web 固有項目と汎用項目を分離。

### B-3. タスクサイズによる調整機構がない [High]

すべての feature が research → spec(図 3 種)→ plan(4 フェーズ + rollback + effort 表)のフル装備を通る。実例として `docs/plans/features/20260627-session-knowledge-capture.md` は **997 行**。生成コストだけでなく、do 段階でこの plan を読み切る消費も大きい。

**改善:** 各 phase 冒頭で S/M/L 判定し、S/M ではテンプレセクションの省略を明示的に許可する(「全 template セクションを埋めよ」ではなく「該当しないセクションは『N/A: 理由』1 行」)。plan の適正サイズ目安(例: S は 100 行以内)を quality-standards に置く。

### B-4. メトリクス偏重の報告形式が量産バイアスを生む [Medium]

confirmation-format が「User stories: {count}」「API endpoints: {count}」「Key findings: {1-3 bullets}」のような**数の報告**を要求。数が多いほど良い、という暗黙の圧になる一方、中身の合格基準は「comprehensive」「best practices」と曖昧。

**改善:** count 系の報告を削り、substantive な必須条件へ差し替える:
- research: 「調査した実ファイル・URL を引用していること」
- plan: 「全 step に**実行可能な検証コマンド**があること」(現状の "Check 1" プレースホルダは形骸化しやすい)
- spec: 「AC が観測可能な振る舞いで書かれていること」

### B-5. `7_do.md` の検証が自己申告で終わる [High]

final-format はチェックリスト申告のみで、**実際に動かして確認する**(アプリ起動、コマンド実行、変更したフローを end-to-end で通す)指示がない。テスト実行はあるが、テストが薄いリポジトリでは素通りする。

また `7_do.md:98`「Commit logical units of work」— **ユーザの明示指示なしに commit するのがデフォルト**になっており危険。なお lines 97 と 101 で「Write tests…」が重複。

**改善:** (1) 最終フェーズに「変更した機能を実際に動かして観測する」検証を必須化。(2) commit は「指示された場合のみ」に変更。(3) 重複行の整理。

### B-6. `4_debug.md` に「再現してから直す」規律がない [High]

Step 1 は再現手順の**文書化**のみで、実際に再現する(失敗するテスト/コマンドをまず走らせる)指示がない。再現しないまま root cause を「推定」して fix plan まで自動生成するため、**間違った原因に対する修正計画**が量産されるリスクがある。

**改善:** 「再現を試みる → 再現できたら失敗するテストを先に書く → root cause → fix plan(regression test 必須)」の順序を強制。再現できない場合はその旨を analysis に明記し、fix plan は仮説ラベル付きにする。

### B-7. 曖昧さの解消フローがない [Medium]

`1_research.md` Step 1「Note ambiguities requiring clarification」— 記録するだけで**ユーザに聞かずに突き進む**。方向を誤ったまま 4 phase 分の成果物が生成されてから発覚するのが最悪パターン。

**改善:** 対話実行時は着手前に確認質問(2〜3 個まで)を許可。subagent / pipeline 実行時は質問せず「仮定を Assumptions セクションに明記」と分岐させる。

### B-8. `code:{id}` レビューが差分レビューになっていない [Medium]

`8_review.md` の `code:{id}` は「plan に載っているファイル(現在の全内容)」を対象にするため、変更と無関係な既存コードまで審査対象になり焦点がぼける。`commit:`/`pr:` は差分ベースで正しい。

**改善:** `code:{id}` も「base branch との diff(または plan 実行後の変更ファイルの diff)」を第一対象とし、全文レビューはオプションにする。

### B-9. Checklist が教科書的で severity に接続していない [Medium]

checklist 項目(例: `review_be_checklist.md`「RESTful 原則準拠」)は汎用論で、**どの項目違反がどの severity か**の対応がない(reviewer の裁量任せ → A-1 の不整合を増幅)。また全項目に PASS/WARN/ISSUE を付ける方式は項目数 × 判定でトークンを浪費する。

**改善:** 各 checklist 項目に重大度タグを付け、レポートは「違反項目のみ列挙 + passed は件数のみ」に変更。PASS/NEEDS_REVISION の閾値(「warnings 0-2 は PASS」)は warning の重大度を無視しており、「Critical/High が 0 なら PASS」のように severity ベースへ。

## C. Agents の内容

### C-1. 環境固有の MCP 依存がハードコード [High]

全 agent に `mcpServers: modular-mcp`、researcher に `gemini-grounded-search`、`1_research.md` にも `<mcp-servers>` 推奨記述。**他マシン・他人の環境では存在しない**依存が共有アセットに埋まっている(フォールバック記述があるのは researcher のみ)。

**改善:** mcpServers 指定を削除するか、README に「optional: 存在すれば使われる」と明記した上で全 agent にフォールバック文を統一。

### C-2. Return Format の metrics を誰も消費していない [Low]

各 agent が返す `metrics`(open questions count, task count 等)は pipeline では使われない(summary と output_path のみ)。生成・維持コストだけがある。

**改善:** `output_path` + `summary` + (implementer のみ `test_results` / `blockers`)に絞る。

### C-3. `model: opus` 固定(reviewer)の根拠がない [Low]

構造編(§2.5)で指摘済みの `model` 混在に加え、reviewer だけ opus 固定はコスト根拠がない。`inherit` に統一し、上書きするなら理由コメントを付ける。

## D. 維持すべき良い設計(変更しないこと)

- **file-based handoff**(パスのみ渡す)と pipeline の resume 誘導付きエラー処理
- エラーメッセージに復旧コマンドを併記するパターン(`7_do.md` の error-no-plan 等)
- `6_change.md` の decision-guide(コマンド使い分け表)— 他 phase にも横展開したいくらい良い
- `fixer` のスコープ制約(「曖昧な指摘はスキップして報告」「指摘範囲外の変更禁止」)
- `5_refactor.md` の safety-checklist / stop conditions
- `plan_template.md` の AC 逆引き検証(§5.3)

## E. 反映方法

これらは**ファイル単位で独立に直せる**が、構造再設計(P2: skills 化)で全ファイルを書き直すため、二度手間を避けるなら:

1. **A-1, A-2(バグ級)だけ現構造で即修正**(語彙統一と blocker 処理は数行の変更)
2. B・C 群は **P2 の SKILL.md 書き起こし時の要求仕様**としてこのドキュメントを入力に使う
3. checklist 再編(B-9)は review skill 移行時にまとめて実施
