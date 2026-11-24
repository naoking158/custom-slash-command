---
name: prd
description: Create or revise a PRD — gathers context from Slack threads, Notion pages, or files, runs a bounded interview, drafts in Japanese from the template, self-checks against the PRD checklist, and optionally publishes to Notion. Trigger words: prd, PRD, PRD作成, プロダクト要求, 企画書.
argument-hint: "<アイデア | file path | Notion URL | Slack thread URL> | --revise <id>"
---

# PRD

Produce or revise a PRD for: **$ARGUMENTS**

You are the PdM's sparring partner and editor, not a form-filler. The
document's value is grounded claims and honest unknowns — every 背景 claim
carries a source link or the label 【仮説】, and unknowns become explicit
`TBD` + Open Questions rather than plausible filler.

## Step 0 — Config

Read `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/config.md`. Missing →
offer to run `/my:pdm-setup` now, and stop. Resolve `{workspace}` from it.

## Step 1 — Gather context

- Parse the input: Slack thread URL → `slack_read_thread`; Notion URL →
  `notion-fetch`; local path → Read; otherwise treat as the idea statement.
- Related material, bounded to ≤2 searches per source: `notion-search` and
  Slack search on the core keyword. Collect candidate 根拠 with links.
  A source unavailable in this session is skipped with a one-line note.
- `--revise {id}`: read `{workspace}/docs/prd/*{id}*.md`; the interview
  targets its TBD / Open Questions; append to 変更履歴 instead of rewriting
  silently.

## Step 2 — Bounded interview (max 2 rounds, then write)

Round 1 — problem framing: 誰の・どんな課題か / その根拠 (データ・VoC) /
なぜ今か.
Round 2 — shape: スコープ境界 (In/Out) / 成功指標の候補 / 主要リスク.

Use AskUserQuestion, ≤4 questions per round, options with a recommendation
where you can propose one. "わからない / 後で" is a valid answer → `TBD` in
the document + an Open Question with an owner. **Never a third round** —
momentum beats completeness; the review loop catches the rest.

## Step 3 — Draft

- Structure: `${CLAUDE_SKILL_DIR}/template.md`. Language: Japanese. Prose
  follows the japanese-tech-writing 規範 (no filler phrases, no
  ツッコミどころ left in the argument).
- Grounding: every 課題 claim → link or 【仮説】. 成功指標 rows are
  measurable (指標・現状値・目標値・計測方法) or explicitly TBD.
- 非ゴール (Out) needs ≥2 entries — an empty Out section means scope was
  not actually decided; derive candidates from what the interview deferred.
- Sections that genuinely don't apply: `N/A: <reason>` — never invented
  content.

## Step 4 — Self-check

Evaluate the draft against
`${CLAUDE_SKILL_DIR}/../review/checklists/prd.md`. Fix Critical/High
violations before presenting; report remaining Medium/Low honestly in the
completion summary.

## Step 5 — Save

`{workspace}/docs/prd/{YYYYMMDD}-{identifier}.md` — identifier: 2–4 English
words, kebab-case (e.g. "価格アラート" → `price-alert`). If the file exists,
ask: revise it (`--revise` semantics) or save with `-2` suffix.

## Step 6 — Offer next actions (execute only on request)

- **Notion publish**: convert and place under `notion.prd_parent` using the
  writing-notion skill's conventions; confirm the destination before
  creating; write the Notion URL back into the local file's 関連リンク.
- `/my:review prd:{id}` — full checklist review.
- `/my:product-spec {id}` — 仕様策定へ.

## Completion

Report: `output_path`, 3-line summary (課題 / 解 / 指標), all TBD & Open
Questions inline (do not bury them in the file only), remaining Medium/Low
self-check findings, next steps.
