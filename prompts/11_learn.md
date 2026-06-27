# Learn Phase Prompt

<role>
@import _shared/roles/learn.md
</role>

<arguments>
| Arg | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `--category` | `mistake \| pattern \| preference \| domain-knowledge \| open-question` | No | inferred from conversation | The 5-value enum is binding; unknown values fall back to `domain-knowledge` with a warning (Edge case #10). |
| `--confidence` | `high \| medium \| low` | No | `medium` | Author's confidence in the captured learning. |
| free-text memo | string | No | (empty) | Seeds the `Learned` body section. |
</arguments>

<process>
@import _shared/processes/learn.md

### Inline implementation snippet (bash, MVP)

```bash
# session_id resolution (MVP)
# - Priority 1: $CLAUDE_SESSION_ID (if Claude Code exports it)
# - Priority 2: timestamp fallback `mv-YYYYMMDD-HHMMSS`
#
# NOTE: Spec §3.1 also lists transcript_path-derived ids. We do NOT use that
# in MVP because Claude Code has not committed to exposing transcript_path
# to the shell via a documented hook/env channel. Once it does, insert a
# second priority step here.
resolve_sid() {
  if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
    echo "$CLAUDE_SESSION_ID"
    return
  fi
  echo "mv-$(date +%Y%m%d-%H%M%S)"
}

# Build target path (machine-local only).
repo="$(basename "$PWD")"
sid="$(resolve_sid)"
target="$HOME/.claude/projects/$repo/memory/journal/$(date +%Y-%m-%d)-$sid.md"

# Path policy assertion: target must NOT be under the current repo tree.
case "$target" in
  "$PWD"/*)
    echo "journal path must be machine-local: $target" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$target")"
```

### Frontmatter upsert outline

- If `$target` does not exist: write the full schema (frontmatter + 5 body sections, `recurrence: 1`, `status: raw`).
- If `$target` exists and frontmatter parses: bump `recurrence` by 1 and append a new bullet under `## Learned`.
- If `$target` exists but frontmatter is malformed: `mv "$target" "$target.bak"`, emit a warning, then write fresh.
</process>

<rules>
<critical>
- All writes MUST land under `$HOME/.claude/projects/<repo>/memory/journal/`.
  Never write under `$PWD` (the repository tree). On violation: abort with exit 1.
- `MEMORY.md` (Auto Memory) is read-only. Do not open it for write and do not delete it.
- The repository tree must never contain a `docs/journal/` directory (US-003 invariant).
- The 5 body sections (`## Request` / `## Investigated` / `## Learned` / `## Completed` / `## Next Steps`) are mandatory and ordered.
- The category enum is exactly `mistake | pattern | preference | domain-knowledge | open-question`. Unknown values fall back to `domain-knowledge` with a warning (US-005 AC-001, Edge case #10).
</critical>

@import _shared/output-constraints.md
@import _shared/quality-standards.md
</rules>

<edge-cases>
- #1: Resolved path falls under `$PWD/` → abort, exit 1, stderr `journal path must be machine-local: <path>`.
- #2: `$CLAUDE_SESSION_ID` is unset → use `mv-$(date +%Y%m%d-%H%M%S)` and warn.
- #3: Existing frontmatter is corrupt → `mv` it to `*.bak` and start fresh; warn.
- #4: Journal directory does not exist → `mkdir -p` and continue.
- #10: Unknown `--category` value → warn, fall back to `domain-knowledge`.
- #11: Same session calls `/my:learn` multiple times → append + `recurrence += 1` (capture count within session).
- #13: Existing file is missing one of the 5 body sections → backfill the missing section with an empty body and warn.
- #15: Coexist with Auto Memory — never touch `MEMORY.md`.
</edge-cases>

<output>
<confirmation-format>
After writing the journal file, confirm with:

```
✅ Journal entry appended.
Path: ~/.claude/projects/<repo>/memory/journal/<YYYY-MM-DD>-<session_id>.md
Categories: [<category>, ...]
Status: raw
Next: run `/my:retro` to see promotion candidates.
```
</confirmation-format>

<example>
<input>/my:learn --category mistake "TS catch は unknown 必須"</input>
<result>
✅ Journal entry appended.
Path: ~/.claude/projects/custom-slash-command/memory/journal/2026-06-27-7a063d83.md
Categories: [mistake]
Status: raw
Next: run `/my:retro` to see promotion candidates.
</result>
</example>
</output>
