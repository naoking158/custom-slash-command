#!/usr/bin/env bash
# log-task.sh — Append the outcome of one autopilot task to its tasks.tsv.
#
#   log-task.sh <logfile> <task_id> <branch> <pr> <review_rounds> <verify> <ci> <outcome>
#
#   review_rounds  non-negative integer
#   verify         pass | pass_after_fix | fail | blocked | unverified
#   ci             green | red | none | skipped | pending
#   outcome        merged | draft | stopped | skipped
#
# Columns: ts (UTC ISO 8601) then the arguments after <logfile>. The header is
# written when the file is missing or empty; rows are only ever appended, so a
# task logged again supersedes its earlier row for readers (autopilot-metrics.sh
# takes the last row per task_id). Nothing is written when an argument is invalid.
#
# Exit status: 0 appended, 2 usage error or invalid argument.
set -euo pipefail

usage() {
  echo "usage: log-task.sh <logfile> <task_id> <branch> <pr> <review_rounds> <verify> <ci> <outcome>" >&2
  exit 2
}

invalid() {
  echo "log-task.sh: $1" >&2
  exit 2
}

[ $# -eq 8 ] || usage
logfile="$1" task_id="$2" branch="$3" pr="$4" rounds="$5" verify="$6" ci="$7" outcome="$8"

case "$task_id" in
  "" | *$'\t'* | *$'\n'* | *$'\r'*) invalid "task_id must be non-empty and on one line: '$task_id'" ;;
esac
[[ "$rounds" =~ ^[0-9]+$ ]] || invalid "review_rounds must be a non-negative integer: '$rounds'"
case "$verify" in
  pass | pass_after_fix | fail | blocked | unverified) ;;
  *) invalid "verify must be pass, pass_after_fix, fail, blocked or unverified: '$verify'" ;;
esac
case "$ci" in
  green | red | none | skipped | pending) ;;
  *) invalid "ci must be green, red, none, skipped or pending: '$ci'" ;;
esac
case "$outcome" in
  merged | draft | stopped | skipped) ;;
  *) invalid "outcome must be merged, draft, stopped or skipped: '$outcome'" ;;
esac

. "$(cd "$(dirname "$0")" && pwd)/tsv.sh"

tsv_append "$logfile" $'ts\ttask_id\tbranch\tpr\treview_rounds\tverify\tci\toutcome' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$task_id" "$branch" "$pr" "$rounds" "$verify" "$ci" "$outcome"
