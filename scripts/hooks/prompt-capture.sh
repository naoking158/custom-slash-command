#!/usr/bin/env bash
# prompt-capture.sh — UserPromptSubmit hook: capture correction candidates.
#
# Reads the hook payload (JSON) from stdin. If the prompt looks like the user
# correcting Claude (Japanese or English markers), appends
#   {ts, session_id, cwd, prompt (truncated to 500 chars)}
# to <data-dir>/corrections.jsonl. Repeated corrections across sessions are
# the strongest signal that a toolkit instruction is missing or wrong;
# /my:retro clusters this queue into promotion candidates.
#
# False positives are acceptable (retro filters); false exits are not:
# always exit 0 so the prompt is never blocked or delayed by an error.
# Dependencies: bash, jq, grep.
set -u

dir="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}"

payload="$(cat)" || exit 0
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null)" || exit 0
[ -z "$prompt" ] && exit 0

# Slash commands are never corrections.
case "$prompt" in /*) exit 0 ;; esac
# Neither are system-injected prompts — <task-notification>, <scheduled-task>,
# <system-reminder>, <local-command-*> arrive wrapped in an XML-ish tag — nor
# the review-screen feedback Markdown that the user pastes back verbatim.
printf '%s' "$prompt" | grep -qE '^[[:space:]]*(<[A-Za-z][A-Za-z-]*[[:space:]>/]|# レビューフィードバック:)' && exit 0

markers='違う|ちがう|そうじゃなく|じゃなくて|ではなく|しないで|やめて|やり直し|覚えて|忘れないで|さっきも|前も言った|何度も言|^no[,. ]|not that|don.t (do|use)|stop (doing|using)|instead of|^actually[, ]|remember (this|that|:)|i (already|just) (said|told)|as i said'
printf '%s' "$prompt" | grep -qiE "$markers" || exit 0

mkdir -p "$dir" 2>/dev/null || exit 0
printf '%s' "$payload" | jq -c '{
  ts: (now | todate),
  session_id: (.session_id // null),
  cwd: (.cwd // null),
  prompt: ((.prompt // "") | .[0:500])
}' >> "$dir/corrections.jsonl" 2>/dev/null

exit 0
