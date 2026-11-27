#!/usr/bin/env bash
# guardrail.sh — Tell which changed files are guardrails, and hold a pull
# request that changes one until a person approves it.
#
# A guardrail is a file that decides what an agent may send out or merge: the
# hooks, the autonomy mode, the deny rules of a goal session, the autopilot
# procedure, and the definition of CI itself. An agent that could change one
# and merge the change itself would be setting its own limits.
#
#   guardrail.sh paths
#       Reads file names on stdin, one per line, and prints the guardrails
#       among them. Exit 0 when there is none, 1 when there is one.
#
#   guardrail.sh gate <owner/name> <pr> [<action>]
#       For CI. Prints the guardrails the pull request changes (renames count
#       under both names). Exit 0 when there is none, or when the pull request
#       carries the label `human-approved`; 1 otherwise. With <action>
#       `synchronize` (new commits were pushed) the label is removed first: an
#       approval covers the commits a person saw, not later ones.
#
# The label is added in the GitHub UI by a person. scripts/hooks/outbound-guard.sh
# denies an agent's attempt to add it.
#
# Exit status: 0 and 1 as above, 2 usage error or gh failed.
# Dependencies: bash; gh for `gate`.
set -u

LABEL=human-approved

is_guardrail() {
  case "$1" in
    .github/*|scripts/ci/*|scripts/hooks/*|orca/settings/*) return 0 ;;
    mise.toml|tests/run.sh|tests/setup_suite.bash) return 0 ;;
    scripts/lib/autonomy.sh|scripts/lib/guard-deps.sh) return 0 ;;
    hooks/hooks.json|hooks.json|skills/autopilot/SKILL.md) return 0 ;;
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
    [ $# -ge 3 ] || fail "usage: guardrail.sh gate <owner/name> <pr> [<action>]"
    repo="$2" pr="$3" action="${4:-}"
    files="$(gh api "repos/$repo/pulls/$pr/files" --paginate \
      --jq '.[] | .filename, (.previous_filename // empty)')" || fail "cannot list the files of $repo#$pr"
    if touched="$(printf '%s\n' "$files" | guardrails_in)"; then
      echo "guardrail: $repo#$pr changes no guardrail"
      exit 0
    fi
    labels="$(gh api "repos/$repo/issues/$pr/labels" --paginate --jq '.[].name')" \
      || fail "cannot read the labels of $repo#$pr"
    if [ "$action" = synchronize ] && printf '%s\n' "$labels" | grep -qx "$LABEL"; then
      gh api --method DELETE "repos/$repo/issues/$pr/labels/$LABEL" >/dev/null \
        || fail "cannot remove the label $LABEL from $repo#$pr after new commits"
      labels="$(printf '%s\n' "$labels" | grep -vx "$LABEL")"
      echo "guardrail: new commits were pushed, so the label $LABEL was removed"
    fi
    echo "guardrail: $repo#$pr changes these guardrails:"
    printf '%s\n' "$touched" | sed 's/^/  /'
    if printf '%s\n' "$labels" | grep -qx "$LABEL"; then
      echo "guardrail: approved by the label $LABEL"
      exit 0
    fi
    echo "guardrail: a person has to review these changes and add the label $LABEL in the GitHub UI"
    exit 1
    ;;
  *) fail "usage: guardrail.sh paths | gate <owner/name> <pr> [<action>]" ;;
esac
