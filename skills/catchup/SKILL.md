---
name: catchup
description: Digest of everything that happened in Slack and Notion since the last run — mentions and threads waiting on your reply, decisions in flight, meeting-note action items — grouped by urgency with links and proposed next actions. Trigger words: catchup, キャッチアップ, 情報整理, 朝会, ダイジェスト.
argument-hint: "[window: 8h|2d|…] [--post] [--quiet]"
---

# Catchup

Arguments: **$ARGUMENTS**

Produce one digest the user can act on in 5 minutes. Signal over volume:
an item without a link and a reason to care does not belong in it.

## Step 0 — Config, window, sources

- Read `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/config.md`
  (missing → offer `/my:pdm-setup`, stop). Resolve `{workspace}`, mention
  token, priority channels, delivery.
- State file: `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/state/last-catchup`
  (ISO 8601). Window = explicit argument > time since state file >
  `digest.default_window` (24h). Cap at 7d and say so when capped.
- Detect available sources (Slack tools / Notion tools / Google Calendar).
  Every unavailable source is named in the digest header — never silently
  dropped.

## Step 1 — Slack sweep (bounded: ~10 tool calls, priority order)

1. **Mentions**: search `"{mention}" after:{date}` via
   `slack_search_public_and_private`; if 0 hits, retry once with the display
   name.
2. **Priority channels** (from config): `slack_read_channel` for the window.
3. **Threads**: for hits that are threads, `slack_read_thread` and classify:
   - **要返信** — a question/request directed at the user with no reply from
     them after it
   - **追跡** — a discussion or decision still in flight
   - **FYI** — everything else worth knowing
4. Per item collect: 一言要約, 発言者, チャンネル, permalink, 期限のヒント.

Stay inside the call budget: mentions first, then channels by config order.
If the budget cuts coverage, record what was not swept for the coverage note.

## Step 2 — Notion sweep (bounded: ~6 tool calls)

1. `notion-search` for pages edited within the window; keep product-relevant
   ones (PRDs, specs, decision docs).
2. `notion-query-meeting-notes` for meetings in the window → extract 決定事項,
   the user's own action items, and open questions.

## Step 3 — Calendar (optional)

If Google Calendar MCP is authenticated: today's meetings; ones needing prep
join 要対応. Skip silently otherwise (this source is enrichment, not core).

## Step 4 — Compose

Structure: `${CLAUDE_SKILL_DIR}/template.md`. Language: Japanese. Rules:

- Dedupe: one topic appearing in Slack and Notion → one item, both links.
- 🔴 要対応 is sorted by (期限 > 発生順) and every entry carries a 提案 —
  返信の方向性, or 起票候補 as a ready-to-run `/my:backlog quick "…"` line.
- Honest coverage note: skipped sources and budget cuts, at the bottom.

## Step 5 — Deliver + advance state

- Print the digest to the console (primary output; `--quiet` → one summary
  line + file path only, for scheduled runs).
- Save to `{workspace}/docs/catchup/{YYYYMMDD-HHMM}.md`.
- `--post`, or `delivery: file+slack-dm`: show the digest, **confirm, then**
  `slack_send_message` to the user's own DM (`my_user_id`). Confirmation is
  required every time; skip silently when Slack is unavailable.
- **Only after the digest file is written**, update the state file to now
  (ISO 8601). A failed run must not advance the timestamp.

## Rules

- Read-only against Slack/Notion, except the explicitly confirmed DM post.
- 返信ドラフトは提案止まり — never send replies to anyone.
- Both Slack and Notion unavailable → stop with guidance (check connector
  auth; run interactively) instead of an empty digest.

## Completion

Report: item counts per section, digest path, the top 3 要対応 inline,
whether the state timestamp advanced, and any coverage gaps.
