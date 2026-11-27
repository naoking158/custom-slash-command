#!/usr/bin/env bats
# Tests for the capture hooks (scripts/hooks/*.sh).
#
# Contract under test:
#   - session-end.sh appends one JSONL index line per session and NEVER
#     exits non-zero (SessionEnd side-effects must not fail the session).
#   - prompt-capture.sh appends a corrections line only for prompts that
#     look like user corrections (JP/EN markers), and NEVER exits non-zero.
#   - Both honor $MY_TOOLKIT_DATA and stay silent on stdout.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SESSION_END="$REPO_ROOT/scripts/hooks/session-end.sh"
  PROMPT_CAPTURE="$REPO_ROOT/scripts/hooks/prompt-capture.sh"
  TMP="$BATS_TEST_TMPDIR"
  export MY_TOOLKIT_DATA="$TMP/my-toolkit"
}

payload() {
  printf '{"session_id":"sid-1234","cwd":"/tmp/proj","transcript_path":"/tmp/t.jsonl","reason":"other","prompt":%s}' "$1"
}

# --- session-end.sh -----------------------------------------------------------

@test "session-end: appends one index line with the payload fields" {
  run bash "$SESSION_END" < <(printf '%s' "$(payload '""')")
  [ "$status" -eq 0 ]
  [ -f "$MY_TOOLKIT_DATA/sessions.jsonl" ]
  line="$(cat "$MY_TOOLKIT_DATA/sessions.jsonl")"
  [ "$(printf '%s' "$line" | jq -r '.session_id')" = "sid-1234" ]
  [ "$(printf '%s' "$line" | jq -r '.cwd')" = "/tmp/proj" ]
  [ "$(printf '%s' "$line" | jq -r '.transcript_path')" = "/tmp/t.jsonl" ]
  [ "$(printf '%s' "$line" | jq -r '.reason')" = "other" ]
  [[ "$(printf '%s' "$line" | jq -r '.ts')" =~ ^[0-9]{4}- ]]
}

@test "session-end: two sessions append two lines" {
  printf '%s' "$(payload '""')" | bash "$SESSION_END"
  printf '%s' "$(payload '""')" | bash "$SESSION_END"
  [ "$(wc -l < "$MY_TOOLKIT_DATA/sessions.jsonl" | tr -d ' ')" = "2" ]
}

@test "session-end: malformed stdin still exits 0 and writes nothing" {
  run bash "$SESSION_END" < <(printf 'not json at all')
  [ "$status" -eq 0 ]
  [ ! -s "$MY_TOOLKIT_DATA/sessions.jsonl" ]
}

@test "session-end: empty stdin exits 0" {
  run bash "$SESSION_END" </dev/null
  [ "$status" -eq 0 ]
}

# --- prompt-capture.sh --------------------------------------------------------

@test "prompt-capture: Japanese correction marker is captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"違う、テストを先に書いて"')")
  [ "$status" -eq 0 ]
  [ -f "$MY_TOOLKIT_DATA/corrections.jsonl" ]
  [ "$(jq -r '.prompt' "$MY_TOOLKIT_DATA/corrections.jsonl")" = "違う、テストを先に書いて" ]
}

@test "prompt-capture: English correction marker is captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"no, use pnpm instead of npm"')")
  [ "$status" -eq 0 ]
  [ -f "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: ordinary prompt is NOT captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"please add a login page"')")
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: slash commands are NOT captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"/my:retro --since 14d"')")
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: prompt is truncated to 500 chars" {
  long="$(printf 'x%.0s' $(seq 1 600))"
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload "\"違う $long\"")")
  [ "$status" -eq 0 ]
  n="$(jq -r '.prompt | length' "$MY_TOOLKIT_DATA/corrections.jsonl")"
  [ "$n" -le 500 ]
}

@test "prompt-capture: malformed stdin still exits 0" {
  run bash "$PROMPT_CAPTURE" < <(printf '{broken')
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: stdout stays empty (never injects context)" {
  out="$(printf '%s' "$(payload '"違う、やり直して"')" | bash "$PROMPT_CAPTURE")"
  [ -z "$out" ]
}

@test "prompt-capture: system-injected <task-notification> is NOT captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"<task-notification>\n<summary>Agent finished</summary>\nUse Monitor instead of sleep.\n</task-notification>"')")
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: system-injected <scheduled-task ...> is NOT captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"<scheduled-task name=\"nightly\">\n自動実行です。質問はしないで進めてください。\n</scheduled-task>"')")
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: pasted review-screen feedback is NOT captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"# レビューフィードバック: pr:641 のレビュー\n\n## 採用された指摘\n\n- A ではなく B を使う"')")
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: a correction that merely contains a tag IS captured" {
  run bash "$PROMPT_CAPTURE" < <(printf '%s' "$(payload '"違う、<div> ではなく <span> を使って"')")
  [ "$status" -eq 0 ]
  [ -f "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}
