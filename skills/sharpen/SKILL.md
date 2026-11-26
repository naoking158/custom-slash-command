---
name: sharpen
description: Deepen a task or goal before anyone starts it — what an expert would also check, the rawest sources to read first, the methods and tools to use, and an objective bar for "done" — and return it rewritten, with a goal ready for /my:autopilot. Does not do the task. Use for /my:sharpen, "sharpen this prompt", or before handing a goal to an agent (依頼を研ぐ, ゴールを深掘り).
argument-hint: "<task or goal description>"
disable-model-invocation: true
---

# Sharpen

Make the request deeper, not bigger. Add what a strong engineer in this area would check without being told, and the bar a result must clear; do not add features, scope or polish nobody asked for.

Do not do the task. The output is the rewritten request.

## 1. Read what is there

Read `$ARGUMENTS` and enough of the repository to know what it touches (the files and the commands it names, the area's recent `git log`). When the request is too vague to place in the code, ask one question and stop.

## 2. Deepen

Answer each, with specifics from this repository:

1. **What would an expert also check?** The questions the request does not ask but the answer depends on: the callers, the edge cases, the data that already exists, how it fails today, what changed recently around it.
2. **Which sources are rawest?** The first-hand material to read before any summary: real logs, real rows, the git history and the PR discussion, the library's source rather than its docs, the failing request rather than a description of it. Name them (paths, commands, queries).
3. **Which methods and tools?** The concrete way to do it: reproduce first, bisect, a throwaway prototype, a script that checks every case. Point to the toolkit's skills where they fit: `/my:how` for an unfamiliar area, `/my:why` for history, `/my:blast-radius` for a change's reach, `/my:architect` before crossing a boundary, `/my:interrogate` for a risky diff.
4. **What proves it right?** A check that does not rest on the agent's own report: a command's output, a test that fails before and passes after, a screen in the real app, a number from the real data.

## 3. Settle what can be settled

For each open choice, decide who settles it:

- An experiment or prototype can answer it (which library is faster here, does the API accept this): say which experiment, run it when it is cheap, and give the recommendation.
- Only a person can answer it (product behavior, priorities, taste): leave it as a question for the user.

## 4. Return

1. **Sharpened request**: the original request rewritten with steps 2 and 3 folded in, ready to paste to an agent.
2. **Goal for autopilot**: a goal text for `/my:autopilot` (or Orca's `start-goal`), with a `Done criteria` list of observable outcomes and the scope (in / out).
3. **Questions for you**: only the choices step 3 left to a person, each with the options and what each one costs.

Adapted from pstack `sharpen` (github.com/cursor/plugins, MIT).
