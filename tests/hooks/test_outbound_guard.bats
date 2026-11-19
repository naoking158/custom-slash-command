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

@test "body file contents are checked" {
  printf 'see docs/reviews/r.md\n' >"$TMP/body.md"
  run_guard "$(bash_payload "gh pr create --draft --title t --body-file $TMP/body.md")"
  [ "$(decision)" = "deny" ]
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
