#!/usr/bin/env bash
# autonomy.sh — Resolve a repository's autonomy mode (strict | ship).
#
# A repository is in ship mode when both hold:
#   - the machine-local config ($MY_AUTONOMY_CONF, default
#     ~/.claude/my-toolkit/autonomy.conf) opts it in with a line
#     `ship <owner/name glob>`;
#   - the last check found that GitHub rulesets on its default branch require
#     a pull request and status checks.
# Anything else is strict, so an unknown or unparsable repository fails closed.
#
# The check asks GitHub, so it runs only when this file is executed:
#   scripts/lib/autonomy.sh [<dir>]    # prints "<mode> <owner/name>"
# A passing check is recorded under $MY_TOOLKIT_DATA/ship-ready/ (default
# ~/.claude/my-toolkit) and counts for 7 days; a failing one removes the
# record and says on stderr which rule is missing. When gh cannot answer, an
# earlier record stands. Classic branch protection is not read.
#
# Sourced by scripts/hooks/outbound-guard.sh, which reads the record only.
# Dependencies: bash, git, sed, date; gh for the check.

SHIP_READY_TTL=604800

# repo_slug DIR — owner/name of DIR's origin remote, empty when unknown.
repo_slug() {
  git -C "$1" remote get-url origin 2>/dev/null \
    | sed -E 's#^(git@[^:]+:|ssh://git@[^/]+/|https?://[^/]+/)##; s#\.git$##'
}

# ship_configured SLUG — succeed when the config opts SLUG into ship mode.
ship_configured() {
  local slug="$1" conf="${MY_AUTONOMY_CONF:-$HOME/.claude/my-toolkit/autonomy.conf}" kind pat
  [ -n "$slug" ] && [ -f "$conf" ] || return 1
  while read -r kind pat _; do
    [ "$kind" = "ship" ] && [ -n "$pat" ] || continue
    # shellcheck disable=SC2254
    case "$slug" in $pat) return 0 ;; esac
  done < "$conf"
  return 1
}

# ship_ready_file SLUG — print where SLUG's check record lives; fail when SLUG
# is not a plain owner/name.
ship_ready_file() {
  case "$1" in ''|*[!A-Za-z0-9._/-]*|*/*/*|/*|*/) return 1 ;; esac
  printf '%s/ship-ready/%s' "${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}" "${1%%/*}__${1#*/}"
}

# ship_ready_recorded SLUG — succeed when a check passed within SHIP_READY_TTL.
ship_ready_recorded() {
  local file at
  file="$(ship_ready_file "$1")" && [ -f "$file" ] || return 1
  read -r at < "$file" || return 1
  case "$at" in ''|*[!0-9]*) return 1 ;; esac
  [ $(( $(date +%s) - at )) -le "$SHIP_READY_TTL" ]
}

# autonomy_mode SLUG — `ship` when the config opts SLUG in and its protection
# was checked, else `strict`.
autonomy_mode() {
  if ship_configured "$1" && ship_ready_recorded "$1"; then echo ship; else echo strict; fi
}

# ship_ready_check SLUG — ask GitHub whether rulesets on SLUG's default branch
# require a pull request and status checks, and record the answer.
# Returns 0 ready, 1 not ready, 2 gh could not answer.
ship_ready_check() {
  local slug="$1" file branch types missing=""
  file="$(ship_ready_file "$slug")" || return 1
  if ! branch="$(gh api "repos/$slug" --jq .default_branch 2>/dev/null)" || [ -z "$branch" ] \
    || ! types="$(gh api "repos/$slug/rules/branches/$branch" --jq '.[].type' 2>/dev/null)"; then
    echo "autonomy: gh could not read the rules of $slug; an earlier record stands" >&2
    return 2
  fi
  printf '%s\n' "$types" | grep -qx pull_request || missing="pull_request"
  printf '%s\n' "$types" | grep -qx required_status_checks \
    || missing="${missing:+$missing and }required_status_checks"
  if [ -n "$missing" ]; then
    rm -f "$file"
    echo "autonomy: $slug stays strict: no ruleset on $branch has a $missing rule" >&2
    return 1
  fi
  mkdir -p "${file%/*}" && date +%s > "$file"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  slug="$(repo_slug "${1:-.}")"
  ship_configured "$slug" && ship_ready_check "$slug"
  printf '%s %s\n' "$(autonomy_mode "$slug")" "${slug:-unknown}"
fi
