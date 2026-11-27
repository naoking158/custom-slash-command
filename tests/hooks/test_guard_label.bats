#!/usr/bin/env bats
# Tests for the approval-label rule of scripts/hooks/outbound-guard.sh.
#
# Contract under test:
#   - An agent cannot add the label `human-approved` through gh, in any mode.
#   - Other labels, and text that only mentions the label, are left alone.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARD="$REPO_ROOT/scripts/hooks/outbound-guard.sh"
  TMP="$(mktemp -d -t guard-label.XXXXXX)"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" remote add origin git@github.com:me/app.git
  git -C "$REPO" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature/x
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
  export MY_TOOLKIT_DATA="$TMP/data"
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"
  mkdir -p "$MY_TOOLKIT_DATA/ship-ready"
  date +%s >"$MY_TOOLKIT_DATA/ship-ready/me__app"
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

@test "adding the approval label is denied however it is written" {
  for command in \
    'gh pr edit 3 --add-label human-approved' \
    'gh pr edit 3 --add-label "bug,human-approved"' \
    'gh pr edit 3 --add-label=human-approved' \
    $'gh pr edit 3 \\\n  --add-label human-approved' \
    'gh pr create --draft --title t --body b --label human-approved' \
    'gh issue edit 3 --add-label human-approved' \
    'gh api --method POST repos/me/app/issues/3/labels -f "labels[]=human-approved"'; do
    [ "$(decision_for "$command")" = "deny" ]
  done
}

@test "other labels and reading the label are allowed" {
  for command in \
    'gh pr edit 3 --add-label bug' \
    'gh label create human-approved --description "a person approved a guardrail change"' \
    'gh pr view 3 --json labels' \
    'echo human-approved'; do
    [ "$(decision_for "$command")" = "allow" ]
  done
}
