#!/usr/bin/env bats
# Tests for skills/autopilot/scripts/reviewed-head.sh.
#
# Contract under test: a PR head is covered only by a PASS report of a full
# review of it, by a PASS delta review from a covered ancestor, or (given the
# default branch) by a merge of the default branch into a covered head that
# shares no file with the PR. A commit added after the last review is not.

bats_require_minimum_version 1.5.0

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  export GIT_CONFIG_GLOBAL=/dev/null
  REVIEWED_HEAD="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)/skills/autopilot/scripts/reviewed-head.sh"
  REPO="$BATS_TEST_TMPDIR/repo"
  REVIEWS="$BATS_TEST_TMPDIR/reviews"
  mkdir -p "$REVIEWS/prs"
  git init -q -b main "$REPO"
  commit_file a.txt base
  git -C "$REPO" switch -q -c pr
  commit_file pr.txt change
  REVIEWED="$(git -C "$REPO" rev-parse HEAD)"
}

# commit_file <file> <content> — commit one file on the current branch.
commit_file() {
  echo "$2" >"$REPO/$1"
  git -C "$REPO" add "$1"
  git -C "$REPO" commit -q -m "$1 $2"
}

# report <name> <assessment> — write a review report under reviews/prs.
report() {
  printf '# Review Report\n\n## Overall Assessment\n\n**%s**\n' "$2" >"$REVIEWS/prs/$1.md"
}

@test "a head with a passing full review is covered" {
  report "7-${REVIEWED:0:7}" PASS
  run -0 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 "$REVIEWED"
  [ "$output" = "$REVIEWS/prs/7-${REVIEWED:0:7}.md" ]
}

@test "a fix committed after the last review is not covered" {
  report "7-${REVIEWED:0:7}" PASS
  commit_file pr.txt medium-fix
  run -1 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 HEAD
  [[ "$output" == *"no passing review covers"* ]]
}

@test "a review that needs revision does not cover its head" {
  report "7-${REVIEWED:0:7}" NEEDS_REVISION
  report "7-${REVIEWED:0:7}-2" NEEDS_REVISION
  run -1 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 "$REVIEWED"
}

@test "a verdict written as an Assessment line is read too" {
  printf '## Summary\n\n**Assessment**: PASS\n\n- PASS: proceed\n' >"$REVIEWS/prs/7-${REVIEWED:0:7}.md"
  run -0 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 "$REVIEWED"
  printf '**Assessment**: NEEDS_REVISION\n\n- PASS: after the fix\n' >"$REVIEWS/prs/7-${REVIEWED:0:7}.md"
  run -1 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 "$REVIEWED"
}

@test "a passing delta review from a covered head covers the fix" {
  report "7-${REVIEWED:0:7}" PASS
  commit_file pr.txt medium-fix
  fix="$(git -C "$REPO" rev-parse HEAD)"
  report "7-${REVIEWED:0:7}..${fix:0:7}" PASS
  run -0 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 "$fix"
  [ "$output" = "$REVIEWS/prs/7-${REVIEWED:0:7}..${fix:0:7}.md" ]
}

@test "a delta review from an unreviewed head does not cover the fix" {
  commit_file pr.txt medium-fix
  fix="$(git -C "$REPO" rev-parse HEAD)"
  report "7-${REVIEWED:0:7}..${fix:0:7}" PASS
  run -1 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 "$fix"
}

@test "a merge of the default branch that shares no file is covered only when asked" {
  report "7-${REVIEWED:0:7}" PASS
  git -C "$REPO" switch -q main
  commit_file other.txt landed
  git -C "$REPO" switch -q pr
  git -C "$REPO" merge -q --no-edit main
  run -1 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 HEAD
  run -0 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 HEAD main
  [[ "$output" == "$REVIEWS/prs/7-${REVIEWED:0:7}.md (then a merge of main sharing no file"* ]]
}

@test "a merge of the default branch that shares a file is not covered" {
  report "7-${REVIEWED:0:7}" PASS
  git -C "$REPO" switch -q main
  commit_file a.txt landed
  git -C "$REPO" switch -q pr
  commit_file a.txt pr-side
  head="$(git -C "$REPO" rev-parse HEAD)"
  report "7-${head:0:7}" PASS
  git -C "$REPO" merge -q --no-edit -X ours main
  run -1 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 HEAD main
}

@test "an unknown commit is a usage error" {
  run -2 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7 deadbeef
  run -2 bash "$REVIEWED_HEAD" "$REPO" "$REVIEWS" 7
}
