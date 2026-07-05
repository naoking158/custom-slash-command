# Implementation Plan: Toolkit Modernization

- **Date:** 2026-07-05
- **Sources:**
  - [docs/research/20260705-toolkit-modernization.md](../../research/20260705-toolkit-modernization.md)(構造再設計)
  - [docs/research/20260705-prompt-content-review.md](../../research/20260705-prompt-content-review.md)(内容品質レビュー)
- **Status:** Implemented 2026-07-05(コミット前レビュー待ち)。検証結果: bats 67/67 green、§5 の grep 検査すべてパス。未検証の残項目は「実環境での plugin 読み込み確認」(§4 step 1 の HIGH リスク 2 件 — skill `agent:` の plugin agent 参照と `skills:` プリロードの namespace 表記 — はフォールバック行で防御済みだが、`/my:research` を一度実行して挙動確認すること)

## 0. 方針

研究ドキュメントの P0〜P6 を統合して一括実行する。旧 `prompts/` への部分修正(P0/P1 単独実施)は P2 で全ファイルを書き直すと無駄になるため、**すべての修正(構造 + 内容)を新構造の書き起こしに織り込む**。旧構造(`commands/`, `prompts/`, `rules/`)は移行完了後に削除する。git 履歴が残るためロールバック可能であり、コミット前にユーザが全 diff をレビューできることを安全弁とする。

## 1. 成果物(Target Tree)

```
custom-slash-command/
├── .claude-plugin/plugin.json        # plugin manifest(namespace /my:*)
├── skills/
│   ├── research/  SKILL.md, template.md
│   ├── spec/      SKILL.md, template.md
│   ├── plan/      SKILL.md, template.md          # debug/refactor/change からも参照
│   ├── debug/     SKILL.md, template.md          # 旧 bug_analysis_template
│   ├── refactor/  SKILL.md, template.md          # 旧 refactor_design_template
│   ├── change/    SKILL.md, template.md          # 旧 change_template
│   ├── do/        SKILL.md
│   ├── review/    SKILL.md, template.md, checklists/ (10)
│   ├── pipeline/  SKILL.md
│   ├── learn/     SKILL.md
│   ├── retro/     SKILL.md, scripts/{redact.sh, redact.denylist}
│   └── rules-{go,rails,react,typescript}/ SKILL.md, references/*.md
├── agents/        researcher, specifier, planner, implementer,
│                  changer, reviewer, fixer(全て薄いシェル + skills: プリロード)
├── hooks/hooks.json                  # SessionEnd learn 促し
├── scripts/       install.sh(plugin 登録 + 旧 symlink 掃除), lib/toolkit.sh
├── tests/         bats(パス更新 + 構造 lint 追加)
├── docs/          (現状維持)
└── README.md      (全面改訂)
```

削除: `commands/`(11), `prompts/`(52), `rules/`(28 → references/ へ移動), 旧 install symlink 3 種。

## 2. 全 SKILL.md 共通仕様

- frontmatter: `description`(英語主文 + 日本語トリガー語)
  - **入口系(research / debug / change / refactor)= inline 実行**: 対話で確認質問(最大 3 問)ができる必要があるため fork しない。pipeline 経由時のみ agent で隔離
  - **変換系(spec / plan / review)= `context: fork` + `agent:`**: file-in → file-out で対話不要のため常時隔離
  - do / learn / retro = inline(do は介入性、learn はセッション文脈が必須)。pipeline / learn / retro は `disable-model-invocation: true`
- **install 方式(検証結果で確定)**: `~/.claude/skills/my` → リポジトリ root の symlink 1 本。skills-directory plugin として in-place 参照・SKILL.md は即時反映。marketplace 方式(キャッシュへコピー)は README に将来オプションとして記載のみ
- **未検証仕様への防御**: agents の `skills:` プリロードは `my:<skill>` 表記とし、本文に「プリロードされていなければ `~/.claude/skills/my/skills/<skill>/SKILL.md` を Read して従う」フォールバック行を必ず併記
- 出力規約・ファイル命名(YYYYMMDD-kebab-case)は各 SKILL.md に数行で inline(共有ファイル参照の 3 層構造を復活させない)
- プレースホルダは single-brace `{id}` に統一
- **Severity は全アセット共通の 1 スケール: Critical / High / Medium / Low。fixer と pipeline review cycle は Critical + High を処理対象とする**(内容レビュー A-1 の修正)
- confirmation format から count 系メトリクスを削除し、実質的な合格条件に置換(同 B-4)

## 3. 内容修正のマッピング(research doc の指摘 → 反映先)

| 指摘 | 反映先 skill |
|---|---|
| A-1 severity 統一 | review, pipeline + agents/fixer |
| A-2 blocker は返して終了 | do + agents/implementer |
| A-3/B-1 コードベース調査必須化 | research(Codebase Investigation step + template に Codebase Findings)、spec(整合確認 step、"single source of truth" 文言修正) |
| B-2 Web/REST 前提の条件化 | spec(プロジェクト種別判定、API/ER 図を該当時のみ)、review(checklist の汎用/Web 分離) |
| B-3 S/M/L サイジング | research/spec/plan/change 冒頭に判定 step、テンプレに「N/A: 理由」許可 |
| B-5 実動作検証 + commit 禁止 | do(最終フェーズに end-to-end 検証、commit は指示時のみ) |
| B-6 再現ファースト | debug(再現 → 失敗テスト → root cause → regression test 必須の fix plan) |
| B-7 確認質問の分岐 | research/change/debug(対話時は最大 3 問、subagent 時は Assumptions 明記) |
| B-8 diff ベース code review | review(`code:{id}` を diff 第一に) |
| B-9 checklist の severity タグ + 違反のみ報告 | review/checklists |
| C-1 MCP 依存除去 | agents 全部(mcpServers 削除) |
| C-2 metrics 削減 | agents の Return Format |
| レビュー出力パス統一 | `docs/reviews/{type}/{id}.md`、perspective 指定時 `{id}--{perspective}.md`(review, pipeline, agents/reviewer, README) |

## 4. 実行ステップ

1. **платform 仕様検証**(claude-code-guide agent): SKILL.md frontmatter 詳細、plugin.json 命名規則と namespace、ローカル install 手順、plugin agent の subagent_type 文字列、`skills:` プリロード、hooks.json スキーマ。**検証結果と食い違う設計は本 plan を修正してから進む**
2. **exemplar skills を手書き**: research(fork 分析系)、do(inline 実行系)、review(checklist 系)、pipeline(orchestration)の 4 つで規約を確立
3. **残り skill を subagent へ fan-out**: spec / plan / debug / refactor / change / learn / retro + rules-×4。exemplar と本 plan §2-3 を入力に与える
4. **agents/ 7 ファイル書き換え**(手書き、小さい)
5. **plugin.json / hooks.json / install.sh / toolkit.sh**(検証結果に依存)
6. **README 全面改訂 + tests 更新** → bats 全実行 + 構造 lint(全 SKILL.md frontmatter 検査)
7. **旧構造削除**(commands/, prompts/, rules/)→ 最終 diff サマリ報告。**コミットはユーザレビュー後**

## 5. 検証項目

- [ ] bats 全 suite green(install / journal / redact)
- [ ] 全 skill: frontmatter が検証済み仕様に準拠(lint スクリプト)
- [ ] severity 語彙が review/pipeline/fixer/debug で一致(grep 検査)
- [ ] レビュー出力パスが全記述で一致(grep 検査)
- [ ] 旧パス参照(`~/.prompts`, `.prompts/`, `commands/my/`)が残っていない(grep 検査)
- [ ] mcpServers 参照が agents に残っていない

## 6. 残リスク

- plugin ローカル運用の実挙動(コピー vs 参照)は検証エージェントの回答に依存。回答が不明瞭な場合、install.sh は「symlink による user-scope 配置(skills/agents を**個別サブディレクトリ単位**で link し、ディレクトリ専有を回避)」を暫定採用し、plugin 化は README に手順のみ記載する
- retro の toolkit repo 解決は `$CLAUDE_TOOLKIT_REPO` を第一義に格上げ(plugin 化で旧 symlink 手がかりが消えるため)
