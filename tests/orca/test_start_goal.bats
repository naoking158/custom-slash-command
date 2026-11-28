#!/usr/bin/env bats
# Tests for orca/bin/start-goal with a fake `orca` on PATH.
#
# Contract under test:
#   - Exit 0 agent launched, 2 configuration error, 3 Orca unusable.
#   - The last stdout line is `[start-goal] exit=<n> <worktree path or ->`.
#   - The worktree comes from origin's default branch; the agent, model and
#     prompt `/my:autopilot <goal>` come from the profile's implement line.
#   - The deny rules are in the worktree before the agent is launched, and
#     existing local settings are kept.
#   - A worktree whose agent could not start is removed again.
#   - A prompt that started no turn is sent once more only when Claude Code is
#     idle at an input box without it; otherwise, or when that also starts no
#     turn, exit 3 keeps the worktree and names the handle.

bats_require_minimum_version 1.5.0

load ../fake_bin

setup_file() {
  local tpl="$BATS_FILE_TMPDIR/repo-tpl"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  git init -q -b trunk "$tpl/seed"
  git -C "$tpl/seed" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git init -q --bare -b trunk "$tpl/origin.git"
  git -C "$tpl/origin.git" fetch -q "$tpl/seed" trunk:trunk
  git clone -q "$tpl/origin.git" "$tpl/repo"
}

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  START_GOAL="$REPO_ROOT/orca/bin/start-goal"
  TMP="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  FAKE_BIN="$TMP/bin"
  mkdir -p "$FAKE_BIN" "$TMP/home" "$TMP/wt"
  export PATH="$FAKE_BIN:$(path_without_orca)"
  if command -v orca >/dev/null; then return 1; fi
  export HOME="$TMP/home"
  export GIT_CONFIG_GLOBAL=/dev/null XDG_CONFIG_HOME="$TMP/home/.config"
  export MY_ORCA_PROFILE="work"
  export FAKE="$TMP"
  unset ORCA_TERMINAL_HANDLE
  make_repo
  fake_orca
  fake_bin "$FAKE_BIN/sleep" <<'SH'
#!/bin/bash
exit 0
SH
}

# path_without_orca — $PATH minus every directory holding an orca executable.
path_without_orca() {
  local dir out="" IFS=:
  for dir in $PATH; do
    [ -x "$dir/orca" ] && continue
    out="${out:+$out:}$dir"
  done
  printf '%s' "$out"
}

# make_repo — $TMP/repo, a clone of a local bare origin whose default branch is trunk.
make_repo() {
  cp -R "$BATS_FILE_TMPDIR/repo-tpl/origin.git" "$BATS_FILE_TMPDIR/repo-tpl/repo" "$TMP/"
  REPO="$TMP/repo"
  git -C "$REPO" remote set-url origin "$TMP/origin.git"
}

# fake_orca — an orca that logs every call to $FAKE/calls. `worktree create`
# saves its arguments, makes a Git checkout under $FAKE/wt/<name> (holding
# $FAKE/existing.json as .claude/settings.local.json when that file exists) and
# answers with its path, or with $FAKE/create.json when present. `agent launch`
# saves its arguments and copies the worktree's local settings and autopilot
# marker as they are at that moment, and answers with $FAKE/launch.json when present.
# `agent list` shows a working agent, or, while $FAKE/idle exists
# and nothing was sent (or $FAKE/send.json is used), one with no title, or none
# while $FAKE/no-agent exists. `terminal read` answers with the lines of
# $FAKE/screen.txt. `terminal send` saves its arguments and reports a started turn,
# or $FAKE/send.json when present.
fake_orca() {
  fake_bin "$FAKE_BIN/orca" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$FAKE/calls"
arg() { local want="$1"; shift; while [ $# -gt 0 ]; do [ "$1" = "$want" ] && { printf '%s' "$2"; return; }; shift; done; }
case "$1 $2" in
  "status --json")
    if [ -f "$FAKE/status.json" ]; then cat "$FAKE/status.json"; else
      echo '{"ok":true,"result":{"runtime":{"reachable":true,"appVersion":"1.4.277"}}}'; fi ;;
  "worktree create")
    shift 2
    printf '%s\n' "$@" >"$FAKE/create.args"
    if [ -f "$FAKE/create.json" ]; then cat "$FAKE/create.json"; exit 1; fi
    wt="$FAKE/wt/$(arg --name "$@")"
    git -C "$FAKE/repo" worktree add -q -b "fake/${wt##*/}" "$wt" "$(arg --base-branch "$@")" 2>/dev/null
    if [ -f "$FAKE/existing.json" ]; then mkdir -p "$wt/.claude"; cp "$FAKE/existing.json" "$wt/.claude/settings.local.json"; fi
    if [ -f "$FAKE/existing-hooks.json" ]; then mkdir -p "$wt/.agents"; cp "$FAKE/existing-hooks.json" "$wt/.agents/hooks.json"; fi
    printf '{"ok":true,"result":{"worktree":{"path":"%s"}}}\n' "$wt" ;;
  "agent launch")
    shift 2
    printf '%s\n' "$@" >"$FAKE/launch.args"
    wt="$(arg --worktree "$@")"; wt="${wt#path:}"
    cp "$wt/.claude/settings.local.json" "$FAKE/settings-at-launch.json" 2>/dev/null
    cp "$wt/.agents/hooks.json" "$FAKE/hooks-at-launch.json" 2>/dev/null
    cp "$(git -C "$wt" rev-parse --absolute-git-dir)/my-autopilot-worktree" "$FAKE/marker-at-launch" 2>/dev/null
    if [ -f "$FAKE/launch.json" ]; then cat "$FAKE/launch.json"; exit 1; fi
    echo '{"ok":true,"result":{"outcome":{"kind":"terminal","handle":"term_fake"}}}' ;;
  "agent list")
    if [ -f "$FAKE/no-agent" ]; then echo '{"ok":true,"result":{"agents":[]}}'
    elif [ -f "$FAKE/idle" ] && { [ ! -f "$FAKE/send.args" ] || [ -f "$FAKE/send.json" ]; }; then
      echo '{"ok":true,"result":{"agents":[{"agent":"claude","state":"done","title":null}]}}'
    else echo '{"ok":true,"result":{"agents":[{"agent":"claude","state":"working","title":null}]}}'; fi ;;
  "terminal read")
    jq -Rn '{ok:true,result:{terminal:{tail:[inputs]}}}' <"$FAKE/screen.txt" ;;
  "terminal send")
    shift 2
    printf '%s\n' "$@" >"$FAKE/send.args"
    if [ -f "$FAKE/send.json" ]; then cat "$FAKE/send.json"; else
      echo '{"ok":true,"result":{"send":{"accepted":true,"prompt":{"stages":["input_accepted","turn_started"]}}}}'; fi ;;
  "terminal close"|"worktree rm")
    echo '{"ok":true,"result":{}}' ;;
  *) exit 64 ;;
esac
SH
}

# make_kit — a copy of orca/ with the work profile, for tests that add a
# profile of their own; prints its path.
make_kit() {
  local kit="$TMP/kit/orca"
  mkdir -p "$kit/bin" "$kit/lib" "$kit/profiles" "$kit/settings"
  cp "$START_GOAL" "$kit/bin/"
  cp "$REPO_ROOT/orca/lib/profile.sh" "$kit/lib/"
  cp "$REPO_ROOT/orca/profiles/work.conf" "$kit/profiles/"
  cp "$REPO_ROOT/orca/settings/goal.deny.json" "$kit/settings/"
  printf '%s' "$kit"
}

run_start_goal() {
  run --separate-stderr bash "$START_GOAL" "$@"
}

last_line() { printf '%s\n' "$output" | tail -n 1; }

called() { grep -q "^$1" "$TMP/calls"; }

# arg_of FILE FLAG — the value after FLAG in a saved argument list.
arg_of() { grep -A1 -x -- "$2" "$TMP/$1.args" | tail -n 1; }

profile_value() { awk -v r="$2" '$1 == r { print $'"$3"' }' "$REPO_ROOT/orca/profiles/$1.conf"; }

deny_rules() { jq -r '.permissions.deny[]' "$REPO_ROOT/orca/settings/goal.deny.json"; }

GOAL='README を直す。"引用" と `code` と $HOME
2行目'

# --- exit 0 ---

@test "creates the worktree from origin's default branch and launches /my:autopilot <goal>" {
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$output" = "[start-goal] exit=0 $TMP/wt/g1" ]
  [ "$(arg_of create --repo)" = "path:$REPO" ]
  [ "$(arg_of create --name)" = "g1" ]
  [ "$(arg_of create --base-branch)" = "origin/trunk" ]
  grep -qx -- --no-parent "$TMP/create.args"
  run ! grep -qx -- --agent "$TMP/create.args"
  [ "$(arg_of launch --agent)" = "$(profile_value work implement 2)" ]
  [ "$(arg_of launch --model)" = "$(profile_value work implement 3)" ]
  [ "$(arg_of launch --worktree)" = "path:$TMP/wt/g1" ]
  [ "$(arg_of launch --surface)" = "terminal" ]
  [ "$(sed -n '/^--prompt$/,/^--json$/p' "$TMP/launch.args" | sed '1d;$d')" = "/my:autopilot $GOAL" ]
}

@test "the default worktree name is goal-<timestamp>" {
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [[ "$(arg_of create --name)" =~ ^goal-[0-9]{8}-[0-9]{6}$ ]]
}

@test "switching MY_ORCA_PROFILE changes the model given to agent launch" {
  kit="$(make_kit)"
  printf 'implement claude alt-model\n' >"$kit/profiles/alt.conf"
  MY_ORCA_PROFILE=work run --separate-stderr "$kit/bin/start-goal" --name w "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(arg_of launch --model)" = "$(profile_value work implement 3)" ]
  MY_ORCA_PROFILE=alt run --separate-stderr "$kit/bin/start-goal" --name a "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(arg_of launch --agent)" = "claude" ]
  [ "$(arg_of launch --model)" = "alt-model" ]
}

@test "a profile whose implement harness is neither claude nor antigravity: exit 2 before creating a worktree" {
  kit="$(make_kit)"
  printf 'implement codex some-model\n' >"$kit/profiles/other.conf"
  MY_ORCA_PROFILE=other run --separate-stderr "$kit/bin/start-goal" "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[start-goal] exit=2 -" ]
  [[ "$stderr" == *"needs claude or antigravity"* ]]
  [ ! -f "$TMP/calls" ]
}

@test "--profile picks the profile for this goal over MY_ORCA_PROFILE" {
  MY_ORCA_PROFILE=work run_start_goal --profile private --name p1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(arg_of launch --agent)" = "$(profile_value private implement 2)" ]
  [ "$(arg_of launch --model)" = "$(profile_value private implement 3)" ]
}

@test "antigravity: the goal deny hook is registered in .agents/hooks.json before the agent starts" {
  [ "$(profile_value private implement 2)" = antigravity ]
  MY_ORCA_PROFILE=private run_start_goal --name a1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(arg_of launch --agent)" = antigravity ]
  [ "$(jq -r '.["goal-deny"].PreToolUse[0].hooks[0].command' "$TMP/hooks-at-launch.json")" = "$REPO_ROOT/scripts/hooks/antigravity-goal-deny.sh" ]
  [ "$(jq -r '.["goal-deny"].PreToolUse[0].matcher' "$TMP/hooks-at-launch.json")" = "*" ]
  [ "$(jq -r '.permissions.deny[]' "$TMP/settings-at-launch.json")" = "$(deny_rules)" ]
  [ -z "$(git -C "$TMP/wt/a1" status --porcelain)" ]
}

@test "antigravity: hooks already in .agents/hooks.json are kept" {
  printf '{"mine":{"Stop":[]}}' >"$TMP/existing-hooks.json"
  MY_ORCA_PROFILE=private run_start_goal --name a1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  jq -e '.mine == {"Stop": []} and (.["goal-deny"].PreToolUse | length == 1)' "$TMP/hooks-at-launch.json"
}

@test "antigravity: a tracked .agents/hooks.json gets the hook without showing as a change" {
  mkdir -p "$REPO/.agents"
  printf '{"team":{"Stop":[]}}\n' >"$REPO/.agents/hooks.json"
  git -C "$REPO" add .agents/hooks.json
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -qm hooks
  git -C "$REPO" push -q origin HEAD:trunk
  git -C "$REPO" fetch -q origin
  MY_ORCA_PROFILE=private run_start_goal --name a1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  jq -e '.team and .["goal-deny"]' "$TMP/hooks-at-launch.json"
  [ -z "$(git -C "$TMP/wt/a1" status --porcelain)" ]
}

@test "antigravity: an existing .agents/hooks.json that is not an object: exit 2, worktree removed, no agent" {
  printf '[]' >"$TMP/existing-hooks.json"
  MY_ORCA_PROFILE=private run_start_goal --name a1 "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"not a JSON object"* ]]
  called "worktree rm"
  ! called "agent launch"
}

# --- deny before launch ---

@test "the deny rules and the autopilot marker are in the worktree before the agent starts" {
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.permissions.deny[]' "$TMP/settings-at-launch.json")" = "$(deny_rules)" ]
  [ "$(cat "$TMP/marker-at-launch")" = "$GOAL" ]
}

@test "existing local settings are kept and the deny rules are added once" {
  cat >"$TMP/existing.json" <<'JSON'
{"permissions":{"allow":["Bash(make:*)"],"deny":["Bash(rm:*)","mcp__notion"]},"env":{"A":"1"}}
JSON
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  s="$TMP/settings-at-launch.json"
  [ "$(jq -c '.permissions.allow' "$s")" = '["Bash(make:*)"]' ]
  [ "$(jq -c '.env' "$s")" = '{"A":"1"}' ]
  [ "$(jq -r '.permissions.deny[0]' "$s")" = "Bash(rm:*)" ]
  [ "$(jq -r '.permissions.deny[]' "$s" | sort | uniq -d)" = "" ]
  [ "$(deny_rules | grep -vxFf <(jq -r '.permissions.deny[]' "$s"))" = "" ]
}

@test "an existing local settings file that is not JSON is left alone: exit 2, worktree removed, no agent" {
  printf 'not json' >"$TMP/existing.json"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[start-goal] exit=2 $TMP/wt/g1" ]
  [ "$(cat "$TMP/wt/g1/.claude/settings.local.json")" = "not json" ]
  run ! called "agent launch"
  called "worktree rm --worktree path:$TMP/wt/g1 --force --delete-branch"
}

@test "existing local settings whose deny is not an array: exit 2, worktree removed, no agent" {
  echo '{"permissions":{"deny":"mcp__notion"}}' >"$TMP/existing.json"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  run ! called "agent launch"
  called "worktree rm --worktree path:$TMP/wt/g1 --force --delete-branch"
}

@test "the local settings file is excluded from Git once, so it never shows as untracked" {
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$TMP/wt/g1" status --porcelain)" ]
  run_start_goal --name g2 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(grep -cx '/.claude/settings.local.json' "$REPO/.git/info/exclude")" -eq 1 ]
}

# --- exit 2 ---

@test "missing goal: exit 2 without calling orca" {
  run_start_goal "$REPO"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[start-goal] exit=2 -" ]
  [ ! -f "$TMP/calls" ]
}

@test "not a Git checkout: exit 2" {
  mkdir "$TMP/plain"
  run_start_goal "$TMP/plain" "$GOAL"
  [ "$status" -eq 2 ]
  [ ! -f "$TMP/calls" ]
}

@test "origin without a default branch: exit 2" {
  git -C "$REPO" remote set-head origin --delete
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"remote set-head origin --auto"* ]]
  [ ! -f "$TMP/calls" ]
}

@test "no profile selected: exit 2" {
  unset MY_ORCA_PROFILE
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[start-goal] exit=2 -" ]
  [ ! -f "$TMP/calls" ]
}

@test "unknown profile: exit 2" {
  MY_ORCA_PROFILE=nosuch run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [ ! -f "$TMP/calls" ]
}

@test "repo not registered in Orca: exit 2 with the repo add hint, no agent" {
  echo '{"ok":false,"error":{"code":"repo_not_found","message":"repo_not_found"}}' >"$TMP/create.json"
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[start-goal] exit=2 -" ]
  [[ "$stderr" == *"orca repo add --path $REPO"* ]]
  run ! called "agent launch"
}

# --- exit 3 ---

@test "no orca on PATH: exit 3" {
  rm "$FAKE_BIN/orca"
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[start-goal] exit=3 -" ]
}

@test "runtime unreachable: exit 3 before creating a worktree" {
  echo '{"ok":true,"result":{"runtime":{"reachable":false}}}' >"$TMP/status.json"
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  run ! called "worktree create"
}

@test "worktree create fails for another reason: exit 3" {
  echo '{"ok":false,"error":{"code":"runtime_error","message":"boom"}}' >"$TMP/create.json"
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[start-goal] exit=3 -" ]
  run ! called "agent launch"
}

@test "agent launch fails: exit 3 and the worktree is removed" {
  echo '{"ok":false,"error":{"code":"runtime_error","message":"boom"}}' >"$TMP/launch.json"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[start-goal] exit=3 $TMP/wt/g1" ]
  called "terminal close --worktree path:$TMP/wt/g1 --all"
  called "worktree rm --worktree path:$TMP/wt/g1 --force --delete-branch"
}

# --- the prompt reaches the session ---

# idle_screen INPUT — Claude Code idle with INPUT in its input box.
idle_screen() {
  touch "$TMP/idle"
  printf '%s\n' ' ▐▛███▜▌   Claude Code' '────────' "❯ $1" '────────' '  ⏵⏵ auto mode on' >"$TMP/screen.txt"
}

@test "a prompt that started a turn is not sent again" {
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  run ! called "terminal send"
}

@test "a prompt that started no turn is sent once more to the idle session: exit 0" {
  idle_screen 'Try "how does <filepath> work?"'
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(last_line)" = "[start-goal] exit=0 $TMP/wt/g1" ]
  [ "$(grep -c '^terminal send' "$TMP/calls")" -eq 1 ]
  [ "$(arg_of send --terminal)" = "term_fake" ]
  [ "$(sed -n '/^--text$/,/^--json$/p' "$TMP/send.args" | sed '1d;$d')" = "/my:autopilot $GOAL" ]
}

@test "a resent prompt that starts no turn either: exit 3, worktree kept, handle and recovery named" {
  idle_screen ''
  echo '{"ok":true,"result":{"send":{"accepted":true,"prompt":{"stages":["input_accepted"]}}}}' >"$TMP/send.json"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[start-goal] exit=3 $TMP/wt/g1" ]
  [[ "$stderr" == *"orca terminal send --terminal term_fake --enter --wait-submit 20 --text "* ]]
  orca() { while [ "$1" != --text ]; do shift; done; printf '%s' "$2"; }
  [ "$(eval "${stderr#*send the prompt by hand with: }")" = "/my:autopilot $GOAL" ]
  [ "$(grep -c '^terminal send' "$TMP/calls")" -eq 1 ]
  run ! called "worktree rm"
  [ -d "$TMP/wt/g1" ]
}

@test "the prompt already in the input box is not sent again: exit 3" {
  idle_screen "/my:autopilot $GOAL"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  run ! called "terminal send"
  run ! called "worktree rm"
}

@test "Claude Code never came up: nothing is typed into the shell, exit 3" {
  touch "$TMP/no-agent"
  printf '%s\n' '~/orca/workspaces/repo/g1' '❯' >"$TMP/screen.txt"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  run ! called "terminal send"
  run ! called "worktree rm"
}
