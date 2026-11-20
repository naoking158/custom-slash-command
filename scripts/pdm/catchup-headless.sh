#!/usr/bin/env bash
# Headless /my:catchup for scheduled local runs (launchd/cron).
#
# LIMITATION: claude.ai connectors (Slack, Gmail, Calendar) are NOT available
# in headless runs — the digest degrades to Notion-only. For full Slack+Notion
# coverage use a claude.ai cloud routine instead (see scripts/pdm/README.md).
#
# One-time prerequisites (interactive):
#   1. `claude` → confirm the notion MCP server is authenticated (/mcp)
#   2. run /my:pdm-setup so the config and workspace exist
set -euo pipefail

PDM_HOME="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm"
LOG_DIR="$PDM_HOME/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/catchup-$(date +%Y%m%d-%H%M%S).log"

# launchd starts with a minimal PATH; make sure `claude` is reachable.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

WORKSPACE="${PDM_WORKSPACE:-$HOME/pdm-workspace}"
cd "$WORKSPACE"

# Read-only MCP allowlist + local file output. Extend deliberately instead of
# reaching for --dangerously-skip-permissions.
ALLOWED_TOOLS="${ALLOWED_TOOLS:-Read,Write,Glob,Grep,mcp__notion__notion-search,mcp__notion__notion-fetch,mcp__notion__notion-query-meeting-notes,mcp__notion__notion-query-data-sources,mcp__notion__notion-query-database-view}"

{
  echo "=== catchup headless run: $(date -Iseconds) (workspace: $WORKSPACE)"
  claude -p "/my:catchup --quiet" --allowedTools "$ALLOWED_TOOLS"
  echo "=== done: $(date -Iseconds)"
} >>"$LOG_FILE" 2>&1
