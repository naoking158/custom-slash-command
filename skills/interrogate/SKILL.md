---
name: interrogate
description: Adversarial code or design stress-test where isolated breakers try to disprove a change and only findings proven by an executed command survive. Use for /my:interrogate, "adversarial review", "try to break this", or high-risk diffs (敵対的レビュー, 反証テスト).
argument-hint: "[<branch|commit|pr:N|files>]"
disable-model-invocation: true
---

# Interrogate

A review that reads code finds what looks wrong. This one keeps only what a command proved wrong. Isolated breakers attack the change in a throwaway worktree; you rerun every finding yourself and drop the ones that do not reproduce.

Do not fix anything. The output is a report.

## 1. Frame

- **Target**: `$ARGUMENTS` (a branch, a commit or range, `pr:<n>`, or files). Empty: the diff from the merge-base with the default branch to the working tree, uncommitted changes included.
- **Intent**: restate what the change is meant to do, from the commit messages, the PR body and what the user said. When the sources disagree or say nothing about a behavior the diff changes, ask the user before attacking: a breaker without a clear intent reports opinions.

## 2. Isolate

Never let a breaker touch the caller's checkout. Make a throwaway detached worktree and put the change in it:

```bash
T="$(mktemp -d "${TMPDIR:-/tmp}/interrogate.XXXXXX")"
git worktree add --detach "$T" <target commit, HEAD by default>
```

When the target is the working tree (no argument), carry the uncommitted changes over, untracked files included:

```bash
git diff --binary HEAD > "$T.patch" && { [ ! -s "$T.patch" ] || git -C "$T" apply "$T.patch"; }
git ls-files -z --others --exclude-standard | tar --null -T - -cf - | tar -xf - -C "$T"
```

A `pr:<n>` target: `git fetch origin pull/<n>/head` and add the worktree at `FETCH_HEAD`. Write `$T` out as a literal absolute path in every later step: each Bash call starts a new shell. From here on, step 5 runs whatever happens, even when a later step fails or you stop early.

## 3. Attack

Start `my:adversary` with the target, the intent and the worktree path `$T`:

- Claude Code: `Agent` with `subagent_type: "my:adversary"`.
- Antigravity: `orca/bin/run-role adversary --out <result file> -- "target: ..." "intent: ..." "worktree: $T"` (see `rules/antigravity.md`). Pass the worktree as an input, not as `--cwd`: run-role takes only an Orca workspace there.

For a large or risky change, start two or three breakers in parallel, each told to focus on one area (inputs and boundaries, state and concurrency, callers and contracts). Where the profile maps `adversary` to a different model than yours, prefer it: a different model misses different things.

A breaker's result starts with `FINDINGS <n>`. `BLOCKED` means it ran nothing (check the worktree path); any other first line means it failed. Run it once more; if it fails again, report the run as not done rather than as "no finding".

## 4. Verify

For every finding, rerun its `Command` yourself in `$T` and read the output:

- Keep it only when the output you see contradicts the intent, as the finding says.
- Merge findings with one root cause into one.
- Drop the rest (did not reproduce, the output matches the intent, the command does not run as written) and count them with the reason.

A finding you did not reproduce does not appear in the report, however plausible it reads.

## 5. Clean up

Whatever happened above, remove the worktree and its files:

```bash
git worktree remove --force <absolute $T> ; rm -rf <absolute $T> <absolute $T>.patch
```

Then `git worktree list` must no longer show it.

## 6. Report

- **Intent**: the one or two sentences you attacked against.
- **Verified findings**: for each, the title, the command, the output you saw, and which part of the intent it breaks. None: say "no finding survived verification".
- **Dropped**: the count and the reasons, breakers' own drops included.

Apply no fix. Name the next step (a regression test per finding, or `/my:review` for what a command cannot prove).

Adapted from pstack `interrogate` (github.com/cursor/plugins, MIT).
