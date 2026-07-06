#!/usr/bin/env bash
# toolkit.sh — Resolve <toolkit_repo> for /my:retro.
#
# Single source of truth for the resolution algorithm. The same logic is
# described inline in skills/retro/SKILL.md; this file exists so tests can
# exercise the actual shell implementation rather than re-implement it.
#
# Priority order (binding decision, US-004 AC-004):
#   1. $CLAUDE_TOOLKIT_REPO env var pointing at an existing directory
#      (first priority: the explicit override must win)
#   2. $CLAUDE_PLUGIN_ROOT / $CLAUDE_SKILL_DIR — set by Claude Code when the
#      caller runs as a plugin component; accepted only if the derived root
#      contains .claude-plugin/plugin.json
#   3. ~/.claude/skills/my symlink — resolved target is accepted only if it
#      contains .claude-plugin/plugin.json (i.e. it is the toolkit repo root)
#   4. Resolution failure → echo "" and return 1
#
# Forbidden: falling back to $PWD or any cwd-derived guess.

resolve_toolkit_repo() {
  local link target candidate
  # Priority 1: $CLAUDE_TOOLKIT_REPO env override
  if [ -n "${CLAUDE_TOOLKIT_REPO:-}" ] && [ -d "$CLAUDE_TOOLKIT_REPO" ]; then
    printf '%s' "$CLAUDE_TOOLKIT_REPO"
    return 0
  fi
  # Priority 2: plugin runtime env vars. CLAUDE_PLUGIN_ROOT points at the
  # plugin root; CLAUDE_SKILL_DIR points at <root>/skills/<name>.
  for candidate in "${CLAUDE_PLUGIN_ROOT:-}" \
                   "${CLAUDE_SKILL_DIR:+$CLAUDE_SKILL_DIR/../..}"; do
    if [ -n "$candidate" ] && [ -d "$candidate" ] \
       && [ -f "$candidate/.claude-plugin/plugin.json" ]; then
      printf '%s' "$(cd "$candidate" && pwd -P)"
      return 0
    fi
  done
  # Priority 3: ~/.claude/skills/my symlink to the toolkit repo root
  link="$HOME/.claude/skills/my"
  if [ -L "$link" ]; then
    target="$(readlink "$link")"
    # Resolve relative symlinks against the symlink's own directory.
    case "$target" in
      /*) ;;
      *) target="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")" ;;
    esac
    if [ -d "$target" ] && [ -f "$target/.claude-plugin/plugin.json" ]; then
      # Normalize to a physical path (portable; no GNU realpath).
      printf '%s' "$(cd "$target" && pwd -P)"
      return 0
    fi
  fi
  # Resolution failure — caller emits placeholder + guidance (US-004 AC-004).
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
