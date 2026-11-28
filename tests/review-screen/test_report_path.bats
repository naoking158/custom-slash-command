#!/usr/bin/env bats
# Tests for skills/review/scripts/report-path.sh.
#
# Contract under test:
#   - With --report-dir, a second review of the same PR never gets the name of
#     an earlier one, whichever of .md / .json / .html that one left behind.
#   - The name carries the head (and the start of a delta review) it read.
#   - Without --report-dir the path is docs/reviews/<type>/<id>, every time,
#     except that a delta review gets its own name.

bats_require_minimum_version 1.5.0

setup() {
  REPORT_PATH="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/skills/review/scripts/report-path.sh"
  DIR="$BATS_TEST_TMPDIR/reviews"
  HEAD=0123456789abcdef0123456789abcdef01234567
  NEXT=fedcba9876543210fedcba9876543210fedcba98
}

@test "a second review of the same head keeps the first report" {
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$HEAD"
  first="$output"
  [ "$first" = "$DIR/prs/52-0123456" ]
  mkdir -p "$DIR/prs"
  echo round1 >"$first.md"
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$HEAD"
  [ "$output" = "$DIR/prs/52-0123456-2" ]
  echo round2 >"$output.md"
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$HEAD"
  [ "$output" = "$DIR/prs/52-0123456-3" ]
  [ "$(cat "$first.md")" = round1 ]
}

@test "a leftover .json or .html also takes the name" {
  mkdir -p "$DIR/prs"
  : >"$DIR/prs/52-0123456.json"
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$HEAD"
  [ "$output" = "$DIR/prs/52-0123456-2" ]
  : >"$DIR/prs/52-0123456--be.html"
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$HEAD" --perspective be
  [ "$output" = "$DIR/prs/52-0123456-2--be" ]
}

@test "a new head and a delta review get their own names" {
  mkdir -p "$DIR/prs"
  : >"$DIR/prs/52-0123456.md"
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$NEXT"
  [ "$output" = "$DIR/prs/52-fedcba9" ]
  run -0 bash "$REPORT_PATH" --report-dir "$DIR" --type prs --id 52 --head "$NEXT" --since "$HEAD"
  [ "$output" = "$DIR/prs/52-0123456..fedcba9" ]
}

@test "without --report-dir the path stays docs/reviews/<type>/<id>" {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p docs/reviews/prs
  : >docs/reviews/prs/52.md
  run -0 bash "$REPORT_PATH" --type prs --id 52 --head "$HEAD"
  [ "$output" = "docs/reviews/prs/52" ]
  run -0 bash "$REPORT_PATH" --type plans --id auth --perspective be
  [ "$output" = "docs/reviews/plans/auth--be" ]
}

@test "without --report-dir a delta review does not replace the full one" {
  cd "$BATS_TEST_TMPDIR"
  run -0 bash "$REPORT_PATH" --type prs --id 52 --head "$NEXT" --since "$HEAD"
  [ "$output" = "docs/reviews/prs/52-0123456..fedcba9" ]
}

@test "usage errors exit 2" {
  run -2 bash "$REPORT_PATH" --type prs
  run -2 bash "$REPORT_PATH" --type prs --id 52 --since "$HEAD"
  run -2 bash "$REPORT_PATH" --type prs --id 52 --bogus x
}
