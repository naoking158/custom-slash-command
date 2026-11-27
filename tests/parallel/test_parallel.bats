#!/usr/bin/env bats
# Tests for tests/parallel.sh, the bats-compatible parallel runner.
#
# Contract under test:
#   - Every test of the fixture gets the same ok / not ok as under bats.
#   - The summary counts every test, and the exit status is 1 when one fails.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUNNER="$REPO_ROOT/tests/parallel.sh"
  FIXTURE="$BATS_TEST_TMPDIR/semantics.bats"
  cp "$BATS_TEST_DIRNAME/fixtures/semantics.bats.txt" "$FIXTURE"
}

# verdicts — "ok|not ok <name>" per test line of the TAP in $output, sorted.
verdicts() {
  printf '%s\n' "$output" | sed -nE 's/^(ok|not ok) [0-9]+ ([^#]*[^ #]).*/\1 \2/p' | sort
}

@test "the runner gives every fixture test the verdict bats gives" {
  run bats --tap "$FIXTURE"
  local want
  want="$(verdicts)"
  [ "$(printf '%s\n' "$want" | grep -c '^not ok ')" -eq 4 ]
  run -1 "$RUNNER" -j 4 "$FIXTURE"
  [ "$(verdicts)" = "$want" ]
}

@test "the summary counts every test and the exit status reports a failure" {
  run -1 "$RUNNER" -j 2 "$FIXTURE"
  [ "${lines[${#lines[@]}-1]}" = "# 13 tests, 4 failed" ]
}

@test "a file that ends before its tests run fails the run" {
  cp "$BATS_TEST_DIRNAME/fixtures/exits-early.bats.txt" "$BATS_TEST_TMPDIR/exits-early.bats"
  run -1 "$RUNNER" "$BATS_TEST_TMPDIR/exits-early.bats"
  [[ "$output" == *"hold 2 tests but 0 reported"* ]]
}

@test "bad -j exits 2" {
  run -2 "$RUNNER" -j 0 "$FIXTURE"
  run -2 "$RUNNER" -j
}
