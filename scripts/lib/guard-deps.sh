# shellcheck shell=bash
# guard-deps.sh — What a guard hook answers when a command it needs is missing.
#
# Sourced by scripts/hooks/outbound-guard.sh and antigravity-guard.sh. Without
# jq or perl a hook cannot read its payload; allowing everything then would
# switch the guard off without a word. A hook in that state denies the calls
# that look outbound and lets the rest through.
# Dependencies: bash, grep.

# missing_dep NAME... — print the first NAME that is not on PATH.
missing_dep() {
  local dep
  for dep in "$@"; do
    command -v "$dep" >/dev/null 2>&1 || { printf '%s' "$dep"; return; }
  done
}

# looks_outbound PAYLOAD — succeed when the raw hook payload mentions a push, a
# gh command that writes, or a Notion write.
looks_outbound() {
  printf '%s' "$1" | grep -qE 'git.*push|gh[[:space:]]+(pr|api|issue|release)|notion-(create|update)-'
}

# missing_dep_reason NAME — the reason shown for a call denied for lack of NAME.
missing_dep_reason() {
  printf 'outbound-guard: %s が PATH になく、外へ出すコマンドを検査できない。%s を入れてからやり直す' "$1" "$1"
}
