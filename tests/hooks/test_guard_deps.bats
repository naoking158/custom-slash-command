#!/usr/bin/env bats
# Tests for the guards when what they need is missing: jq for
# antigravity-guard, and for outbound-guard the binary bin/my-toolkit-<os>-<arch>
# (missing, or failing when it runs).
#
# Contract under test:
#   - A guard that cannot read its payload denies a call that looks outbound.
#   - It says nothing about a call that matches none of the outbound patterns.

load ../fake_bin

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
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

# guard_tree [BINARY_BODY] — print a copy of the hooks (symlinks) with no
# binary for any machine, or with BINARY_BODY as the binary for every machine.
guard_tree() {
  local tree="$TMP/tree" target
  mkdir -p "$tree/scripts/hooks" "$tree/scripts/lib" "$tree/bin"
  ln -sf "$REPO_ROOT/scripts/hooks/outbound-guard.sh" "$REPO_ROOT/scripts/hooks/antigravity-guard.sh" "$tree/scripts/hooks/"
  ln -sf "$REPO_ROOT/scripts/lib/guard-deps.sh" "$tree/scripts/lib/"
  if [ $# -gt 0 ]; then
    for target in darwin-arm64 darwin-amd64 linux-arm64 linux-amd64; do
      printf '#!/bin/bash\n%s\n' "$1" | fake_bin "$tree/bin/my-toolkit-$target"
    done
  fi
  printf '%s' "$tree"
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

@test "outbound-guard without its binary denies a push and names the binary" {
  run_with_path "$PATH" "$(guard_tree)/scripts/hooks/outbound-guard.sh" "$(bash_payload 'git push origin main')"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  [[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')" == *"bin/my-toolkit-"* ]]
}

@test "outbound-guard whose binary fails denies a merge and names the binary" {
  run_with_path "$PATH" "$(guard_tree 'cat >/dev/null; exit 1')/scripts/hooks/outbound-guard.sh" \
    "$(bash_payload 'gh pr merge 3 --squash')"
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  [[ "$output" == *"bin/my-toolkit-"* ]]
}

@test "outbound-guard without its binary stays silent for a command that sends nothing out" {
  run_with_path "$PATH" "$(guard_tree)/scripts/hooks/outbound-guard.sh" "$(bash_payload 'ls -la')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "outbound-guard without its binary does not take a path with git in it, or the word in pushd, for a push" {
  local guard
  guard="$(guard_tree)/scripts/hooks/outbound-guard.sh"
  REPO="$TMP/github.com/me/app"
  mkdir -p "$REPO"
  for command in 'pushd src' 'grep -rn push .' 'echo "high priority"' 'gh project list'; do
    run_with_path "$PATH" "$guard" "$(bash_payload "$command")"
    [ -z "$output" ]
  done
}

@test "outbound-guard without its binary denies a push after a newline, a tab, or git options" {
  local guard
  guard="$(guard_tree)/scripts/hooks/outbound-guard.sh"
  for command in $'cd /x\ngit push' $'git\tpush' 'git -C /x push' 'git -c user.name="a b" push' \
    '/usr/bin/git push origin main' $'gh\tpr merge 3' $'gh \\\npr merge 3'; do
    run_with_path "$PATH" "$guard" "$(bash_payload "$command")"
    [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  done
}

@test "antigravity-guard without jq denies a push and allows the rest" {
  run_with_path "$(bin_without jq)" "$AGY_GUARD" "$(agy_payload 'git push origin main')"
  [ "$(printf '%s' "$output" | jq -r '.decision')" = "deny" ]

  run_with_path "$(bin_without jq)" "$AGY_GUARD" "$(agy_payload 'ls -la')"
  [ "$output" = '{"decision":"allow"}' ]
}

@test "antigravity-guard whose outbound-guard has no binary denies a push" {
  run_with_path "$PATH" "$(guard_tree)/scripts/hooks/antigravity-guard.sh" "$(agy_payload 'git push origin main')"
  [ "$(printf '%s' "$output" | jq -r '.decision')" = "deny" ]
  [[ "$output" == *"bin/my-toolkit-"* ]]
}
