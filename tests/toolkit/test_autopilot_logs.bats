#!/usr/bin/env bats
# Tests for skills/autopilot/scripts/log-decision.sh, log-task.sh and
# scripts/lib/patch-id.sh.
#
# Contract under test:
#   - The log scripts write the header once, then append one row per call;
#     every cell stays on one line and a cell that a spreadsheet would run as
#     a formula gets a leading '.
#   - log-task.sh rejects a wrong argument count or an invalid value with
#     exit 2 and writes nothing.
#   - patch-id.sh prints the same id for the same change on different bases, a
#     different id for a different change (whitespace included), `empty` for no
#     change, and exits 2
#     on an invalid ref or outside a repository.

bats_require_minimum_version 1.5.0

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  LOG_DECISION="$REPO_ROOT/skills/autopilot/scripts/log-decision.sh"
  LOG_TASK="$REPO_ROOT/skills/autopilot/scripts/log-task.sh"
  PATCH_ID="$REPO_ROOT/scripts/lib/patch-id.sh"
  TMP="$(mktemp -d -t autopilot-logs-test.XXXXXX)"
  export GIT_CONFIG_GLOBAL=/dev/null
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# field <file> <line> <column> — one cell of a TSV file.
field() {
  sed -n "${2}p" "$1" | cut -f"$3"
}

@test "log-decision writes the header once and appends a row per call" {
  log="$TMP/new/dir/decisions.tsv"
  run -0 "$LOG_DECISION" "$log" start "resume" "new run" "progress.md" ok
  run -0 "$LOG_DECISION" "$log" task1 "split PR" "too large" "#3" done
  [ "$(sed -n 1p "$log")" = "$(printf 'ts\tphase\tdecision\twhy\tevidence\tresult')" ]
  [ "$(wc -l <"$log" | tr -d ' ')" -eq 3 ]
  [ "$(grep -c '^ts' "$log")" -eq 1 ]
  [[ "$(field "$log" 2 1)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
  [ "$(field "$log" 3 3)" = "split PR" ]
  [ "$(field "$log" 3 6)" = "done" ]
}

@test "log-decision flattens tabs and newlines and quotes formula-like cells" {
  log="$TMP/decisions.tsv"
  run -0 "$LOG_DECISION" "$log" "$(printf 'a\tb')" "$(printf 'c\nd')" "$(printf 'e\rf')" "=SUM(A1)" "+1"
  [ "$(wc -l <"$log" | tr -d ' ')" -eq 2 ]
  [ "$(sed -n 2p "$log" | awk -F'\t' '{print NF}')" -eq 6 ]
  [ "$(field "$log" 2 2)" = "a b" ]
  [ "$(field "$log" 2 3)" = "c d" ]
  [ "$(field "$log" 2 4)" = "e f" ]
  [ "$(field "$log" 2 5)" = "'=SUM(A1)" ]
  [ "$(field "$log" 2 6)" = "'+1" ]
  run -0 "$LOG_DECISION" "$log" "-x" "@here" "mid=dle" "" ""
  [ "$(field "$log" 3 2)" = "'-x" ]
  [ "$(field "$log" 3 3)" = "'@here" ]
  [ "$(field "$log" 3 4)" = "mid=dle" ]
}

@test "log-decision with a wrong argument count exits 2 and writes nothing" {
  run -2 "$LOG_DECISION" "$TMP/decisions.tsv" start decision why evidence
  [[ "$output" == usage:* ]]
  [ ! -e "$TMP/decisions.tsv" ]
}

@test "log-task appends a row for every valid value" {
  log="$TMP/tasks.tsv"
  for v in pass pass_after_fix fail blocked unverified; do
    run -0 "$LOG_TASK" "$log" "v-$v" auto/x/01 "#1" 0 "$v" none merged
  done
  for c in green red none skipped pending; do
    run -0 "$LOG_TASK" "$log" "c-$c" auto/x/01 "#1" 1 pass "$c" draft
  done
  for o in merged draft stopped skipped; do
    run -0 "$LOG_TASK" "$log" "o-$o" auto/x/01 "-" 12 pass green "$o"
  done
  [ "$(sed -n 1p "$log")" = "$(printf 'ts\ttask_id\tbranch\tpr\treview_rounds\tverify\tci\toutcome')" ]
  [ "$(wc -l <"$log" | tr -d ' ')" -eq 15 ]
  [ "$(field "$log" 3 6)" = "pass_after_fix" ]
  [ "$(field "$log" 11 7)" = "pending" ]
  [ "$(field "$log" 15 2)" = "o-skipped" ]
  [ "$(field "$log" 15 4)" = "'-" ]
  [ "$(field "$log" 15 5)" = "12" ]
}

@test "log-task rejects invalid values with exit 2 and writes nothing" {
  log="$TMP/tasks.tsv"
  run -2 "$LOG_TASK" "$log" t1 b "#1" two pass none merged
  run -2 "$LOG_TASK" "$log" t1 b "#1" -1 pass none merged
  run -2 "$LOG_TASK" "$log" t1 b "#1" 1 PASS none merged
  run -2 "$LOG_TASK" "$log" t1 b "#1" 1 pass yellow merged
  run -2 "$LOG_TASK" "$log" t1 b "#1" 1 pass none closed
  run -2 "$LOG_TASK" "$log" "" b "#1" 1 pass none merged
  run -2 "$LOG_TASK" "$log" "$(printf 't\t1')" b "#1" 1 pass none merged
  run -2 "$LOG_TASK" "$log" t1 b "#1" 1 pass none
  [[ "$output" == usage:* ]]
  [ ! -e "$log" ]
}

# git_in <dir> <args...> — git with a fixed identity.
git_in() {
  local dir="$1"
  shift
  git -C "$dir" -c user.name=t -c user.email=t@t "$@"
}

# make_repo — $TMP/repo with base commit b0 (tags b0), a second base b1 that
# changes another file, and branches applying the same or a different change.
make_repo() {
  R="$TMP/repo"
  git init -q -b main "$R"
  printf 'one\ntwo\nthree\n' >"$R/a.txt"
  printf 'x\n' >"$R/other.txt"
  git_in "$R" add a.txt other.txt
  git_in "$R" commit -q -m b0
  git_in "$R" tag b0
  printf 'y\n' >"$R/other.txt"
  git_in "$R" commit -q -am b1
  git_in "$R" tag b1
  git_in "$R" checkout -q -b on-b0 b0
  printf 'one\nTWO\nthree\n' >"$R/a.txt"
  git_in "$R" commit -q -am change
  git_in "$R" checkout -q -b on-b1 b1
  printf 'one\nTWO\nthree\n' >"$R/a.txt"
  git_in "$R" commit -q -am change
  git_in "$R" checkout -q -b different b0
  printf 'one\n2\nthree\n' >"$R/a.txt"
  git_in "$R" commit -q -am different
}

@test "patch-id is the same for the same change on different bases" {
  make_repo
  run -0 "$PATCH_ID" b0 on-b0 "$R"
  first="$output"
  [[ "$first" =~ ^[0-9a-f]{40}$ ]]
  run -0 "$PATCH_ID" b1 on-b1 "$R"
  [ "$output" = "$first" ]
  run -0 "$PATCH_ID" b0 different "$R"
  [[ "$output" =~ ^[0-9a-f]{40}$ ]]
  [ "$output" != "$first" ]
}

@test "patch-id differs when changes differ only in whitespace" {
  make_repo
  git_in "$R" checkout -q -b indent4 b0
  printf 'one\n    two\nthree\n' >"$R/a.txt"
  git_in "$R" commit -q -am indent4
  git_in "$R" checkout -q -b indent1 b0
  printf 'one\n two\nthree\n' >"$R/a.txt"
  git_in "$R" commit -q -am indent1
  run -0 "$PATCH_ID" b0 indent4 "$R"
  four="$output"
  run -0 "$PATCH_ID" b0 indent1 "$R"
  [ "$output" != "$four" ]
}

@test "patch-id prints empty for no change and defaults to the current directory" {
  make_repo
  cd "$R"
  run -0 "$PATCH_ID" b0 b0
  [ "$output" = "empty" ]
}

@test "patch-id exits 2 on an invalid ref, outside a repository, or a wrong argument count" {
  make_repo
  run -2 "$PATCH_ID" b0 no-such-ref "$R"
  [[ "$output" == *no-such-ref* ]]
  mkdir "$TMP/plain"
  run -2 "$PATCH_ID" HEAD HEAD "$TMP/plain"
  run -2 "$PATCH_ID" b0
  [[ "$output" == usage:* ]]
  run -2 "$PATCH_ID" b0 b1 "$R" extra
}
