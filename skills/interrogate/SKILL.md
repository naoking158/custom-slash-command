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
git -C "$(git rev-parse --show-toplevel)" ls-files -z --others --exclude-standard \
  | tar -C "$(git rev-parse --show-toplevel)" --null -T - -cf - | tar -xf - -C "$T"
```

A `pr:<n>` target: `git fetch origin pull/<n>/head`, then add the worktree at the sha from `gh pr view <n> --json headRefOid -q .headRefOid` (not `FETCH_HEAD`, which another fetch can move). Write `$T` out as a literal absolute path in every later step: each Bash call starts a new shell. From here on, step 5 runs whatever happens, even when a later step fails or you stop early.

## 3. Attack

Start `my:adversary` with the target, the intent and the worktree path `$T`:

- Claude Code: `Agent` with `subagent_type: "my:adversary"`.
- Antigravity: `invoke_subagent` with the `adversary` subagent, the target, the intent and `$T` in its task (see `rules/antigravity.md`).

For a large or risky change, start two or three breakers in parallel, each told to focus on one area (inputs and boundaries, state and concurrency, callers and contracts).

A breaker's result starts with `FINDINGS <n>`, or `BLOCKED` when it ran nothing. On `BLOCKED`, check the worktree path and start it again once; a second `BLOCKED` is reported as "not run", never as "no finding". A result that starts with neither failed: run it once more, then go on with what you have.

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
