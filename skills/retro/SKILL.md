---
name: retro
description: Run the toolkit improvement loop — cluster accumulated journal signals and captured corrections, propose concrete edits to toolkit assets, and open approved ones as pull requests. Trigger words: retro, retrospective, promote, 振り返り, 昇格.
argument-hint: "[--since <Nd|YYYY-MM-DD>] [--deep] [--dry-run]"
disable-model-invocation: true
---

# Retro — Cluster, Propose, Apply

Mine accumulated improvement signals and turn the approved ones into real
edits to this toolkit. Input: **$ARGUMENTS**

You are running the promotion half of the toolkit's improvement loop. The
capture half (hooks + `/my:learn`) is cheap and automatic; this half is
deliberate and **approval-gated**: no edit is made to the toolkit repo
until the user approves a specific proposal, and an approved edit goes in as
a pull request from a branch of its own, never into the checkout.

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

## Step 1b — Bring the toolkit repo up to date

The checkout at `{toolkit_repo}` is also the live install of the skills and
hooks, and it may be behind origin. Judging signals on a stale checkout
proposes fixes that are already merged.

```bash
"${CLAUDE_SKILL_DIR}/scripts/sync-origin.sh" "{toolkit_repo}"
```

It fetches origin and fast-forwards the checkout only when it is on the
default branch, has no uncommitted changes to tracked files and has no
commits of its own; any other checkout is left as it is. It prints:

- `base: origin/<default> <sha>`: call this ref `{base}`. From here on,
  read toolkit files at `{base}` (`git -C {toolkit_repo} show {base}:<path>`),
  not from the checkout, unless the checkout line says `updated` or
  `current`.
- `checkout: updated <old>..<new> | current | kept (<reason>)`: put this
  line in the Step 8 report. When it says `updated` and
  `git -C {toolkit_repo} diff --name-only <old>..<new>` lists
  `skills/retro/`, read this SKILL.md again before going on.

Exit status:

- 0: go on.
- 1, the fetch failed (third line `fetch: failed (...)`): go on through
  Step 5 on the last fetched `{base}`, and put
  `⚠️ origin を取得できなかった。{base} 時点の内容で判断しており、修正済みかどうかは未確認`
  at the top of the proposals and the report. Step 3 marks no cluster as
  already fixed, so nothing is archived on stale data. Step 6 runs the
  script again first and stops if the fetch still fails.
- 2: show its message and STOP. Retro needs a Git checkout with an origin
  to judge signals and to open pull requests.

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
- **Six-month filter**: keep only signals that will still hold in six months
  and would change what a future agent does. Drop one-off events tied to a
  specific commit SHA, a count, or a temporary version, and list them in
  Step 5 as "dropped by the six-month filter" so the user can overrule.
- Corrections that concern *project* behavior rather than toolkit assets
  are noted at the end as "not toolkit-related" — suggest the user let auto
  memory keep them; do not fabricate a toolkit change from them.
- **Already fixed?** For each remaining cluster, check `{base}` and the open
  pull requests before proposing anything:
  - `{base}`: read the target files there and the commits since the oldest
    signal (`git -C {toolkit_repo} log --oneline --since=<date> {base} -- <paths>`).
  - Open pull requests: `gh pr list -R <owner/name> --state open --json number,title,files`
    (`<owner/name>` from `gh repo view --json nameWithOwner -q .nameWithOwner`
    run in `{toolkit_repo}`), then `gh pr diff <n> -R <owner/name>` for the ones
    touching the target.
  - Evidence: when the signal is behavior (a script or hook output, a
    command that failed), reproduce it on `{base}` in a throwaway detached
    worktree (`git -C {toolkit_repo} worktree add --detach <tmp dir> {base}`,
    `git worktree remove` afterwards) and quote the command and its result.
    When it is an instruction, quote the line in `{base}` that now covers
    the case. Without such evidence the cluster is not fixed.
  - Fixed in `{base}` → do not propose; list it in Step 5 as `既に修正済み`
    with the evidence, and Step 7 archives it.
  - Fixed only in an open pull request → do not propose; list it as
    `修正中 (#<n>)` and leave its signals `raw` (Step 7). A pull request can
    still be closed unmerged, and the next retro archives the cluster once it
    is in `{base}`.
  - When the fetch failed or gh failed, the check is `未確認`: propose the
    cluster as usual and say so.

## Step 4 — Classify each cluster on the promotion ladder

Choose the **cheapest rung that makes the fix stick** (official guidance:
instruction → skill → rule → hook):

Apply targets are paths in the toolkit repo; Step 6 edits them in a
worktree branched from `{base}`.

| Rung | When | Apply target |
|------|------|--------------|
| Skill edit | A `my:*` skill's instructions caused the issue or lack a case | `skills/<name>/SKILL.md` (or its templates/checklists) |
| Language rule | Recurring code-level correction in a supported language | `skills/rules-<lang>/references/*.md` (+ index line in its SKILL.md) |
| New skill | A recurring workflow no asset covers | scaffold `skills/<name>/SKILL.md` |
| Hook | The rule must be deterministic, not advisory | propose an entry for `hooks/hooks.json` + script under `scripts/hooks/` (guardrails: the pull request waits for a person, see Step 6) |
| User CLAUDE.md | Needed in EVERY session, toolkit-independent | propose text for `~/.claude/CLAUDE.md` (apply only with approval) |
| Handoff | Structural change too big for an inline edit | write the proposed change (target files, steps, reason) into the report and stop; the user starts it as a separate task |

When a `my:*` skill already covered the case but did not trigger (or
triggered where it should not), classify the cluster as a **trigger fix**:
adjust that skill's frontmatter `description` (trigger phrases, where it
applies and where it does not) instead of restating its content in another
skill or a general rule.

Promotion is not only additive. When a cluster shows an existing rule
causing the friction (asking for approval nobody needs, refusing a
legitimate step, contradicting a newer rule), or the reason a rule was
added no longer holds, propose **deleting or narrowing** that rule on the
same rung instead of adding another one on top.

Write every promoted instruction in plain wording with its scope and its
reason. Where the user wants to keep the decision rather than forbid the
action, write an approval requirement (`ask before deleting files`) instead
of a prohibition (`never delete files`): an unscoped `never` is followed
literally and blocks the legitimate cases too.

## Step 5 — Propose (the approval gate)

For each cluster present: title, category, recurrence, source signals,
chosen rung, and a **concrete diff sketch** of the edit against `{base}`.
List the `既に修正済み` and `修正中 (#<n>)` clusters after them, without a
diff. Then ask the user
which proposals to apply (AskUserQuestion with multiSelect when available;
plain conversation otherwise). `--dry-run` stops here.

## Step 6 — Apply approved proposals

- **Redact first**: pipe any journal/correction-derived text that will be
  written into repo files through `${CLAUDE_SKILL_DIR}/scripts/redact.sh`
  (deny-list sits beside it). Exit 2 means a secret was masked — show the
  masked text and re-confirm before writing. Script missing → warn and ask
  the user to eyeball the text instead.
- **Fresh base**: run Step 1b's script again. A failed fetch now stops
  here: report the approved proposals as not applied. When `{base}` moved,
  redo the already-fixed check for the approved clusters and drop the ones
  now fixed.
- **One pull request per proposal**, each from its own worktree branched
  from `{base}`, never from the checkout and never by editing the checkout:

  ```bash
  git -C {toolkit_repo} worktree add --no-track -b retro/<slug> {toolkit_repo}-retro-<slug> {base}
  ```

  `--no-track` keeps the branch from tracking the default branch; push it
  with `git push -u origin retro/<slug>`. Edit there, keeping edits
  minimal and in the style of the file.
  `~/.claude/CLAUDE.md`, when that rung was approved, is outside the repo:
  edit it directly.
- **Test in the worktree** with the repository's own tasks (run
  `mise trust` first; a new worktree is untrusted): `mise run test` (every
  bats suite, then `go test ./...`) and `mise run lint`. Do not open a pull
  request while either fails: fix it on the branch, or drop the proposal and
  say why.
- **Open the pull request** following the user's rules for pull requests
  (`~/.claude/CLAUDE.md`: draft unless the repository is in ship mode),
  staging files by name. Merge it yourself only when those rules allow.
- **Guardrails** (hooks, `scripts/hooks/`, CI, `skills/autopilot/SKILL.md`
  and others): list them with the worktree's copy of the script, since the
  checkout's may be behind:
  `git -C <worktree> diff --name-only {base}...HEAD | <worktree>/scripts/ci/guardrail.sh paths`. A
  pull request that changes one waits in CI until a person adds the
  `human-approved` label. Never add the label, never merge it, and say in
  the report that it waits for that label.
- Remove each worktree once its branch is pushed
  (`git -C {toolkit_repo} worktree remove <worktree>`).
- Remind the user: a merged change reaches the live install when the
  checkout fast-forwards (the next run's Step 1b, or
  `git -C {toolkit_repo} merge --ff-only`); hook changes then need
  `/reload-plugins` or a restart.

## Step 7 — Bookkeeping

- For each journal entry whose cluster's pull request was merged in this
  run: set `status: promoted` and move the file to `$data/journal/archive/`.
  When the pull request is still open, leave the entry `raw` and add a
  `pr: <url>` line to its frontmatter; the next retro finds it fixed in
  `{base}` and archives it.
- Clusters found `既に修正済み` in Step 3: set `status: archived`, add a
  `fixed_by: <commit or line>` line, and move to `archive/`. `修正中 (#<n>)`
  clusters stay `raw`.
- Signals dropped by the six-month filter and not overruled, and
  rejected-with-reason clusters: set `status: archived` and move to
  `archive/` so they stop resurfacing. "Not now" clusters stay `raw`.
- Consumed corrections (those of promoted, archived and already-fixed
  clusters): append their lines to
  `$data/corrections.archive.jsonl` and rewrite `corrections.jsonl`
  without them.
- **Prune**: list `raw` entries older than 60 days and propose archiving
  them (a signal nobody promoted in 60 days is probably noise).

## Step 8 — Report

Summarize: the `checkout:` line of Step 1b (and the fetch warning, if
any), clusters found / proposed / applied / already fixed / archived, each
pull request's URL with the files it changes, the test commands run and
their results, pull requests waiting for the `human-approved` label, and any
change handed off as a separate task.

Then add the autopilot metrics (orca.md 4.9) under a `### Autopilot の指標`
heading, pasting the script's output lines as they are:

```bash
"${CLAUDE_SKILL_DIR}/scripts/autopilot-metrics.sh" --checkout "{toolkit_repo}"
```

- The period is the script's default (the last 28 days), not `--since`: the
  metrics are compared against 4-week baselines.
- `不明` counts records the script could not read; report them, do not guess
  values for them. Exit 2 is a usage error: show its message instead.
- Print this block also when Step 2 exits for lack of signals and when
  `--dry-run` stops at Step 5. It only reads, so it is not a write.
- The script also needs git and gh (read-only). When gh is not logged in,
  the gh-based lines show the repository as `不明`.
- Human pushback leaves out comments by the PR author, so pushback the user
  gives on their own autopilot PR shows up only as a PR closed without merging.

## Critical rules

- **Approval-gated writes.** No repo file changes before Step 5 approval.
  The only change to the checkout is Step 1b's fetch and fast-forward,
  which runs also under `--dry-run`; `--dry-run` writes nothing else,
  including bookkeeping.
- **Edits go through pull requests.** Approved edits are made on a branch
  in a worktree from `{base}`, never in the `{toolkit_repo}` checkout.
- **Never derive `{toolkit_repo}` from `$PWD`.** Resolution failure aborts.
- **Redaction before promotion.** Journal text comes from arbitrary
  projects; nothing lands in the repo without passing redact.sh.
- Outside the repo, write only the Step 6 worktrees, `~/.claude/CLAUDE.md`
  when that rung was approved, and the journal/queue mutations of Step 7
  under `$data/`.
- Dependencies: bash + jq + coreutils + git; gh for the open pull request
  check and Step 6; mise for the tests.

## Examples

```
/my:retro
/my:retro --since 14d --dry-run
/my:retro --deep          # also mine transcripts before they expire
```
