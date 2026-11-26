#!/usr/bin/env bash
# antigravity-stop.sh — Antigravity Stop hook: pass each turn to session-end.sh
# and prompt-capture.sh. Claude Code runs those on SessionEnd and
# UserPromptSubmit, which Antigravity does not have.
#
# Antigravity runs Stop at the end of each turn with {conversationId, cwd,
# transcriptPath, terminationReason, lastUserInput}, and again for the same
# input when a background command it started finishes. The conversation is
# indexed in sessions.jsonl on its first turn only, and an input goes to
# prompt-capture.sh, which keeps the corrections, unless the conversation
# already queued it.
# Always prints {"decision":""} and exits 0, so it never changes the turn.
# Dependencies: bash, jq, grep, and those of the two hooks.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}"

payload="$(cat)" || payload=""
session="$(printf '%s' "$payload" | jq -r '.conversationId // empty' 2>/dev/null)"
if [ -n "$session" ]; then
  if ! grep -qF "\"session_id\":$(jq -cn --arg s "$session" '$s')," "$dir/sessions.jsonl" 2>/dev/null; then
    printf '%s' "$payload" \
      | jq -c '{session_id: .conversationId, cwd, transcript_path: .transcriptPath, reason: .terminationReason}' 2>/dev/null \
      | "$here/session-end.sh"
  fi
  input="$(printf '%s' "$payload" | jq -r '.lastUserInput // empty' 2>/dev/null)"
  if ! jq -e --arg s "$session" --arg p "$input" 'select(.session_id == $s and .prompt == ($p | .[0:500]))' \
      "$dir/corrections.jsonl" >/dev/null 2>&1; then
    printf '%s' "$payload" \
      | jq -c '{session_id: .conversationId, cwd, prompt: .lastUserInput}' 2>/dev/null \
      | "$here/prompt-capture.sh"
  fi
fi
printf '{"decision":""}\n'
exit 0
