#!/usr/bin/env bats
# Tests for scripts/hooks/antigravity-goal-deny.sh, the Antigravity PreToolUse
# hook start-goal registers in a goal worktree.
#
# Contract under test:
#   - The rules come from orca/settings/goal.deny.json: an MCP server named in
#     an mcp__ rule is denied through call_mcp_tool and as an eager mcp_ tool;
#     a Bash(<prefix>:*) rule denies running <prefix> in a command line or in
#     input sent to a background command.
#   - Everything else gets {"decision":"allow"}.
#   - Unreadable input is denied, and the hook always exits 0.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/scripts/hooks/antigravity-goal-deny.sh"
}

decision_for() {
  run bash "$HOOK" < <(printf '%s' "$1")
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -r .decision
}

command_payload() { jq -cn --arg c "$1" '{toolCall: {name: "run_command", args: {CommandLine: $c}}}'; }

@test "the rules file still names Slack and Notion servers and orca slack" {
  jq -e '.permissions.deny | index("mcp__slack") and index("mcp__notion") and index("Bash(orca slack:*)")' \
    "$REPO_ROOT/orca/settings/goal.deny.json"
}

@test "Slack and Notion MCP tools are denied, through call_mcp_tool and as eager tools" {
  [ "$(decision_for '{"toolCall":{"name":"call_mcp_tool","args":{"ServerName":"Slack-Work","ToolName":"post"}}}')" = deny ]
  [ "$(decision_for '{"toolCall":{"name":"mcp_notion_create_pages","args":{}}}')" = deny ]
  [ "$(decision_for '{"toolCall":{"name":"call_mcp_tool","args":{"ServerName":"github","ToolName":"get"}}}')" = allow ]
}

@test "orca slack is denied wherever the line runs it, and only there" {
  local c
  for c in 'orca slack post hi' 'git status && orca  slack x' 'bash -c "orca slack x"' 'x=$(orca slack y)'; do
    [ "$(decision_for "$(command_payload "$c")")" = deny ] || { echo "allowed: $c"; return 1; }
  done
  [ "$(decision_for "$(command_payload 'echo orca slacking')")" = allow ]
  [ "$(decision_for "$(command_payload 'git status')")" = allow ]
}

@test "input sent to a background command is checked like a command line" {
  [ "$(decision_for '{"toolCall":{"name":"manage_task","args":{"Action":"send_input","Input":"orca slack x\n"}}}')" = deny ]
  [ "$(decision_for '{"toolCall":{"name":"manage_task","args":{"Action":"status"}}}')" = allow ]
}

@test "unreadable input is denied and exits 0" {
  [ "$(decision_for 'not json')" = deny ]
}
