#!/usr/bin/env bats
# Tests for scripts/lib/wait-ci.sh.
#
# Contract under test:
#   - The verdict is the exit status: 0 green, 1 red, 3 no run for the commit,
#     4 still running at the timeout.
#   - A commit whose runs are not registered yet is waited for, not reported.
#   - Every run of the commit counts, including one that registers late.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  WAIT_CI="$REPO_ROOT/scripts/lib/wait-ci.sh"
  TMP="$(mktemp -d -t wait-ci-test.XXXXXX)"
  mkdir -p "$TMP/bin"
  # Stub gh: `workflow list` prints $GH_WORKFLOWS; each `run list` prints the
  # next line of $TMP/frames and repeats the last one.
  cat >"$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
dir="$(cd "$(dirname "$0")/.." && pwd)"
echo "$*" >>"$dir/calls"
case "$1 $2" in
  "workflow list") printf '%s\n' "${GH_WORKFLOWS-1}" ;;
  "run list")
    n="$(cat "$dir/n" 2>/dev/null || echo 1)"
    total="$(wc -l <"$dir/frames" | tr -d ' ')"
    [ "$n" -le "$total" ] || n="$total"
    sed -n "${n}p" "$dir/frames"
    echo $((n + 1)) >"$dir/n" ;;
esac
GH
  chmod +x "$TMP/bin/gh"
  export PATH="$TMP/bin:$PATH"
  export WAIT_CI_INTERVAL=0
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

run_of() {
  jq -cn --arg s "$1" --arg c "$2" --arg w "${3:-ci}" \
    '{databaseId: 1, workflowName: $w, status: $s, conclusion: $c}'
}

@test "a run that registers late is waited for and reported green" {
  {
    echo '[]'
    echo '[]'
    echo "[$(run_of in_progress "")]"
    echo "[$(run_of completed success)]"
  } >"$TMP/frames"
  run "$WAIT_CI" me/app abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"CI: green"* ]]
}

@test "a failed run is red" {
  echo "[$(run_of completed failure)]" >"$TMP/frames"
  run "$WAIT_CI" me/app abc123
  [ "$status" -eq 1 ]
  [[ "$output" == *"failure"* ]]
}

@test "a second run that registers after the first one passed still counts" {
  {
    echo "[$(run_of completed success ci)]"
    echo "[$(run_of completed success ci),$(run_of in_progress "" release)]"
    echo "[$(run_of completed success ci),$(run_of completed failure release)]"
  } >"$TMP/frames"
  run "$WAIT_CI" me/app abc123
  [ "$status" -eq 1 ]
}

@test "a repository without workflows is exit 3 without waiting" {
  export GH_WORKFLOWS=""
  echo '[]' >"$TMP/frames"
  run "$WAIT_CI" me/app abc123
  [ "$status" -eq 3 ]
  ! grep -q '^run list' "$TMP/calls"
}

@test "no run for the commit within the register window is exit 3" {
  echo '[]' >"$TMP/frames"
  WAIT_CI_REGISTER=0 run "$WAIT_CI" me/app abc123
  [ "$status" -eq 3 ]
}

@test "runs still in progress at the timeout are exit 4" {
  echo "[$(run_of in_progress "")]" >"$TMP/frames"
  WAIT_CI_TIMEOUT=0 run "$WAIT_CI" me/app abc123
  [ "$status" -eq 4 ]
}

@test "a gh failure is not reported as a verdict" {
  cat >"$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh: not logged in" >&2
exit 4
GH
  run "$WAIT_CI" me/app abc123
  [ "$status" -eq 2 ]
}
