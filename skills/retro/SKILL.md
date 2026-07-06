---
description: Run the toolkit improvement loop — cluster accumulated journal signals and captured corrections, propose concrete edits to toolkit assets, and apply approved ones directly. Trigger words: retro, retrospective, promote, 振り返り, 昇格.
argument-hint: "[--since <Nd|YYYY-MM-DD>] [--deep] [--dry-run]"
disable-model-invocation: true
---

# Retro — Cluster, Propose, Apply

Mine accumulated improvement signals and turn the approved ones into real
edits to this toolkit. Input: **$ARGUMENTS**

You are running the promotion half of the toolkit's improvement loop. The
capture half (hooks + `/my:learn`) is cheap and automatic; this half is
deliberate and **approval-gated**: nothing is written to the toolkit repo
until the user approves a specific proposal.

## Arguments

| Arg | Default | Notes |
|-----|---------|-------|
| `--since <Nd\|YYYY-MM-DD>` | `30d` | Lower bound for journal entries and corrections. Invalid → exit with `usage: --since <Nd|YYYY-MM-DD>`. |
| `--deep` | off | Additionally scan recent session transcripts (from `sessions.jsonl`) for repeated corrections the hook regex missed. Slower; use before the ~30-day transcript expiry. |
| `--dry-run` | off | Report candidates only; skip the proposal/apply phase. |

## Step 1 — Resolve the toolkit repo (abort if unresolved)

```bash
source "${CLAUDE_SKILL_DIR}/../../scripts/lib/toolkit.sh"
toolkit_repo="$(resolve_toolkit_repo)" || true
```

If empty, print the guidance below and STOP — never guess the repo from
`$PWD` or any cwd-derived path:

```
⚠️ Toolkit repo を解決できませんでした。次のいずれかで対処してください:
  1. `ln -s <toolkit-repo> ~/.claude/skills/my` で symlink を張る
  2. `export CLAUDE_TOOLKIT_REPO=<toolkit-repo>` を設定する
```

## Step 2 — Gather signals

Data dir: `data="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}"`.

1. **Journal**: `$data/journal/*.md` with `status: raw` and `date` within
   `--since`. If the dir is empty AND the queues below are empty, print
   `No signals found at $data. The hooks and /my:learn will fill it as you work.`
   and exit 0.
2. **Corrections queue**: `$data/corrections.jsonl` — user-correction
   prompts captured by the UserPromptSubmit hook. Read entries within
   `--since`; these are noisy by design, so weigh clusters, not single hits.
3. **Native /insights**: if the user has run `/insights` recently, ask them
   to paste relevant friction points (do not try to locate the report
   yourself).
4. **`--deep` only**: for sessions listed in `$data/sessions.jsonl` within
   `--since`, read their `transcript_path` files (skip missing ones) and
   look for repeated corrections and abandoned/retried tool patterns. Use
   subagents to keep transcript bulk out of this context; each returns at
   most a 10-line digest per session.

## Step 3 — Cluster and rank

- Group signals by theme and toolkit target; a cluster's **recurrence** is
  the number of independent signals (journal entries + distinct correction
  sessions) supporting it.
- Rank: `mistake` clusters first, then `gap`, `friction`, `pattern`,
  `question`; within a group by recurrence desc, date desc.
- Corrections that concern *project* behavior rather than toolkit assets
  are noted at the end as "not toolkit-related" — suggest the user let auto
  memory keep them; do not fabricate a toolkit change from them.

## Step 4 — Classify each cluster on the promotion ladder

Choose the **cheapest rung that makes the fix stick** (official guidance:
instruction → skill → rule → hook):

| Rung | When | Apply target |
|------|------|--------------|
| Skill edit | A `my:*` skill's instructions caused the issue or lack a case | `{toolkit_repo}/skills/<name>/SKILL.md` (or its templates/checklists) |
| Language rule | Recurring code-level correction in a supported language | `{toolkit_repo}/skills/rules-<lang>/references/*.md` (+ index line in its SKILL.md) |
| New skill | A recurring workflow no asset covers | scaffold `{toolkit_repo}/skills/<name>/SKILL.md` |
| Hook | The rule must be deterministic, not advisory | propose an entry for `{toolkit_repo}/hooks/hooks.json` + script under `scripts/hooks/` |
| User CLAUDE.md | Needed in EVERY session, toolkit-independent | propose text for `~/.claude/CLAUDE.md` (apply only with approval) |
| SDD handoff | Structural change too big for an inline edit | `cd {toolkit_repo} && /my:change "<title>"` |

## Step 5 — Propose (the approval gate)

For each cluster present: title, category, recurrence, source signals,
chosen rung, and a **concrete diff sketch** of the edit. Then ask the user
which proposals to apply (AskUserQuestion with multiSelect when available;
plain conversation otherwise). `--dry-run` stops here.

## Step 6 — Apply approved proposals

- **Redact first**: pipe any journal/correction-derived text that will be
  written into repo files through `${CLAUDE_SKILL_DIR}/scripts/redact.sh`
  (deny-list sits beside it). Exit 2 means a secret was masked — show the
  masked text and re-confirm before writing. Script missing → warn and ask
  the user to eyeball the text instead.
- Edit ONLY files under `{toolkit_repo}` (plus `~/.claude/CLAUDE.md` when
  that rung was approved). Keep edits minimal and in the style of the file.
- If `scripts/` or `hooks/` were touched, run `bats {toolkit_repo}/tests/`
  and report the result; revert on failure.
- Remind the user: skill edits hot-reload immediately; hook changes need
  `/reload-plugins` or a restart.

## Step 7 — Bookkeeping

- For each journal entry whose cluster was applied: set `status: promoted`
  and move the file to `$data/journal/archive/`.
- Rejected-with-reason clusters: set `status: archived` and move to
  `archive/` so they stop resurfacing. "Not now" clusters stay `raw`.
- Consumed corrections: append their lines to
  `$data/corrections.archive.jsonl` and rewrite `corrections.jsonl`
  without them.
- **Prune**: list `raw` entries older than 60 days and propose archiving
  them (a signal nobody promoted in 60 days is probably noise).

## Step 8 — Report

Summarize: clusters found / proposed / applied / archived, files edited
(with paths), test results, and anything handed off to `/my:change`.

## Critical rules

- **Approval-gated writes.** No repo file changes before Step 5 approval.
  `--dry-run` never writes anything, including bookkeeping.
- **Never derive `{toolkit_repo}` from `$PWD`.** Resolution failure aborts.
- **Redaction before promotion.** Journal text comes from arbitrary
  projects; nothing lands in the repo without passing redact.sh.
- Journal/queue mutations (Step 7) are the ONLY writes outside the repo,
  and only under `$data/`.
- Dependencies: bash + jq + coreutils.

## Examples

```
/my:retro
/my:retro --since 14d --dry-run
/my:retro --deep          # also mine transcripts before they expire
```
