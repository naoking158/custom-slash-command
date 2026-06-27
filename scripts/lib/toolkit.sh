#!/usr/bin/env bash
# toolkit.sh — Resolve <toolkit_repo> for /my:retro.
#
# Single source of truth for the resolution algorithm specified in
# docs/specs/20260627-session-knowledge-capture.md §3.5. The same logic
# is described inline in prompts/12_retro.md; this file exists so tests
# can exercise the actual shell implementation rather than re-implement it.
#
# Priority order (binding decision, US-004 AC-004):
#   1. ~/.claude/commands symlink whose target is a directory named "commands"
#   2. $CLAUDE_TOOLKIT_REPO env var pointing at an existing directory
#   3. Resolution failure → echo "" and return 1
#
# Forbidden: falling back to $PWD or any cwd-derived guess.

resolve_toolkit_repo() {
  local link target parent
  link="$HOME/.claude/commands"
  if [ -L "$link" ]; then
    target="$(readlink "$link")"
    case "$target" in
      /*) ;;
      *) target="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")" ;;
    esac
    parent="$(dirname "$target")"
    if [ -d "$target" ] && [ "$(basename "$target")" = "commands" ] && [ -d "$parent" ]; then
      printf '%s' "$parent"
      return 0
    fi
  fi
  if [ -n "${CLAUDE_TOOLKIT_REPO:-}" ] && [ -d "$CLAUDE_TOOLKIT_REPO" ]; then
    printf '%s' "$CLAUDE_TOOLKIT_REPO"
    return 0
  fi
  printf ''
  return 1
}

# When sourced, callers invoke `resolve_toolkit_repo`. When executed directly
# (e.g. `bash scripts/lib/toolkit.sh`), run the function and exit with its
# status so it can be used from non-bash callers too.
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then
  resolve_toolkit_repo
  exit $?
fi
