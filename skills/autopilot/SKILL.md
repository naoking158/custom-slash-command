---
name: autopilot
description: Work toward a goal autonomously for a long stretch — split it into small changes and, for each one, implement, test, verify in the real app, open a PR, run an AI review and fix what it finds. In ship-mode repositories the agent merges each PR once CI is green; elsewhere it stacks draft PRs for a human to land. Use for /my:autopilot, "このゴールで自律的に進めて", "PR を積んで進めて", or any request to keep working unattended until a goal is met.
argument-hint: "<goal>  |  resume <goal-slug>"
disable-model-invocation: true
---

# Autopilot

Goal: **$ARGUMENTS**

Run without asking the user anything until a stop condition below is reached. Decide, record the decision in the progress log, and continue. The user reads the log and the final report, not the conversation.

## 0. Set up

1. Resolve the mode from the repository you will change:

   ```bash
   "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/autonomy.sh" <repo>
   ```

   It prints `ship <owner/name>` or `strict <owner/name>`. Strict runs the **stack** loop; ship runs the **ship** loop. The outbound-guard hook enforces the same split, so a denied command means you picked the wrong loop, not that you should work around it.

2. State lives outside the repository in `R=~/.local/state/autopilot/<owner>-<name>/`, one directory per goal in `S=$R/<goal-slug>/`:
   - `goal.md` from [`goal-template.md`](goal-template.md). Fill purpose, done criteria (observable), scope, out of scope and the budget. Derive what the user did not say and mark it `(derived)`. With `resume <goal-slug>`, read the existing files instead and continue from the log.
   - `progress.md`: append one entry per task (task, branch, PR, review rounds, verify verdict, CI, outcome) and one line per decision you made on the user's behalf.
   - `reviews/`: the `my:review` reports for this goal's PRs (step 1.6 writes them here).
   - `$R/found.md`: the repository's Found list, shared by every goal, so that no goal has to know where another one wrote. Read it at every start, resume included, and log how many rows are open. Missing → create it with the header `| Goal | Where | Why it matters | Size | State |`, then move the rows of any `## Found` section still left in an earlier goal's `goal.md` into it, tagged with that goal's slug, and delete those sections.

3. Work in a dedicated worktree so the user's checkout is never touched: `git -C <repo> worktree add <repo>-autopilot-<goal-slug> origin/<default>` (reuse it on resume).

4. Stage files by name, never `git add -A`, so that a stray file in the worktree does not ride along.

5. Write the task list into `goal.md`: changes small enough to review in one sitting, ordered so each one leaves the build green.

## 1. One task

For every task, in order:

1. **Branch.** ship: `auto/<goal-slug>/<nn>-<slug>` from the updated default branch. stack: the same name from the previous task's branch (the first one from the default branch).
2. **Implement** with completion criteria stated first (global CLAUDE.md rules apply: reproduce bugs first, regression test, small commits).
3. **Test and lint** the way the repository's CLAUDE.md / CI does. Red → fix before moving on.
4. **Verify.** If the repository has a `verify-<app>` skill, launch `Agent` with `subagent_type: "my:verifier"`, giving it the worktree path and this task's criteria. FAIL → fix and verify again. BLOCKED → record it; continue only if the remaining criteria were observed some other way, else stop (see §3). No verify skill → record "unverified in the app" for the task.
5. **Push and open the PR.** Body: 課題 → 対応 → 設計判断, short, plus for stack mode one line `Stack: n/N, base #<parent PR>`. ship: `gh pr create --base <default>`. stack: `gh pr create --draft --base <parent branch>`.
6. **Review and fix.** Run the `my:review` skill with `pr:<number> --no-screen --report-dir <absolute path of $S/reviews>`: the review runs in the session's directory, not in the worktree, and its report belongs with the run's state, not in anyone's checkout. Fix every Critical/High finding, push, and review again — at most 2 fix rounds. Medium/Low: fix when cheap, otherwise list them in the progress log. Never cite finding IDs or report paths in commits or PR text.
7. **Land.**
   - ship:
     - Wait for CI on the commit you pushed: run `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/wait-ci.sh" <owner/name> <sha>` with `run_in_background`, as the whole command. Its exit status is the verdict, and a trailing `echo` or pipe would replace it. `gh pr checks --watch` is no substitute: right after a push GitHub has registered no run yet, and it exits at once with "no checks reported".
       - 0: green.
       - 1 or 4: red. Fix on the branch (counts toward the failure limit).
       - 3: no run exists for this commit. When no workflow of the repository runs for this change, the tests of step 3 are the gate: log `CI: none`. Otherwise treat it as red.
     - Merge when green: `gh pr merge <n> -R <owner/name> --squash --delete-branch`. With `-R`, gh leaves local branches alone and deletes only the remote branch; without it, gh tries the local branch first, and when the worktree still has it checked out that fails before the remote is deleted. Then update the default branch, and delete the local branch with `git branch -D` once the worktree has moved to the next task's branch.
   - stack: leave the draft open. Never mark it ready and never merge it.
8. **Log** the task in `progress.md`, then pick the next task.

### Things you notice along the way

Keep each PR to its task. When you notice something worth improving that the current task does not need, do not fix it in this PR; route it:

- **The repository's code** (a smell, a missing test, dead code, a confusing name outside the diff): append it to `$R/found.md` with this goal's slug, location, why it matters, and a size guess (S/M/L). A repository-local `verify-<app>` skill counts as repository code.
- **A `my:*` asset** (this skill, `my:review`, `my:verifier`, the guard): run `/my:learn` with the category and target, then keep going. `/my:retro` decides on the change later with the user.
- **Any other tool outside the repository** (a personal skill, global settings): record it under `## Tool friction` in `progress.md`.

Never edit toolkit skills, personal skills, settings or CLAUDE.md during a run: the run's own rules must not change under it.

## 2. Mode rules

**ship**
- When the goal's tasks are done and budget remains, take open `found.md` rows that sit inside the scope, whichever goal recorded them, as further tasks through the same loop, smallest and highest-value first. Mark each row as done (PR), skipped (why) or left.
- Fix forward: after each merge, wait for the default branch's CI on the merge commit: the same `wait-ci.sh`, in the background, with the sha from `gh pr view <n> -R <owner/name> --json mergeCommit -q .mergeCommit.oid`. If it goes red (exit 1 or 4), the next task is fixing it (or `git revert` of the culprit through a PR) before anything else.
- Never create tags or releases, and never push to the default branch directly; everything lands through a PR.

**stack**
- When a lower PR changes (review fix, rework), bring each PR above it up to date with `git merge <parent branch>` and push. Never rebase or force-push an open stack; after the user lands the bottom PR they restack themselves.
- At most 5 open PRs in one stack. At the cap, stop.
- Verification is serial (one app stack at a time); do not run tasks in parallel.
- Do not turn `found.md` rows into PRs: an unrequested PR in the stack costs the user review time. They go in the final report.

## 3. Stop conditions

Stop and write the final report when any of these holds:

- The done criteria in `goal.md` are observed.
- The task budget in `goal.md` is spent.
- The same task failed verify, CI or review twice after fixes that share a premise (write the premise down in the log first).
- BLOCKED for a reason only a human can clear: data the test user lacks, an expired login (AWS SSO, gh), a decision outside `goal.md`'s scope, or an irreversible action.
- stack: the stack cap is reached. ship: the default branch is red and two fix attempts did not turn it green.

## 4. Final report

Append to `progress.md` and show the user:

- Outcome against each done criterion (met / not met, with the evidence: PR, verify evidence dir, CI run).
- PRs in order with their state (merged / draft, review rounds, remaining Medium/Low).
- Why it stopped, and what a human has to do next (land the stack bottom-up, provide data, renew a login).
- Decisions made on the user's behalf.
- `found.md` rows still open across the repository (count, and the rows this run added), `/my:learn` signals captured, and `## Tool friction` entries.

Clean up: remove the worktree only when everything in it is pushed (`git worktree remove`), and stop any app stack a verify run left behind.
