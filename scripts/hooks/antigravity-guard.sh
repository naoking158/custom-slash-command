#!/usr/bin/env bash
# antigravity-guard.sh — Antigravity PreToolUse hook: apply outbound-guard.sh
# to run_command calls and to the input manage_task sends to a background
# command (Action send_input), which a shell running there would execute.
#
# Antigravity sends {toolCall:{name, args}, cwd, workspacePaths}, where args is
# {CommandLine, Cwd} for run_command and {Action, Input, TaskId} for
# manage_task, and requires a {decision, reason} object on stdout with exit 0.
# This script converts the payload to the Claude Code shape outbound-guard.sh
# reads and converts its permissionDecision back. When the guard has no
# objection, or the payload cannot be read, it answers "allow", which hands the
# call to Antigravity's own permission policy. The guard's "ask" becomes
# "force_ask": Antigravity's "ask" is skipped when the user has set "Always Allow".
# Dependencies: bash, jq, and those of outbound-guard.sh.
set -u

allow() {
  printf '{"decision":"allow"}\n'
  exit 0
}

payload="$(cat)" || allow
claude_payload="$(printf '%s' "$payload" | jq -c '
  .toolCall as $t
  | (if $t.name == "run_command" then $t.args.CommandLine
     elif $t.name == "manage_task" and $t.args.Action == "send_input" then $t.args.Input
     else null end) as $command
  | select(($command | type) == "string")
  | {tool_name: "Bash",
     cwd: ($t.args.Cwd // .cwd // .workspacePaths[0] // ""),
     tool_input: {command: $command}}' 2>/dev/null)"
[ -n "$claude_payload" ] || allow

guard="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/outbound-guard.sh"
verdict="$(printf '%s' "$claude_payload" | "$guard" 2>/dev/null | jq -c '
  .hookSpecificOutput
  | select(.permissionDecision == "deny" or .permissionDecision == "ask")
  | {decision: (if .permissionDecision == "ask" then "force_ask" else .permissionDecision end),
     reason: .permissionDecisionReason}' 2>/dev/null)"
[ -n "$verdict" ] || allow
printf '%s\n' "$verdict"
exit 0
