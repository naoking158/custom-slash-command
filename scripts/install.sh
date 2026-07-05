#!/usr/bin/env bash
# install.sh — Install this toolkit as a skills-directory plugin.
#
#   $HOME/.claude/skills/my -> <repo>   (single symlink; plugin is discovered
#                                        in place, so repo edits apply live)
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

CLAUDE_DIR="$HOME/.claude"
PLUGIN_LINK="$CLAUDE_DIR/skills/my"

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

Creates this symlink (idempotent):
  $HOME/.claude/skills/my -> <repo>

and removes legacy symlinks ($HOME/.prompts, $HOME/.claude/commands,
$HOME/.claude/agents) when they point into this repo.

Modes:
  (default)     Install the link if missing. Clean legacy links.
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

# Resolve a possibly-relative symlink target to an absolute path.
abs_target() {
  local link="$1" target
  target="$(readlink "$link")"
  case "$target" in
    /*) printf '%s' "$target" ;;
    *)  printf '%s/%s' "$(cd "$(dirname "$link")" && pwd -P)" "$target" ;;
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
      mkdir -p "$(dirname "$target")"
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

# --- main --------------------------------------------------------------------

case "$MODE" in
  install)   printf 'Installing plugin symlink (repo: %s)\n' "$REPO_ROOT" ;;
  uninstall) printf 'Uninstalling plugin symlink\n' ;;
  check)     printf 'Checking plugin symlink (repo: %s)\n' "$REPO_ROOT" ;;
esac

failed=0
case "$MODE" in
  install)
    install_plugin_link "$PLUGIN_LINK" "$REPO_ROOT" || failed=1
    for legacy in "${LEGACY_LINKS[@]}"; do
      cleanup_legacy "$legacy"
    done
    ;;
  uninstall)
    uninstall_plugin_link "$PLUGIN_LINK" "$REPO_ROOT" || failed=1
    for legacy in "${LEGACY_LINKS[@]}"; do
      cleanup_legacy "$legacy"
    done
    ;;
  check)
    check_plugin_link "$PLUGIN_LINK" "$REPO_ROOT" || failed=1
    for legacy in "${LEGACY_LINKS[@]}"; do
      check_legacy "$legacy" || failed=1
    done
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
  install)   printf '\nDone. Restart Claude Code (or run /reload-plugins) to pick up the plugin.\n' ;;
  uninstall) printf '\nDone.\n' ;;
  check)     printf '\nAll good.\n' ;;
esac
