---
description: Run the SDD pipeline end to end via isolated subagents. Feature flow research → spec → plan → do, or change flow change → do, with optional review cycles.
argument-hint: "<description|identifier> [--flow feature|change] [--from <step>] [--to <step>] [--only <step>] [--no-review]"
disable-model-invocation: true
---

# Pipeline Orchestration

Arguments: **$ARGUMENTS**

Coordinate sequential execution of pipeline steps, each in an isolated
subagent. State passes between steps **only through files under `docs/`** —
pass file paths and the identifier to subagents, never file contents. The
orchestrating session keeps only each subagent's returned summary.

## Parameters

| Option | Default | Values |
|--------|---------|--------|
| `--flow` | `feature` | `feature` (research→spec→plan→do) / `change` (change→do) |
| `--from` / `--to` | feature: research→plan; change: change→do | any step of the flow |
| `--only` | – | single step; mutually exclusive with `--from`/`--to` |
| `--review` / `--no-review` | review on | review+fix cycle after each non-`do` step |

First non-option argument: `YYYYMMDD-*` pattern → existing identifier;
otherwise a new description → generate identifier (`YYYYMMDD-` + 2–4 English
kebab-case words extracted from it).

Validation (fail fast, one-line error each): unknown flow; step not in flow;
`--from` after `--to`; `--only` combined with `--from`/`--to`; no arguments →
print the Parameters table above as usage.

When `--from` is not the flow's first step, the previous step's output file
must exist; if missing, error with `Run /my:{previous_step} {id} first.`

## Steps and subagents

| Step | subagent_type | Input | Output |
|------|---------------|-------|--------|
| research | `my:researcher` | description | `docs/research/{id}.md` |
| spec | `my:specifier` | `docs/research/{id}.md` | `docs/specs/{id}.md` |
| plan | `my:planner` | `docs/specs/{id}.md` | `docs/plans/features/{id}.md` |
| change | `my:changer` | description | `docs/analysis/changes/{id}.md` + `docs/plans/changes/{id}.md` |
| do | `my:implementer` | plan path | code changes |

Subagent prompt: identifier, input path(s), output path(s), today's date —
nothing else. If the `my:` namespaced type is not resolvable, retry with the
bare name (e.g. `researcher`).

## Execution loop

For each selected step, in order (never parallelize):

1. Announce `[{n}/{total}] {step}…`. If the step's output file already exists,
   list it as an overwrite target before proceeding.
2. Launch the subagent (Task tool).
3. Verify the expected output file(s) exist (skip for `do`; `change` must
   produce both files). Missing output or subagent failure → stop immediately,
   preserve artifacts, print: `Resume with: /my:pipeline {id} [--flow {flow}] --from {step}`.
   A subagent returning status `blocked` is a failure: surface its blocker
   description verbatim.
4. Review cycle (when enabled, for every step except `do`):
   a. Launch `my:reviewer` with the step's output path; review is written to
      `docs/reviews/{type}/{id}.md` ({type}: research | specs | plans | changes).
   b. Read only the review's summary/assessment.
   c. If any **Critical or High** findings: launch `my:fixer` with the review
      path + target path (fixer applies Critical/High only). One cycle max.
   d. Otherwise continue.

## Completion

Summarize: artifacts actually created this run (paths), review assessments,
and the next command (`/my:do {id}` if the run stopped at plan; code
review / commit if it included `do`).
