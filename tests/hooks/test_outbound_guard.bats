#!/usr/bin/env bats
# Tests for scripts/hooks/outbound-guard.sh (PreToolUse).
#
# Contract under test:
#   - PRs are created as drafts only and never marked ready.
#   - git push never forces, deletes, or targets the default branch.
#   - Outbound text never cites review IDs, local absolute paths, or untracked docs/.
#   - Allowed commands produce no output; the hook never exits non-zero.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARD="$REPO_ROOT/scripts/hooks/outbound-guard.sh"
  TMP="$(mktemp -d -t guard-test.XXXXXX)"
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  mkdir -p "$REPO/docs/log"
  echo x >"$REPO/docs/log/tracked.md"
  git -C "$REPO" add docs/log/tracked.md
  git -C "$REPO" -c user.email=t@example.com -c user.name=t commit -q -m docs
  git -C "$REPO" checkout -q -b feature/x
  export MY_AUTONOMY_CONF="$TMP/autonomy.conf"
}

# ship_repo — opt REPO into ship mode as me/app.
ship_repo() {
  git -C "$REPO" remote add origin git@github.com:me/app.git
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

bash_payload() {
  jq -cn --arg c "$1" --arg d "$REPO" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
}

run_guard() {
  run bash -c 'printf "%s" "$1" | "$2"' _ "$1" "$GUARD"
  [ "$status" -eq 0 ]
}

decision() {
  printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision'
}

# --- PR state ------------------------------------------------------------------

@test "gh pr create without --draft is denied" {
  run_guard "$(bash_payload 'gh pr create --title t --body b')"
  [ "$(decision)" = "deny" ]
}

@test "gh pr create --draft is allowed" {
  run_guard "$(bash_payload 'gh pr create --draft --title t --body b')"
  [ -z "$output" ]
}

@test "gh pr create -d is allowed" {
  run_guard "$(bash_payload 'gh pr create -d --title t --body b')"
  [ -z "$output" ]
}

@test "gh pr create --draft=false is denied" {
  run_guard "$(bash_payload 'gh pr create --draft=false --title t --body b')"
  [ "$(decision)" = "deny" ]
}

@test "gh pr ready is denied" {
  run_guard "$(bash_payload 'gh pr ready 12')"
  [ "$(decision)" = "deny" ]
}

@test "gh api markPullRequestReadyForReview is denied" {
  run_guard "$(bash_payload 'gh api graphql -f query="mutation { markPullRequestReadyForReview(input:{pullRequestId:\"x\"}) { clientMutationId } }"')"
  [ "$(decision)" = "deny" ]
}

@test "read-only gh pr commands pass" {
  run_guard "$(bash_payload 'gh pr view 12 --json isDraft')"
  [ -z "$output" ]
}

@test "a read-only API query for the ready-for-review event passes" {
  run_guard "$(bash_payload "gh api graphql -f query='{ repository(owner:\"o\",name:\"r\") { pullRequest(number:1) { timelineItems(itemTypes:[READY_FOR_REVIEW_EVENT], first:5) { nodes { __typename } } } } }'")"
  [ -z "$output" ]
}

# --- git push ------------------------------------------------------------------

@test "push of a feature branch is allowed" {
  run_guard "$(bash_payload 'git push -u origin feature/x')"
  [ -z "$output" ]
}

@test "bare push from a feature branch is allowed" {
  run_guard "$(bash_payload 'git push')"
  [ -z "$output" ]
}

@test "push to main is denied" {
  run_guard "$(bash_payload 'git push origin main')"
  [ "$(decision)" = "deny" ]
}

@test "push of HEAD:master is denied" {
  run_guard "$(bash_payload 'git push origin HEAD:master')"
  [ "$(decision)" = "deny" ]
}

@test "bare push while on main is denied" {
  git -C "$REPO" checkout -q main
  run_guard "$(bash_payload 'git push')"
  [ "$(decision)" = "deny" ]
}

@test "push to the origin/HEAD default branch is denied" {
  git -C "$REPO" update-ref refs/remotes/origin/develop HEAD
  git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  run_guard "$(bash_payload 'git push origin develop')"
  [ "$(decision)" = "deny" ]
}

@test "force push is denied" {
  run_guard "$(bash_payload 'git push --force-with-lease origin feature/x')"
  [ "$(decision)" = "deny" ]
}

@test "plus refspec is denied" {
  run_guard "$(bash_payload 'git push origin +feature/x')"
  [ "$(decision)" = "deny" ]
}

@test "deleting a remote branch is denied" {
  run_guard "$(bash_payload 'git push origin :feature/x')"
  [ "$(decision)" = "deny" ]
}

@test "leading cd selects the repository" {
  git -C "$REPO" checkout -q main
  run_guard "$(jq -cn --arg c "cd $REPO && git push" '{tool_name:"Bash",cwd:"/",tool_input:{command:$c}}')"
  [ "$(decision)" = "deny" ]
}

# --- outbound text ---------------------------------------------------------------

@test "commit message with a review finding ID is denied" {
  run_guard "$(bash_payload 'git commit -m "fix: address H003 from review"')"
  [ "$(decision)" = "deny" ]
}

@test "PR body citing docs/reviews is denied" {
  run_guard "$(bash_payload 'gh pr create --draft --title t --body "see docs/reviews/20261119-x.md"')"
  [ "$(decision)" = "deny" ]
}

@test "commit message citing an untracked docs file is denied" {
  run_guard "$(bash_payload 'git commit -m "plan is in docs/plans/features/x.md"')"
  [ "$(decision)" = "deny" ]
}

@test "commit message citing a tracked docs file is allowed" {
  run_guard "$(bash_payload 'git commit -m "record the result in docs/log/tracked.md"')"
  [ -z "$output" ]
}

@test "local absolute path in a PR comment is denied" {
  run_guard "$(bash_payload 'gh pr comment 3 --body "details: /Users/me/Desktop/design.md"')"
  [ "$(decision)" = "deny" ]
}

@test "leading cd path is not mistaken for a leak" {
  run_guard "$(jq -cn --arg c "cd $REPO && git commit -m 'add guard'" '{tool_name:"Bash",cwd:"/",tool_input:{command:$c}}')"
  [ -z "$output" ]
}

@test "paths in setup steps before the commit are not a leak" {
  run_guard "$(bash_payload 'git init -q /Users/me/tmp/w && git -C /Users/me/tmp/w commit --allow-empty -m init')"
  [ -z "$output" ]
}

@test "commands mentioned inside a heredoc message are not run" {
  cmd="$(printf 'git commit -q -F - <<%sEOF%s\ngh pr create and git push origin main are described here\nEOF' "'" "'")"
  run_guard "$(bash_payload "$cmd")"
  [ -z "$output" ]
}

@test "commands mentioned inside a quoted message are not run" {
  run_guard "$(bash_payload 'git commit -m "explain why gh pr ready is denied"')"
  [ -z "$output" ]
}

@test "body file contents are checked" {
  printf 'see docs/reviews/r.md\n' >"$TMP/body.md"
  run_guard "$(bash_payload "gh pr create --draft --title t --body-file $TMP/body.md")"
  [ "$(decision)" = "deny" ]
}

@test "paths in commands after a heredoc commit are not a leak" {
  cmd="$(printf 'git commit -q -F - <<%sEOF%s\nfix: x\nEOF\ngit push -q 2>&1 | tail -1; cat /private/tmp/claude-1/x/out.txt' "'" "'")"
  run_guard "$(bash_payload "$cmd")"
  [ -z "$output" ]
}

@test "paths in commands after a PR body are not a leak" {
  cmd="$(printf 'gh pr create --draft --title t --body "$(cat <<%sEOF%s\nbody\nEOF\n)"; cat /private/tmp/claude-1/x/out.txt' "'" "'")"
  run_guard "$(bash_payload "$cmd")"
  [ -z "$output" ]
}

@test "a path in the PR body is denied even with later commands" {
  run_guard "$(bash_payload 'gh pr create --draft --title t --body "see /Users/me/x.md" && cat /private/tmp/claude-1/x/out.txt')"
  [ "$(decision)" = "deny" ]
}

@test "a path inside a heredoc commit message is denied" {
  cmd="$(printf 'git commit -q -F - <<%sEOF%s\nsee /Users/me/notes.md\nEOF\ngit push -q' "'" "'")"
  run_guard "$(bash_payload "$cmd")"
  [ "$(decision)" = "deny" ]
}

@test "a path in a body continued onto the next line is denied" {
  cmd="$(printf 'gh pr create --draft \\\n  --title t \\\n  --body "see /Users/me/x.md"')"
  run_guard "$(bash_payload "$cmd")"
  [ "$(decision)" = "deny" ]
}

@test "a path in a heredoc whose operator line goes on is denied" {
  cmd="$(printf 'git commit -q -F - <<%sEOF%s && git push -q\nsee /Users/me/notes.md\nEOF' "'" "'")"
  run_guard "$(bash_payload "$cmd")"
  [ "$(decision)" = "deny" ]
}

@test "a path in a body piped into the outbound command is denied" {
  cmd="$(printf 'cat <<%sEOF%s | gh pr create --draft --title t --body-file -\nsee /Users/me/notes.md\nEOF' "'" "'")"
  run_guard "$(bash_payload "$cmd")"
  [ "$(decision)" = "deny" ]
}

@test "an env prefix before the commit is not a leak" {
  run_guard "$(bash_payload 'GIT_INDEX_FILE=/Users/me/idx git commit -m "add guard"')"
  [ -z "$output" ]
}

@test "notion page update with a local path is denied" {
  run_guard "$(jq -cn '{tool_name:"mcp__claude_ai_Notion__notion-update-page",cwd:"/",tool_input:{content:"正本 /Users/me/Desktop/x.md"}}')"
  [ "$(decision)" = "deny" ]
}

@test "unrelated tools pass silently" {
  run_guard "$(jq -cn '{tool_name:"Read",cwd:"/",tool_input:{file_path:"/Users/me/x"}}')"
  [ -z "$output" ]
}

@test "malformed payload never fails" {
  run bash -c 'printf "not json" | "$1"' _ "$GUARD"
  [ "$status" -eq 0 ]
}

# ============================================================================
# autonomy modes
# ============================================================================

@test "strict: gh pr merge is denied" {
  run_guard "$(bash_payload 'gh pr merge 3 --squash')"
  [ "$(decision)" = "deny" ]
}

@test "strict: merging through the API is denied" {
  run_guard "$(bash_payload 'gh api -X PUT repos/o/r/pulls/3/merge')"
  [ "$(decision)" = "deny" ]
}

@test "strict: a repo absent from the config stays strict" {
  git -C "$REPO" remote add origin git@github.com:work/app.git
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"
  run_guard "$(bash_payload 'gh pr create --title t --body b')"
  [ "$(decision)" = "deny" ]
}

@test "ship: non-draft PR, ready and merge are allowed" {
  ship_repo
  run_guard "$(bash_payload 'gh pr create --title t --body b')"
  [ -z "$output" ]
  run_guard "$(bash_payload 'gh pr ready 3')"
  [ -z "$output" ]
  run_guard "$(bash_payload 'gh pr merge 3 --squash --delete-branch')"
  [ -z "$output" ]
}

@test "ship: pushing to the default branch is still denied" {
  ship_repo
  run_guard "$(bash_payload 'git push origin main')"
  [ "$(decision)" = "deny" ]
}

@test "ship: force push is still denied" {
  ship_repo
  run_guard "$(bash_payload 'git push --force-with-lease origin feature/x')"
  [ "$(decision)" = "deny" ]
}

@test "ship: leak checks still apply" {
  ship_repo
  run_guard "$(bash_payload 'gh pr create --title t --body "see /Users/me/x.md"')"
  [ "$(decision)" = "deny" ]
}

@test "ship cwd: gh -R naming another repo is judged as that repo" {
  ship_repo
  run_guard "$(bash_payload 'gh pr merge 3 -R work/app')"
  [ "$(decision)" = "deny" ]
}

@test "ship cwd: cd into a strict repo is judged as that repo" {
  ship_repo
  WORK="$TMP/work"
  git init -q -b main "$WORK"
  git -C "$WORK" remote add origin https://github.com/work/app.git
  run_guard "$(bash_payload "cd $WORK && gh pr merge 3")"
  [ "$(decision)" = "deny" ]
}
