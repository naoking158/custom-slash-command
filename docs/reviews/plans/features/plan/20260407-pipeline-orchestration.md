# Review Report: 20260407-pipeline-orchestration

## Metadata
- **Target**: plan / 20260407-pipeline-orchestration
- **Content-Type**: plan
- **Perspectives**: plan, maint
- **Reviewed**: 2026-04-07
- **Input Files**: `docs/plans/features/20260407-pipeline-orchestration.md`

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| Plan Content Review | ⚠️ | 3 warnings |
| Maintainability Review | ⚠️ | 1 warning |

**Overall Assessment**: NEEDS_REVISION

---

## Detailed Findings

### [plan] Plan Content Review

#### ✅ Passed

- **Structure: Task granularity** — 4 Phase 構成（Foundation → Core Logic → Integration → Testing）で各 Step が明確な成果物を持つ
- **Structure: Dependencies** — Phase 間の依存関係が明示的（Phase 3 は Phase 1-2 の成果物に依存）
- **Structure: Implementation order** — 依存関係に整合する実装順序
- **Structure: Phase completion criteria** — 各 Step に Verification チェックリストが定義されている
- **Feasibility: Technical approach** — Step 2.1 でプロンプト構造（role, input-handling, pipeline-definition, execution-flow, subagent-prompts, progress-format, error-handling, rules）が具体的に記述されている
- **Feasibility: Integration points** — Section 4.2 で全 6 subagent と全 prompts ファイルへの依存を明示
- **Feasibility: External dependencies** — Section 4.1 で外部依存なし（pure markdown）と明記
- **Completeness: Error handling** — 3 種のエラーケース（入力ファイル不足、subagent 失敗、パラメータエラー）を網羅
- **Completeness: Test tasks** — Phase 4 に 5 つのテストステップ（認識、パラメータ解析、E2E、部分実行、レビューサイクル）
- **Completeness: Rollback strategy** — Section 6 で 2 ファイル削除のみの簡潔なロールバック手順
- **Completeness: Acceptance criteria** — Section 5.3 で spec の全 User Story（US-001〜US-006）の AC を網羅
- **Completeness: Target file paths** — Section 2.1 で作成対象ファイル 2 つを明記
- **Clarity: Step descriptions** — 各ステップが他の開発者が実装可能な具体性を持つ
- **Clarity: What/Where/How** — 各変更の対象ファイル、変更内容、方法が記述されている
- **Risk: Breaking changes** — 既存ファイルの変更なし（Section 2.2）
- **Risk: Backward compatibility** — Section 5.3 US-006 で既存コマンドの互換性を検証

#### ⚠️ Warnings

- **[W001]** Technical risks section が未記載
  - **Location**: Plan 全体（Section 4 周辺に不足）
  - **Suggestion**: subagent のコンテキストウィンドウ制限、プロンプトサイズの肥大化、subagent 間の暗黙的な出力フォーマット依存（research の出力形式が specifier の期待と一致しない場合のリスク）について、リスクと緩和策のセクションを追加する。最低限「全 subagent は既存の独立コマンドとして動作検証済みのため、リスクは低い」という根拠の記載があると良い。

- **[W002]** `do` ステップのレビューサイクル挙動が未定義
  - **Location**: `docs/plans/features/20260407-pipeline-orchestration.md`:131-137
  - **Suggestion**: `<pipeline-definition>` のレビューサイクルテーブルで reviewer の Input が `docs/{type_path}/{id}.md` だが、`do` ステップの出力は "(code changes)" でドキュメントファイルではない。`--to=do --review` 指定時に `do` ステップ後のレビューサイクルをどう扱うか（スキップ? code review として実行?）を明記すべき。提案: `do` ステップ後はレビューサイクル対象外とし、`<execution-flow>` に「review cycle は document-producing steps (research, spec, plan) にのみ適用」と明記する。

- **[W003]** `--to=plan` がデフォルトだが、`--to=do` との組み合わせで実行ステップ数と進捗表示の整合性が曖昧
  - **Location**: `docs/plans/features/20260407-pipeline-orchestration.md`:142-157
  - **Suggestion**: `<execution-flow>` の進捗表示 `[N/M]` の M（total）の算出方法を明記する。特にレビューサイクル有効時のステップ数カウント方法（review + fix を 1 ステップとしてカウント? 別々?）を定義すべき。提案: M はメインステップ（research, spec, plan, do）のみカウントし、review/fix は sub-step として別表示（現在の `progress-format` の「インデント付き表示」がこれに該当するが、M のカウント定義を明示する）。

#### ❌ Issues

(none)

---

### [maint] Maintainability Review

#### ✅ Passed

- **Naming** — パラメータ名（`--from`, `--to`, `--only`, `--review`）が直感的で一貫性がある
- **Naming** — identifier 形式 `YYYYMMDD-{kebab-case}` が既存コマンドと統一されている
- **Naming** — subagent 名が `agents/` ディレクトリのファイル名と一致
- **Consistency** — コマンド定義ファイルの構造が既存の `do.md`, `review.md` と同パターン
- **Consistency** — 出力ディレクトリ規約が既存コマンドと一致（`docs/research/`, `docs/specs/`, `docs/plans/features/`）
- **Readability** — テーブル、コードブロック、セクション分けが効果的に使用されている
- **Code Organization** — Phase 分割が論理的（Foundation → Core → Integration → Testing）

#### ⚠️ Warnings

- **[W004]** `~/.prompts` シンボリックリンクが依存関係セクションに未記載
  - **Location**: `docs/plans/features/20260407-pipeline-orchestration.md`:379-380
  - **Suggestion**: Section 4.2 Internal Dependencies に `~/.claude/commands` と `~/.claude/agents` のシンボリックリンクは記載されているが、`~/.prompts → prompts/` のシンボリックリンクが記載されていない。Step 1.1 で「`~/.prompts/10_pipeline.md` への Read 指示」と記述しつつ、Section 2.1 では `prompts/10_pipeline.md` に作成するため、このシンボリックリンク関係を明示すべき。実装者が混乱する可能性がある。

#### ❌ Issues

(none)

---

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| 🟡 Medium | `do` ステップのレビューサイクル挙動を定義する | Step 2.1 `<pipeline-definition>` / `<execution-flow>` |
| 🟡 Medium | 進捗表示の total ステップ数の算出ルールを明記する | Step 2.1 `<execution-flow>` / `<progress-format>` |
| 🟢 Low | Technical risks セクションを追加する | Section 4 の後または新規 Section |
| 🟢 Low | `~/.prompts` シンボリックリンクを Section 4.2 に追記する | Section 4.2 Internal Dependencies |

## Next Steps

Consider addressing before proceeding, or continue with:
`/my:do 20260407-pipeline-orchestration`

Warnings are non-blocking. The most impactful improvement is **W002**（`do` ステップのレビューサイクル定義）で、これを明確にしておくことで実装時の判断迷いを防げる。
