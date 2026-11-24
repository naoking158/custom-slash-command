---
name: pdm-setup
description: First-run configuration for the PdM skills (prd / product-spec / backlog / catchup) — sets the workspace directory, backlog destination (Notion DB / GitHub Issues / draft-only), priority Slack channels, and digest preferences in a machine-local config. Trigger words: pdm setup, PdM設定, PdM 初期設定.
argument-hint: "[--show]"
---

# PdM Setup

Create or update the machine-local config every PdM skill reads:

```
${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/config.md
```

`--show` → print the current config (or "not configured — run /my:pdm-setup")
and stop.

## Principles

- Config holds **IDs, URLs, and preferences only** — never tokens or secrets.
- Machine-local, never inside a repository tree (learn/retro precedent).
- Discovery (Notion/Slack search) only *proposes* candidates; every value is
  confirmed by the user before it is written.
- Re-running is safe: show current values as defaults and update only the
  sections the user wants to change.

## Wizard

Ask section by section (AskUserQuestion where options are enumerable). A
section whose tools are unavailable in this session (e.g. Slack connector
missing) is skipped with a note — it can be filled in later by re-running.

### 1. Workspace

Directory for PdM artifacts (default `~/pdm-workspace`). Create
`docs/prd/ docs/product-specs/ docs/backlog/ docs/catchup/` inside it.
If it is not a git repository, recommend `git init` (ask, don't force) —
history on PRDs/specs pays off. Run `/my:review` from this directory: the
`prd:` / `pspec:` targets resolve against `docs/` of the CWD.

### 2. Backlog destination

Options: **Notion database** / **GitHub Issues** / **draft-only** (tickets
stay as local markdown until filed manually).

- **Notion**: the user pastes the database URL, or search for candidates
  (`notion-search` for "backlog", "開発バックログ", "product backlog") and
  confirm one. Fetch the database and build the property map by matching
  against its **actual schema** — map only properties that exist:
  title / status (+ the status value new tickets get) / assignee /
  estimate / labels / epic relation. Record the data source id.
- **GitHub**: `owner/repo`; verify with `gh repo view {owner/repo}`;
  optionally default labels.

### 3. Slack

- Resolve the user's own profile (`slack_read_user_profile`) → user id and
  mention token `<@U…>`.
- Priority channels for the digest: the user names them; resolve each via
  `slack_search_channels` and confirm the matches (name + id).

### 4. Notion PRD parent (optional)

Page URL under which finished PRDs are published.

### 5. Digest preferences

- `default_window`: how far back `/my:catchup` looks when no state exists
  (default `24h`).
- `delivery`: `file` (default) or `file+slack-dm` (digest also DMed to self,
  confirmed each time).

## Write the config

Exact format (omit optional keys that were not configured):

```markdown
# PdM Config
updated: {YYYY-MM-DD}

## workspace
path: {absolute path}

## backlog
destination: {notion | github | draft-only}
notion_data_source: {id or url}
notion_property_map:
  title: {property name}
  status: {property name} = {value for new tickets}
  assignee: {property name}
  estimate: {property name}
  labels: {property name}
github_repo: {owner/repo}

## slack
my_user_id: {U…}
mention: <@{U…}>
priority_channels:
  - {#name} ({C…})

## notion
prd_parent: {page url}

## digest
default_window: 24h
delivery: {file | file+slack-dm}
```

## Smoke test (after writing)

- Notion destination → query the data source for one row and show that the
  title property resolves.
- GitHub destination → `gh issue list --repo {owner/repo} --limit 1`.
- Report ✅ / ⛔ per section, with what was skipped and why.

## Completion

Report: config path, configured sections, skipped sections (and how to fill
them later), then suggest first uses: `/my:catchup`, `/my:prd "<アイデア>"`.
