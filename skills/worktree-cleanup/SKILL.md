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
| `hold-active` | Orca pinned, or with a live terminal or agent | keep |
| `hold-open-pr` | its branch has an open or draft PR | keep |
| `verify-recent-chat` | a Claude Code session touched it in the last 4 days | check (step 2) |
| `safe` | merged into the base, or its PR merged or closed with no commit beyond the PR's head | candidate |
| `review` | none of the above, or the Orca list was truncated | ask |

`ORCA=?` means Orca's list was truncated and did not include this worktree, so its state is unknown. `AUTOPILOT=goal` marks a worktree made for an autopilot goal: check that goal's `progress.md` for a final report before removing it.

## 2. Check recent sessions

The bucket is advice, not permission. For each `verify-recent-chat` row, and any row you doubt, read only the tail of the newest session file that touched it (under the Claude Code projects directory for the worktree, or for the main checkout) and decide whether that work is still going. Ask the user which sessions and Orca workspaces they still use; what they name wins over the bucket.

## 3. Confirm the deletion list (never skip)

Show the table, then for every candidate:

- `wip:<N>`: a summary of `git -C <wt> diff` and `git -C <wt> diff --cached`;
- `scratch:<N>`: the untracked file names (`git -C <wt> status --porcelain`).

Get the user's explicit approval of the exact list of paths to remove. Keep `hold-wip`, `hold-active` and `hold-open-pr` unless the user names them.

## 4. Remove the approved worktrees

Per approved path:

- `ORCA` is not `-` (Orca manages it): `orca worktree rm --worktree "path:<wt>" --json`. Add `--delete-branch` only when `MERGED=YES`: a squash-merged branch is not an ancestor of the base, and its branch is the only copy of commits made after the PR. Orca also keeps a branch it cannot prove merged.
- `ORCA` is `-`: `git -C <repo> worktree remove --force <wt>`. When the directory survives on ignored build output, list what is left, then remove the directory. Finish with `git -C <repo> worktree prune`. The branch stays, so no commit is lost.

## 5. Report

Run `df -h /` and `git -C <repo> worktree list` again.

**Reply:** `df -h /` before and after with the space reclaimed, the worktrees removed, and for each one kept, its reason in one line (uncommitted work, open PR, active in Orca, or in use by which session).

Adapted from pstack `poteto-mode` playbook `worktree-cleanup` (github.com/cursor/plugins, MIT).
