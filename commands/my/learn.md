---
description: "Capture session knowledge into a machine-local journal"
---

# Learn Phase - Session Knowledge Capture

Capture a session-level learning into the machine-local journal store.

## Instructions

Read and follow the prompt logic at: `~/.prompts/11_learn.md`

## Input

$ARGUMENTS

The user may invoke this with no arguments (full conversational inference) or
with one or more of:

- `--category <mistake|pattern|preference|domain-knowledge|open-question>`
  (the enum is binding; unknown values fall back to `domain-knowledge`
  with a warning — US-005 AC-001 / Edge case #10)
- `--confidence <high|medium|low>` (default `medium`)
- a free-text memo that seeds the `## Learned` body section

## Process

1. Resolve `session_id` from `$CLAUDE_SESSION_ID`; fall back to `mv-YYYYMMDD-HHMMSS`
2. Compute target path
   `$HOME/.claude/projects/<basename $PWD>/memory/journal/<YYYY-MM-DD>-<session_id>.md`
   and ASSERT it is NOT under `$PWD/` (US-003: machine-local only)
3. Upsert frontmatter — new file: full schema with `recurrence: 1`, `status: raw`;
   existing file: bump `recurrence`, append to `## Learned`
4. Render the 5 mandatory body sections (`Request`, `Investigated`, `Learned`,
   `Completed`, `Next Steps`) plus the optional `Suggested Actions`
5. Print the confirmation stanza and suggest `/my:retro`

## File Naming

Journal entries use a fixed `YYYY-MM-DD-<session_id>.md` scheme — the generic
date+identifier normalizer (`prompts/_shared/file-naming-rules.md`) is
intentionally NOT applied here.

## Critical Constraints

- All writes MUST land under `$HOME/.claude/projects/<repo>/memory/journal/`.
  Never write inside the repository tree (US-003 AC-002). On violation: abort
  with exit 1 and stderr message `journal path must be machine-local: <path>`.
- The repository tree MUST NOT contain a `docs/journal/` directory at any
  point (US-003 AC-001 invariant).
- `MEMORY.md` (Auto Memory) is read-only — never open it for write, never
  delete it (Edge case #15).
- Dependencies are restricted to `bash` + `jq` + `coreutils`. Do not introduce
  Python / Node / Ruby (NFR-006).
- The category enum has exactly 5 values:
  `mistake | pattern | preference | domain-knowledge | open-question`.
  Unknown values are accepted but warned and rewritten to `domain-knowledge`.

## After Completion

Print the confirmation stanza, then suggest the next step:

```
Next: run `/my:retro` to surface promotion candidates from accumulated journals.
```

## Examples

```
/my:learn
/my:learn --category mistake "TS catch は unknown 必須"
/my:learn --confidence high "Pattern: prefer Result type over throws"
```
