#!/usr/bin/env bash
# wait-ci.sh — Wait for the GitHub Actions runs of one commit and report them.
#
#   scripts/lib/wait-ci.sh <owner/name> <sha>
#
# `gh pr checks --watch` and `gh run list --branch` answer for what GitHub has
# registered so far. Right after a push or a merge that is nothing yet, or the
# previous commit's run, so they report no result or the wrong commit's. This
# script waits until a run for <sha> exists and until every run for <sha> has
# completed, then prints one line per run and a `CI:` summary line.
#
# <sha> is the full 40-character commit sha (`git rev-parse HEAD`): GitHub
# matches nothing on an abbreviated one. Only the runs the commit itself
# triggered count (push, pull_request, pull_request_target, merge_group): a
# scheduled workflow also runs on the default branch's head commit, and its
# result says nothing about the change. Checks that are not GitHub Actions
# runs are not seen.
#
# Exit status (the verdict; do not append `echo` or a pipe when calling):
#   0  every run concluded success, skipped or neutral
#   1  a run concluded otherwise (failure, cancelled, timed out ...)
#   2  usage error (an abbreviated sha, or one the repository does not
#      have, included), or gh failed
#   3  no run for <sha>, which the repository has: the repository has no
#      workflow, or none appeared within WAIT_CI_REGISTER seconds
#   4  runs were still in progress after WAIT_CI_TIMEOUT seconds
#
# Environment, in seconds: WAIT_CI_REGISTER (default 120), WAIT_CI_TIMEOUT
# (default 3600), WAIT_CI_INTERVAL between polls (default 15).
# Dependencies: bash, gh, jq.
set -u

fail() {
  echo "wait-ci: $1" >&2
  exit 2
}

repo="${1:-}"
sha="${2:-}"
[ -n "$repo" ] && [ -n "$sha" ] || fail "usage: wait-ci.sh <owner/name> <sha>"
case "$sha" in
  *[!0-9a-f]*) fail "<sha> must be the full 40-character commit sha, got: $sha" ;;
esac
[ "${#sha}" -eq 40 ] || fail "<sha> must be the full 40-character commit sha, got: $sha"
register="${WAIT_CI_REGISTER:-120}"
timeout="${WAIT_CI_TIMEOUT:-3600}"
interval="${WAIT_CI_INTERVAL:-15}"

# none MESSAGE — exit 3 with MESSAGE, or exit 2 when the repository has no
# commit <sha>.
none() {
  local err
  err="$(gh api "repos/$repo/commits/$sha" --jq .sha 2>&1 >/dev/null)" \
    || fail "no commit $sha in $repo, or gh failed (pass \$(git rev-parse HEAD)): $err"
  echo "CI: none ($1)"
  exit 3
}

report() {
  printf '%s' "$json" | jq -r --arg repo "$repo" '.[]
    | "\(if .status == "completed" then .conclusion else .status end)\t\(.workflowName) (\(.event))\thttps://github.com/\($repo)/actions/runs/\(.databaseId)"'
}

workflows="$(gh workflow list -R "$repo" --json id --jq length)" || fail "gh workflow list failed for $repo"
case "$workflows" in
  ""|0) none "$repo has no workflow" ;;
esac

SECONDS=0
settled=""
while :; do
  json="$(gh run list -R "$repo" --commit "$sha" -L 200 --json databaseId,workflowName,status,conclusion,event)" \
    || fail "gh run list failed for $repo"
  json="$(printf '%s' "$json" | jq -c '[.[] | select(.event == "push" or .event == "pull_request"
    or .event == "pull_request_target" or .event == "merge_group")]')" || fail "unreadable run list"
  total="$(printf '%s' "$json" | jq 'length')"
  pending="$(printf '%s' "$json" | jq '[.[] | select(.status != "completed")] | length')"
  if [ "$total" -eq 0 ]; then
    [ "$SECONDS" -lt "$register" ] || none "no run for $sha after ${register}s"
  elif [ "$pending" -gt 0 ]; then
    [ "$SECONDS" -lt "$timeout" ] || { report; echo "CI: still running ($sha)"; exit 4; }
    settled=""
  elif [ "$settled" = "$total" ]; then
    break
  else
    settled="$total"
  fi
  sleep "$interval"
done

report
red="$(printf '%s' "$json" | jq '[.[] | select(.conclusion != "success" and .conclusion != "skipped" and .conclusion != "neutral")] | length')"
if [ "$red" -eq 0 ]; then
  echo "CI: green ($sha)"
  exit 0
fi
echo "CI: red ($sha)"
exit 1
