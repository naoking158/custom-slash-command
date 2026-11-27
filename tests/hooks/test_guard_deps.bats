#!/usr/bin/env bats
# Tests for the guards when jq or perl is not on PATH.
#
# Contract under test:
#   - A guard that cannot read its payload denies a call that looks outbound.
#   - It says nothing about a call that matches none of the outbound patterns.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARD="$REPO_ROOT/scripts/hooks/outbound-guard.sh"
  AGY_GUARD="$REPO_ROOT/scripts/hooks/antigravity-guard.sh"
  TMP="$(mktemp -d -t guard-deps.XXXXXX)"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature/x
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# bin_without NAME — print a directory holding what the guards run, except NAME.
bin_without() {
  local dir="$TMP/bin-no-$1" tool
  mkdir -p "$dir"
  for tool in bash cat grep dirname git sed sort perl jq; do
    [ "$tool" = "$1" ] || ln -sf "$(command -v "$tool")" "$dir/$tool"
  done
  printf '%s' "$dir"
}

bash_payload() {
  jq -cn --arg c "$1" --arg d "$REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
}

agy_payload() {
  jq -cn --arg c "$1" --arg d "$REPO" '{toolCall:{name:"run_command",args:{CommandLine:$c,Cwd:$d}},cwd:$d}'
}

# run_with_path PATH HOOK PAYLOAD
run_with_path() {
  run bash -c 'printf "%s" "$3" | PATH="$1" "$2"' _ "$1" "$2" "$3"
}

@test "outbound-guard without jq denies a push and names jq" {
  run_with_path "$(bin_without jq)" "$GUARD" "$(bash_payload 'git push origin main')"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')" == *"jq"* ]]
}

@test "outbound-guard without perl denies a merge and names perl" {
  run_with_path "$(bin_without perl)" "$GUARD" "$(bash_payload 'gh pr merge 3 --squash')"
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  [[ "$output" == *"perl"* ]]
}

@test "outbound-guard without jq stays silent for a command that sends nothing out" {
  run_with_path "$(bin_without jq)" "$GUARD" "$(bash_payload 'ls -la')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "outbound-guard without jq does not take a path with git in it, or the word in pushd, for a push" {
  REPO="$TMP/github.com/me/app"
  mkdir -p "$REPO"
  for command in 'pushd src' 'grep -rn push .' 'echo "high priority"' 'gh project list'; do
    run_with_path "$(bin_without jq)" "$GUARD" "$(bash_payload "$command")"
    [ -z "$output" ]
  done
}

@test "outbound-guard without jq denies a push after a newline, a tab, or git options" {
  for command in $'cd /x\ngit push' $'git\tpush' 'git -C /x push' 'git -c user.name="a b" push' \
    '/usr/bin/git push origin main' $'gh\tpr merge 3' $'gh \\\npr merge 3'; do
    run_with_path "$(bin_without jq)" "$GUARD" "$(bash_payload "$command")"
    [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  done
}

@test "antigravity-guard without jq denies a push and allows the rest" {
  run_with_path "$(bin_without jq)" "$AGY_GUARD" "$(agy_payload 'git push origin main')"
  [ "$(printf '%s' "$output" | jq -r '.decision')" = "deny" ]

  run_with_path "$(bin_without jq)" "$AGY_GUARD" "$(agy_payload 'ls -la')"
  [ "$output" = '{"decision":"allow"}' ]
}

@test "antigravity-guard without perl denies a push" {
  run_with_path "$(bin_without perl)" "$AGY_GUARD" "$(agy_payload 'git push origin main')"
  [ "$(printf '%s' "$output" | jq -r '.decision')" = "deny" ]
  [[ "$output" == *"perl"* ]]
}
