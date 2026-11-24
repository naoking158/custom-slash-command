#!/usr/bin/env bats
# Tests for scripts/hooks/antigravity-guard.sh and the root hooks.json that
# registers it as an Antigravity PreToolUse hook.
#
# Contract under test:
#   - A run_command call that outbound-guard.sh objects to gets its decision
#     (deny / ask) and reason back in Antigravity's {decision, reason} shape.
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

@test "tag push asks" {
  run_hook "$(run_command_payload 'git push --tags')"
  [ "$(printf '%s' "$output" | jq -r .decision)" = "ask" ]
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

@test "hooks.json registers the hook on run_command with a plugin-relative command" {
  local cmd
  [ "$(jq -r '."outbound-guard".PreToolUse[0].matcher' "$REPO_ROOT/hooks.json")" = "run_command" ]
  cmd="$(jq -r '."outbound-guard".PreToolUse[0].hooks[0].command' "$REPO_ROOT/hooks.json")"
  [[ "$cmd" == ./* ]]
  [ -x "$REPO_ROOT/$cmd" ]
}
