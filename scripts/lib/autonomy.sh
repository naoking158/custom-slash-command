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
# ~/.claude/my-toolkit) and counts for 7 days. A ruleset this token can bypass
# does not count. A failing check, and a repository GitHub will not show
# (missing, or rulesets unavailable on its plan), removes the record and says
# why on stderr. When GitHub gives no answer (network, login, rate limit), an
# earlier record stands. Classic branch protection is not read.
#
# Sourced by scripts/hooks/outbound-guard.sh, which reads the record only.
# Dependencies: bash, git, sed, date, grep; gh, mktemp, cut, sort, tr for the check.

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
  at=$(( $(date +%s) - at ))
  [ "$at" -ge 0 ] && [ "$at" -le "$SHIP_READY_TTL" ]
}

# autonomy_mode SLUG — `ship` when the config opts SLUG in and its protection
# was checked, else `strict`.
autonomy_mode() {
  if ship_configured "$1" && ship_ready_recorded "$1"; then echo ship; else echo strict; fi
}

# ship_gh ENDPOINT JQ — print GitHub's answer. On failure print gh's message
# and return 1 when GitHub refused for good (not found, or rulesets are not
# available to this repository's plan), 2 when a retry may pass.
ship_gh() {
  local out err rc message
  err="$(mktemp)" || return 2
  out="$(gh api "$1" --jq "$2" 2>"$err")"
  rc=$?
  message="$(tail -n 1 "$err")"
  rm -f "$err"
  if [ "$rc" -eq 0 ]; then printf '%s' "$out"; return 0; fi
  printf '%s' "${message:-gh failed}"
  case "$message" in *"(HTTP 404)"*|*"Upgrade to GitHub"*"(HTTP 403)"*) return 1 ;; esac
  return 2
}

# ship_ready_ask SLUG — ask GitHub whether rulesets that this token cannot
# bypass require a pull request and status checks on SLUG's default branch.
# Prints why not. Returns 0 ready, 1 not ready, 2 GitHub gave no answer.
ship_ready_ask() {
  local slug="$1" branch rules id bypass rc types=" " missing=""
  branch="$(ship_gh "repos/$slug" .default_branch)" || { rc=$?; printf '%s' "$branch"; return "$rc"; }
  rules="$(ship_gh "repos/$slug/rules/branches/$branch" \
    '.[] | select(.type == "pull_request" or .type == "required_status_checks") | "\(.type) \(.ruleset_id)"')" \
    || { rc=$?; printf '%s' "$rules"; return "$rc"; }
  for id in $(printf '%s\n' "$rules" | cut -d' ' -f2 | sort -u); do
    bypass="$(ship_gh "repos/$slug/rulesets/$id" .current_user_can_bypass)" \
      || { rc=$?; printf '%s' "$bypass"; return "$rc"; }
    [ "$bypass" = never ] || continue
    types="$types$(printf '%s\n' "$rules" | grep " $id\$" | cut -d' ' -f1 | tr '\n' ' ')"
  done
  case "$types" in *" pull_request "*) ;; *) missing="pull_request" ;; esac
  case "$types" in *" required_status_checks "*) ;; *) missing="${missing:+$missing and }required_status_checks" ;; esac
  [ -n "$missing" ] || return 0
  printf 'no ruleset on %s that this token cannot bypass has a %s rule' "$branch" "$missing"
  return 1
}

# ship_ready_check SLUG — run ship_ready_ask and keep the record in step: a
# pass writes it, a refusal removes it, no answer leaves it as it was. The
# reason goes to stderr. Returns what ship_ready_ask returned.
ship_ready_check() {
  local slug="$1" file why rc
  file="$(ship_ready_file "$slug")" || return 1
  why="$(ship_ready_ask "$slug")"
  rc=$?
  case "$rc" in
    0) mkdir -p "${file%/*}" && date +%s > "$file" ;;
    1) rm -f "$file"
       echo "autonomy: $slug stays strict: $why" >&2 ;;
    *) if ship_ready_recorded "$slug"; then
         echo "autonomy: GitHub gave no answer for $slug ($why); the earlier record stands" >&2
       else
         echo "autonomy: GitHub gave no answer for $slug ($why); with no record it stays strict" >&2
       fi ;;
  esac
  return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  slug="$(repo_slug "${1:-.}")"
  ship_configured "$slug" && ship_ready_check "$slug"
  printf '%s %s\n' "$(autonomy_mode "$slug")" "${slug:-unknown}"
fi
