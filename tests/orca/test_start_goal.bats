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

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  START_GOAL="$REPO_ROOT/orca/bin/start-goal"
  TMP="$(mktemp -d -t orca-start-goal-test.XXXXXX)"
  TMP="$(cd "$TMP" && pwd -P)"
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
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
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
  git init -q -b trunk "$TMP/seed"
  git -C "$TMP/seed" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git init -q --bare -b trunk "$TMP/origin.git"
  git -C "$TMP/origin.git" fetch -q "$TMP/seed" trunk:trunk
  git clone -q "$TMP/origin.git" "$TMP/repo"
  REPO="$TMP/repo"
}

# fake_orca — an orca that logs every call to $FAKE/calls. `worktree create`
# saves its arguments, makes a Git checkout under $FAKE/wt/<name> (holding
# $FAKE/existing.json as .claude/settings.local.json when that file exists) and
# answers with its path, or with $FAKE/create.json when present. `agent launch`
# saves its arguments and copies the worktree's local settings and autopilot
# marker as they are at that moment, and answers with $FAKE/launch.json when present.
fake_orca() {
  cat >"$FAKE_BIN/orca" <<'SH'
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
    printf '{"ok":true,"result":{"worktree":{"path":"%s"}}}\n' "$wt" ;;
  "agent launch")
    shift 2
    printf '%s\n' "$@" >"$FAKE/launch.args"
    wt="$(arg --worktree "$@")"; wt="${wt#path:}"
    cp "$wt/.claude/settings.local.json" "$FAKE/settings-at-launch.json" 2>/dev/null
    cp "$(git -C "$wt" rev-parse --absolute-git-dir)/my-autopilot-worktree" "$FAKE/marker-at-launch" 2>/dev/null
    if [ -f "$FAKE/launch.json" ]; then cat "$FAKE/launch.json"; exit 1; fi
    echo '{"ok":true,"result":{"outcome":{"kind":"terminal","handle":"term_fake"}}}' ;;
  "terminal close"|"worktree rm")
    echo '{"ok":true,"result":{}}' ;;
  *) exit 64 ;;
esac
SH
  chmod +x "$FAKE_BIN/orca"
}

run_start_goal() {
  run --separate-stderr "$START_GOAL" "$@"
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
  ! grep -qx -- --agent "$TMP/create.args"
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
  kit="$TMP/kit/orca"
  mkdir -p "$kit/bin" "$kit/lib" "$kit/profiles" "$kit/settings"
  cp "$START_GOAL" "$kit/bin/"
  cp "$REPO_ROOT/orca/lib/profile.sh" "$kit/lib/"
  cp "$REPO_ROOT/orca/profiles/work.conf" "$kit/profiles/"
  cp "$REPO_ROOT/orca/settings/goal.deny.json" "$kit/settings/"
  printf 'implement claude alt-model\n' >"$kit/profiles/alt.conf"
  MY_ORCA_PROFILE=work run --separate-stderr "$kit/bin/start-goal" --name w "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(arg_of launch --model)" = "$(profile_value work implement 3)" ]
  MY_ORCA_PROFILE=alt run --separate-stderr "$kit/bin/start-goal" --name a "$REPO" "$GOAL"
  [ "$status" -eq 0 ]
  [ "$(arg_of launch --agent)" = "claude" ]
  [ "$(arg_of launch --model)" = "alt-model" ]
}

@test "a profile whose implement harness is not claude: exit 2 before creating a worktree" {
  [ "$(profile_value private implement 2)" != claude ]
  MY_ORCA_PROFILE=private run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[start-goal] exit=2 -" ]
  [[ "$stderr" == *"needs claude"* ]]
  [ ! -f "$TMP/calls" ]
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
  ! called "agent launch"
  called "worktree rm --worktree path:$TMP/wt/g1 --force --delete-branch"
}

@test "existing local settings whose deny is not an array: exit 2, worktree removed, no agent" {
  echo '{"permissions":{"deny":"mcp__notion"}}' >"$TMP/existing.json"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 2 ]
  ! called "agent launch"
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
  ! called "agent launch"
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
  ! called "worktree create"
}

@test "worktree create fails for another reason: exit 3" {
  echo '{"ok":false,"error":{"code":"runtime_error","message":"boom"}}' >"$TMP/create.json"
  run_start_goal "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[start-goal] exit=3 -" ]
  ! called "agent launch"
}

@test "agent launch fails: exit 3 and the worktree is removed" {
  echo '{"ok":false,"error":{"code":"runtime_error","message":"boom"}}' >"$TMP/launch.json"
  run_start_goal --name g1 "$REPO" "$GOAL"
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[start-goal] exit=3 $TMP/wt/g1" ]
  called "terminal close --worktree path:$TMP/wt/g1 --all"
  called "worktree rm --worktree path:$TMP/wt/g1 --force --delete-branch"
}
