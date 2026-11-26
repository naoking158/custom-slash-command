#!/usr/bin/env bats
# Tests for orca/bin/doctor with a fake `orca` on PATH.
#
# Contract under test:
#   - Exit 0 only when orca is reachable, the shell is in an Orca terminal and
#     both guards deny a push to main.
#   - Each failure has its own exit code: 3 no orca, 4 runtime unreachable,
#     5 not in an Orca terminal, 6 outbound-guard allows, 7 antigravity-guard
#     allows. Every check still runs and is reported.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  DOCTOR="$REPO_ROOT/orca/bin/doctor"
  TMP="$(mktemp -d -t orca-doctor-test.XXXXXX)"
  FAKE_BIN="$TMP/bin"
  mkdir -p "$FAKE_BIN"
  export PATH="$FAKE_BIN:$(path_without_orca)"
  if command -v orca >/dev/null; then return 1; fi
  export ORCA_TERMINAL_HANDLE="term_fake"
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
}

# path_without_orca — $PATH minus every directory holding an orca executable.
path_without_orca() {
  local dir out="" IFS=:
  for dir in $PATH; do
    [ -x "$dir/orca" ] && continue
    out="${out:+$out:}$dir"
  done
  printf '%s' "$out"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# fake_orca STATUS_JSON [EXIT] — an orca whose `status --json` prints STATUS_JSON.
fake_orca() {
  printf '%s' "$1" >"$TMP/status.json"
  cat >"$FAKE_BIN/orca" <<SH
#!/bin/bash
[ "\$1 \$2" = "status --json" ] || exit 64
cat "$TMP/status.json"
exit ${2:-0}
SH
  chmod +x "$FAKE_BIN/orca"
}

reachable='{"id":"local-status","ok":true,"result":{"runtime":{"state":"ready","reachable":true,"appVersion":"1.4.277"}}}'

# doctor_with_guards OUTBOUND_BODY ANTIGRAVITY_BODY — run a copy of doctor
# whose sibling scripts/hooks hold stub guards with the given bodies.
doctor_with_guards() {
  local tree="$TMP/tree"
  mkdir -p "$tree/orca/bin" "$tree/scripts/hooks"
  cp "$DOCTOR" "$tree/orca/bin/doctor"
  printf '#!/bin/bash\ncat >/dev/null\n%s\n' "$1" >"$tree/scripts/hooks/outbound-guard.sh"
  printf '#!/bin/bash\ncat >/dev/null\n%s\n' "$2" >"$tree/scripts/hooks/antigravity-guard.sh"
  chmod +x "$tree/scripts/hooks/"*.sh
  run "$tree/orca/bin/doctor"
}

deny_claude="echo '{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"}}'"
deny_antigravity="echo '{\"decision\":\"deny\"}'"

@test "all checks pass: exit 0" {
  fake_orca "$reachable"
  run "$DOCTOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orca 1.4.277"* ]]
  [[ "$output" == *"outbound-guard denies"* ]]
  [[ "$output" == *"antigravity-guard denies"* ]]
  [[ "$output" == *"All good."* ]]
}

@test "no orca command: exit 3, guards still checked" {
  run "$DOCTOR"
  [ "$status" -eq 3 ]
  [[ "$output" == *"orca command not found"* ]]
  [[ "$output" == *"outbound-guard denies"* ]]
}

@test "orca status fails: exit 4" {
  fake_orca '' 1
  run "$DOCTOR"
  [ "$status" -eq 4 ]
}

@test "orca status prints non-JSON: exit 4" {
  fake_orca 'Orca is not running'
  run "$DOCTOR"
  [ "$status" -eq 4 ]
}

@test "runtime not reachable: exit 4" {
  fake_orca '{"ok":true,"result":{"runtime":{"state":"starting","reachable":false}}}'
  run "$DOCTOR"
  [ "$status" -eq 4 ]
  [[ "$output" == *"not reachable"* ]]
}

@test "outside an Orca terminal: exit 5" {
  fake_orca "$reachable"
  unset ORCA_TERMINAL_HANDLE
  run "$DOCTOR"
  [ "$status" -eq 5 ]
  [[ "$output" == *"ORCA_TERMINAL_HANDLE"* ]]
}

@test "outbound-guard that stays silent: exit 6" {
  fake_orca "$reachable"
  doctor_with_guards ":" "$deny_antigravity"
  [ "$status" -eq 6 ]
  [[ "$output" == *"outbound-guard did not deny"* ]]
}

@test "outbound-guard that asks instead of denying: exit 6" {
  fake_orca "$reachable"
  doctor_with_guards "echo '{\"hookSpecificOutput\":{\"permissionDecision\":\"ask\"}}'" "$deny_antigravity"
  [ "$status" -eq 6 ]
}

@test "antigravity-guard that allows: exit 7" {
  fake_orca "$reachable"
  doctor_with_guards "$deny_claude" "echo '{\"decision\":\"allow\"}'"
  [ "$status" -eq 7 ]
  [[ "$output" == *"antigravity-guard did not deny"* ]]
}

@test "stub guards that both deny: exit 0" {
  fake_orca "$reachable"
  doctor_with_guards "$deny_claude" "$deny_antigravity"
  [ "$status" -eq 0 ]
}

@test "first failure wins: no orca and a silent guard exit 3" {
  doctor_with_guards ":" ":"
  [ "$status" -eq 3 ]
  [[ "$output" == *"outbound-guard did not deny"* ]]
  [[ "$output" == *"antigravity-guard did not deny"* ]]
}

@test "unknown argument: exit 2" {
  run "$DOCTOR" --bogus
  [ "$status" -eq 2 ]
}
