#!/usr/bin/env bats
# Tests for the approval-label rule of scripts/hooks/outbound-guard.sh.
#
# Contract under test:
#   - An agent cannot add the label `human-approved` with gh pr / gh issue,
#     rename a label to it, or write labels through gh api, in any mode.
#   - Other labels, and commands that only read or mention the label, are
#     left alone.
#   - A label the command line does not show (a variable) is denied.

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARD="$REPO_ROOT/scripts/hooks/outbound-guard.sh"
  TMP="$(mktemp -d -t guard-label.XXXXXX)"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" remote add origin git@github.com:me/app.git
  git -C "$REPO" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature/x
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

decision_for() {
  local payload verdict
  payload="$(jq -cn --arg c "$1" --arg d "$REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}')"
  verdict="$(printf '%s' "$payload" | "$GUARD")"
  [ -n "$verdict" ] || { echo allow; return; }
  printf '%s' "$verdict" | jq -r '.hookSpecificOutput.permissionDecision'
}

@test "adding the approval label with gh pr or gh issue is denied" {
  for command in \
    'gh pr edit 3 --add-label human-approved' \
    'gh pr edit 3 --add-label Human-Approved' \
    'gh pr edit 3 --add-label "bug,human-approved"' \
    'gh pr edit 3 --add-label=human-approved' \
    'gh pr edit 3 --add-label human-"approved"' \
    $'gh pr edit 3 \\\n  --add-label human-approved' \
    'gh pr create --draft --title t --body b --label human-approved' \
    'gh pr create --draft --title t --body b -l human-approved' \
    'gh issue edit 3 --add-label human-approved'; do
    [ "$(decision_for "$command")" = "deny" ]
  done
}

@test "a label the command line does not show is denied" {
  for command in 'L=human-approved; gh pr edit 3 --add-label "$L"' 'gh pr edit 3 --add-label "$(cat label.txt)"'; do
    [ "$(decision_for "$command")" = "deny" ]
  done
}

@test "renaming a label to the approval label is denied" {
  [ "$(decision_for 'gh label edit bug --name human-approved')" = "deny" ]
}

@test "label writes through gh api are denied whatever the label" {
  for command in \
    'gh api --method POST repos/me/app/issues/3/labels -f "labels[]=human-approved"' \
    'gh api --method POST repos/me/app/issues/3/labels -f "labels[]=bug"' \
    'gh api --method PATCH repos/me/app/labels/bug -f new_name=human-approved' \
    $'gh api graphql -f query=\'mutation { addLabelsToLabelable(input: {labelableId: "x", labelIds: ["y"]}) { clientMutationId } }\'' \
    $'echo \'{"labels":["human-approved"]}\' | gh api --method POST repos/me/app/issues/3/labels --input -'; do
    [ "$(decision_for "$command")" = "deny" ]
  done
}

@test "the rule holds in strict and in ship mode" {
  [ "$(decision_for 'gh pr edit 3 --add-label human-approved')" = "deny" ]
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"
  [ "$(decision_for 'gh pr edit 3 --add-label human-approved')" = "deny" ]
}

@test "other labels, and reading or mentioning the label, are allowed" {
  for command in \
    'gh pr edit 3 --add-label bug' \
    'gh pr list --label human-approved' \
    'gh label create human-approved --description "a person approved a guardrail change"' \
    'gh pr view 3 --json labels' \
    'gh api repos/me/app/issues/3/labels' \
    'echo human-approved'; do
    [ "$(decision_for "$command")" = "allow" ]
  done
}
