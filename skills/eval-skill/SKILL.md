---
name: eval-skill
description: Blind A/B evaluation of a change to a SKILL.md, a rule or an agent — run the same natural task with and without the change in sanitized directories, have an isolated judge score anonymous variants against a hidden rubric, then check the transcripts before deciding Promote, Revise or Drop. Use for /my:eval-skill, "did this skill change help", or before promoting a toolkit change (スキル評価, ブラインド比較).
argument-hint: "<skill path or change description>"
disable-model-invocation: true
---

# Eval skill

Find out whether a change to a skill, a rule or an agent makes an agent behave better on real work, without letting the subject or the judge know what is being tested.

## Non-negotiables

Break one and the result is void; start over.

- **No leaking names.** Nothing the subject can see (directory names, file names, the prompt, branch names, commit messages) contains `eval`, `test`, `judge`, `experiment`, `rubric`, `score`, `compare`, `benchmark`, `candidate` or `arena`. A repository's own test files are fine; your scaffolding is not.
- **A natural task.** The subject gets the request a user would type. It is not told which skill or principle is under study, and it is not asked which ones it used.
- **The rubric is the judge's alone.** The subject never sees it.
- **Anonymous variants.** The judge sees `variant-a`, `variant-b` and nothing that says which one has the change, and scores all of them in one pass against the same rubric.

## 1. Frame

- The change: the diff of the skill, rule or agent, and the behavior it is meant to change.
- One to three tasks where that behavior shows: real requests from this toolkit's history, or a realistic one in a real repository.
- A rubric of three to six items, each observable in a transcript or a diff ("reproduced the bug before fixing", "ran the verify skill", "the diff touches only X"). Write it now and do not change it after seeing a result.

## 2. Prepare clean directories

For each variant and each task, one working directory that looks like ordinary work:

- A fresh clone or worktree of the target repository with a plain name (for example the feature the task is about), under `${TMPDIR:-/tmp}`.
- The toolkit as that variant has it: the baseline at `main`, the change on its branch. Point the subject at it (`CLAUDE_PLUGIN_ROOT`, or a checkout of this repository in that state) without naming it after the variant.
- Randomize which variant is `a` and which is `b`, and record the mapping where the judge cannot read it.

## 3. Run

Run each variant on each task in isolation and in parallel: a separate `Agent`, a separate `claude -p` session in the variant's directory, or an Orca worker (`orca/bin/run-role` profiles choose the harness and model). Give every run the same prompt, word for word. Keep each transcript and the final diff.

## 4. Judge blind

Start a read-only judge, from a different model family when the profile offers one (the `review` or `audit` line), with the rubric, the task, and for each anonymous variant its final diff and a transcript excerpt (files read, commands run, the closing message). Ask for a score and one line of evidence per rubric item per variant.

## 5. Check the transcripts

Do not take the judge's word or the subject's account. For each rubric item, check the transcript yourself: which files were read, which checks actually ran and what they printed, the shape of the final diff. Where the transcript and the judge disagree, the transcript wins; note the disagreement.

Then decide:

- **Promote**: the change wins on the items it targets and loses on none.
- **Revise**: mixed, or it wins for a reason other than the one intended. Say what to change.
- **Drop**: no difference, or worse.

## Report

The change and the tasks, the rubric, a table of variant × item (after unblinding) with the evidence, the disagreements found in step 5, and the verdict with its reason. Keep the directories until the user has read the report, then remove them.

Adapted from pstack `eval` playbook (github.com/cursor/plugins, MIT).
