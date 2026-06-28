#!/usr/bin/env bash
# install.sh — Set up the three symlinks required by this toolkit.
#
#   $HOME/.prompts          -> <repo>/prompts
#   $HOME/.claude/commands  -> <repo>/commands
#   $HOME/.claude/agents    -> <repo>/agents
#
# Usage:
#   ./scripts/install.sh             # create missing links (idempotent)
#   ./scripts/install.sh --check     # report current state, no changes
#   ./scripts/install.sh --uninstall # remove only the links we manage
#   ./scripts/install.sh --force     # replace a symlink that points elsewhere
#   ./scripts/install.sh --help
#
# The script never overwrites a real file/directory at a target path and never
# touches a symlink that points somewhere else (unless --force is given).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

CLAUDE_DIR="$HOME/.claude"

# target|source pairs, in install order.
LINKS=(
  "$HOME/.prompts|$REPO_ROOT/prompts"
  "$CLAUDE_DIR/commands|$REPO_ROOT/commands"
  "$CLAUDE_DIR/agents|$REPO_ROOT/agents"
)

MODE="install"
FORCE=0

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [--check | --uninstall] [--force] [-h|--help]

Creates these symlinks (idempotent):
  $HOME/.prompts          -> <repo>/prompts
  $HOME/.claude/commands  -> <repo>/commands
  $HOME/.claude/agents    -> <repo>/agents

Modes:
  (default)     Install missing links. Skip ones already correct.
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

install_one() {
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

uninstall_one() {
  local target="$1" want="$2" state
  state="$(inspect_target "$target" "$want")"
  case "$state" in
    ok)
      rm "$target"
      printf '  OK     removed:        %s\n' "$target"
      ;;
    wrong-symlink:*)
      local existing="${state#wrong-symlink:}"
      printf '  SKIP   not ours:       %s -> %s\n' "$target" "$existing"
      ;;
    real-path)
      printf '  SKIP   real path:      %s\n' "$target"
      ;;
    absent)
      printf '  SKIP   absent:         %s\n' "$target"
      ;;
  esac
}

check_one() {
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

# --- main --------------------------------------------------------------------

if [ "$MODE" = "install" ]; then
  mkdir -p "$CLAUDE_DIR"
fi

case "$MODE" in
  install)   printf 'Installing toolkit symlinks (repo: %s)\n' "$REPO_ROOT" ;;
  uninstall) printf 'Uninstalling toolkit symlinks\n' ;;
  check)     printf 'Checking toolkit symlinks (repo: %s)\n' "$REPO_ROOT" ;;
esac

failed=0
for entry in "${LINKS[@]}"; do
  target="${entry%|*}"
  want="${entry#*|}"
  case "$MODE" in
    install)   install_one   "$target" "$want" || failed=1 ;;
    uninstall) uninstall_one "$target" "$want" || failed=1 ;;
    check)     check_one     "$target" "$want" || failed=1 ;;
  esac
done

if [ "$failed" -ne 0 ]; then
  case "$MODE" in
    install)   printf '\nDone with errors. Fix the issues above and re-run.\n' >&2 ;;
    check)     printf '\nCheck failed. Run ./scripts/install.sh to fix.\n' >&2 ;;
    uninstall) printf '\nUninstall finished with warnings.\n' >&2 ;;
  esac
  exit 1
fi

case "$MODE" in
  install)   printf '\nDone.\n' ;;
  uninstall) printf '\nDone.\n' ;;
  check)     printf '\nAll good.\n' ;;
esac
