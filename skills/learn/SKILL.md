---
description: Capture session knowledge into a machine-local journal entry. Records what the session requested, investigated, learned, and completed, with recurrence tracking for repeat learnings. Trigger words: learn, journal, 学び, ジャーナル.
argument-hint: "[--category <mistake|pattern|preference|domain-knowledge|open-question>] [--confidence <high|medium|low>] [free-text memo]"
disable-model-invocation: true
---

# Learn Phase — Session Knowledge Capture

Capture a session-level learning into the machine-local journal store.
Input: **$ARGUMENTS**

You are acting as a session knowledge capturer. Append this session's
learnings to a journal entry under `~/.claude/projects/` — never inside the
repository tree — so `/my:retro` can later surface promotion candidates.
Repeat invocations within a session append idempotently and bump `recurrence`.

## Arguments

The user may invoke this with no arguments (full conversational inference) or
with one or more of:

| Arg | Values | Default | Notes |
|-----|--------|---------|-------|
| `--category` | `mistake \| pattern \| preference \| domain-knowledge \| open-question` | inferred from conversation | The 5-value enum is binding; unknown values fall back to `domain-knowledge` with a warning. |
| `--confidence` | `high \| medium \| low` | `medium` | Author's confidence in the captured learning. |
| free-text memo | string | (empty) | Seeds the `## Learned` body section. |

## Step 1 — Resolve session_id

- Prefer `$CLAUDE_SESSION_ID` if set.
- Otherwise fall back to `mv-$(date +%Y%m%d-%H%M%S)` and emit a warning.
- Do NOT rely on an undocumented `transcript_path` variable; that channel is
  deferred until Claude Code exposes it via a documented hook payload or env var.

## Step 2 — Build the target path

Journal entries live at
`~/.claude/projects/{repo}/memory/journal/{YYYY-MM-DD}-{session_id}.md`
where `{repo}` is `basename "$PWD"`. Assert machine-locality before writing:

```bash
repo="$(basename "$PWD")"
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

## Step 3 — Upsert the entry

- File absent: write the full frontmatter schema (below) with `recurrence: 1`,
  `status: raw`, plus the 5 mandatory body sections.
- File present and frontmatter parses: bump `recurrence` by 1, append a new
  bullet under `## Learned`, and leave all other fields intact.
- File present but frontmatter is malformed: `mv "$target" "$target.bak"`,
  emit a warning, then write fresh.

Frontmatter schema of a journal entry:

```yaml
---
session_id: {session_id}
date: {YYYY-MM-DD}
project: {repo}
categories: [{category}, ...]   # values from the 5-value enum
confidence: medium              # high | medium | low
recurrence: 1                   # bumped +1 on each repeat capture
status: raw                     # raw | promoted | archived (learn always writes raw)
source_commits: []
tags: []
---
```

## Step 4 — Render body sections

- Order is fixed and all 5 are required:
  `## Request` / `## Investigated` / `## Learned` / `## Completed` / `## Next Steps`.
- A 6th section `## Suggested Actions` (promotion candidates: target asset
  path, change summary, rationale) is optional but feeds `/my:retro` directly.
- Categories: infer from the conversation OR honor the `--category` flag
  (must be in the enum).

## Step 5 — Confirm

After writing the journal file, confirm with:

```
✅ Journal entry appended.
Path: ~/.claude/projects/{repo}/memory/journal/{YYYY-MM-DD}-{session_id}.md
Categories: [{category}, ...]
Status: raw
Next: run `/my:retro` to see promotion candidates.
```

## File naming

Journal entries use a fixed `{YYYY-MM-DD}-{session_id}.md` scheme — the
generic date+identifier naming used by other skills (`{YYYYMMDD}-{kebab-case}`)
is intentionally NOT applied here.

## Critical rules

- All writes MUST land under `~/.claude/projects/{repo}/memory/journal/`.
  Never write inside the repository tree (`$PWD/`). On violation: abort with
  exit 1 and stderr message `journal path must be machine-local: {path}`.
- The repository tree MUST NOT contain a `docs/journal/` directory at any
  point. If one is about to be created, refuse and exit.
- `MEMORY.md` (Auto Memory) is read-only — never open it for write, never
  delete it. This skill coexists with Auto Memory; it does not replace it.
- The 5 body sections are mandatory and ordered.
- The category enum has exactly 5 values:
  `mistake | pattern | preference | domain-knowledge | open-question`.
  Unknown values are accepted but warned and rewritten to `domain-knowledge`.
- Dependencies are restricted to `bash` + `jq` + `coreutils`. Do not introduce
  Python / Node / Ruby.

## Edge cases

- Resolved path falls under `$PWD/` → abort, exit 1, stderr
  `journal path must be machine-local: {path}`.
- `$CLAUDE_SESSION_ID` unset → use `mv-$(date +%Y%m%d-%H%M%S)` and warn.
- Existing frontmatter is corrupt → `mv` it to `*.bak`, start fresh, warn.
- Journal directory does not exist → `mkdir -p` and continue.
- Unknown `--category` value → warn, fall back to `domain-knowledge`.
- Same session calls `/my:learn` multiple times → append + `recurrence += 1`
  (capture count within session).
- Existing file is missing one of the 5 body sections → backfill the missing
  section with an empty body and warn.

## Completion

Print the confirmation stanza above, then suggest the next step:

```
Next: run `/my:retro` to surface promotion candidates from accumulated journals.
```

## Examples

```
/my:learn
/my:learn --category mistake "TS catch は unknown 必須"
/my:learn --confidence high "Pattern: prefer Result type over throws"
```
