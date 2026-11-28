#!/usr/bin/env bash
# profile.sh — Resolve which orca/profiles/<name>.conf this machine uses.
#
# The profile is $MY_ORCA_PROFILE, else the first `profile <name>` line in
# ~/.claude/my-toolkit/orca.conf. Sourced by orca/bin/start-goal and
# scripts/install.sh.

case "${BASH_SOURCE[0]}" in */*) profile_lib_dir="${BASH_SOURCE[0]%/*}" ;; *) profile_lib_dir=. ;; esac
ORCA_PROFILES_DIR="$(cd "$profile_lib_dir/../profiles" && pwd -P)"
ORCA_CONF="$HOME/.claude/my-toolkit/orca.conf"

# orca_profile_name — print the selected profile name, empty when none.
orca_profile_name() {
  local key value
  if [ -n "${MY_ORCA_PROFILE:-}" ]; then
    printf '%s' "$MY_ORCA_PROFILE"
    return
  fi
  [ -f "$ORCA_CONF" ] || return 0
  while read -r key value _ || [ -n "$key" ]; do
    if [ "$key" = profile ] && [ -n "$value" ]; then printf '%s' "$value"; return; fi
  done < "$ORCA_CONF"
}

# orca_profile_file NAME — print the profile file for NAME; fail when NAME is
# not a plain name or has no file.
orca_profile_file() {
  case "$1" in ''|*[!A-Za-z0-9_-]*) return 1 ;; esac
  [ -f "$ORCA_PROFILES_DIR/$1.conf" ] || return 1
  printf '%s' "$ORCA_PROFILES_DIR/$1.conf"
}

# orca_profile_choices — print the available profile names, space-separated.
orca_profile_choices() {
  local f out=""
  for f in "$ORCA_PROFILES_DIR"/*.conf; do
    [ -f "$f" ] || continue
    f="${f##*/}"
    out="${out:+$out }${f%.conf}"
  done
  printf '%s' "$out"
}
