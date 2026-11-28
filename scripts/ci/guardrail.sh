#!/usr/bin/env bash
# guardrail.sh — Tell which changed files are guardrails, and hold a pull
# request that changes one until a person approves it.
#
# A guardrail is a file that decides what an agent may send out or merge: the
# hooks (with the Go source and the built binaries of outbound-guard), the
# permission settings, the autonomy mode, the deny rules of a goal
# session and the script that applies them, the autopilot procedure, and the
# definition of CI with the script that reads its verdict. An agent that could change one
# and merge the change itself would be setting its own limits.
#
#   guardrail.sh paths
#       Reads file names on stdin, one per line, and prints the guardrails
#       among them. Exit 0 when there is none, 1 when there is one.
#
#   guardrail.sh gate <owner/name> <pr>
#       For CI, run from a checkout of the base branch. Prints the guardrails
#       the pull request changes (a renamed file counts under both names).
#       Exit 0 when there is none; when the pull request carries the label
#       `human-approved` and the label was added after the last push to its
#       branch; or when it only tightens outbound-guard (below). 1 otherwise.
#       An approval covers the commits a person saw, so a push after it makes
#       it stale: remove the label and add it again. The times compared are
#       GitHub's (the label event and the push activity), so the order of CI
#       runs does not matter.
#
#   guardrail.sh tighten <base> <head>
#       The local half of the outbound-guard exception, for two commits in
#       this repository. Exit 0 when the change from base to head passes it.
#
# The outbound-guard exception. A pull request passes without the label when
# all of these hold; HEAD_SHA in the environment names the head commit CI
# judges, and without it there is no exception:
#   - It comes from a branch of this repository, HEAD_SHA is its head now, the
#     checkout this script runs from is the base branch's tip now, and the head
#     contains that tip, so the merge result is the head.
#   - It changes only non-test .go files in internal/outboundguard (mode
#     100644), internal/outboundguard/guard_test.go, and the four
#     bin/my-toolkit-<os>-<arch> (mode 100755).
#   - The test files are the base's, except cases added to the guardTests
#     table that only drive the test's fixture (the base's cases stay byte
#     for byte and in order); every non-test file builds
#     on all four platforms; the non-test files import nothing the base's do
#     not (scripts/ci/tighten checks the source without running it).
#   - scripts/build-bin.sh rebuilds bin/ from the head byte for byte.
#   - Last, the head's go test of internal/outboundguard passes and runs at
#     least as many guardTests cases as the head has, so every case the base
#     had still decides the same way.
# What it does not stop: a change that loosens the guard for an input no
# case covers; and code written to deceive the check, such as code that
# behaves differently when Env holds the fixture's values or after some
# time, or that tampers with the job while go test runs it. The exception
# catches a mistake in a fix, not an agent set on cheating; a person sees
# such code only by reading the diff. The exception holds only when the base
# branch requires this check and requires branches to be up to date before
# merging; otherwise the base can move after this check and the merge result
# is no longer the head it judged.
#
# The label is added in the GitHub UI by a person. scripts/hooks/outbound-guard.sh
# denies an agent's attempts to add it.
#
# Exit status: 0 and 1 as above, 2 usage error or gh failed.
# Dependencies: bash, grep, sed; gh for `gate`; git, go and tar for the
# exception.
set -u

LABEL=human-approved

is_guardrail() {
  case "$1" in
    .github/*|.claude/*|scripts/ci/*|scripts/hooks/*|orca/settings/*) return 0 ;;
    mise.toml|tests/run.sh|tests/setup_suite.bash) return 0 ;;
    scripts/lib/autonomy.sh|scripts/lib/guard-deps.sh|scripts/lib/wait-ci.sh) return 0 ;;
    hooks/hooks.json|hooks.json|orca/bin/start-goal|skills/autopilot/SKILL.md) return 0 ;;
    bin/*|cmd/*|internal/outboundguard/*|go.mod|go.sum|scripts/build-bin.sh) return 0 ;;
  esac
  return 1
}

# in_tighten_scope NAME — whether NAME may change in a pull request that only
# tightens outbound-guard.
in_tighten_scope() {
  case "$1" in
    bin/my-toolkit-darwin-arm64|bin/my-toolkit-darwin-amd64|bin/my-toolkit-linux-arm64|bin/my-toolkit-linux-amd64) return 0 ;;
    internal/outboundguard/*/*) return 1 ;;
    internal/outboundguard/*.go) return 0 ;;
  esac
  return 1
}

# guardrails_in — print the guardrails among the names on stdin; fail when
# there is one.
guardrails_in() {
  local name found=0
  while IFS= read -r name || [ -n "$name" ]; do
    is_guardrail "$name" || continue
    printf '%s\n' "$name"
    found=1
  done
  [ "$found" -eq 0 ]
}

fail() {
  echo "guardrail: $1" >&2
  exit 2
}

# label_approved REPO PR — whether PR carries the label, added after the last
# push to its branch. Exits 2 when gh fails.
label_approved() {
  local repo="$1" pr="$2" labels approved head pushed
  labels="$(gh api "repos/$repo/issues/$pr/labels" --paginate --jq '.[].name')" \
    || fail "cannot read the labels of $repo#$pr"
  if ! printf '%s\n' "$labels" | grep -qix "$LABEL"; then
    echo "guardrail: a person has to review these changes and add the label $LABEL in the GitHub UI"
    return 1
  fi
  approved="$(gh api "repos/$repo/issues/$pr/events" --paginate \
    --jq ".[] | select(.event == \"labeled\" and (.label.name | ascii_downcase) == \"$LABEL\") | .created_at")" \
    || fail "cannot read the label events of $repo#$pr"
  approved="$(printf '%s\n' "$approved" | sort | tail -n 1)"
  head="$(gh api "repos/$repo/pulls/$pr" --jq '"\(.head.repo.full_name) \(.head.ref)"')" \
    || fail "cannot read the head of $repo#$pr"
  pushed="$(gh api --method GET "repos/${head%% *}/activity" -f "ref=refs/heads/${head#* }" -F per_page=1 \
    --jq '.[0].timestamp // empty')" || fail "cannot read the pushes to ${head#* }"
  [ -n "$approved" ] && [ -n "$pushed" ] || fail "no time for the label ($approved) or the last push ($pushed)"
  if [[ "$approved" > "$pushed" ]]; then
    echo "guardrail: approved by the label $LABEL, added $approved after the last push $pushed"
    return 0
  fi
  echo "guardrail: the label $LABEL was added $approved, not after the last push $pushed."
  echo "guardrail: a person has to review the new commits, remove the label and add it again"
  return 1
}

# only_tightens REPO PR — the outbound-guard exception for PR: the checks
# that need GitHub, then fetch the head and run tighten. Prints why it does
# not apply.
only_tightens() {
  local repo="$1" pr="$2" name pull head_repo head_sha base_ref base_tip status
  [ -n "${HEAD_SHA:-}" ] || return 1
  while IFS= read -r name; do
    in_tighten_scope "$name" || { echo "guardrail: not only tightening outbound-guard: $name is outside it"; return 1; }
  done <<<"$files"
  pull="$(gh api "repos/$repo/pulls/$pr" --jq '"\(.head.repo.full_name) \(.head.sha) \(.base.ref)"')" \
    || fail "cannot read the head of $repo#$pr"
  read -r head_repo head_sha base_ref <<<"$pull"
  [ "$head_repo" = "$repo" ] || { echo "guardrail: not only tightening outbound-guard: the head is in $head_repo"; return 1; }
  [ "$head_sha" = "$HEAD_SHA" ] || { echo "guardrail: not only tightening outbound-guard: the head is now $head_sha, not $HEAD_SHA"; return 1; }
  base_tip="$(gh api "repos/$repo/branches/$base_ref" --jq '.commit.sha')" || fail "cannot read the tip of $base_ref"
  [ "$(git rev-parse HEAD)" = "$base_tip" ] \
    || { echo "guardrail: not only tightening outbound-guard: this run checked out $(git rev-parse HEAD), not the tip $base_tip of $base_ref"; return 1; }
  status="$(gh api "repos/$repo/compare/$base_tip...$head_sha" --jq '.status')" || fail "cannot compare $base_tip with $head_sha"
  [ "$status" = ahead ] || { echo "guardrail: not only tightening outbound-guard: the head is $status of $base_ref; update the branch"; return 1; }
  git fetch -q --no-tags --depth=1 origin "refs/pull/$pr/head" || fail "cannot fetch the head of $repo#$pr"
  [ "$(git rev-parse FETCH_HEAD)" = "$head_sha" ] \
    || { echo "guardrail: not only tightening outbound-guard: fetched $(git rev-parse FETCH_HEAD), not $head_sha"; return 1; }
  tighten "$base_tip" "$head_sha"
}

# tighten BASE HEAD — the local checks of the outbound-guard exception. The
# head's code runs only in the last step. Runs in a subshell to clean up its
# temporary directory on exit.
tighten() (
  local base="$1" head="$2" root diff tmp line meta path mode status cases out bin passed
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  diff="$(git diff --raw --no-renames --no-abbrev "$base" "$head")" || fail "cannot compare $base with $head"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    meta="${line%%$'\t'*}" path="${line#*$'\t'}"
    read -r _ mode _ _ status <<<"$meta"
    in_tighten_scope "$path" || { echo "guardrail: not only tightening outbound-guard: $path is outside it"; return 1; }
    case "$path:$status:$mode" in
      bin/*:[AM]:100755|internal/*:[AM]:100644|internal/*:D:*) ;;
      *) echo "guardrail: not only tightening outbound-guard: $path ($status, mode $mode)"; return 1 ;;
    esac
  done <<<"$diff"
  tmp="$(mktemp -d)" || fail "cannot make a temporary directory"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  mkdir "$tmp/base" "$tmp/head"
  git archive "$base" internal/outboundguard | tar -x -C "$tmp/base" || fail "cannot read $base"
  git archive "$head" | tar -x -C "$tmp/head" || fail "cannot read $head"
  cases="$(cd "$root" && env -u GH_TOKEN go run ./scripts/ci/tighten "$tmp/base/internal/outboundguard" "$tmp/head/internal/outboundguard")" \
    || { echo "guardrail: not only tightening outbound-guard: the source check above failed"; return 1; }
  env -u GH_TOKEN bash "$tmp/head/scripts/build-bin.sh" || { echo "guardrail: not only tightening outbound-guard: bin/ does not build"; return 1; }
  for bin in my-toolkit-darwin-arm64 my-toolkit-darwin-amd64 my-toolkit-linux-arm64 my-toolkit-linux-amd64; do
    [ "$(git hash-object "$tmp/head/bin/$bin")" = "$(git rev-parse "$head:bin/$bin")" ] \
      || { echo "guardrail: not only tightening outbound-guard: bin/$bin is not what scripts/build-bin.sh builds from the head"; return 1; }
  done
  out="$(cd "$tmp/head" && env -u GH_TOKEN go test -count=1 -json ./internal/outboundguard/)" \
    || { echo "guardrail: not only tightening outbound-guard: go test of the head failed"; return 1; }
  passed="$(printf '%s\n' "$out" | grep -cE '"Action":"pass".*"Test":"TestGuard/')"
  [ "$passed" -ge "$cases" ] \
    || { echo "guardrail: not only tightening outbound-guard: go test passed $passed of the $cases cases"; return 1; }
  echo "guardrail: only tightens outbound-guard: $cases cases pass and bin/ is built from the head"
)

case "${1:-}" in
  paths)
    [ $# -eq 1 ] || fail "usage: guardrail.sh paths < file-names"
    guardrails_in
    ;;
  gate)
    [ $# -eq 3 ] || fail "usage: guardrail.sh gate <owner/name> <pr>"
    repo="$2" pr="$3"
    files="$(gh api "repos/$repo/pulls/$pr/files" --paginate \
      --jq '.[] | .filename, (.previous_filename // empty)')" || fail "cannot list the files of $repo#$pr"
    if touched="$(printf '%s\n' "$files" | guardrails_in)"; then
      echo "guardrail: $repo#$pr changes no guardrail"
      exit 0
    fi
    echo "guardrail: $repo#$pr changes these guardrails:"
    printf '%s\n' "$touched" | sed 's/^/  /'

    label_approved "$repo" "$pr" && exit 0
    only_tightens "$repo" "$pr" && exit 0
    exit 1
    ;;
  tighten)
    [ $# -eq 3 ] || fail "usage: guardrail.sh tighten <base> <head>"
    tighten "$2" "$3"
    ;;
  *) fail "usage: guardrail.sh paths | gate <owner/name> <pr> | tighten <base> <head>" ;;
esac
