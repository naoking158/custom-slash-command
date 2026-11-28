#!/usr/bin/env bats
# Tests for skills/retro/scripts/sync-origin.sh against a local bare origin
# whose default branch is `trunk`.
#
# Contract under test:
#   - A clean checkout on the default branch that is behind is fast-forwarded.
#   - A checkout on another branch, with uncommitted changes, or with commits
#     of its own is left alone; base still names the fetched origin/<default>.
#   - The default branch comes from origin, also when origin/HEAD is missing.
#   - A failed fetch exits 1 and leaves the checkout alone.

bats_require_minimum_version 1.5.0

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  SYNC="$REPO_ROOT/skills/retro/scripts/sync-origin.sh"
  TMP="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  export HOME="$TMP/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  mkdir -p "$HOME"

  git init -q --bare -b trunk "$TMP/origin.git"
  git clone -q "$TMP/origin.git" "$TMP/up" 2>/dev/null
  git -C "$TMP/up" checkout -q -b trunk
  echo one > "$TMP/up/a"
  git -C "$TMP/up" add a
  git -C "$TMP/up" commit -q -m one
  git -C "$TMP/up" push -q origin trunk

  git clone -q "$TMP/origin.git" "$TMP/co"
  OLD="$(git -C "$TMP/co" rev-parse HEAD)"

  echo two > "$TMP/up/a"
  git -C "$TMP/up" commit -q -am two
  git -C "$TMP/up" push -q origin trunk
  NEW="$(git -C "$TMP/up" rev-parse HEAD)"
}

head_of() { git -C "$TMP/co" rev-parse HEAD; }

@test "sync: clean checkout on the default branch is fast-forwarded" {
  run "$SYNC" "$TMP/co"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "base: origin/trunk $NEW" ]
  [ "${lines[1]}" = "checkout: updated ${OLD:0:7}..${NEW:0:7}" ]
  [ "$(head_of)" = "$NEW" ]
}

@test "sync: default branch is asked from origin when origin/HEAD is missing" {
  git -C "$TMP/co" remote set-head origin --delete
  run "$SYNC" "$TMP/co"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "base: origin/trunk $NEW" ]
  [ "$(head_of)" = "$NEW" ]
}

@test "sync: uncommitted changes keep the checkout where it is" {
  echo dirty > "$TMP/co/a"
  run "$SYNC" "$TMP/co"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "base: origin/trunk $NEW" ]
  [ "${lines[1]}" = "checkout: kept (uncommitted changes)" ]
  [ "$(head_of)" = "$OLD" ]
  [ "$(cat "$TMP/co/a")" = dirty ]
}

@test "sync: another branch keeps the checkout where it is" {
  git -C "$TMP/co" checkout -q -b work
  run "$SYNC" "$TMP/co"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "base: origin/trunk $NEW" ]
  [ "${lines[1]}" = "checkout: kept (on branch work, not trunk)" ]
  [ "$(head_of)" = "$OLD" ]
}

@test "sync: local commits on the default branch are not merged" {
  echo mine > "$TMP/co/b"
  git -C "$TMP/co" add b
  git -C "$TMP/co" commit -q -m mine
  local mine
  mine="$(head_of)"
  run "$SYNC" "$TMP/co"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "checkout: kept (diverged from origin/trunk)" ]
  [ "$(head_of)" = "$mine" ]
}

@test "sync: failed fetch exits 1 and judges on the last fetched ref" {
  git -C "$TMP/co" remote set-url origin "$TMP/missing.git"
  run "$SYNC" "$TMP/co"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "base: origin/trunk $OLD" ]
  [ "${lines[1]}" = "checkout: current" ]
  [[ "${lines[2]}" == "fetch: failed ("* ]]
  [ "$(head_of)" = "$OLD" ]
}
