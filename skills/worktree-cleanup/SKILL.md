---
name: worktree-cleanup
description: Safely audit and prune merged or abandoned git worktrees and Orca worktrees without losing uncommitted work or active sessions. Use for /my:worktree-cleanup, "clean up worktrees", or reclaiming disk from stale autopilot/Orca worktrees (worktree整理, ワークツリー削除).
argument-hint: "[-b <base-ref>] [<repo path>]"
disable-model-invocation: true
---

# Worktree cleanup

This is the one workflow here that deletes the user's state with no code review to catch a slip, so the gates below are the review. Removing a clean worktree is recoverable from its branch; uncommitted work is not.

## 1. Snapshot and audit

Record `df -h /`. Then run the audit, which reads the worktree list from git rather than from paths you type:

```bash
"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/worktree-audit.sh" [-b <base-ref>] [<repo path>]
```

Without `-b`, `MERGED` checks against `origin/HEAD`; pass `-b origin/<branch>` when PRs merge into another branch. It prints one row per worktree with `SIZE`, `AGE`, `MERGED`, `DIRTY`, `REMOTE`, `PR`, `ORCA`, `AUTOPILOT`, `LAST_CHAT` and a suggested `BUCKET`. It deletes nothing.

| Bucket | Meaning | Default |
|---|---|---|
| `hold-wip` | tracked uncommitted edits | keep |
| `hold-locked` | locked with `git worktree lock` | keep; never unlock it to remove it |
| `hold-active` | Orca pinned, or with a live terminal or agent | keep |
| `hold-open-pr` | its branch has an open or draft PR | keep |
| `verify-recent-chat` | a Claude Code session touched it in the last 4 days | check (step 2) |
| `safe` | merged into the base, or its PR merged or closed with no commit beyond the PR's head | candidate |
| `review` | none of the above, or its Orca state or `git status` is unknown | ask |

`ORCA=?` means Orca is installed but did not answer, or its list was truncated without this worktree, so its Orca state is unknown. `DIRTY=unknown` means `git status` failed there. `AUTOPILOT=goal` marks a worktree made for an autopilot goal: check that goal's `progress.md` for a final report before removing it.

## 2. Check recent sessions

The bucket is advice, not permission. For each `verify-recent-chat` row, and any row you doubt, read only the tail of the newest session file that touched it (under the Claude Code projects directory for the worktree, or for the main checkout) and decide whether that work is still going. Ask the user which sessions and Orca workspaces they still use; what they name wins over the bucket.

## 3. Confirm the deletion list (never skip)

Show the table, then for every candidate:

- `wip:<N>`: a summary of `git -C <wt> diff` and `git -C <wt> diff --cached`;
- `scratch:<N>`: the untracked file names (`git -C <wt> status --porcelain`);
- ignored files that removal also deletes, such as `.env` (`git -C <wt> status --porcelain --ignored`, the `!!` lines);
- `MERGED=no`: the commits not in the base (`git -C <wt> log --oneline <base>..HEAD`). When `REMOTE=detached`, no branch holds them: create one (`git -C <wt> branch <name>`) or drop the worktree from the list.

Get the user's explicit approval of the exact list of paths to remove. Keep `hold-wip`, `hold-locked`, `hold-active` and `hold-open-pr` unless the user names them.

## 4. Remove the approved worktrees

Per approved path:

- `ORCA` is `?` (unknown): remove it by neither command yet. Get Orca to answer (`orca status --json` reports the runtime reachable) and run the audit again. A row whose new bucket is a `hold-*` one is kept; any other row goes back to step 3 for approval with its new values, and its new `ORCA` value then picks the command below. If it is still `?`, keep the worktree and report it as kept because its Orca state is unknown.
- `ORCA` is any other value but `-` (Orca manages it): `orca worktree rm --worktree "path:<wt>" --force --json`. `--force` removes a worktree that still has the untracked or ignored files step 3 listed and the user approved; it does not force branch deletion. Add `--delete-branch` only when `MERGED=YES`: a squash-merged branch is not an ancestor of the base, and its branch is the only copy of commits made after the PR. Orca also keeps a branch it cannot prove merged.
- `ORCA` is `-` (Orca does not know it): `git -C <repo> worktree remove --force <wt>`. `--force` also deletes untracked and ignored files, which is why step 3 lists them. When the directory survives, list what is left, then remove it. Finish with `git -C <repo> worktree prune`. A worktree on a branch keeps its commits on that branch; a detached one keeps them only if step 3 made a branch.

## 5. Report

Run `df -h /` and `git -C <repo> worktree list` again.

**Reply:** `df -h /` before and after with the space reclaimed, the worktrees removed, and for each one kept, its reason in one line (uncommitted work, open PR, active in Orca, Orca state unknown, or in use by which session).

Adapted from pstack `poteto-mode` playbook `worktree-cleanup` (github.com/cursor/plugins, MIT).
