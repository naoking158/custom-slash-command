#!/usr/bin/env bats
# Tests for scripts/hooks/outbound-guard.sh started as the hook is: the
# launcher, then the binary for this machine. The rules themselves are tested
# in process by internal/outboundguard/guard_test.go.
#
# Contract under test:
#   - The hook never exits non-zero.
#   - Under the system bash (3.2 on macOS) the launcher hands the payload to
#     the binary, which reads the files the command sends.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARD="$REPO_ROOT/scripts/hooks/outbound-guard.sh"
  TMP="$BATS_TEST_TMPDIR"
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
}

bash_payload() {
  jq -cn --arg c "$1" --arg d "$TMP" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
}

decision() {
  printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision'
}

@test "malformed payload never fails" {
  run bash -c 'printf "not json" | "$1"' _ "$GUARD"
  [ "$status" -eq 0 ]
}

@test "api: an input file is read under the system bash too" {
  [ -x /bin/bash ] || skip "no /bin/bash"
  printf '{"body":"fixed H001"}' >"$TMP/a.json"
  run bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$(bash_payload "gh api --method POST repos/o/r/issues/1/comments --input $TMP/a.json")" "$GUARD"
  [ "$(decision)" = "deny" ]
}
