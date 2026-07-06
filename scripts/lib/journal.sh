#!/usr/bin/env bash
# journal.sh — Single source of truth for the toolkit's machine-local data dir.
#
# The improvement-signal store is GLOBAL (one per machine), not per-project:
# signals target the toolkit itself, regardless of which project they were
# observed in. Layout:
#
#   ~/.claude/my-toolkit/
#   ├── journal/                    # one markdown file per improvement signal
#   │   └── archive/                # promoted / archived signals
#   ├── sessions.jsonl              # SessionEnd hook: index of all sessions
#   ├── corrections.jsonl           # UserPromptSubmit hook: correction candidates
#   └── corrections.archive.jsonl   # corrections already consumed by /my:retro
#
# Override the root with $MY_TOOLKIT_DATA (used by tests).

my_toolkit_data_dir() {
  printf '%s' "${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}"
}

# When executed directly, print the resolved dir.
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then
  my_toolkit_data_dir
  echo
fi
