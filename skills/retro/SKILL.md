---
description: Surface promotion candidates from accumulated journal entries as a read-only report with safe /my:change handoff commands. Trigger words: retro, retrospective, promote, 振り返り, 昇格.
argument-hint: "[--since <Nd|YYYY-MM-DD>] [--category <mistake|pattern|preference|domain-knowledge|open-question>] [--min-recurrence <int>]"
disable-model-invocation: true
---

# Retro Phase — Promotion Candidate Curation

Scan accumulated journal entries and surface promotion candidates as a
read-only report. Input: **$ARGUMENTS**

You are acting as a promotion candidate curator. This skill never mutates the
journal store, never touches `MEMORY.md`, never writes under `$PWD/` or the
toolkit repo. Output goes to stdout only — no files are produced.

## Arguments

| Arg | Values | Default | Notes |
|-----|--------|---------|-------|
| `--since` | duration (`Nd`) or date (`YYYY-MM-DD`) | `14d` | Lower-bound on the entry date. Invalid value → exit 1 with `usage: --since <Nd|YYYY-MM-DD>` on stderr. |
| `--category` | category enum | (all) | Restrict output to a single category. |
| `--min-recurrence` | integer ≥ 1 | `1` | Skip entries with `recurrence` below this. Negative / non-numeric → exit 1 with usage. |

## Step 1 — Enumerate

Glob `~/.claude/projects/{repo}/memory/journal/*.md` where `{repo}` is
`basename "$PWD"`. If empty or missing, print
`No journal entries found at {path}. Run /my:learn first.` and exit 0.

## Step 2 — Filter

Parse frontmatter with an awk/sed/jq pipeline (schema is flat `key: value`
plus short YAML arrays; deep nesting is out of scope). Apply `--since`,
`--category`, `--min-recurrence`; skip entries with `status: promoted` or
`status: archived`. `--since` parsing: `date -v -Nd` on macOS, `date -d "N days ago"` on GNU.

## Step 3 — Resolve the toolkit repo

Follow this priority order strictly. The tested shell implementation is
`resolve_toolkit_repo()` in `scripts/lib/toolkit.sh` of the toolkit repo:

1. `$CLAUDE_TOOLKIT_REPO` env var pointing at an existing directory.
2. The symlink `~/.claude/skills/my` — resolve it to its target (portably:
   `cd`/`pwd -P`, no GNU `realpath`); valid only if the target contains
   `.claude-plugin/plugin.json`. Then `toolkit_repo := {target}`.
3. Otherwise: `toolkit_repo := ""` (empty) — render the literal placeholder
   `<TOOLKIT_REPO>` and the replacement guide in the footer.

FORBIDDEN: do NOT fall back to `$PWD` or any cwd-derived path, and NEVER
silently substitute the cwd for the toolkit repo. cwd is an arbitrary
project, not the toolkit repo.

## Step 4 — Build candidates

For each entry, collect `## Suggested Actions`; if absent, synthesize
candidates from `## Learned` bullets. Each candidate: title /
target_asset_path / change_summary / rationale / source_entries / recurrence.

## Step 5 — Duplicate detection

- If toolkit_repo is non-empty: grep nearby files under
  `{toolkit_repo}/{skills,agents}/`. Annotate `duplicate_of` when a
  near-match is found; do not exclude.
- If toolkit_repo is empty: SKIP this step and annotate each candidate with
  `(duplicate check skipped: toolkit repo not resolved)`.
- Dedup MUST grep under `{toolkit_repo}/` only — never under `$PWD/`.

## Step 6 — Redact

Pipe each candidate's renderable text through
`${CLAUDE_SKILL_DIR}/scripts/redact.sh` (its deny-list `redact.denylist`
sits beside it) BEFORE displaying:

- exit 0 → `redaction_status: clean` (include candidate)
- exit 2 → a secret was matched: the candidate MUST be dropped from output,
  `redaction_status: excluded`, log to stderr
- script missing → warn on stderr and continue without redaction
- `masked` is reserved for Phase 2 and must not be emitted in MVP

## Step 7 — Group and sort

Group by category, mistake first (then pattern, preference, domain-knowledge,
open-question); within each group sort by `recurrence desc, date desc`.
Entries with an unknown category render under `domain-knowledge` with a
warning. Duplicate-annotated candidates sort to the end of their group.

## Step 8 — Render

Header line `Toolkit repo: {toolkit_repo}` (or `<TOOLKIT_REPO>  (⚠️ 自動解決に失敗)`
on failure). For every candidate print the safe handoff command:

```
cd {toolkit_repo} \
  && /my:change "{title}"
```

When toolkit_repo is empty, substitute the literal placeholder
`<TOOLKIT_REPO>` — never the cwd. Footer:

- Tip 1: the command MUST be run **with the leading `cd`** — dropping it
  causes `/my:change` to scaffold `docs/analysis/changes/` and
  `docs/plans/changes/` under the wrong project.
- Tip 2: after a successful promotion, manually flip the journal frontmatter
  from `status: raw` to `status: promoted`.
- On resolution failure, append:

```
⚠️ Toolkit repo の自動解決に失敗しました。
次のいずれかで対処してください:
  1. `ln -s <toolkit-repo> ~/.claude/skills/my` で symlink を張る
  2. `export CLAUDE_TOOLKIT_REPO=<toolkit-repo>` を設定する
  3. 上記コマンドの `<TOOLKIT_REPO>` を手で置き換える
cwd を toolkit と推測して置換することは行いません。
```

## Critical rules

- **Read-only operation.** Do not mutate any journal file, any `MEMORY.md`,
  any file under `{toolkit_repo}/`, or anything under `$PWD/`. The
  `status: raw → promoted` flip is performed manually by the user.
- **Never guess `{toolkit_repo}` from `$PWD` or any cwd-derived path.** When
  resolution fails, emit the literal string `<TOOLKIT_REPO>` and include the
  replacement guide in the footer.
- **Every `/my:change` handoff line MUST be prefixed with `cd {toolkit_repo}`.**
  Bare `/my:change "..."` lines without a leading `cd` are FORBIDDEN — they
  would land promotion artifacts in the user's current project.
- `redact.sh` exit 2 → the affected candidate MUST be excluded from output.
- Dependencies are restricted to `bash` + `jq` + `coreutils`.

## After completion

Tell the user to copy each `cd {toolkit_repo} && /my:change "..."` line as a
**single unit** — never drop the leading `cd`. After `/my:change` (and
`/my:do`) complete successfully, they manually flip the source entry to
`status: promoted` so it disappears from the next `/my:retro` run.

## Example output (resolved)

```
# Retrospective: last 14 days (12 entries scanned)
Toolkit repo: /Users/naoki/src/github.com/naoking158/custom-slash-command

## mistake (3 candidates)

### M1. "TypeScript の error union 型を `unknown` で受けない"
- Source: 2026-06-20-3f4b.md, 2026-06-25-7a06.md (recurrence: 2)
- Target asset: skills/rules-typescript/references/ts-error-handling.md
- Change summary: "error catch 句に `unknown` 型注釈を明示する例を追記"
- Next:
    cd /Users/naoki/src/github.com/naoking158/custom-slash-command \
      && /my:change "ts-error-handling: enforce unknown in catch"

---
Tip 1: Always run the command above **with the leading `cd`**.
Tip 2: After a successful promotion, manually flip the journal frontmatter
from `status: raw` to `status: promoted`.
```

## Examples

```
/my:retro
/my:retro --since 30d
/my:retro --category mistake --min-recurrence 2
/my:retro --since 2026-06-01 --category pattern
```
