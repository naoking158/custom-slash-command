---
description: "Surface promotion candidates from accumulated journals"
---

# Retro Phase - Promotion Candidate Curation

Scan accumulated journal entries and surface promotion candidates as a
read-only report. This command never mutates the journal store, never touches
`MEMORY.md`, and never writes under the current working directory.

## Instructions

Read and follow the prompt logic at: `~/.prompts/12_retro.md`

## Input

$ARGUMENTS

Optional flags:

- `--since <Nd|YYYY-MM-DD>` (default `14d`) — lower-bound on entry date.
  Invalid value → exit 1 with usage (Edge case #6).
- `--category <mistake|pattern|preference|domain-knowledge|open-question>`
  (default: all categories)
- `--min-recurrence <int ≥ 1>` (default `1`) — skip entries below this
  recurrence threshold. Negative / non-numeric → exit 1 (Edge case #9).

## Process

1. Enumerate `~/.claude/projects/<basename $PWD>/memory/journal/*.md`.
   Empty directory → print `No journal entries found at <path>. Run /my:learn first.`
   and exit 0.
2. Filter by `--since`, `--category`, `--min-recurrence`; skip entries with
   `status: promoted` or `status: archived`.
3. Resolve `<toolkit_repo>` per Spec §3.5:
   1. `~/.claude/commands` symlink whose target ends in `/commands`
   2. `$CLAUDE_TOOLKIT_REPO` env var pointing at an existing directory
   3. Otherwise: leave empty and emit the literal placeholder `<TOOLKIT_REPO>`
      (NEVER fall back to `$PWD` — US-004 AC-004 / §7.4 threat model).
4. Build candidates from each entry's `## Suggested Actions`; synthesize from
   `## Learned` bullets if absent.
5. Detect duplicates against `<toolkit_repo>/{rules,prompts,commands,agents}/`
   (only when resolved; annotate `(duplicate check skipped: toolkit repo not resolved)`
   otherwise).
6. Pipe each candidate through `scripts/redact.sh`:
   - exit 0 → keep candidate, `redaction_status: clean`
   - exit 2 → drop candidate, `redaction_status: excluded` (log to stderr)
   - script missing → warn and continue without redaction (Edge case #7)
7. Group by category (mistake-first, then pattern, preference,
   domain-knowledge, open-question); within each group sort by
   `recurrence desc, date desc`.
8. Render to stdout with a header line `Toolkit repo: <toolkit_repo>` and the
   `/my:change` handoff command for every candidate.

## File Naming

This command produces no files — output is rendered to stdout only.

## Critical Constraints

- **Read-only operation.** Do not mutate any journal file, any `MEMORY.md`,
  any file under `<toolkit_repo>/`, or anything under `$PWD/`. The
  `status: raw → promoted` flip is performed manually by the user
  (US-002 AC-004 / US-004 AC-002 / US-004 AC-003).
- **Never guess `<toolkit_repo>` from `$PWD` or any cwd-derived path**
  (Spec §3.5 / US-004 AC-004). When resolution fails, emit the literal
  string `<TOOLKIT_REPO>` and include the replacement guide in the footer.
- **Every `/my:change` handoff line MUST be prefixed with `cd <toolkit_repo>`**
  (US-004 AC-001). The canonical form is:
  ```
  cd <toolkit_repo> \
    && /my:change "<title>"
  ```
  Bare `/my:change "..."` lines without a leading `cd` are FORBIDDEN — they
  would cause `/my:change` to scaffold `docs/analysis/changes/` and
  `docs/plans/changes/` under the user's arbitrary current project rather
  than the toolkit repo (§7.4 threat model).
- `scripts/redact.sh` exit 2 means a secret was matched — the affected
  candidate MUST be excluded from output. `masked` is reserved for Phase 2
  and must not be emitted in MVP.
- Dependencies are restricted to `bash` + `jq` + `coreutils` (NFR-006).
- Duplicate detection MUST grep under `<toolkit_repo>/` only — never under
  `$PWD/`.

## After Completion

The output already includes the safe `cd <toolkit_repo> && /my:change "..."`
command. Copy that **entire line as a single unit** — do NOT drop the leading
`cd`, otherwise promotion artifacts will land in the wrong project.

After `/my:change` (and `/my:do`) complete successfully, manually flip the
source journal entry's frontmatter from `status: raw` to `status: promoted`
so it disappears from the next `/my:retro` run (US-004 AC-003).

If `<toolkit_repo>` was rendered as the literal `<TOOLKIT_REPO>`, either:

1. Create the symlink:
   `ln -s <custom-slash-command absolute path>/commands ~/.claude/commands`
2. Or hand-edit `<TOOLKIT_REPO>` in the copied command to the absolute
   toolkit path before running it.

Never substitute `$PWD` / the current project root for `<TOOLKIT_REPO>`.

## Examples

```
/my:retro
/my:retro --since 30d
/my:retro --category mistake --min-recurrence 2
/my:retro --since 2026-06-01 --category pattern
```
