#!/usr/bin/env bats
# Tests for scripts/hooks/antigravity-guard.sh and the root hooks.json that
# registers it as an Antigravity PreToolUse hook.
#
# Contract under test:
#   - A run_command call, or a manage_task send_input whose Input is a
#     command, that outbound-guard.sh objects to gets its decision
#     and reason back in Antigravity's {decision, reason} shape; "ask" becomes
#     "force_ask" so an "Always Allow" setting cannot skip it.
#   - Every other call, and unreadable input, gets {"decision":"allow"}.
#   - The hook always exits 0 (Antigravity ignores a failing hook).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/scripts/hooks/antigravity-guard.sh"
  TMP="$(mktemp -d -t ag-guard-test.XXXXXX)"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature/x
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# run_command_payload CMD — the PreToolUse payload Antigravity documents.
run_command_payload() {
  jq -cn --arg c "$1" --arg d "$REPO" '{
    toolCall: {name: "run_command", args: {CommandLine: $c, Cwd: $d, WaitMsBeforeAsync: 5000}},
    stepIdx: 19,
    conversationId: "ec33ebf9-0cba-4100-8142-c61503f6c587",
    workspacePaths: [$d],
    modelName: "gemini-3.6-flash-medium"
  }'
}

run_hook() {
  run bash -c 'printf "%s" "$1" | "$2"' _ "$1" "$HOOK"
  [ "$status" -eq 0 ]
}

@test "push to the default branch is denied with the guard's reason" {
  run_hook "$(run_command_payload 'git push origin main')"
  [ "$(printf '%s' "$output" | jq -r .decision)" = "deny" ]
  [[ "$(printf '%s' "$output" | jq -r .reason)" == outbound-guard:* ]]
}

@test "non-draft PR in a strict repository is denied" {
  run_hook "$(run_command_payload 'gh pr create --title t --body b')"
  [ "$(printf '%s' "$output" | jq -r .decision)" = "deny" ]
}

@test "tag push always asks" {
  run_hook "$(run_command_payload 'git push --tags')"
  [ "$(printf '%s' "$output" | jq -r .decision)" = "force_ask" ]
}

@test "a command the guard allows is passed to Antigravity's own policy" {
  run_hook "$(run_command_payload 'git push -u origin feature/x')"
  [ "$output" = '{"decision":"allow"}' ]
}

@test "the repository is taken from Cwd, so ship mode allows merging" {
  git -C "$REPO" remote add origin git@github.com:me/app.git
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"
  run_hook "$(run_command_payload 'gh pr merge 3 --squash')"
  [ "$output" = '{"decision":"allow"}' ]
}

@test "input sent to a background command is checked like a command" {
  run_hook "$(jq -cn --arg d "$REPO" '{
    toolCall: {name: "manage_task", args: {Action: "send_input", Input: "git push origin main\n", TaskId: "c/task-5"}},
    cwd: $d, workspacePaths: [$d]}')"
  [ "$(printf '%s' "$output" | jq -r .decision)" = "deny" ]
}

@test "manage_task actions other than send_input are allowed" {
  run_hook '{"toolCall":{"name":"manage_task","args":{"Action":"kill","TaskId":"c/task-5"}}}'
  [ "$output" = '{"decision":"allow"}' ]
}

@test "other tools are allowed" {
  run_hook '{"toolCall":{"name":"view_file","args":{"AbsolutePath":"/etc/hosts"}}}'
  [ "$output" = '{"decision":"allow"}' ]
}

@test "unreadable input is allowed and exits 0" {
  run_hook 'not json'
  [ "$output" = '{"decision":"allow"}' ]
  run_hook ''
  [ "$output" = '{"decision":"allow"}' ]
}

@test "hooks.json registers the hook on run_command and manage_task with a plugin-relative command" {
  local cmd
  [ "$(jq -c '[."outbound-guard".PreToolUse[].matcher]' "$REPO_ROOT/hooks.json")" = '["run_command","manage_task"]' ]
  for cmd in $(jq -r '."outbound-guard".PreToolUse[].hooks[].command' "$REPO_ROOT/hooks.json"); do
    [[ "$cmd" == ./* ]]
    [ -x "$REPO_ROOT/$cmd" ]
  done
}

@test "the Antigravity manifest names the plugin my and keeps to the schema's keys" {
  local m="$REPO_ROOT/.antigravity-plugin/plugin.json"
  [ "$(jq -r .name "$m")" = "my" ]
  [ "$(jq -r '[keys[] | select(IN("$schema","name","displayName","description","version","disabled","logo","suggestedPrompts","skills","author","homepage","repository","license","keywords","extensions") | not)] | length' "$m")" = "0" ]
}
