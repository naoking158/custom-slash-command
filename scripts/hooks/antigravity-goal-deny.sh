#!/usr/bin/env bash
# antigravity-goal-deny.sh — Antigravity PreToolUse hook that applies the deny
# rules of a goal session (orca/settings/goal.deny.json) in Antigravity.
#
# orca/bin/start-goal registers it in the goal worktree's .agents/hooks.json:
# Antigravity has no settings file per workspace, but runs the hooks.json of
# the workspace. The rules are read from goal.deny.json, written for Claude
# Code:
#   - `mcp__<server>` (`mcp__claude_ai_<server>` too) denies every tool of an
#     MCP server whose name contains <server>, case-insensitively: a call
#     through call_mcp_tool (args.ServerName) or an eager tool
#     mcp_<server>_<tool>.
#   - `Bash(<prefix>:*)` denies a run_command line, or input that manage_task
#     sends to a background command, that runs <prefix> as a command: at the
#     start, or after `;`, `&`, `|`, `(`, a quote, a backtick, or a newline,
#     with any run of spaces between its words.
# Antigravity sends {toolCall:{name, args}} and requires {decision, reason} on
# stdout with exit 0. Anything not denied gets "allow", which hands the call to
# Antigravity's own permission policy. A payload or rule file it cannot read
# is denied: the hook exists only in goal sessions, where a silent pass would
# drop the rules.
# Dependencies: bash, jq.
set -u

rules="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)/orca/settings/goal.deny.json"

deny() {
  jq -cn --arg r "goal-deny: $1" '{decision: "deny", reason: $r}'
  exit 0
}

command -v jq >/dev/null 2>&1 || { printf '{"decision":"deny","reason":"goal-deny: jq is required"}\n'; exit 0; }
payload="$(cat)" || deny "cannot read the hook input"
verdict="$(jq -cn --argjson p "$payload" --slurpfile f "$rules" '
  ($f[0].permissions.deny) as $deny
  | [$deny[] | select(startswith("mcp__")) | ltrimstr("mcp__") | ltrimstr("claude_ai_") | ascii_downcase] as $servers
  | [$deny[] | capture("^Bash\\((?<p>.+):\\*\\)$") | .p] as $prefixes
  | $p.toolCall as $t
  | ($t.name // "") as $name
  | (if $name == "call_mcp_tool" then ($t.args.ServerName // "")
     elif ($name | startswith("mcp_")) then $name
     else null end | if . == null then null else ascii_downcase end) as $server
  | (if $name == "run_command" then $t.args.CommandLine
     elif $name == "manage_task" and $t.args.Action == "send_input" then $t.args.Input
     else null end) as $line
  | if $server != null and any($servers[]; . as $s | $server | contains($s)) then
      "the goal session may not use the MCP server " + $server
    elif ($line | type) == "string"
      and any($prefixes[]; . as $x | $line | test("(^|[;&|(`\"\u0027\\n])\\s*" + ($x | gsub("(?<c>[.*+?^${}()|\\[\\]\\\\])"; "\\\(.c)") | gsub(" +"; "\\s+")) + "(\\s|$)")) then
      "the goal session may not run " + ($prefixes | join(", "))
    else "" end' 2>/dev/null)" || deny "cannot read the hook input or $rules"
verdict="$(printf '%s' "$verdict" | jq -r .)"
[ -z "$verdict" ] || deny "$verdict"
printf '{"decision":"allow"}\n'
exit 0
