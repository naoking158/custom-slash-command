---
name: backlog
description: Decompose a PRD or product spec into backlog tickets (epics → INVEST stories with Given/When/Then acceptance criteria and S/M/L estimates), review them as a table, and file approved ones to the configured destination (Notion DB / GitHub Issues). quick mode drafts a single ticket from a sentence or Slack thread. Trigger words: backlog, 起票, チケット, バックログ.
argument-hint: "<spec/prd id | path> | quick <一言 | Slack thread URL>"
---

# Backlog

Input: **$ARGUMENTS**

Filing tickets is outward-facing: **nothing is created before the user
approves the exact drafts shown.** Drafts are always saved locally first as
an audit trail.

## Step 0 — Config

Read `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/config.md` (missing →
offer `/my:pdm-setup`, stop). Resolve `{workspace}` and
`backlog.destination` (`notion` / `github` / `draft-only`).

## Mode A — Decompose (default)

### 1. Locate the source
Prefer the product spec (`{workspace}/docs/product-specs/*{id}*.md`), fall
back to the PRD. Read it fully.

### 2. Decompose
- **Epic** = one PRD goal / feature group.
- **Story** = INVEST: a vertical slice a developer could start tomorrow,
  ideally ≤1 sprint. Each ticket:
  - **タイトル** — 成果が分かる動詞句 (「〜できるようにする」「〜を防ぐ」)
  - **背景/価値** — 1–3 lines + link to the source FR/AC
  - **受け入れ基準** — Given/When/Then, 2–5 items, taken from the spec's AC
  - **見積** — S (≤半日) / M (2–3日) / L (分割候補 — attach a split proposal)
  - **依存** / **ラベル案**
- Ticket format: `${CLAUDE_SKILL_DIR}/template.md`. Language: Japanese.

### 3. Review gate (mandatory)
Present ① a summary table (ID / タイトル / 見積 / 依存 / epic) and ② the
full drafts. Then AskUserQuestion: file all / select which / edit first /
save drafts only. Apply edits and re-show changed tickets before filing.

### 4. Save drafts (always, before filing)
`{workspace}/docs/backlog/{YYYYMMDD}-{id}.md` — the decomposition table +
all tickets.

### 5. File approved tickets
- Duplicate guard first: one search of the destination for near-duplicate
  titles; warn and let the user drop duplicates.
- **notion**: `notion-create-pages` into `backlog.notion_data_source`,
  batched, using `notion_property_map` (set the configured status value for
  new tickets; leave unmapped properties alone).
- **github**: `gh issue create --repo {github_repo}` per ticket
  (title / body / labels).
- **draft-only**: stop after step 4 and say how to file later.
- Create **only** tickets shown and approved this session.

### 6. Close the loop
Write the created ticket URLs back into the draft file next to each ticket;
report a table of links.

## Mode B — `quick <input>`

One ticket from a sentence or a Slack thread URL (read the thread for
context and link it as 背景). Same ticket format, same review gate (show →
confirm → file). Also append a one-line record to
`{workspace}/docs/backlog/inbox.md` with the created link.

## Failure handling

Destination unavailable (Notion tools absent, `gh` fails, mapping broken) →
drafts are already saved; report exactly what failed and how to file
manually. Never retry a create that may have partially succeeded without
checking for the ticket first.

## Completion

Report: created links (or draft path if not filed), skipped/dropped items
with reasons, and a reminder that `/my:catchup` findings can flow here via
`quick`.
