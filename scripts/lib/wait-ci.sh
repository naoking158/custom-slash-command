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
# Exit status (the verdict; do not append `echo` or a pipe when calling):
#   0  every run concluded success, skipped or neutral
#   1  a run concluded otherwise (failure, cancelled, timed out ...)
#   2  usage error, or gh failed
#   3  no run for <sha>: the repository has no workflow, or none appeared
#      within WAIT_CI_REGISTER seconds
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
register="${WAIT_CI_REGISTER:-120}"
timeout="${WAIT_CI_TIMEOUT:-3600}"
interval="${WAIT_CI_INTERVAL:-15}"

report() {
  printf '%s' "$json" | jq -r --arg repo "$repo" '.[]
    | "\(if .status == "completed" then .conclusion else .status end)\t\(.workflowName)\thttps://github.com/\($repo)/actions/runs/\(.databaseId)"'
}

workflows="$(gh workflow list -R "$repo" --json id --jq length)" || fail "gh workflow list failed for $repo"
case "$workflows" in
  ""|0) echo "CI: none ($repo has no workflow)"; exit 3 ;;
esac

SECONDS=0
settled=""
while :; do
  json="$(gh run list -R "$repo" --commit "$sha" --json databaseId,workflowName,status,conclusion)" \
    || fail "gh run list failed for $repo"
  total="$(printf '%s' "$json" | jq 'length')" || fail "unreadable run list"
  pending="$(printf '%s' "$json" | jq '[.[] | select(.status != "completed")] | length')"
  if [ "$total" -eq 0 ]; then
    [ "$SECONDS" -lt "$register" ] || { echo "CI: none (no run for $sha after ${register}s)"; exit 3; }
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
