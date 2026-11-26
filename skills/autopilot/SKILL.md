---
name: autopilot
description: Work toward a goal autonomously for a long stretch — split it into small changes and, for each one, implement, test, verify in the real app, open a PR, run an AI review and fix what it finds. In ship-mode repositories the agent merges each PR once CI is green; elsewhere it stacks draft PRs for a human to land. Use for /my:autopilot, "このゴールで自律的に進めて", "PR を積んで進めて", or any request to keep working unattended until a goal is met.
argument-hint: "<goal>  |  resume <goal-slug>"
disable-model-invocation: true
---

# Autopilot

Goal: **$ARGUMENTS**

Run without asking the user anything until a stop condition below is reached. Decide, record the decision in `decisions.tsv`, and continue. The user reads `progress.md`, `decisions.tsv` and the final report, not the conversation.

## 0. Set up

1. Resolve the mode from the repository you will change:

   ```bash
   "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/autonomy.sh" <repo>
   ```

   It prints `ship <owner/name>` or `strict <owner/name>`. Strict runs the **stack** loop; ship runs the **ship** loop. The outbound-guard hook enforces the same split, so a denied command means you picked the wrong loop, not that you should work around it.

2. State lives outside the repository in `R=~/.local/state/autopilot/<owner>-<name>/`, one directory per goal in `S=$R/<goal-slug>/`:
   - `goal.md` from [`goal-template.md`](goal-template.md). Fill purpose, done criteria (observable), scope, out of scope and the budget. Derive what the user did not say and mark it `(derived)`. With `resume <goal-slug>`, read the existing files instead and continue from the log.
   - `progress.md`: append one entry per task (task, branch, PR, review rounds, verify verdict, CI, outcome, evidence) for the human reader.
   - `decisions.tsv`: one row per decision point — a choice made on the user's behalf, a fork taken, a pivot, a revert, a blocker. Append with `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/skills/autopilot/scripts/log-decision.sh" "$S/decisions.tsv" <phase> <decision> <why> <evidence> <result>`, where `<phase>` is `start`, `task<n>` or `final` and `<evidence>` is a path, PR or command a reader can check. The first row of every run is `phase=start`; on `resume`, its evidence names the last `ts` already in the file, so this run's rows can be told apart.
   - `tasks.tsv`: one row per finished task (step 1.8), appended with `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/skills/autopilot/scripts/log-task.sh" "$S/tasks.tsv" <task_id> <branch> <pr> <review_rounds> <verify> <ci> <outcome>`. `<task_id>` is the task's `#` in `goal.md` (a number, so `/my:retro` matches it with the same task in `progress.md`). The script rejects values outside its enums; logging a task again supersedes its earlier row.
   - Both TSV files are append-only: never edit or delete a row; add a corrected one.
   - `reviews/`: the `my:review` reports for this goal's PRs (step 1.6 writes them here).
   - `$R/found.md`: the repository's Found list, shared by every goal, so that no goal has to know where another one wrote. Read it at every start, resume included, and log how many rows are open. Missing → create it with the header `| Goal | Where | Why it matters | Size | State |`, then move the rows of any `## Found` section still left in an earlier goal's `goal.md` into it, tagged with that goal's slug, and delete those sections.

3. Work in a dedicated worktree so the user's checkout is never touched. If the current directory is a worktree made for this goal (`$(git rev-parse --absolute-git-dir)/my-autopilot-worktree` exists), work in it; otherwise `git -C <repo> worktree add <repo>-autopilot-<goal-slug> origin/<default>` (reuse it on resume).

4. Stage files by name, never `git add -A`, so that a stray file in the worktree does not ride along.

5. Write the task list into `goal.md`: changes small enough to review in one sitting, ordered so each one leaves the build green.

## 1. One task

For every task, in order:

1. **Branch.** ship: `auto/<goal-slug>/<nn>-<slug>` from the updated default branch. stack: the same name from the previous task's branch (the first one from the default branch).
2. **Implement** with completion criteria stated first (global CLAUDE.md rules apply: reproduce bugs first, regression test, small commits).
3. **Test and lint** the way the repository's CLAUDE.md / CI does. Red → fix before moving on.

   Never make a gate pass by loosening it: do not skip or delete a test, add a lint or type suppression, widen a threshold or tolerance, or turn a check into a soft failure in order to get CI, tests, lint or type checks green, and never merge such a change on your own. When the gate itself is wrong, fix it as a separate task whose PR says so and never merge that PR yourself, even in ship mode: leave it open and list it under "Waiting on a human" in the final report. Or record BLOCKED and leave the decision to a human.
4. **Verify.** If the repository has a `verify-<app>` skill, launch `Agent` with `subagent_type: "my:verifier"`, giving it the worktree path and this task's criteria. FAIL → fix and verify again. BLOCKED → record it; continue only if the remaining criteria were observed some other way, else stop (see §3). No verify skill → record "unverified in the app" for the task.
5. **Push and open the PR.** Body: 課題 → 対応 → 設計判断, short, plus for stack mode one line `Stack: n/N, base #<parent PR>`. ship: `gh pr create --base <default>`. stack: `gh pr create --draft --base <parent branch>`.
6. **Review and fix.** Run the `my:review` skill with `pr:<number> --no-screen --report-dir <absolute path of $S/reviews>`: the review runs in the session's directory, not in the worktree, and its report belongs with the run's state, not in anyone's checkout. Fix every Critical/High finding, push, and review again — at most 2 fix rounds. Medium/Low: fix when cheap, otherwise list them in the progress log. Never cite finding IDs or report paths in commits or PR text.
7. **Land.**
   - ship:
     - Take in what landed under the PR: `git fetch -q origin <default>`. If `git log --oneline HEAD..origin/<default>` prints anything, note which files `git diff --name-only HEAD...origin/<default>` (what the default branch gained) shares with `git diff --name-only origin/<default>...HEAD` (what the PR changes), then merge `origin/<default>` into the branch, run the tests and push. A shared file means another goal, or the user, is changing the same code: review again as well (not a fix round). A merge that is clean as text can still break what the PR assumes.
     - Wait for CI on the commit you pushed: run `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/wait-ci.sh" <owner/name> <sha>` with `run_in_background`, as the whole command. `<sha>` is the full sha from `git rev-parse HEAD`. The exit status is the verdict, and a trailing `echo` or pipe would replace it. `gh pr checks --watch` is no substitute: right after a push GitHub has registered no run yet, and it exits at once with "no checks reported".
       - 0: green.
       - 1: red. Fix on the branch (counts toward the failure limit).
       - 2: gh failed (login, network) or the sha was abbreviated. Run it again once; a second 2 is BLOCKED.
       - 3: no run exists for this commit. When no workflow of the repository runs for this change, the tests of step 3 are the gate: log `CI: none`. Otherwise treat it as red.
       - 4: still running after an hour. Run it again; this is not a failure.
     - Merge when green: `gh pr merge <n> -R <owner/name> --squash --delete-branch`. With `-R`, gh leaves local branches alone and deletes only the remote branch; without it, gh tries the local branch first, and when the worktree still has it checked out that fails before the remote is deleted.
     - Confirm it landed: exit 0 from `gh pr merge` is not proof (a merge queue may still hold it, or the base may not be the default branch). Read `gh pr view <n> -R <owner/name> --json state,mergedAt,baseRefName,mergeCommit` and go on only when `state` is `MERGED` and `baseRefName` is `<default>`. Otherwise wait and read it again; still not landed after an hour → BLOCKED.
     - Then update the default branch, and delete the local branch with `git branch -D` once the worktree has moved to the next task's branch.
   - stack: leave the draft open. Never mark it ready and never merge it.
8. **Log** the task in `progress.md` and `tasks.tsv`, then pick the next task.

### Things you notice along the way

Keep each PR to its task. When you notice something worth improving that the current task does not need, do not fix it in this PR; route it:

- **The repository's code** (a smell, a missing test, dead code, a confusing name outside the diff): append it to `$R/found.md` with this goal's slug, location, why it matters, and a size guess (S/M/L). A repository-local `verify-<app>` skill counts as repository code.
- **A `my:*` asset** (this skill, `my:review`, `my:verifier`, the guard): run `/my:learn` with the category and target, then keep going. `/my:retro` decides on the change later with the user.
- **Any other tool outside the repository** (a personal skill, global settings): record it under `## Tool friction` in `progress.md`.

Never edit toolkit skills, personal skills, settings or CLAUDE.md during a run: the run's own rules must not change under it.

## 2. Mode rules

**ship**
- When the goal's tasks are done and budget remains, take open `found.md` rows that sit inside the scope, whichever goal recorded them, as further tasks through the same loop, smallest and highest-value first. Mark each row as done (PR), skipped (why) or left.
- Fix forward: after each merge, wait for the default branch's CI on the merge commit: the same `wait-ci.sh`, in the background, with the sha from `gh pr view <n> -R <owner/name> --json mergeCommit -q .mergeCommit.oid`. If it goes red (exit 1), the next task is fixing it (or `git revert` of the culprit through a PR) before anything else.
- Never create tags or releases, and never push to the default branch directly; everything lands through a PR.

**stack**
- When a lower PR changes (review fix, rework), bring each PR above it up to date with `git merge <parent branch>` and push. Never rebase or force-push an open stack; after the user lands the bottom PR they restack themselves.
- Carry verdicts over by patch-id: before and after that merge, run `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/patch-id.sh" "$(git merge-base <parent branch> HEAD)" HEAD`. Run the tests after every merge. The same id, when the PR shares no file with what the merge brought in (compare the files of `git diff --name-only` for the merge and for the PR, as in step 7), means the PR's own change is unchanged: keep its earlier verify and review verdicts and log both ids in `decisions.tsv`. A different id or a shared file means verify and review it again.
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

First audit this run's trail: read `decisions.tsv` from this run's `phase=start` row on, check that every `evidence` that is a file path exists, and append a row for any fork, pivot or blocker that is missing. Never edit or delete an earlier row.

Then append the report to `progress.md` and show the user, decision first:

1. **One line**: whether a human has to act, or that nothing is needed.
2. **Waiting on a human** (only when something is): riskiest first, each with the target (PR link or task), the recommended action, the evidence, the risk, and the exact operation to perform, so that this reply alone is enough to decide.
3. **Done criteria**: met / not met for each, with the evidence (PR, verify evidence dir, CI run).
4. **PRs** in order with their state (merged / draft), review rounds and remaining Medium/Low.
5. **Run record**: the paths of `decisions.tsv`, `tasks.tsv` and `progress.md`, why it stopped, the decisions made on the user's behalf, `found.md` rows still open across the repository (count, and the rows this run added), `/my:learn` signals captured, and `## Tool friction` entries.

Clean up: remove the worktree only when everything in it is pushed (`git worktree remove`), and stop any app stack a verify run left behind.
