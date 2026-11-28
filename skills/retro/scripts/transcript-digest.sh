#!/usr/bin/env bash
# transcript-digest.sh — Print what a person typed and which tool calls failed
# in one session transcript, for /my:retro --deep.
#
# Usage: transcript-digest.sh <transcript.jsonl>
#
# Reads both transcript formats that sessions.jsonl points at:
#   - Claude Code (~/.claude/projects/<dir>/<session>.jsonl): "user" records
#     whose content is text are prompts; tool_result blocks with is_error are
#     failures.
#   - Antigravity (<brain>/<id>/.system_generated/logs/transcript_full.jsonl):
#     USER_INPUT steps are prompts (the text inside <USER_REQUEST>); steps with
#     status ERROR are failures, with the tool call that produced them.
# Output, one line per event in transcript order, text flattened to one line
# and cut to 300 characters:
#   USER <timestamp> <text>
#   TOOL_ERROR <timestamp> <tool> <message>
#
# Exit codes: 0 printed (possibly nothing), 1 usage error or unreadable file,
# 2 the file is in neither format.
# Dependencies: bash, jq.
set -u

[ $# -eq 1 ] || { echo "usage: transcript-digest.sh <transcript.jsonl>" >&2; exit 1; }
[ -r "$1" ] || { echo "transcript-digest.sh: cannot read $1" >&2; exit 1; }

format="$(jq -r 'if has("step_index") and has("type") then "antigravity"
  elif (.type == "user" or .type == "assistant") and has("message") then "claude"
  else empty end' "$1" 2>/dev/null | head -n 1)"

case "$format" in
  antigravity)
    jq -rs '
      def flat: tostring | gsub("\\s+"; " ") | .[0:300];
      reduce .[] as $s ({calls: [], out: []};
        if $s.type == "PLANNER_RESPONSE" then .calls += [($s.tool_calls // [])[] | .name]
        elif $s.type == "USER_INPUT" then
          .out += ["USER \($s.created_at) \($s.content // "" | (capture("<USER_REQUEST>\\s*(?<t>[\\s\\S]*?)\\s*</USER_REQUEST>").t // .) | flat)"]
        elif $s.status == "ERROR" then
          .out += ["TOOL_ERROR \($s.created_at) \(.calls[0] // "-") \($s.error // $s.content // "" | flat)"]
          | .calls |= .[1:]
        elif $s.source == "MODEL" and $s.type != "PLANNER_RESPONSE" then .calls |= .[1:]
        else . end)
      | .out[]' "$1"
    ;;
  claude)
    jq -r '
      def flat: tostring | gsub("\\s+"; " ") | .[0:300];
      select(.type == "user" and (.isMeta | not) and (.isSidechain | not))
      | .timestamp as $ts
      | .message.content
      | if type == "string" then "USER \($ts) \(flat)"
        else (.[] | if .type == "text" then "USER \($ts) \(.text | flat)"
                    elif .type == "tool_result" and .is_error == true
                    then "TOOL_ERROR \($ts) - \(.content | if type == "array" then map(.text? // "") | join(" ") else . end | flat)"
                    else empty end)
        end' "$1"
    ;;
  *)
    echo "transcript-digest.sh: $1 is neither a Claude Code nor an Antigravity transcript" >&2
    exit 2
    ;;
esac
