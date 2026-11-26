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
- The tools the task needs, as one `--allowedTools` list shared by every run (edits, plus the Bash commands for the build, tests and git). A run without them cannot change anything, and the comparison measures nothing.

## 2. Prepare clean directories

For each variant and each task, one working directory that looks like ordinary work:

- A fresh clone or worktree of the target repository with a plain name (for example the feature the task is about), under `${TMPDIR:-/tmp}`.
- A toolkit checkout of this repository in the variant's state: the baseline at `main`, the change on its branch. Delete `skills/eval-skill/` from it, so the subject's skill list does not name this evaluation.
- A home directory of its own with a plain name, where `HOME=<that dir> MY_ORCA_PROFILE=work <toolkit checkout>/scripts/install.sh` links `~/.claude/skills/my` to that checkout (without `MY_ORCA_PROFILE`, a machine with `orca` on PATH makes it exit 1 after linking; check that `<that dir>/.claude/skills/my` points at the checkout). This is what switches the toolkit: a session loads `my` from `$HOME/.claude/skills/my`, and a subagent (`Agent`) or `--plugin-dir` would keep the session's own copy loaded beside it. Give it credentials without copying your own home (`ANTHROPIC_API_KEY`, or a token from `claude setup-token` in `CLAUDE_CODE_OAUTH_TOKEN`); none available → stop and say so.
- Randomize which variant is `a` and which is `b`, and record the mapping where the judge cannot read it.

## 3. Run

Run each variant on each task as its own session, in parallel, from the variant's working directory:

```bash
HOME=<variant home> claude -p "<the task>" --permission-mode acceptEdits \
  --allowedTools "<the commands the task needs, e.g. Bash(git *) Bash(npm test *)>" \
  --output-format stream-json --verbose > <transcript file outside the working directory>
```

`-p` denies every tool the flags do not allow, so pass the list from step 1, the same for every variant. Do not use `bypassPermissions`: the subject runs as you, on your machine, outside any sandbox. Give every run the same prompt, word for word. Keep each transcript and the final diff, new files included (`git -C <working directory> add -A -N && git -C <working directory> diff`). Do not run subjects as `Agent` subagents or through `orca/bin/run-role`: a subagent shares this session's toolkit, and run-role runs only its fixed roles.

## 4. Judge blind

Start a read-only judge as an `Agent` subagent, given only the rubric, the task, and for each anonymous variant its final diff and a transcript excerpt (files read, commands run, the closing message). Keep the variant mapping in this conversation, not in a file the judge can read. Ask for a score and one line of evidence per rubric item per variant. For a judge from another model family, run it the way step 3 runs a subject (`claude -p` with another `--model`, or another harness), with the same materials and read-only tools.

## 5. Check the transcripts

First confirm that each run loaded its own variant: the transcript reads the changed file from that variant's toolkit checkout (or invokes the changed skill and shows its variant text). Then confirm that no tool call was denied for permission (`permission_denials` in the result line). A run that loaded the other variant or neither, or that hit a denial, voids the comparison: fix step 2 or the allowed list and run again.

Do not take the judge's word or the subject's account. For each rubric item, check the transcript yourself: which files were read, which checks actually ran and what they printed, the shape of the final diff. Where the transcript and the judge disagree, the transcript wins; note the disagreement.

Then decide:

- **Promote**: the change wins on the items it targets and loses on none.
- **Revise**: mixed, or it wins for a reason other than the one intended. Say what to change.
- **Drop**: no difference, or worse.

## Report

The change and the tasks, the rubric, a table of variant × item (after unblinding) with the evidence, the disagreements found in step 5, and the verdict with its reason. Keep the directories until the user has read the report, then remove them.

Adapted from pstack `eval` playbook (github.com/cursor/plugins, MIT).
