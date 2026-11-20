# PdM scheduling recipes

Three ways to get a recurring catchup digest, in recommended order. All of
them assume `/my:pdm-setup` has been run once.

## 1. claude.ai cloud routine — recommended (full Slack + Notion)

Cloud routines run on Anthropic-managed infrastructure with claude.ai
connectors (Slack, Notion, Gmail, Calendar) available, even when your laptop
is closed. The routine does not need this plugin — give it a self-contained
prompt. In an interactive Claude Code session, run `/schedule` and ask for:

```
平日 8:30 JST に実行するルーティンを作って。内容:
1. Slack で過去24時間の自分宛メンション、自分が参加しているスレッドの
   未返信、プロダクト系チャンネルの動きを収集する
2. Notion の直近更新ページと議事録から、決定事項と自分のアクション
   アイテムを抽出する
3. 🔴要対応 / 🟡進行中の議論 / 🟢FYI / 📝会議ノート に分類し、
   全項目にリンクを付けたダイジェストを作る
4. それを私の Slack DM に送る
```

Docs: https://code.claude.com/docs/en/scheduled-tasks

## 2. Interactive habit — zero setup, full sources

Open Claude Code in the morning (in the PdM workspace) and run:

```
/my:catchup
```

The session has all connectors, the digest covers Slack + Notion + Calendar,
and 要対応 items can flow straight into `/my:backlog quick`.

## 3. Local launchd — Notion-only, laptop must be awake

Headless `claude -p` cannot reach claude.ai connectors, so the digest
degrades to Notion + meeting notes (still useful as a document radar).

One-time setup:

```bash
# 1. verify notion MCP works headlessly (OAuth must already be cached):
claude -p "notion-search で適当なページを1件検索して件名だけ出して" \
  --allowedTools "mcp__notion__notion-search"

# 2. install the launchd job (substitute the repo path):
REPO=$HOME/src/github.com/naoking158/custom-slash-command
sed "s|{REPO_PATH}|$REPO|" "$REPO/scripts/pdm/com.my.pdm-catchup.plist.template" \
  > ~/Library/LaunchAgents/com.my.pdm-catchup.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.my.pdm-catchup.plist

# check / remove:
launchctl print gui/$(id -u)/com.my.pdm-catchup | head
launchctl bootout gui/$(id -u)/com.my.pdm-catchup
```

Logs land in `~/.claude/my-toolkit/pdm/logs/`. If runs start failing with
auth errors, re-authenticate the notion server once in an interactive
session (`/mcp`).

Set `PDM_WORKSPACE` in the plist (`EnvironmentVariables`) if your workspace
is not `~/pdm-workspace`.

## Which one?

| | Slack | Notion | laptop closed | setup |
|---|---|---|---|---|
| Cloud routine | ✅ | ✅ | ✅ | 1 command |
| Interactive habit | ✅ | ✅ | – | none |
| launchd headless | ❌ | ✅ | ❌ | medium |

Start with **2** today, add **1** when you want it pushed to you.
