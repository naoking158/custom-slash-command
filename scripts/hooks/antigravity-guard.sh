#!/usr/bin/env bash
# antigravity-guard.sh — Antigravity PreToolUse hook: apply outbound-guard.sh
# to run_command calls.
#
# Antigravity sends {toolCall:{name, args:{CommandLine, Cwd}}, workspacePaths}
# and requires a {decision, reason} object on stdout with exit 0. This script
# converts the payload to the Claude Code shape outbound-guard.sh reads and
# converts its permissionDecision back. When the guard has no objection, or the
# payload cannot be read, it answers "allow", which hands the call to
# Antigravity's own permission policy.
# Dependencies: bash, jq, and those of outbound-guard.sh.
set -u

allow() {
  printf '{"decision":"allow"}\n'
  exit 0
}

payload="$(cat)" || allow
claude_payload="$(printf '%s' "$payload" | jq -c '
  select(.toolCall.name == "run_command" and (.toolCall.args.CommandLine | type) == "string")
  | {tool_name: "Bash",
     cwd: (.toolCall.args.Cwd // .workspacePaths[0] // ""),
     tool_input: {command: .toolCall.args.CommandLine}}' 2>/dev/null)"
[ -n "$claude_payload" ] || allow

guard="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/outbound-guard.sh"
verdict="$(printf '%s' "$claude_payload" | "$guard" 2>/dev/null | jq -c '
  .hookSpecificOutput
  | select(.permissionDecision == "deny" or .permissionDecision == "ask")
  | {decision: .permissionDecision, reason: .permissionDecisionReason}' 2>/dev/null)"
[ -n "$verdict" ] || allow
printf '%s\n' "$verdict"
exit 0
