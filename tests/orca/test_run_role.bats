#!/usr/bin/env bats
# Tests for orca/bin/run-role with a fake `orca` on PATH.
#
# Contract under test:
#   - Exit 0 result meets the role contract, 1 worker failed or bad result,
#     2 configuration error, 3 Orca unusable, 4 timeout (worker stopped).
#   - The last stdout line is `[run-role] <agent> exit=<n> <absolute --out>`.
#   - diff-reviewer's task holds only the agent body, the patch, hunk index,
#     checklists, output path and the three reporting rules.
#   - The profile picks the harness and model given to worker-start.
#   - Completion is read from worker-show; `orchestration check` is never used.

bats_require_minimum_version 1.5.0

load ../fake_bin

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  RUN_ROLE="$REPO_ROOT/orca/bin/run-role"
  TMP="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
  FAKE_BIN="$TMP/bin"
  mkdir -p "$FAKE_BIN" "$TMP/home" "$TMP/in"
  export PATH="$FAKE_BIN:$(path_without_orca)"
  if command -v orca >/dev/null; then return 1; fi
  export HOME="$TMP/home"
  export ORCA_TERMINAL_HANDLE="term_fake"
  unset ORCA_AGENT_SESSION_ID
  export MY_ORCA_PROFILE="work"
  export MY_ORCA_POLL_SECONDS="0.1"
  export FAKE="$TMP"
  OUT="$TMP/out/result"
  mkdir -p "$TMP/out"
  printf 'diff --git a/x b/x\n' >"$TMP/in/diff.patch"
  printf 'h001\tx\t@@ -1 +1 @@\t1\t1\n' >"$TMP/in/hunks.tsv"
  printf '# be\n' >"$TMP/in/be.md"
  printf '# security\n' >"$TMP/in/security.md"
  printf 'plan: secret intent\n' >"$TMP/in/plan.md"
  fake_orca
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

# fake_orca — an orca that logs every call to $FAKE/calls, saves the
# worker-start arguments and spec, and answers worker-show with the lines of
# $FAKE/states ("<state> <activity>", the last one repeats; "fail" makes
# the call fail with no output). On the first
# settled state it copies $FAKE/result.src (if any) to the --out path.
fake_orca() {
  printf 'succeeded working\n' >"$TMP/states"
  fake_bin "$FAKE_BIN/orca" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$FAKE/calls"
case "$1 $2" in
  "status --json")
    if [ -f "$FAKE/status.json" ]; then cat "$FAKE/status.json"; else
      echo '{"ok":true,"result":{"runtime":{"reachable":true,"appVersion":"1.4.277"}}}'; fi ;;
  "orchestration worker-start")
    shift 2
    : >"$FAKE/start.args"
    while [ $# -gt 0 ]; do
      printf '%s\n' "$1" >>"$FAKE/start.args"
      [ "$1" = "--spec-file" ] && cp "$2" "$FAKE/spec.txt"
      shift
    done
    if [ -f "$FAKE/start.json" ]; then cat "$FAKE/start.json"; exit "$(cat "$FAKE/start.rc" 2>/dev/null || echo 0)"; fi
    echo '{"ok":true,"result":{"dispatchId":"ctx_fake","state":"ready"}}' ;;
  "orchestration worker-show")
    line="$(head -n 1 "$FAKE/states")"
    if [ "$(wc -l <"$FAKE/states")" -gt 1 ]; then
      tail -n +2 "$FAKE/states" >"$FAKE/states.next" && mv "$FAKE/states.next" "$FAKE/states"
    fi
    set -- $line
    [ "$1" = fail ] && exit 1
    case "$1" in succeeded|failed|stopped)
      if [ -f "$FAKE/result.src" ] && [ ! -f "$FAKE/result.done" ]; then
        cp "$FAKE/result.src" "$(cat "$FAKE/result.dest")"; : >"$FAKE/result.done"
      fi ;;
    esac
    printf '{"ok":true,"result":{"dispatchId":"ctx_fake","state":"%s","activity":"%s","workspace":"ws_fake::%s"}}\n' "$1" "$2" "$FAKE/ws" ;;
  "orchestration worker-release"|"orchestration worker-stop")
    echo '{"ok":true,"result":{"dispatchId":"ctx_fake"}}' ;;
  *) exit 64 ;;
esac
SH
}

# worker_writes CONTENT [DEST] — the fake worker writes CONTENT to DEST (default $OUT).
worker_writes() {
  printf '%s' "$1" >"$TMP/result.src"
  printf '%s' "${2:-$OUT}" >"$TMP/result.dest"
}

pass1='{"schema_version":1,"findings":[]}'

run_diff_reviewer() {
  run --separate-stderr "$RUN_ROLE" diff-reviewer --out "$OUT" "$@" -- \
    --patch "$TMP/in/diff.patch" --hunks "$TMP/in/hunks.tsv" --checklist "$TMP/in/be.md"
}

last_line() { printf '%s\n' "$output" | tail -n 1; }

called() { grep -q "^$1" "$TMP/calls"; }

start_arg() { grep -A1 -x -- "$1" "$TMP/start.args" | tail -n 1; }

profile_value() { awk -v r="$2" '$1 == r { print $'"$3"' }' "$REPO_ROOT/orca/profiles/$1.conf"; }

# --- exit 0 ---

@test "diff-reviewer with a valid pass1.json: exit 0, final line, worker released" {
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$status" -eq 0 ]
  [ "$(last_line)" = "[run-role] diff-reviewer exit=0 $OUT" ]
  called "orchestration worker-release --dispatch ctx_fake"
  ! called "orchestration check"
}

@test "stdout holds only the final line" {
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$status" -eq 0 ]
  [ "$output" = "[run-role] diff-reviewer exit=0 $OUT" ]
}

@test "waits through working states until the worker succeeds" {
  printf 'ready working\nready working\nsucceeded working\n' >"$TMP/states"
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$status" -eq 0 ]
  [ "$(grep -c '^orchestration worker-show --dispatch ctx_fake --json' "$TMP/calls")" -eq 3 ]
}

@test "verifier whose result starts with PASS: exit 0" {
  worker_writes $'PASS\n- criterion 1: met\n'
  run --separate-stderr "$RUN_ROLE" verifier --out "$OUT" -- "checkout: /repo" "criteria: page shows X"
  [ "$status" -eq 0 ]
  [ "$(last_line)" = "[run-role] verifier exit=0 $OUT" ]
}

@test "reviewer with a report path and an assessment: exit 0" {
  mkdir -p "$TMP/ws/docs/reviews" && : >"$TMP/ws/docs/reviews/r.md"
  worker_writes $'output_path: docs/reviews/r.md\nassessment: NEEDS_REVISION\n'
  run --separate-stderr "$RUN_ROLE" reviewer --out "$OUT" -- "pr:12 --no-screen"
  [ "$status" -eq 0 ]
}

@test "relative --out is reported as an absolute path" {
  worker_writes "$pass1" "$TMP/out/pass1.json"
  cd "$TMP/out"
  run --separate-stderr "$RUN_ROLE" diff-reviewer --out ./pass1.json -- \
    --patch ../in/diff.patch --hunks ../in/hunks.tsv --checklist ../in/be.md
  [ "$status" -eq 0 ]
  [ "$(last_line)" = "[run-role] diff-reviewer exit=0 $TMP/out/pass1.json" ]
  grep -qx -- "- Patch file: $TMP/out/../in/diff.patch" "$TMP/spec.txt"
}

@test "--from outside an Orca terminal is passed to worker-start" {
  unset ORCA_TERMINAL_HANDLE
  worker_writes "$pass1"
  run_diff_reviewer --from term_other
  [ "$status" -eq 0 ]
  [ "$(start_arg --from)" = "term_other" ]
}

@test "in an Orca agent session without a terminal, the worker starts without --from" {
  unset ORCA_TERMINAL_HANDLE
  export ORCA_AGENT_SESSION_ID="sess_fake"
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$status" -eq 0 ]
  ! grep -qx -- --from "$TMP/start.args"
}

@test "relative --cwd is resolved to the directory's absolute path" {
  worker_writes "$pass1"
  cd "$TMP/in"
  run_diff_reviewer --cwd .
  [ "$status" -eq 0 ]
  [ "$(start_arg --worktree)" = "path:$TMP/in" ]
}

@test "--cwd that does not exist: exit 2" {
  run_diff_reviewer --cwd "$TMP/none"
  [ "$status" -eq 2 ]
}

@test "orca.conf without a trailing newline still names the profile" {
  unset MY_ORCA_PROFILE
  mkdir -p "$HOME/.claude/my-toolkit"
  printf 'profile work' >"$HOME/.claude/my-toolkit/orca.conf"
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$status" -eq 0 ]
}

@test "zero MY_ORCA_POLL_SECONDS: exit 2" {
  export MY_ORCA_POLL_SECONDS=0
  run_diff_reviewer
  [ "$status" -eq 2 ]
}

@test "non-numeric MY_ORCA_POLL_SECONDS: exit 2" {
  export MY_ORCA_POLL_SECONDS=abc
  run_diff_reviewer
  [ "$status" -eq 2 ]
}

@test "worker runs in the calling workspace unless --cwd names one" {
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$(start_arg --worktree)" = "current" ]
  rm -f "$TMP/result.done"
  run_diff_reviewer --cwd "$TMP/in/"
  [ "$status" -eq 0 ]
  [ "$(start_arg --worktree)" = "path:$TMP/in" ]
}

# --- exit 1 ---

@test "worker reports failure: exit 1, worker released" {
  printf 'failed working\n' >"$TMP/states"
  run_diff_reviewer
  [ "$status" -eq 1 ]
  [ "$(last_line)" = "[run-role] diff-reviewer exit=1 $OUT" ]
  called "orchestration worker-release --dispatch ctx_fake"
}

@test "worker abandoned by Orca: exit 1 without waiting for --timeout" {
  printf 'abandoned idle\n' >"$TMP/states"
  run_diff_reviewer --timeout 3600
  [ "$status" -eq 1 ]
  called "orchestration worker-release --dispatch ctx_fake"
}

@test "worker stopped: exit 1" {
  printf 'stopped idle\n' >"$TMP/states"
  run_diff_reviewer
  [ "$status" -eq 1 ]
}

@test "pass1.json that is not JSON: exit 1" {
  worker_writes 'not json'
  run_diff_reviewer
  [ "$status" -eq 1 ]
}

@test "pass1.json without findings: exit 1" {
  worker_writes '{"schema_version":1}'
  run_diff_reviewer
  [ "$status" -eq 1 ]
}

@test "a stale result from an earlier run does not count: exit 1" {
  printf '%s' "$pass1" >"$OUT"
  run_diff_reviewer
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "verifier result that does not start with a verdict: exit 1" {
  worker_writes $'Looks good to me.\nPASS\n'
  run --separate-stderr "$RUN_ROLE" verifier --out "$OUT"
  [ "$status" -eq 1 ]
}

@test "reviewer report path starting with ~/ is read from \$HOME" {
  mkdir -p "$HOME/rev" && : >"$HOME/rev/r.md"
  worker_writes $'output_path: ~/rev/r.md\nassessment: PASS\n'
  run --separate-stderr "$RUN_ROLE" reviewer --out "$OUT"
  [ "$status" -eq 0 ]
}

@test "reviewer result naming a report the worker did not write: exit 1" {
  worker_writes $'output_path: docs/reviews/r.md\nassessment: PASS\n'
  run --separate-stderr "$RUN_ROLE" reviewer --out "$OUT"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"$TMP/ws/docs/reviews/r.md"* ]]
}

@test "reviewer result without an assessment: exit 1" {
  worker_writes $'output_path: docs/reviews/r.md\n'
  run --separate-stderr "$RUN_ROLE" reviewer --out "$OUT"
  [ "$status" -eq 1 ]
}

# --- exit 2 ---

@test "no MY_ORCA_PROFILE and no orca.conf: exit 2, no worker started" {
  unset MY_ORCA_PROFILE
  run_diff_reviewer
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[run-role] diff-reviewer exit=2 $OUT" ]
  [ ! -e "$TMP/start.args" ]
}

@test "profile from orca.conf when MY_ORCA_PROFILE is unset" {
  unset MY_ORCA_PROFILE
  mkdir -p "$HOME/.claude/my-toolkit"
  printf '# comment\nprofile private\n' >"$HOME/.claude/my-toolkit/orca.conf"
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$status" -eq 0 ]
  [ "$(start_arg --agent)" = "$(profile_value private review 2)" ]
}

@test "MY_ORCA_PROFILE wins over orca.conf" {
  mkdir -p "$HOME/.claude/my-toolkit"
  printf 'profile private\n' >"$HOME/.claude/my-toolkit/orca.conf"
  worker_writes "$pass1"
  run_diff_reviewer
  [ "$(start_arg --agent)" = "$(profile_value work review 2)" ]
}

@test "unknown profile: exit 2" {
  export MY_ORCA_PROFILE=nope
  run_diff_reviewer
  [ "$status" -eq 2 ]
}

@test "profile name with a path: exit 2" {
  export MY_ORCA_PROFILE=../profiles/work
  run_diff_reviewer
  [ "$status" -eq 2 ]
}

@test "unknown agent: exit 2" {
  run --separate-stderr "$RUN_ROLE" planner --out "$OUT"
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[run-role] planner exit=2 $OUT" ]
}

@test "missing --out: exit 2" {
  run --separate-stderr "$RUN_ROLE" verifier
  [ "$status" -eq 2 ]
  [ "$(last_line)" = "[run-role] verifier exit=2 -" ]
}

@test "diff-reviewer given a plan path: exit 2, no worker started" {
  run --separate-stderr "$RUN_ROLE" diff-reviewer --out "$OUT" -- \
    --patch "$TMP/in/diff.patch" --hunks "$TMP/in/hunks.tsv" --checklist "$TMP/in/be.md" \
    --plan "$TMP/in/plan.md"
  [ "$status" -eq 2 ]
  [ ! -e "$TMP/start.args" ]
}

@test "diff-reviewer without a checklist: exit 2" {
  run --separate-stderr "$RUN_ROLE" diff-reviewer --out "$OUT" -- \
    --patch "$TMP/in/diff.patch" --hunks "$TMP/in/hunks.tsv"
  [ "$status" -eq 2 ]
}

@test "diff-reviewer with a missing patch file: exit 2" {
  run --separate-stderr "$RUN_ROLE" diff-reviewer --out "$OUT" -- \
    --patch "$TMP/in/none.patch" --hunks "$TMP/in/hunks.tsv" --checklist "$TMP/in/be.md"
  [ "$status" -eq 2 ]
}

@test "--cwd that Orca does not know: exit 2" {
  printf '{"ok":false,"error":{"code":"selector_not_found"}}' >"$TMP/start.json"
  printf '1' >"$TMP/start.rc"
  run_diff_reviewer --cwd "$TMP/in"
  [ "$status" -eq 2 ]
}

# --- exit 3 ---

@test "no orca command: exit 3" {
  rm "$FAKE_BIN/orca"
  run_diff_reviewer
  [ "$status" -eq 3 ]
  [ "$(last_line)" = "[run-role] diff-reviewer exit=3 $OUT" ]
}

@test "outside Orca without --from: exit 3, no worker started" {
  unset ORCA_TERMINAL_HANDLE
  run_diff_reviewer
  [ "$status" -eq 3 ]
  [ ! -e "$TMP/start.args" ]
}

@test "runtime not reachable: exit 3" {
  printf '{"ok":true,"result":{"runtime":{"reachable":false}}}' >"$TMP/status.json"
  run_diff_reviewer
  [ "$status" -eq 3 ]
}

@test "worker-start refused: exit 3" {
  printf '{"ok":false,"error":{"code":"agent_unavailable"}}' >"$TMP/start.json"
  printf '1' >"$TMP/start.rc"
  run_diff_reviewer
  [ "$status" -eq 3 ]
}

# --- exit 4 ---

@test "worker blocked past --timeout: exit 4, worker stopped then released" {
  printf 'ready blocked\n' >"$TMP/states"
  run_diff_reviewer --timeout 1
  [ "$status" -eq 4 ]
  [ "$(last_line)" = "[run-role] diff-reviewer exit=4 $OUT" ]
  [ "$(grep -E '^orchestration worker-(stop|release)' "$TMP/calls" | cut -d' ' -f2)" = $'worker-stop\nworker-release' ]
  ! called "orchestration check"
}

@test "worker-show failing three times in a row: exit 3, worker stopped" {
  printf 'fail\n' >"$TMP/states"
  run_diff_reviewer
  [ "$status" -eq 3 ]
  called "orchestration worker-stop --dispatch ctx_fake"
}

# --- what diff-reviewer receives ---

@test "diff-reviewer task is the agent body, the four inputs and the three rules only" {
  worker_writes "$pass1"
  run --separate-stderr "$RUN_ROLE" diff-reviewer --out "$OUT" -- \
    --patch "$TMP/in/diff.patch" --hunks "$TMP/in/hunks.tsv" \
    --checklist "$TMP/in/be.md" --checklist "$TMP/in/security.md"
  [ "$status" -eq 0 ]
  expected="$TMP/expected.md"
  {
    agent="$REPO_ROOT/agents/diff-reviewer.md"
    tail -n +"$(($(grep -n '^---$' "$agent" | sed -n 2p | cut -d: -f1) + 1))" "$agent"
    cat <<EOF

## Inputs

- Patch file: $TMP/in/diff.patch
- Hunk index (hunks.tsv): $TMP/in/hunks.tsv
- Checklist: $TMP/in/be.md
- Checklist: $TMP/in/security.md
- Write pass1.json to: $OUT

## Reporting

- Write your result to $OUT. That file is the only result anyone reads.
- Report completion in one line.
- Do not ask questions. Make each judgment call yourself and state it in the result.
EOF
  } >"$expected"
  diff -u "$expected" "$TMP/spec.txt"
  ! grep -q "plan" "$TMP/start.args"
}

# --- the profile picks harness and model ---

@test "switching MY_ORCA_PROFILE changes the harness and model given to worker-start" {
  worker_writes "$pass1"
  export MY_ORCA_PROFILE=work
  run_diff_reviewer
  [ "$status" -eq 0 ]
  work_agent="$(start_arg --agent)" work_model="$(start_arg --model)"

  rm -f "$TMP/result.done"
  export MY_ORCA_PROFILE=private
  run_diff_reviewer
  [ "$status" -eq 0 ]
  private_agent="$(start_arg --agent)" private_model="$(start_arg --model)"

  [ "$work_agent" = "$(profile_value work review 2)" ]
  [ "$work_model" = "$(profile_value work review 3)" ]
  [ "$private_agent" = "$(profile_value private review 2)" ]
  [ "$private_model" = "$(profile_value private review 3)" ]
  [ "$work_agent" != "$private_agent" ]
  [ "$work_model" != "$private_model" ]
}

@test "verifier uses the profile's verify line" {
  worker_writes $'BLOCKED (launch)\n'
  run --separate-stderr "$RUN_ROLE" verifier --out "$OUT"
  [ "$status" -eq 0 ]
  [ "$(start_arg --model)" = "$(profile_value work verify 3)" ]
}

# --- adversary and trail-auditor ---

# bare_profile — a copy of run-role whose only profile, "bare", has just a
# review line, so the adversary and audit roles must fall back to it.
bare_profile() {
  mkdir -p "$TMP/root"
  cp -R "$REPO_ROOT/orca" "$REPO_ROOT/agents" "$TMP/root/"
  rm -f "$TMP/root/orca/profiles/"*.conf
  printf 'review    bareharness    baremodel\n' >"$TMP/root/orca/profiles/bare.conf"
  export MY_ORCA_PROFILE=bare
}

@test "adversary with FINDINGS 0 or FINDINGS 2: exit 0 on the profile's adversary line" {
  worker_writes $'FINDINGS 0\nDropped: 1 (did not reproduce)\n'
  run --separate-stderr "$RUN_ROLE" adversary --out "$OUT" -- "worktree: /tmp/x"
  [ "$status" -eq 0 ]
  [ "$(last_line)" = "[run-role] adversary exit=0 $OUT" ]
  [ "$(start_arg --model)" = "$(profile_value work adversary 3)" ]
  [ "$(start_arg --agent)" = "$(profile_value work adversary 2)" ]

  rm -f "$TMP/result.done"
  worker_writes $'FINDINGS 2\n### a\n### b\nDropped: 0 ()\n'
  run --separate-stderr "$RUN_ROLE" adversary --out "$OUT"
  [ "$status" -eq 0 ]
}

@test "adversary whose first line is not FINDINGS <n>: exit 1" {
  worker_writes $'Found 2 bugs\nFINDINGS 2\n'
  run --separate-stderr "$RUN_ROLE" adversary --out "$OUT"
  [ "$status" -eq 1 ]
  rm -f "$TMP/result.done"
  worker_writes $'FINDINGS two\n'
  run --separate-stderr "$RUN_ROLE" adversary --out "$OUT"
  [ "$status" -eq 1 ]
}

@test "trail-auditor with an Attention section: exit 0 on the profile's audit line" {
  worker_writes $'reviewed by opus\n\n## Attention\n\nNo flags\n'
  run --separate-stderr "$RUN_ROLE" trail-auditor --out "$OUT" -- "state: /tmp/s"
  [ "$status" -eq 0 ]
  [ "$(start_arg --model)" = "$(profile_value work audit 3)" ]
  [ "$(start_arg --agent)" = "$(profile_value work audit 2)" ]
}

@test "trail-auditor without an Attention section: exit 1" {
  worker_writes $'reviewed by opus\n\nNo flags\n'
  run --separate-stderr "$RUN_ROLE" trail-auditor --out "$OUT"
  [ "$status" -eq 1 ]
}

@test "adversary and trail-auditor fall back to the review line" {
  bare_profile
  worker_writes $'FINDINGS 0\n'
  run --separate-stderr "$TMP/root/orca/bin/run-role" adversary --out "$OUT"
  [ "$status" -eq 0 ]
  [ "$(start_arg --agent)" = bareharness ]
  [ "$(start_arg --model)" = baremodel ]

  rm -f "$TMP/result.done"
  worker_writes $'reviewed by x\n## Attention\nNo flags\n'
  run --separate-stderr "$TMP/root/orca/bin/run-role" trail-auditor --out "$OUT"
  [ "$status" -eq 0 ]
  [ "$(start_arg --model)" = baremodel ]
}

@test "verifier does not fall back to the review line" {
  bare_profile
  run --separate-stderr "$TMP/root/orca/bin/run-role" verifier --out "$OUT"
  [ "$status" -eq 2 ]
}

@test "adversary that ran nothing returns BLOCKED, passed on for the caller: exit 0" {
  worker_writes $'BLOCKED: no worktree to run in\n'
  run --separate-stderr "$RUN_ROLE" adversary --out "$OUT"
  [ "$status" -eq 0 ]
  [ "$(head -n 1 "$OUT")" = "BLOCKED: no worktree to run in" ]
}
