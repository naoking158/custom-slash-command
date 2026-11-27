#!/usr/bin/env bats
# Tests for scripts/lib/autonomy.sh and the guard's use of its record.
#
# Contract under test:
#   - ship needs both the config line and a ruleset check that passed.
#   - A failing check removes the record and names the missing rule on stderr.
#   - When gh cannot answer, an earlier record stands; a stale one does not count.
#   - The guard denies a merge in a configured repository that has no record.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  AUTONOMY="$REPO_ROOT/scripts/lib/autonomy.sh"
  GUARD="$REPO_ROOT/scripts/hooks/outbound-guard.sh"
  TMP="$(mktemp -d -t autonomy-test.XXXXXX)"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" remote add origin git@github.com:me/app.git
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
  export MY_TOOLKIT_DATA="$TMP/data"
  RECORD="$MY_TOOLKIT_DATA/ship-ready/me__app"
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"

  export GH_LOG="$TMP/gh.log"
  export GH_RULES="deletion pull_request required_status_checks"
  mkdir -p "$TMP/bin"
  cat >"$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
[ -z "${GH_FAIL:-}" ] || exit 1
case "$2" in
  repos/*/rules/branches/main) for rule in $GH_RULES; do echo "$rule"; done ;;
  repos/*) echo main ;;
esac
STUB
  chmod +x "$TMP/bin/gh"
  PATH="$TMP/bin:$PATH"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

record() {
  mkdir -p "${RECORD%/*}"
  echo "$1" >"$RECORD"
}

@test "a configured repository whose rulesets require a PR and status checks is ship" {
  run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$status" -eq 0 ]
  [ "$output" = "ship me/app" ]
  [ -f "$RECORD" ]
}

@test "without a required_status_checks rule the repository is strict and the record is removed" {
  record "$(date +%s)"
  GH_RULES="deletion pull_request" run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$output" = "strict me/app" ]
  [[ "$stderr" == *"required_status_checks"* ]]
  [[ "$stderr" != *"pull_request and"* ]]
  [ ! -e "$RECORD" ]
}

@test "a repository with no ruleset at all names both missing rules" {
  GH_RULES="" run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$output" = "strict me/app" ]
  [[ "$stderr" == *"pull_request and required_status_checks"* ]]
}

@test "a repository the config does not name is strict without asking GitHub" {
  echo 'ship other/*' >"$MY_AUTONOMY_CONF"
  run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$output" = "strict me/app" ]
  [ ! -e "$GH_LOG" ]
}

@test "when gh fails, an earlier record stands and no record means strict" {
  GH_FAIL=1 run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$output" = "strict me/app" ]

  record "$(date +%s)"
  GH_FAIL=1 run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$output" = "ship me/app" ]
  [[ "$stderr" == *"gh could not read"* ]]
}

@test "a record older than 7 days does not count" {
  record "$(( $(date +%s) - 700000 ))"
  GH_FAIL=1 run --separate-stderr "$AUTONOMY" "$REPO"
  [ "$output" = "strict me/app" ]
}

@test "guard: a configured repository without a record cannot merge, and the reason says how to check" {
  payload="$(jq -cn --arg d "$REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:"gh pr merge 3 --squash"}}')"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$payload" "$GUARD"
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ]
  [[ "$output" == *"autonomy.sh"* ]]

  record "$(date +%s)"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$payload" "$GUARD"
  [ -z "$output" ]
}
