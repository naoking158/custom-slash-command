#!/usr/bin/env bash
# install.sh — Install this toolkit as a Claude Code skills-directory plugin
# and as an Antigravity plugin.
#
#   $HOME/.claude/skills/my -> <repo>   (single symlink; plugin is discovered
#                                        in place, so repo edits apply live)
#   $HOME/.gemini/config/plugins/my -> <repo>
#                                       (the same repo as an Antigravity plugin)
#   $HOME/.claude/rules/<f>.md -> <repo>/rules/<f>.md
#                                       (plugins cannot ship rules, so each
#                                        file except the Antigravity-only
#                                        AGENTS.md and antigravity.md is
#                                        linked on its own)
#
# When an `orca` command is on PATH, install and --check also confirm that
# orca/bin/doctor is executable and point at it without running it, and that
# an Orca profile is selected ($MY_ORCA_PROFILE or `profile <name>` in
# ~/.claude/my-toolkit/orca.conf) and exists. Without `orca`, nothing about
# the Orca layer is done or printed.
#
# Also cleans up symlinks from the pre-plugin layout when they point into
# this repo:
#   $HOME/.prompts, $HOME/.claude/commands, $HOME/.claude/agents
#
# Usage:
#   ./scripts/install.sh             # create the link, clean legacy links
#   ./scripts/install.sh --check     # report current state, no changes
#   ./scripts/install.sh --uninstall # remove only what we manage
#   ./scripts/install.sh --force     # replace a symlink that points elsewhere
#   ./scripts/install.sh --help
#
# The script never overwrites a real file/directory at a target path and never
# touches a symlink that points somewhere else (unless --force is given).

set -euo pipefail

case "${BASH_SOURCE[0]}" in */*) self_dir="${BASH_SOURCE[0]%/*}" ;; *) self_dir=. ;; esac
SCRIPT_DIR="$(cd "$self_dir" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

CLAUDE_DIR="$HOME/.claude"
PLUGIN_LINK="$CLAUDE_DIR/skills/my"
ANTIGRAVITY_PLUGIN_LINK="$HOME/.gemini/config/plugins/my"
RULES_DIR="$CLAUDE_DIR/rules"
ORCA_DOCTOR="$REPO_ROOT/orca/bin/doctor"
ORCA_PROFILE_LIB="$REPO_ROOT/orca/lib/profile.sh"

# Symlinks from the pre-plugin layout. Removed when they point into this repo
# (including dangling links left behind after the repo restructure).
LEGACY_LINKS=(
  "$HOME/.prompts"
  "$CLAUDE_DIR/commands"
  "$CLAUDE_DIR/agents"
)

MODE="install"
FORCE=0

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [--check | --uninstall] [--force] [-h|--help]

Creates these symlinks (idempotent):
  $HOME/.claude/skills/my -> <repo>
  $HOME/.gemini/config/plugins/my -> <repo>   (Antigravity plugin)
  $HOME/.claude/rules/<f>.md -> <repo>/rules/<f>.md   (one per rules file, except
                                                        AGENTS.md and antigravity.md)

and removes legacy symlinks ($HOME/.prompts, $HOME/.claude/commands,
$HOME/.claude/agents) when they point into this repo.

When an `orca` command is on PATH, install and --check also confirm that
orca/bin/doctor is executable (run it from an Orca terminal yourself) and that
an Orca profile is selected: MY_ORCA_PROFILE, or a `profile <name>` line in
$HOME/.claude/my-toolkit/orca.conf (work on the work machine, private on the
private one).

Modes:
  (default)     Install the links if missing. Clean legacy links.
  --check       Report state and exit non-zero if anything is missing/wrong.
  --uninstall   Remove only the symlinks we manage. Never touch real files
                or symlinks pointing elsewhere.
  --force       When installing, replace a symlink that points to another
                location. Does NOT override the real-file safeguard.
EOF
}

# --- arg parsing -------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --check)     MODE=check ;;
    --uninstall) MODE=uninstall ;;
    --force)     FORCE=1 ;;
    -h|--help)   usage; exit 0 ;;
    *)
      printf 'install.sh: unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# --- helpers -----------------------------------------------------------------

# parent_dir PATH — PATH without its last component, as dirname prints it for
# a path that does not end in /.
parent_dir() {
  case "$1" in
    */*) local p="${1%/*}"; printf '%s' "${p:-/}" ;;
    *) printf '.' ;;
  esac
}

# Resolve a possibly-relative symlink target to an absolute path.
abs_target() {
  local link="$1" target
  target="$(readlink "$link")"
  case "$target" in
    /*) printf '%s' "$target" ;;
    *)  printf '%s/%s' "$(cd "$(parent_dir "$link")" && pwd -P)" "$target" ;;
  esac
}

# Echo one of: absent | ok | wrong-symlink:<actual> | real-path
inspect_target() {
  local target="$1" want="$2"
  if [ -L "$target" ]; then
    local actual want_real actual_real
    actual="$(abs_target "$target")"
    want_real="$(cd "$want" && pwd -P)"
    if [ -d "$actual" ]; then
      actual_real="$(cd "$actual" && pwd -P)"
    else
      actual_real="$actual"
    fi
    if [ "$actual_real" = "$want_real" ]; then
      printf 'ok'
    else
      printf 'wrong-symlink:%s' "$actual_real"
    fi
  elif [ -e "$target" ]; then
    printf 'real-path'
  else
    printf 'absent'
  fi
}

install_plugin_link() {
  local target="$1" want="$2" state
  state="$(inspect_target "$target" "$want")"
  case "$state" in
    ok)
      printf '  OK     already linked: %s\n' "$target"
      ;;
    absent)
      mkdir -p "$(parent_dir "$target")"
      ln -s "$want" "$target"
      printf '  OK     created:        %s -> %s\n' "$target" "$want"
      ;;
    wrong-symlink:*)
      local existing="${state#wrong-symlink:}"
      if [ "$FORCE" -eq 1 ]; then
        rm "$target"
        ln -s "$want" "$target"
        printf '  OK     replaced:       %s -> %s (was: %s)\n' "$target" "$want" "$existing"
      else
        printf '  ERROR  points elsewhere: %s -> %s\n' "$target" "$existing" >&2
        printf '         re-run with --force to replace.\n' >&2
        return 1
      fi
      ;;
    real-path)
      printf '  ERROR  real file/dir at %s — refusing to touch.\n' "$target" >&2
      printf '         move or remove it manually, then re-run.\n' >&2
      return 1
      ;;
  esac
}

uninstall_plugin_link() {
  local target="$1" want="$2" state
  state="$(inspect_target "$target" "$want")"
  case "$state" in
    ok)
      rm "$target"
      printf '  OK     removed:        %s\n' "$target"
      ;;
    wrong-symlink:*)
      printf '  SKIP   not ours:       %s -> %s\n' "$target" "${state#wrong-symlink:}"
      ;;
    real-path)
      printf '  SKIP   real path:      %s\n' "$target"
      ;;
    absent)
      printf '  SKIP   absent:         %s\n' "$target"
      ;;
  esac
}

check_plugin_link() {
  local target="$1" want="$2" state
  state="$(inspect_target "$target" "$want")"
  case "$state" in
    ok)
      printf '  OK        %s -> %s\n' "$target" "$want"
      ;;
    absent)
      printf '  MISSING   %s\n' "$target"
      return 1
      ;;
    wrong-symlink:*)
      printf '  WRONG     %s -> %s\n' "$target" "${state#wrong-symlink:}"
      return 1
      ;;
    real-path)
      printf '  CONFLICT  %s (real file/dir)\n' "$target"
      return 1
      ;;
  esac
}

# Echo one of: absent | ok | wrong-symlink:<actual> | real-path (for files)
inspect_file_link() {
  local target="$1" want="$2"
  if [ -L "$target" ]; then
    local actual
    actual="$(abs_target "$target")"
    if [ "$actual" = "$want" ]; then printf 'ok'; else printf 'wrong-symlink:%s' "$actual"; fi
  elif [ -e "$target" ]; then
    printf 'real-path'
  else
    printf 'absent'
  fi
}

# Usage: rule_link <install|uninstall|check> <target> <want>
rule_link() {
  local mode="$1" target="$2" want="$3" state
  state="$(inspect_file_link "$target" "$want")"
  case "$mode:$state" in
    install:ok)        printf '  OK     already linked: %s\n' "$target" ;;
    install:absent)
      mkdir -p "$(parent_dir "$target")"
      ln -s "$want" "$target"
      printf '  OK     created:        %s -> %s\n' "$target" "$want" ;;
    install:wrong-symlink:*)
      if [ "$FORCE" -eq 1 ]; then
        rm "$target"; ln -s "$want" "$target"
        printf '  OK     replaced:       %s -> %s\n' "$target" "$want"
      else
        printf '  ERROR  points elsewhere: %s -> %s\n' "$target" "${state#wrong-symlink:}" >&2
        printf '         re-run with --force to replace.\n' >&2
        return 1
      fi ;;
    install:real-path)
      printf '  ERROR  real file at %s — refusing to touch.\n' "$target" >&2
      printf '         move or remove it manually, then re-run.\n' >&2
      return 1 ;;
    uninstall:ok)      rm "$target"; printf '  OK     removed:        %s\n' "$target" ;;
    uninstall:*)       printf '  SKIP   not ours:       %s\n' "$target" ;;
    check:ok)          printf '  OK        %s -> %s\n' "$target" "$want" ;;
    check:absent)      printf '  MISSING   %s\n' "$target"; return 1 ;;
    check:wrong-symlink:*) printf '  WRONG     %s -> %s\n' "$target" "${state#wrong-symlink:}"; return 1 ;;
    check:real-path)   printf '  CONFLICT  %s (real file)\n' "$target"; return 1 ;;
  esac
}

for_each_rule() {
  local mode="$1" src rc=0
  for src in "$REPO_ROOT"/rules/*.md; do
    [ -e "$src" ] || continue
    case "${src##*/}" in AGENTS.md|antigravity.md) continue ;; esac
    rule_link "$mode" "$RULES_DIR/${src##*/}" "$src" || rc=1
  done
  return "$rc"
}

# Legacy links may dangle (their old targets under the repo no longer exist),
# so classify by literal target path instead of resolving directories.
legacy_points_into_repo() {
  local target="$1" actual
  [ -L "$target" ] || return 1
  actual="$(abs_target "$target")"
  case "$actual" in
    "$REPO_ROOT"|"$REPO_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

cleanup_legacy() {
  local target="$1"
  if legacy_points_into_repo "$target"; then
    rm "$target"
    printf '  OK     legacy removed: %s\n' "$target"
  elif [ -L "$target" ] || [ -e "$target" ]; then
    printf '  SKIP   not ours:       %s\n' "$target"
  fi
}

check_legacy() {
  local target="$1"
  if legacy_points_into_repo "$target"; then
    printf '  LEGACY    %s (points into repo; run install to clean up)\n' "$target"
    return 1
  fi
  return 0
}

# orca_problem MODE TEXT — report a missing piece of the Orca layer.
orca_problem() {
  if [ "$1" = install ]; then
    printf '  ERROR  %s\n' "$2" >&2
  else
    printf '  MISSING   %s\n' "$2"
  fi
}

# Usage: orca_layer <install|check> — confirm orca/bin/doctor and the Orca
# profile when an orca command is on PATH.
orca_layer() {
  command -v orca >/dev/null 2>&1 || return 0
  if [ ! -x "$ORCA_DOCTOR" ] || [ ! -f "$ORCA_PROFILE_LIB" ]; then
    orca_problem "$1" "$ORCA_DOCTOR (orca found on PATH, but the Orca layer is not executable)"
    return 1
  fi
  printf '  OK        orca found; run %s from an Orca terminal\n' "$ORCA_DOCTOR"

  # shellcheck source=../orca/lib/profile.sh
  . "$ORCA_PROFILE_LIB"
  local name
  name="$(orca_profile_name)"
  if [ -z "$name" ]; then
    orca_problem "$1" "Orca profile not selected: write 'profile <name>' in $ORCA_CONF or set MY_ORCA_PROFILE (choices: $(orca_profile_choices)). Without it, Antigravity stops at every step that launches an agent"
    return 1
  fi
  if ! orca_profile_file "$name" >/dev/null; then
    orca_problem "$1" "Orca profile '$name' has no orca/profiles/$name.conf (choices: $(orca_profile_choices))"
    return 1
  fi
  printf '  OK        Orca profile: %s\n' "$name"
}

# --- main --------------------------------------------------------------------

case "$MODE" in
  install)   printf 'Installing plugin symlinks (repo: %s)\n' "$REPO_ROOT" ;;
  uninstall) printf 'Uninstalling plugin symlinks\n' ;;
  check)     printf 'Checking plugin symlinks (repo: %s)\n' "$REPO_ROOT" ;;
esac

failed=0
case "$MODE" in
  install)
    install_plugin_link "$PLUGIN_LINK" "$REPO_ROOT" || failed=1
    install_plugin_link "$ANTIGRAVITY_PLUGIN_LINK" "$REPO_ROOT" || failed=1
    for_each_rule install || failed=1
    for legacy in "${LEGACY_LINKS[@]}"; do
      cleanup_legacy "$legacy"
    done
    orca_layer install || failed=1
    ;;
  uninstall)
    uninstall_plugin_link "$PLUGIN_LINK" "$REPO_ROOT" || failed=1
    uninstall_plugin_link "$ANTIGRAVITY_PLUGIN_LINK" "$REPO_ROOT" || failed=1
    for_each_rule uninstall || failed=1
    for legacy in "${LEGACY_LINKS[@]}"; do
      cleanup_legacy "$legacy"
    done
    ;;
  check)
    check_plugin_link "$PLUGIN_LINK" "$REPO_ROOT" || failed=1
    check_plugin_link "$ANTIGRAVITY_PLUGIN_LINK" "$REPO_ROOT" || failed=1
    for_each_rule check || failed=1
    for legacy in "${LEGACY_LINKS[@]}"; do
      check_legacy "$legacy" || failed=1
    done
    orca_layer check || failed=1
    ;;
esac

if [ "$failed" -ne 0 ]; then
  case "$MODE" in
    install)   printf '\nDone with errors. Fix the issues above and re-run.\n' >&2 ;;
    check)     printf '\nCheck failed. Run ./scripts/install.sh to fix.\n' >&2 ;;
    uninstall) printf '\nUninstall finished with warnings.\n' >&2 ;;
  esac
  exit 1
fi

case "$MODE" in
  install)   printf '\nDone. Restart Claude Code (or run /reload-plugins) and start a new Antigravity conversation to pick up the plugin.\n' ;;
  uninstall) printf '\nDone.\n' ;;
  check)     printf '\nAll good.\n' ;;
esac
