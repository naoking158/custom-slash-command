# shellcheck shell=bash
# guard-deps.sh — What a guard hook answers when a command it needs is missing.
#
# Sourced by scripts/hooks/outbound-guard.sh and antigravity-guard.sh. Without
# what reads its payload (the binary for outbound-guard, jq for
# antigravity-guard) a hook cannot judge a call; allowing everything then would
# switch the guard off without a word. A hook in that state denies the calls
# that look outbound and stays out of the way of the rest.
# Dependencies: bash, grep.

# missing_dep NAME... — print the first NAME that is not on PATH.
missing_dep() {
  local dep
  for dep in "$@"; do
    command -v "$dep" >/dev/null 2>&1 || { printf '%s' "$dep"; return; }
  done
}

# looks_outbound PAYLOAD — succeed when the raw hook payload holds a `git push`,
# a gh pr / api / issue / release call (reads included: they cannot be told
# apart here), or a Notion write. The payload is JSON, so a newline or a tab
# in the command arrives as the two characters \n or \t; both count as a word
# boundary.
looks_outbound() {
  printf '%s' "$1" | grep -qE \
    -e '(^|[^[:alnum:]_.-]|\\[nrt])git([[:space:]]|\\[nrt]|\\\\)(.*([^[:alnum:]_-]|\\[nrt]))?push([^[:alnum:]_-]|$)' \
    -e '(^|[^[:alnum:]_.-]|\\[nrt])gh([[:space:]]|\\[nrt]|\\\\)+(pr|api|issue|release)([^[:alnum:]_-]|$)' \
    -e 'notion-(create|update)-'
}

# missing_dep_reason NAME — the reason shown for a call denied for lack of NAME.
missing_dep_reason() {
  printf 'outbound-guard: %s が PATH になく、外へ出すコマンドを検査できない。%s を入れてからやり直す' "$1" "$1"
}
