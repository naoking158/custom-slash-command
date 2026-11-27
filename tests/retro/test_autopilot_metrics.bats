#!/usr/bin/env bats
# Tests for skills/retro/scripts/autopilot-metrics.sh with progress logs shaped
# like real autopilot runs, a fake `gh` on PATH and a throwaway Git repository.
#
# Contract under test:
#   - Review rounds and verify outcomes come from a goal's tasks.tsv when it has
#     a row for the task (the last row per task_id wins), else from the task heading
#     sections of progress.md; what cannot be read is reported as 不明.
#   - Human pushback counts auto/ PRs created in the period with a comment or a
#     COMMENTED / CHANGES_REQUESTED review by someone who is neither the PR
#     author nor a bot, and auto/ PRs closed without merging.
#   - Reverts count commits in the period that undo an auto/ PR.
#   - Goals, PRs and commits outside the period are not counted.
#   - When gh fails the report still prints, with the repository as 不明.

bats_require_minimum_version 1.5.0

load ../fake_bin

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  METRICS="$REPO_ROOT/skills/retro/scripts/autopilot-metrics.sh"
  LOG_TASK="$REPO_ROOT/skills/autopilot/scripts/log-task.sh"
  TMP="$(mktemp -d -t autopilot-metrics-test.XXXXXX)"
  TMP="$(cd "$TMP" && pwd -P)"
  mkdir -p "$TMP/bin" "$TMP/home"
  export PATH="$TMP/bin:$PATH"
  export HOME="$TMP/home"
  export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$TMP/home/.config"
  export MY_METRICS_TODAY=2026-11-26
  export FAKE="$TMP"
  STATE="$HOME/.local/state/autopilot"
  REPO="$TMP/repo"
  cp -R "$BATS_FILE_TMPDIR/tpl/." "$TMP/"
}

# setup_file — builds the goals, repository, PRs and fake gh once; each test
# copies them. They hold no absolute path, so the copy works anywhere.
setup_file() {
  TMP="$BATS_FILE_TMPDIR/tpl"
  mkdir -p "$TMP/bin" "$TMP/home"
  export HOME="$TMP/home" GIT_CONFIG_GLOBAL=/dev/null
  STATE="$HOME/.local/state/autopilot"
  make_goals
  make_repo
  make_prs
  fake_gh
  export OLD8 C1 MANUAL
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# goal <slug> <started or -> — writes $STATE/o-r/<slug>/goal.md; progress.md comes from stdin.
goal() {
  local dir="$STATE/o-r/$1"
  mkdir -p "$dir"
  {
    echo "# $1"
    echo
    echo "- Repository: o/r  Mode: ship"
    [ "$2" = - ] || echo "- Started: $2"
  } >"$dir/goal.md"
  cat >"$dir/progress.md"
}

# tsv_goal <repo> <slug> <started> — a goal of <repo> started on <started>; its
# progress.md comes from stdin and its tasks.tsv from the task() calls after it.
tsv_goal() {
  local dir="$STATE/${1%/*}-${1#*/}/$2"
  mkdir -p "$dir"
  printf '# %s\n\n- Repository: %s  Mode: ship\n- Started: %s\n' "$2" "$1" "$3" >"$dir/goal.md"
  cat >"$dir/progress.md"
  TSV_DIR="$dir"
}

# task <task_id> <review_rounds> <verify> — logs one task of the last tsv_goal with log-task.sh.
task() {
  "$LOG_TASK" "$TSV_DIR/tasks.tsv" "$1" "auto/t/$1" "#1" "$2" "$3" none merged
}

make_goals() {
  goal goal-a 2026-11-20 <<'MD'
# Progress: goal-a

- 決定: ship モード
- verify: BLOCKED（前置きの行は読まない）

## Task 1: run-role
- branch auto/a/01-run-role, PR #1
- review r1: PASS (C0/H0/M3/L5)。M001 を修正
- review r2: NEEDS_REVISION (C0/H1/M2/L7)。H001 を修正
- 決定: 2ラウンドの上限に達したので再レビューせずマージ

## Task 2: readme
- verify: verify-<app> skill なし（unverified in the app）
- review r1: PASS (M2/L2) 全件修正。r2: PASS (L1) 参照を修正

## Task 3: screen
- verify 1 回目 FAIL（基準 6 の文言）
- verify: PASS (evidence 2 回目)
- review 1 回: PASS（Low 3）

## Task 4: docs
- verify: PASS（文書のみ）

## Task 5: login
- review round 1: PASS
- verify: BLOCKED（AWS SSO の期限切れ）

## Final report
- review r3: PASS（要約は読まない）
- verify: PASS
MD
  goal goal-b 2026-09-01 <<'MD'
## Task 1: old
- review r1: PASS
- verify: PASS
MD
  goal goal-c - <<'MD'
## Task 1: undated
- review r1: PASS
- verify: PASS
MD
  goal goal-d 2026-11-21 <<'MD'
## Tasks
- Task 1 resize: PR #51, review 1 回 PASS
MD
}

# commit <date> <subject> [body] — an empty commit on $REPO dated <date> noon; prints its sha.
commit() {
  GIT_AUTHOR_DATE="$1T12:00:00+0900" GIT_COMMITTER_DATE="$1T12:00:00+0900" \
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$2" ${3:+-m "$3"}
  git -C "$REPO" rev-parse HEAD
}

# make_repo — $TMP/repo with origin o/r: merge commits of PRs #8 (old) and #1, a
# commit no PR made, and reverts in and out of the period.
make_repo() {
  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" remote add origin https://github.com/o/r.git
  OLD8="$(commit 2026-09-11 "old feature (#8)")"
  commit 2026-10-01 "Revert \"old feature (#8)\"" "This reverts commit $OLD8." >/dev/null
  C1="$(commit 2026-11-20 "feat a (#1)")"
  MANUAL="$(commit 2026-11-21 "manual change")"
  commit 2026-11-24 "Revert \"feat a (#1)\"" "This reverts commit $C1." >/dev/null
  commit 2026-11-25 "Undo old feature" "This reverts commit $OLD8." >/dev/null
  commit 2026-11-25 "Revert \"manual change\"" "This reverts commit $MANUAL." >/dev/null
}

# pr <number> <branch> <state> <created date> <merge sha or -> <comments> <reviews>
# — one PR as `gh pr list` prints it plus the REST comments and reviews. Comments
# and reviews are `login:type[:state]` words; the list form drops the [bot] marker.
pr() {
  jq -nc --argjson n "$1" --arg b "$2" --arg st "$3" --arg c "$4T03:00:00Z" --arg m "$5" \
    --arg com "$6" --arg rev "$7" '
    def users($s): $s | split(" ") | map(select(. != "") | split(":"));
    {number: $n, headRefName: $b, state: $st, createdAt: $c,
     author: {login: "me", is_bot: false},
     mergeCommit: (if $m == "-" then null else {oid: $m} end),
     comments: [users($com)[] | {author: {login: .[0]}}],
     reviews: [users($rev)[] | {author: {login: .[0]}, state: .[2]}],
     rest_comments: [users($com)[] | {user: {login: .[0], type: .[1]}}],
     rest_reviews: [users($rev)[] | {user: {login: .[0], type: .[1]}, state: .[2]}]}'
}

make_prs() {
  {
    pr 1 auto/a/01 MERGED 2026-11-20 "$C1" "me:User" "me:User:COMMENTED"
    pr 2 auto/a/02 MERGED 2026-11-21 - "alice:User" ""
    pr 3 auto/a/03 CLOSED 2026-11-22 - "" "bob:User:CHANGES_REQUESTED"
    pr 4 auto/a/04 MERGED 2026-11-22 - "notion-workspace:Bot" "copilot-pull-request-reviewer:Bot:COMMENTED"
    pr 5 auto/a/05 MERGED 2026-11-23 - "" "carol:User:APPROVED"
    pr 6 feature/x CLOSED 2026-11-23 - "alice:User" ""
    pr 7 auto/old/01 CLOSED 2026-09-10 - "alice:User" ""
    pr 8 auto/old/02 MERGED 2026-09-11 "$OLD8" "" ""
  } | jq -s '.' >"$TMP/prs.json"
}

# fake_gh — answers the read-only calls the script makes from $FAKE/prs.json and
# logs them to $FAKE/gh.calls. Fails every call when $FAKE/gh-fail exists.
fake_gh() {
  fake_bin "$TMP/bin/gh" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$FAKE/gh.calls"
[ -f "$FAKE/gh-fail" ] && { echo "gh: not logged in" >&2; exit 1; }
arg() { local want="$1"; shift; while [ $# -gt 0 ]; do [ "$1" = "$want" ] && { printf '%s' "$2"; return; }; shift; done; }
q="$(arg -q "$@")"
out() { if [ -n "$q" ]; then jq -r "$q"; else cat; fi; }
case "$1 $2" in
  "pr list")
    search="$(arg --search "$@")"
    case "$search" in
      created:*) jq 'map(del(.rest_comments, .rest_reviews))' "$FAKE/prs.json" | out ;;
      *) jq --arg s "$search" 'map(select((.mergeCommit.oid // "") | startswith($s)))' "$FAKE/prs.json" | out ;;
    esac ;;
  "pr view")
    jq --argjson n "$3" '.[] | select(.number == $n)' "$FAKE/prs.json" | out ;;
  "api --paginate")
    n="$(printf '%s' "$3" | cut -d/ -f5)"
    case "$3" in
      */comments) jq --argjson n "$n" '.[] | select(.number == $n) | .rest_comments' "$FAKE/prs.json" ;;
      */reviews) jq --argjson n "$n" '.[] | select(.number == $n) | .rest_reviews' "$FAKE/prs.json" ;;
    esac ;;
  *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
esac
SH
}

@test "four metrics and the unreadable counts come out of logs, gh and git" {
  run -0 "$METRICS" --checkout "$REPO"
  [ "${lines[0]}" = "期間: 2026-10-30..2026-11-26" ]
  [ "${lines[1]}" = "進行の記録: ゴール 2、タスク 5（Started が読めないゴール 1、タスクの見出しがないゴール 1）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 4（1回 2、2回 2、平均 1.5）、不明 1" ]
  [ "${lines[3]}" = "verify: PASS 1、修正後に PASS 1、BLOCKED 1、未検証 1、不明 1" ]
  [ "${lines[4]}" = "人間の差し戻し: auto/ の PR 5、人間のコメントか変更要求 2、マージせずに閉じた 1、不明のリポジトリ 0" ]
  [ "${lines[5]}" = "マージ後の手戻り: auto/ の PR を取り消したコミット 2、auto/ と結びつかない revert 1、不明のリポジトリ 0" ]
  [ "${#lines[@]}" -eq 6 ]
}

@test "goals, PRs and commits outside the period are not counted" {
  run -0 "$METRICS" --checkout "$REPO" --since 2026-11-22 --until 2026-11-23
  [ "${lines[0]}" = "期間: 2026-11-22..2026-11-23" ]
  [ "${lines[1]}" = "進行の記録: ゴール 0、タスク 0（Started が読めないゴール 1、タスクの見出しがないゴール 0）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 0、不明 0" ]
  [ "${lines[4]}" = "人間の差し戻し: auto/ の PR 3、人間のコメントか変更要求 1、マージせずに閉じた 1、不明のリポジトリ 0" ]
  [ "${lines[5]}" = "マージ後の手戻り: auto/ の PR を取り消したコミット 0、auto/ と結びつかない revert 0、不明のリポジトリ 0" ]
}

@test "--since Nd covers N days ending on --until, and a goal started on the first day is in" {
  run -0 "$METRICS" --since 7d --until 2026-11-26
  [ "${lines[0]}" = "期間: 2026-11-20..2026-11-26" ]
  [ "${lines[1]}" = "進行の記録: ゴール 2、タスク 5（Started が読めないゴール 1、タスクの見出しがないゴール 1）" ]
}

@test "a repository without a checkout is unknown for reverts" {
  run -0 "$METRICS"
  [ "${lines[4]}" = "人間の差し戻し: auto/ の PR 5、人間のコメントか変更要求 2、マージせずに閉じた 1、不明のリポジトリ 0" ]
  [ "${lines[5]}" = "マージ後の手戻り: auto/ の PR を取り消したコミット 0、auto/ と結びつかない revert 0、不明のリポジトリ 1（o/r）" ]
}

@test "when gh fails the log metrics still print and the repository is unknown" {
  touch "$TMP/gh-fail"
  run -0 "$METRICS" --checkout "$REPO"
  [ "${lines[2]}" = "レビューの往復数: 読めた 4（1回 2、2回 2、平均 1.5）、不明 1" ]
  [ "${lines[4]}" = "人間の差し戻し: auto/ の PR 0、人間のコメントか変更要求 0、マージせずに閉じた 0、不明のリポジトリ 1（o/r）" ]
  [ "${lines[5]}" = "マージ後の手戻り: auto/ の PR を取り消したコミット 0、auto/ と結びつかない revert 0、不明のリポジトリ 1（o/r）" ]
}

@test "a revert whose body names the commit after its first line is counted" {
  commit 2026-11-25 "Back out the old feature (#9)" "$(printf 'Squash of the revert PR.\n\nThis reverts commit %s.' "$OLD8")" >/dev/null
  run -0 "$METRICS" --checkout "$REPO"
  [ "${lines[5]}" = "マージ後の手戻り: auto/ の PR を取り消したコミット 3、auto/ と結びつかない revert 1、不明のリポジトリ 0" ]
}

@test "--repo keeps other repositories' goals out" {
  run -0 "$METRICS" --repo x/y
  [ "${lines[1]}" = "進行の記録: ゴール 0、タスク 0（Started が読めないゴール 0、タスクの見出しがないゴール 0）" ]
  ! grep -q -- '-R o/r' "$TMP/gh.calls"
}

@test "gh is only asked to read" {
  run -0 "$METRICS" --checkout "$REPO"
  run ! grep -vE '^(pr list|pr view|api --paginate repos/o/r/(issues|pulls)/[0-9]+/(comments|reviews)$)' "$TMP/gh.calls"
}

@test "a malformed period is a usage error" {
  run -2 "$METRICS" --since yesterday
  [[ "$output" == usage:* ]]
  run -2 "$METRICS" --until 26/11/2026
}

@test "tasks.tsv gives review rounds and verify outcomes, and fail is unknown" {
  tsv_goal t/t tsv 2026-11-22 <<'MD'
## Task 1: superseded by task 1 of tasks.tsv
- review r9: PASS
- verify: PASS
MD
  task 1 0 pass
  task 2 1 pass_after_fix
  task 3 2 blocked
  task 4 1 unverified
  task 5 3 fail
  run -0 "$METRICS" --repo t/t
  [ "${lines[1]}" = "進行の記録: ゴール 1、タスク 5（Started が読めないゴール 0、タスクの見出しがないゴール 0）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 5（0回 1、1回 2、2回 1、3回 1、平均 1.4）、不明 0" ]
  [ "${lines[3]}" = "verify: PASS 1、修正後に PASS 1、BLOCKED 1、未検証 1、不明 1" ]
}

@test "the last tasks.tsv row of a task_id wins" {
  tsv_goal t/t tsv 2026-11-22 </dev/null
  task 1 4 fail
  task 2 2 blocked
  task 1 1 pass
  run -0 "$METRICS" --repo t/t
  [ "${lines[1]}" = "進行の記録: ゴール 1、タスク 2（Started が読めないゴール 0、タスクの見出しがないゴール 0）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 2（1回 1、2回 1、平均 1.5）、不明 0" ]
  [ "${lines[3]}" = "verify: PASS 1、修正後に PASS 0、BLOCKED 1、未検証 0、不明 0" ]
}

@test "goals with tasks.tsv and goals with only progress.md add up" {
  tsv_goal o/r tsv 2026-11-22 </dev/null
  task 1 0 pass
  task 2 1 pass_after_fix
  task 3 2 blocked
  task 4 1 unverified
  task 5 3 fail
  run -0 "$METRICS" --checkout "$REPO"
  [ "${lines[1]}" = "進行の記録: ゴール 3、タスク 10（Started が読めないゴール 1、タスクの見出しがないゴール 1）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 9（0回 1、1回 4、2回 3、3回 1、平均 1.44）、不明 1" ]
  [ "${lines[3]}" = "verify: PASS 2、修正後に PASS 2、BLOCKED 2、未検証 2、不明 2" ]
}

@test "a tasks.tsv with only its header falls back to progress.md" {
  tsv_goal t/t tsv 2026-11-22 <<'MD'
## Task 1: read from progress.md
- review r2: PASS
- verify: PASS
MD
  printf 'ts\ttask_id\tbranch\tpr\treview_rounds\tverify\tci\toutcome\n' >"$TSV_DIR/tasks.tsv"
  run -0 "$METRICS" --repo t/t
  [ "${lines[1]}" = "進行の記録: ゴール 1、タスク 1（Started が読めないゴール 0、タスクの見出しがないゴール 0）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 1（2回 1、平均 2）、不明 0" ]
  [ "${lines[3]}" = "verify: PASS 1、修正後に PASS 0、BLOCKED 0、未検証 0、不明 0" ]
}

@test "tasks missing from tasks.tsv are still read from progress.md" {
  tsv_goal t/t tsv 2026-11-22 <<'MD'
## Task 1: only in progress.md
- review r2: PASS
- verify: PASS

## Task 2: superseded by tasks.tsv
- review r9: PASS
- verify: BLOCKED
MD
  task 2 1 unverified
  run -0 "$METRICS" --repo t/t
  [ "${lines[1]}" = "進行の記録: ゴール 1、タスク 2（Started が読めないゴール 0、タスクの見出しがないゴール 0）" ]
  [ "${lines[2]}" = "レビューの往復数: 読めた 2（1回 1、2回 1、平均 1.5）、不明 0" ]
  [ "${lines[3]}" = "verify: PASS 1、修正後に PASS 0、BLOCKED 0、未検証 1、不明 0" ]
}
