#!/usr/bin/env bash
# guardrail.sh — Tell which changed files are guardrails, and hold a pull
# request that changes one until a person approves it.
#
# A guardrail is a file that decides what an agent may send out or merge: the
# hooks, the permission settings, the autonomy mode, the deny rules of a goal
# session and the script that applies them, the autopilot procedure, and the
# definition of CI with the script that reads its verdict. An agent that could change one
# and merge the change itself would be setting its own limits.
#
#   guardrail.sh paths
#       Reads file names on stdin, one per line, and prints the guardrails
#       among them. Exit 0 when there is none, 1 when there is one.
#
#   guardrail.sh gate <owner/name> <pr>
#       For CI. Prints the guardrails the pull request changes (a renamed file
#       counts under both names). Exit 0 when there is none, or when the pull
#       request carries the label `human-approved` and the label was added
#       after the last push to its branch; 1 otherwise. An approval covers the
#       commits a person saw, so a push after it makes it stale: remove the
#       label and add it again. The times compared are GitHub's (the label
#       event and the push activity), so the order of CI runs does not matter.
#
# The label is added in the GitHub UI by a person. scripts/hooks/outbound-guard.sh
# denies an agent's attempts to add it.
#
# Exit status: 0 and 1 as above, 2 usage error or gh failed.
# Dependencies: bash, grep, sed; gh for `gate`.
set -u

LABEL=human-approved

is_guardrail() {
  case "$1" in
    .github/*|.claude/*|scripts/ci/*|scripts/hooks/*|orca/settings/*) return 0 ;;
    mise.toml|tests/run.sh|tests/setup_suite.bash) return 0 ;;
    scripts/lib/autonomy.sh|scripts/lib/guard-deps.sh|scripts/lib/wait-ci.sh) return 0 ;;
    hooks/hooks.json|hooks.json|orca/bin/start-goal|skills/autopilot/SKILL.md) return 0 ;;
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

    labels="$(gh api "repos/$repo/issues/$pr/labels" --paginate --jq '.[].name')" \
      || fail "cannot read the labels of $repo#$pr"
    if ! printf '%s\n' "$labels" | grep -qix "$LABEL"; then
      echo "guardrail: a person has to review these changes and add the label $LABEL in the GitHub UI"
      exit 1
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
      exit 0
    fi
    echo "guardrail: the label $LABEL was added $approved, not after the last push $pushed."
    echo "guardrail: a person has to review the new commits, remove the label and add it again"
    exit 1
    ;;
  *) fail "usage: guardrail.sh paths | gate <owner/name> <pr>" ;;
esac
