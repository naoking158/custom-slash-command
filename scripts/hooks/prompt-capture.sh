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
# Orca prepends its own text to the owner's words: `[Orca: ...]` lines with
# their `<<<`/`>>>` quotes, the `## First run` rules, and `──── From:` mail.
# Those parts are cut before matching, and only what is left is stored; a
# prompt that is all Orca text, or an Orca worker dispatch, is not stored.
# A block whose end cannot be found is kept, since a stored false positive
# can be dropped by retro but a missed correction cannot be recovered. The
# `## First run` rules are ASCII `- ` lines that start with a capital letter
# and end at an `Orca: ` line, a blank line or the next Orca block; any other
# line right after them keeps them, as an end that cannot be found. A stored
# prompt that still starts with Orca text keeps its last 500 characters,
# where the owner's words are, instead of its first.
#
# False positives are acceptable (retro filters); false exits are not:
# always exit 0 so the prompt is never blocked or delayed by an error.
# Dependencies: bash, jq, grep, awk, sed.
set -u

dir="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}"

payload="$(cat)" || exit 0
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null)" || exit 0
[ -z "$prompt" ] && exit 0

case "$prompt" in "You are working inside Orca, a multi-agent IDE."*) exit 0 ;; esac
# strip_orca — print stdin without the blocks Orca prepends. Each block is
# buffered and printed back when its closing line never comes.
strip_orca() {
  awk '
    function flush() { printf "%s", buf; buf = "" }
    function keep(line) { buf = buf line "\n" }
    mode == "mail" { keep($0); if ($0 ~ /^(─)+$/) { buf = ""; mode = "" } ; next }
    mode == "quote" { keep($0); if ($0 == ">>>") { buf = ""; mode = "after" } ; next }
    mode == "after" && index($0, "${ORCA_CLI_COMMAND:-orca}") { next }
    mode == "rules" && ($0 == "" || $0 == "## First run") { keep($0); next }
    mode == "rules" && /^- [A-Z][ -~]*$/ { keep($0); mode = "bullets"; next }
    mode == "bullets" && /^- [A-Z][ -~]*$/ { keep($0); next }
    mode == "bullets" && /^Orca: / { buf = ""; mode = ""; next }
    mode == "bullets" && $0 == "" { buf = ""; mode = ""; print; next }
    mode == "bullets" && /^(\[Orca: |──── From: )/ { buf = "" }
    mode == "orca" && $0 == "<<<" { keep($0); mode = "quote"; next }
    { flush(); mode = "" }
    /^──── From: / { keep($0); mode = "mail"; next }
    /^\[Orca: / { mode = /first run/ ? "rules" : "orca"; if (mode == "rules") keep($0); next }
    { print }
    END { flush() }
  '
}
human="$(printf '%s\n' "$prompt" | strip_orca)"
if [ "$human" = "$prompt" ]; then
  human=""
else
  human="$(printf '%s' "$human" | sed -e '/./,$!d')"
  [ -z "$human" ] && exit 0
  prompt="$human"
fi

# Slash commands are never corrections.
case "$prompt" in /*) exit 0 ;; esac
# Neither are system-injected prompts — <task-notification>, <scheduled-task>,
# <system-reminder>, <local-command-*> arrive wrapped in an XML-ish tag — nor
# the review-screen feedback Markdown that the user pastes back verbatim.
printf '%s' "$prompt" | grep -qE '^[[:space:]]*(<[A-Za-z][A-Za-z-]*[[:space:]>/]|# レビューフィードバック:)' && exit 0

markers='違う|ちがう|そうじゃなく|じゃなくて|ではなく|しないで|やめて|やり直し|覚えて|忘れないで|さっきも|前も言った|何度も言|^no[,. ]|not that|don.t (do|use)|stop (doing|using)|instead of|^actually[, ]|remember (this|that|:)|i (already|just) (said|told)|as i said'
printf '%s' "$prompt" | grep -qiE "$markers" || exit 0

mkdir -p "$dir" 2>/dev/null || exit 0
printf '%s' "$payload" | jq -c --arg human "$human" '{
  ts: (now | todate),
  session_id: (.session_id // null),
  cwd: (.cwd // null),
  prompt: ((if $human == "" then .prompt // "" else $human end)
    | if test("^(\\[Orca: |──── From: |<<<\n)") then .[-500:] else .[0:500] end)
}' >> "$dir/corrections.jsonl" 2>/dev/null

exit 0
