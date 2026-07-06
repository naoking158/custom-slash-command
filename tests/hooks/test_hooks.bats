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
  TMP="$(mktemp -d -t hooks-test.XXXXXX)"
  export MY_TOOLKIT_DATA="$TMP/my-toolkit"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

payload() {
  printf '{"session_id":"sid-1234","cwd":"/tmp/proj","transcript_path":"/tmp/t.jsonl","reason":"other","prompt":%s}' "$1"
}

# --- session-end.sh -----------------------------------------------------------

@test "session-end: appends one index line with the payload fields" {
  run bash -c "printf '%s' '$(payload '""')' | \"$SESSION_END\""
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
  printf '%s' "$(payload '""')" | "$SESSION_END"
  printf '%s' "$(payload '""')" | "$SESSION_END"
  [ "$(wc -l < "$MY_TOOLKIT_DATA/sessions.jsonl" | tr -d ' ')" = "2" ]
}

@test "session-end: malformed stdin still exits 0 and writes nothing" {
  run bash -c "printf 'not json at all' | \"$SESSION_END\""
  [ "$status" -eq 0 ]
  [ ! -s "$MY_TOOLKIT_DATA/sessions.jsonl" ]
}

@test "session-end: empty stdin exits 0" {
  run bash -c ": | \"$SESSION_END\""
  [ "$status" -eq 0 ]
}

# --- prompt-capture.sh --------------------------------------------------------

@test "prompt-capture: Japanese correction marker is captured" {
  run bash -c "printf '%s' '$(payload '"違う、テストを先に書いて"')' | \"$PROMPT_CAPTURE\""
  [ "$status" -eq 0 ]
  [ -f "$MY_TOOLKIT_DATA/corrections.jsonl" ]
  [ "$(jq -r '.prompt' "$MY_TOOLKIT_DATA/corrections.jsonl")" = "違う、テストを先に書いて" ]
}

@test "prompt-capture: English correction marker is captured" {
  run bash -c "printf '%s' '$(payload '"no, use pnpm instead of npm"')' | \"$PROMPT_CAPTURE\""
  [ "$status" -eq 0 ]
  [ -f "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: ordinary prompt is NOT captured" {
  run bash -c "printf '%s' '$(payload '"please add a login page"')' | \"$PROMPT_CAPTURE\""
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: slash commands are NOT captured" {
  run bash -c "printf '%s' '$(payload '"/my:retro --since 14d"')' | \"$PROMPT_CAPTURE\""
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: prompt is truncated to 500 chars" {
  long="$(printf 'x%.0s' $(seq 1 600))"
  run bash -c "printf '%s' '$(payload "\"違う $long\"")' | \"$PROMPT_CAPTURE\""
  [ "$status" -eq 0 ]
  n="$(jq -r '.prompt | length' "$MY_TOOLKIT_DATA/corrections.jsonl")"
  [ "$n" -le 500 ]
}

@test "prompt-capture: malformed stdin still exits 0" {
  run bash -c "printf '{broken' | \"$PROMPT_CAPTURE\""
  [ "$status" -eq 0 ]
  [ ! -e "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "prompt-capture: stdout stays empty (never injects context)" {
  out="$(printf '%s' "$(payload '"違う、やり直して"')" | "$PROMPT_CAPTURE")"
  [ -z "$out" ]
}
