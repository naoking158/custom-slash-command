#!/usr/bin/env bash
# session-end.sh — SessionEnd hook: append one index line per session.
#
# Reads the hook payload (JSON) from stdin and appends
#   {ts, session_id, cwd, transcript_path, reason}
# to <data-dir>/sessions.jsonl. /my:retro uses this index to find sessions
# whose transcripts have not been mined yet (transcripts are deleted after
# ~30 days, so the index also records what existed).
#
# Constraints:
#   - SessionEnd hooks have a 1.5s default budget and plugin hooks cannot
#     raise it — this script must stay a single jq call.
#   - Must NEVER fail the session: always exit 0.
# Dependencies: bash, jq.
set -u

dir="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}"
mkdir -p "$dir" 2>/dev/null || exit 0

jq -c '{
  ts: (now | todate),
  session_id: (.session_id // null),
  cwd: (.cwd // null),
  transcript_path: (.transcript_path // null),
  reason: (.reason // null)
}' >> "$dir/sessions.jsonl" 2>/dev/null

exit 0
