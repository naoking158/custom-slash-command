#!/usr/bin/env bats
# Tests for scripts/hooks/antigravity-stop.sh, the Antigravity Stop hook that
# feeds session-end.sh and prompt-capture.sh.
#
# Contract under test:
#   - A conversation is indexed in sessions.jsonl once, however many turns end.
#   - The turn's user input reaches prompt-capture.sh, so a correction is
#     queued with the conversation as its session, once per conversation.
#   - The hook prints {"decision":""} and exits 0, even on unreadable input.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/scripts/hooks/antigravity-stop.sh"
  TMP="$BATS_TEST_TMPDIR"
  export MY_TOOLKIT_DATA="$TMP/my-toolkit"
}

# stop_payload INPUT — the Stop payload agy 1.5.17 sends, trimmed.
stop_payload() {
  jq -cn --arg u "$1" '{
    hookEventName: "Stop", conversationId: "conv-1", cwd: "/tmp/proj",
    transcriptPath: "/tmp/conv-1/transcript_full.jsonl",
    terminationReason: "NO_TOOL_CALL", lastUserInput: $u}'
}

run_hook() {
  run bash "$HOOK" < <(printf '%s' "$1")
  [ "$status" -eq 0 ]
  [ "$output" = '{"decision":""}' ]
}

@test "the conversation is indexed once over several turns" {
  run_hook "$(stop_payload 'list the files')"
  run_hook "$(stop_payload 'now read README')"
  [ "$(wc -l <"$MY_TOOLKIT_DATA/sessions.jsonl")" -eq 1 ]
  [ "$(jq -r .session_id "$MY_TOOLKIT_DATA/sessions.jsonl")" = "conv-1" ]
  [ "$(jq -r .transcript_path "$MY_TOOLKIT_DATA/sessions.jsonl")" = "/tmp/conv-1/transcript_full.jsonl" ]
}

@test "a correction is queued under the conversation" {
  run_hook "$(stop_payload '違う、そうじゃなくて list_dir を使って')"
  [ "$(jq -r .session_id "$MY_TOOLKIT_DATA/corrections.jsonl")" = "conv-1" ]
  [ "$(jq -r .prompt "$MY_TOOLKIT_DATA/corrections.jsonl")" = "違う、そうじゃなくて list_dir を使って" ]
}

@test "a turn ending twice for one input (a background command finished) queues it once" {
  run_hook "$(stop_payload '違う、そうじゃなくて list_dir を使って')"
  run_hook "$(stop_payload '違う、そうじゃなくて list_dir を使って')"
  [ "$(wc -l <"$MY_TOOLKIT_DATA/corrections.jsonl")" -eq 1 ]
}

@test "an input ending in a newline is also queued once" {
  run_hook "$(stop_payload $'違う、それじゃない\n')"
  run_hook "$(stop_payload $'違う、それじゃない\n')"
  [ "$(wc -l <"$MY_TOOLKIT_DATA/corrections.jsonl")" -eq 1 ]
}

@test "an ordinary prompt is not queued" {
  run_hook "$(stop_payload 'list the files')"
  [ ! -f "$MY_TOOLKIT_DATA/corrections.jsonl" ]
}

@test "unreadable input still answers and exits 0" {
  run_hook 'not json'
  run_hook ''
}

@test "hooks.json registers the hook on Stop with a plugin-relative command" {
  local cmd
  cmd="$(jq -r '."retro-capture".Stop[0].command' "$REPO_ROOT/hooks.json")"
  [[ "$cmd" == ./* ]]
  [ -x "$REPO_ROOT/$cmd" ]
}
