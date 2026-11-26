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

# payload_in DIR COMMAND — a Bash payload whose session cwd is DIR.
payload_in() {
  jq -cn --arg c "$2" --arg d "$1" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
}

# main_and_worktree — put REPO on main and add WT, a worktree on feature/x.
main_and_worktree() {
  git -C "$REPO" checkout -q main
  WT="$TMP/wt"
  git -C "$REPO" worktree add -q "$WT" feature/x
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

@test "bare push after an assignment and cd is judged in that directory" {
  main_and_worktree
  run_guard "$(bash_payload "W=$WT; cd \$W && git add f && git commit -q -m \"msg\" && git push -q && echo pushed")"
  [ -z "$output" ]
}

@test "bare push after a later cd into a checkout on the default branch is denied" {
  main_and_worktree
  run_guard "$(payload_in "$WT" "M=$REPO; cd \"\$M\" && git push -q")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$WT" "export X=1; cd $REPO && git push -q")"
  [ "$(decision)" = "deny" ]
}

@test "git -C with a relative path is resolved from the preceding cd" {
  main_and_worktree
  run_guard "$(payload_in / "cd $TMP && git -C wt push -q")"
  [ -z "$output" ]
  run_guard "$(payload_in / "cd $TMP && git -C repo push -q")"
  [ "$(decision)" = "deny" ]
}

@test "a cd after the push does not move it" {
  main_and_worktree
  run_guard "$(payload_in "$WT" "git push -q && cd $REPO && git fetch -q")"
  [ -z "$output" ]
}

@test "a cd inside a subshell ends with the subshell" {
  main_and_worktree
  run_guard "$(payload_in "$WT" "(cd $REPO && make) ; git push -q")"
  [ -z "$output" ]
  run_guard "$(payload_in "$WT" "(cd $REPO && git push -q)")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$WT" "(cd $REPO && echo \$(true && true) && git push -q)")"
  [ "$(decision)" = "deny" ]
}

@test "a push whose directory cannot be followed is denied" {
  run_guard "$(bash_payload 'cd "$(mktemp -d)" && git push -q origin feature/x')"
  [ "$(decision)" = "deny" ]
}

@test "every push on the line is judged" {
  run_guard "$(bash_payload 'git push origin feature/x && git push origin main')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push origin feature/x; git push --force origin feature/x')"
  [ "$(decision)" = "deny" ]
}

@test "git -c before push is still a push" {
  run_guard "$(bash_payload 'git -c credential.helper=x push origin main')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git -c credential.helper=x push origin feature/x')"
  [ -z "$output" ]
}

@test "a quoted refspec is read" {
  run_guard "$(bash_payload 'git push origin "main"')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload "git push origin 'HEAD:main'")"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push origin "feature/x"')"
  [ -z "$output" ]
}

@test "a refspec held in a variable is read when the line assigns it" {
  run_guard "$(bash_payload 'B=main; git push origin "$B"')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'B=feature/x; git push origin $B')"
  [ -z "$output" ]
}

@test "a push after a single-quoted string holding one double quote is still judged" {
  run_guard "$(bash_payload "grep -n 'x \"' f.txt && git commit -q -m \"msg\" && git push origin main 2>&1 | grep -v '^remote'")"
  [ "$(decision)" = "deny" ]
}

@test "a push argument the line does not show is denied" {
  run_guard "$(bash_payload 'git push origin "$(git branch --show-current)"')"
  [ "$(decision)" = "deny" ]
}

@test "a redirection is not a push argument" {
  main_and_worktree
  run_guard "$(bash_payload 'git push origin &>/dev/null')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push &> /dev/null')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push origin > /tmp/out.log')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push -q >/dev/null 2>&1')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push origin main>/dev/null')"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$WT" 'cd . > /dev/null && git push origin feature/x 2> err.txt')"
  [ -z "$output" ]
}

@test "a cd behind if, builtin, a command substitution or a function is followed" {
  main_and_worktree
  run_guard "$(payload_in "$WT" "if cd $REPO; then git push -q; fi")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$WT" "builtin cd $REPO && git push -q")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$WT" "out=\$(cd $REPO && git push -q 2>&1); echo \"\$out\"")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$WT" "f() { cd $REPO && git push -q; }; f")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in "$REPO" "out=\$(cd $WT && git push -q 2>&1); echo \"\$out\"")"
  [ -z "$output" ]
}

@test "an escaped quote or a \$'…' string does not hide a later push" {
  cmd="git commit -q -m 'it'\\''s done' && git push origin main 2>&1 | grep -v '^remote'"
  run_guard "$(bash_payload "$cmd")"
  [ "$(decision)" = "deny" ]
  cmd="git commit -q -m \$'it\\'s done' && git push origin main && echo 'ok'"
  run_guard "$(bash_payload "$cmd")"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'echo \"start\" && git push origin main && echo "done"')"
  [ "$(decision)" = "deny" ]
}

@test "a comment is not read as part of the command" {
  main_and_worktree
  cmd="$(printf "# it's time to publish\ngit push --force origin feature/x\necho 'done'")"
  run_guard "$(payload_in "$WT" "$cmd")"
  [ "$(decision)" = "deny" ]
  cmd="$(printf 'cd %s  # the worktree\ngit push -u origin feature/x' "$WT")"
  run_guard "$(bash_payload "$cmd")"
  [ -z "$output" ]
  run_guard "$(payload_in "$WT" 'git push origin feature/x  # not main, no --force')"
  [ -z "$output" ]
  cmd="$(printf '(cd %s && make)  # build (see the notes\ngit push -q' "$REPO")"
  run_guard "$(payload_in "$WT" "$cmd")"
  [ -z "$output" ]
}

@test "a tag push asks only when nothing on the line is denied" {
  run_guard "$(bash_payload 'git push --tags')"
  [ "$(decision)" = "ask" ]
  run_guard "$(bash_payload 'git push --tags && gh pr merge 3')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'git push --tags origin feature/x && git push origin main')"
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

@test "a path in a message after a single-quoted string holding one double quote is denied" {
  run_guard "$(bash_payload "grep -n 'x \"' f.txt && git commit -q -m \"see /Users/me/notes.md\"")"
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

@test "ship cwd: a later cd into a strict repo is judged as that repo" {
  ship_repo
  WORK="$TMP/work"
  git init -q -b main "$WORK"
  git -C "$WORK" remote add origin https://github.com/work/app.git
  run_guard "$(bash_payload "S=$WORK; cd \$S && gh pr merge 3")"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload "export X=1; cd $WORK && gh pr create --title t --body b")"
  [ "$(decision)" = "deny" ]
}

@test "strict cwd: a later cd into a ship repo is judged as that repo" {
  SHIP="$TMP/ship"
  git init -q -b main "$SHIP"
  git -C "$SHIP" remote add origin git@github.com:me/app.git
  echo 'ship me/*' >"$MY_AUTONOMY_CONF"
  run_guard "$(bash_payload "S=$SHIP; cd \$S && gh pr merge 3 --squash")"
  [ -z "$output" ]
}

@test "a PR command whose repository cannot be followed is denied unless -R names it" {
  ship_repo
  run_guard "$(bash_payload 'cd "$(mktemp -d)" && gh pr merge 3')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'cd "$(mktemp -d)" && gh pr merge 3 -R me/app')"
  [ -z "$output" ]
  run_guard "$(bash_payload 'cd "$(mktemp -d)" && gh pr view 3')"
  [ -z "$output" ]
}

@test "strict: every PR command on the line is judged" {
  run_guard "$(bash_payload 'gh pr create --title a --body b; gh pr create --draft --title c --body d')"
  [ "$(decision)" = "deny" ]
}

@test "a commit in a directory that cannot be followed is not denied for that" {
  run_guard "$(bash_payload 'D="$(mktemp -d)"; cd "$D" && git init -q && git commit -q --allow-empty -m init')"
  [ -z "$output" ]
}

@test "the tracked-docs test runs where the commit runs" {
  run_guard "$(payload_in / "X=1; cd $REPO && git commit -m \"plan is in docs/plans/features/x.md\"")"
  [ "$(decision)" = "deny" ]
  run_guard "$(payload_in / "X=1; cd $REPO && git commit -m \"record the result in docs/log/tracked.md\"")"
  [ -z "$output" ]
}

@test "strict: a PR command closed by a parenthesis or followed by a redirection is judged" {
  run_guard "$(bash_payload '(gh pr merge)')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'out=$(gh pr ready)')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'gh pr merge>/dev/null')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'gh pr new --title t --body b')"
  [ "$(decision)" = "deny" ]
}

@test "ship cwd: a cd inside a command substitution into a strict repo is followed" {
  ship_repo
  WORK="$TMP/work"
  git init -q -b main "$WORK"
  git -C "$WORK" remote add origin https://github.com/work/app.git
  run_guard "$(bash_payload "url=\$(cd $WORK && gh pr create --title t --body b)")"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload "if cd $WORK; then gh pr merge 3 --squash; fi")"
  [ "$(decision)" = "deny" ]
}

@test "a gh message command whose directory cannot be followed is denied" {
  printf 'see docs/reviews/r.md\n' >"$REPO/body.md"
  run_guard "$(bash_payload 'W=$(pwd); cd "$W" && gh pr create --draft --title t --body-file body.md')"
  [ "$(decision)" = "deny" ]
  run_guard "$(bash_payload 'W=$(pwd); cd "$W" && gh pr comment 3 --body "plan is in docs/plans/features/x.md"')"
  [ "$(decision)" = "deny" ]
}

@test "the hint for gh api does not offer -R" {
  ship_repo
  run_guard "$(bash_payload 'cd "$(mktemp -d)" && gh api -X PUT repos/me/app/pulls/3/merge')"
  [ "$(decision)" = "deny" ]
  [[ "$output" != *"-R"* ]]
}
