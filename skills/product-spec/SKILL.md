---
name: product-spec
description: Create a functional specification (機能仕様書) from a PRD — user flows, numbered functional requirements, a systematic edge-case sweep, Given/When/Then acceptance criteria, and measurement requirements. Trigger words: product spec, 機能仕様, 仕様策定, 詳細仕様.
argument-hint: "<prd id | path>  e.g. 20260711-price-alert"
---

# Product Spec (機能仕様)

Input PRD: **$ARGUMENTS**

This is a transform skill: do **not** interview. Where the PRD is ambiguous,
decide reasonably and record the decision in 前提 (Assumptions); anything that
genuinely blocks a decision goes to 未決事項 with an owner. The spec's job is
to be implementable and testable without re-reading the PRD discussion.

## Step 0 — Config + locate the PRD

Read `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/config.md` (missing →
offer `/my:pdm-setup`, stop); resolve `{workspace}`. PRD lookup order: the
argument as a path → `{workspace}/docs/prd/*{id}*.md` → `docs/prd/*{id}*.md`
under the CWD. Missing → error naming the paths checked, suggest `/my:prd`.

## Step 1 — Extract the contract

From the PRD: the R-{n} requirement list with priorities, scope In/Out, and
成功指標. The spec must cover **every Must and Should requirement** — build
the PRD→FR mapping table (section 9 of the template) as you go, not at the
end.

## Step 2 — Design the behavior

- ユーザーフロー: main flow + alternate flows as a mermaid flowchart.
- One FR-{n} per behavior: trigger, 入力, 挙動, 出力, 状態変化. Group by
  画面/機能 when there is a UI (Figma link placeholder where design exists).
- 権限・データ: who can do what; what is stored, where, retention.

## Step 3 — Edge-case sweep (systematic)

Consider **every** category explicitly and write findings or
`N/A: <reason>` — no empty cells:

状態遷移(中断・再開・二重実行) / 権限・ロール / 並行・競合 /
空・境界・上限 / エラー・リトライ・タイムアウト / 時刻・タイムゾーン /
多言語・文字種 / 既存データ・後方互換

## Step 4 — Acceptance criteria

Given/When/Then per FR (2–5 each). Testable only — an adjective is not a
criterion ("速い" → 数値、"使いやすい" → 観測可能な行動).

## Step 5 — 計測要件

Event definitions (イベント名 / 発火条件 / プロパティ) sufficient to compute
the PRD's 成功指標 — state the mapping 指標 → イベント explicitly.

## Step 6 — Self-check + save

- Structure: `${CLAUDE_SKILL_DIR}/template.md`. Language: Japanese.
- Self-check against `${CLAUDE_SKILL_DIR}/../review/checklists/product-spec.md`;
  fix Critical/High before presenting.
- Save as `{workspace}/docs/product-specs/{same id as the PRD}.md`. If the
  file exists, ask before overwriting.

## Completion

Report: `output_path`, coverage (PRD Must/Should n/n → FR), Assumptions and
未決事項 inline, remaining Medium/Low self-check findings, next steps:
`/my:review pspec:{id}` → `/my:backlog {id}`.
