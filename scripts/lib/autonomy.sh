#!/usr/bin/env bash
# autonomy.sh — Resolve a repository's autonomy mode (strict | ship).
#
# The machine-local config ($MY_AUTONOMY_CONF, default
# ~/.claude/my-toolkit/autonomy.conf) opts repositories into ship mode with
# lines of the form `ship <owner/name glob>`. Anything else is strict, so an
# unknown or unparsable repository fails closed.
#
# Sourced by scripts/hooks/outbound-guard.sh; run directly as
#   scripts/lib/autonomy.sh [<dir>]    # prints "<mode> <owner/name>"

# repo_slug DIR — owner/name of DIR's origin remote, empty when unknown.
repo_slug() {
  git -C "$1" remote get-url origin 2>/dev/null \
    | sed -E 's#^(git@[^:]+:|ssh://git@[^/]+/|https?://[^/]+/)##; s#\.git$##'
}

# autonomy_mode SLUG — `ship` when the config opts SLUG in, else `strict`.
autonomy_mode() {
  local slug="$1" conf="${MY_AUTONOMY_CONF:-$HOME/.claude/my-toolkit/autonomy.conf}" kind pat
  [ -n "$slug" ] && [ -f "$conf" ] || { echo strict; return; }
  while read -r kind pat _; do
    [ "$kind" = "ship" ] && [ -n "$pat" ] || continue
    # shellcheck disable=SC2254
    case "$slug" in $pat) echo ship; return ;; esac
  done < "$conf"
  echo strict
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  slug="$(repo_slug "${1:-.}")"
  printf '%s %s\n' "$(autonomy_mode "$slug")" "${slug:-unknown}"
fi
