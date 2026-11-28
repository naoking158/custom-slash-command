#!/usr/bin/env bats
# Tests for skills/retro/scripts/transcript-digest.sh.
#
# Contract under test:
#   - An Antigravity transcript gives one USER line per USER_INPUT (the text
#     inside <USER_REQUEST>) and one TOOL_ERROR line per failed step, named
#     after the tool call it answers.
#   - A Claude Code transcript gives USER lines for typed text and TOOL_ERROR
#     lines for tool results with is_error; meta and sidechain records are
#     skipped.
#   - A file in neither format exits 2.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DIGEST="$REPO_ROOT/skills/retro/scripts/transcript-digest.sh"
  T="$BATS_TEST_TMPDIR"
}

@test "Antigravity: prompts and failed steps with their tool" {
  cat >"$T/agy.jsonl" <<'JSONL'
{"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-11-28T05:00:00Z","content":"<USER_REQUEST>\nfix the\ntest\n</USER_REQUEST>\n<ADDITIONAL_METADATA>x</ADDITIONAL_METADATA>"}
{"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","status":"DONE","created_at":"2026-11-28T05:00:01Z","tool_calls":[{"name":"view_file","args":{}},{"name":"run_command","args":{}}]}
{"step_index":2,"source":"MODEL","type":"GENERIC","status":"DONE","created_at":"2026-11-28T05:00:02Z","content":"ok"}
{"step_index":3,"source":"MODEL","type":"GENERIC","status":"ERROR","created_at":"2026-11-28T05:00:03Z","content":"","error":"tool call denied by pre-tool hook: no"}
{"step_index":4,"source":"SYSTEM","type":"SYSTEM_MESSAGE","status":"DONE","created_at":"2026-11-28T05:00:04Z","content":"reminder"}
{"step_index":5,"source":"USER_EXPLICIT","type":"USER_INPUT","status":"DONE","created_at":"2026-11-28T05:01:00Z","content":"<USER_REQUEST>\nno, use bats\n</USER_REQUEST>"}
JSONL
  run bash "$DIGEST" "$T/agy.jsonl"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "USER 2026-11-28T05:00:00Z fix the test" ]
  [ "${lines[1]}" = "TOOL_ERROR 2026-11-28T05:00:03Z run_command tool call denied by pre-tool hook: no" ]
  [ "${lines[2]}" = "USER 2026-11-28T05:01:00Z no, use bats" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "Claude Code: typed text and failed tool results, without meta or sidechain records" {
  cat >"$T/cc.jsonl" <<'JSONL'
{"type":"user","timestamp":"t1","message":{"role":"user","content":"fix the\ntest"}}
{"type":"assistant","timestamp":"t2","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash"}]}}
{"type":"user","timestamp":"t3","message":{"role":"user","content":[{"type":"tool_result","is_error":true,"content":"exit 1"}]}}
{"type":"user","timestamp":"t4","message":{"role":"user","content":[{"type":"tool_result","content":"fine"}]}}
{"type":"user","timestamp":"t5","isMeta":true,"message":{"role":"user","content":"caveat"}}
{"type":"user","timestamp":"t6","isSidechain":true,"message":{"role":"user","content":"subagent prompt"}}
{"type":"user","timestamp":"t7","message":{"role":"user","content":[{"type":"text","text":"no, use bats"}]}}
JSONL
  run bash "$DIGEST" "$T/cc.jsonl"
  [ "$status" -eq 0 ]
  [ "$output" = "USER t1 fix the test
TOOL_ERROR t3 - exit 1
USER t7 no, use bats" ]
}

@test "a file in neither format exits 2" {
  printf '{"foo":1}\n' >"$T/other.jsonl"
  run bash "$DIGEST" "$T/other.jsonl"
  [ "$status" -eq 2 ]
}
