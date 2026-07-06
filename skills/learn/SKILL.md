---
description: Capture a toolkit improvement signal — a moment where a my:* skill, agent, hook, or rule misbehaved, was missing, or worked notably well — into the machine-local journal that /my:retro promotes from. Invoke when the user corrects toolkit-driven behavior, hits toolkit friction, or says learn/学び/ジャーナル. Do NOT invoke for project knowledge (auto memory handles that).
argument-hint: "[--category <mistake|gap|friction|pattern|question>] [--target <skills/...|agents/...|hooks|CLAUDE.md>] [free-text memo]"
---

# Learn — Toolkit Improvement Signal Capture

Record one improvement signal for the **toolkit itself** (this plugin's
skills / agents / hooks / rules). Input: **$ARGUMENTS**

## Routing rule (decide this FIRST)

Two kinds of knowledge come out of a session. Only one belongs here:

| Kind | Example | Where it goes |
|------|---------|---------------|
| **Project knowledge** — facts about the codebase, domain, or environment you are working in | "Homebrew 6 requires tap trust", "this repo's tests need `-race`" | **Native auto memory** (`~/.claude/projects/<project>/memory/`). Write it there as a normal memory; do not create a journal entry. |
| **Toolkit signal** — evidence that a `my:*` asset should change | "/my:plan skipped baseline tests again", "reviewer keeps missing N+1 queries", "no skill covers DB migrations" | **The journal** (this skill). |

If the input contains both, split it: memory for the project fact, journal
for the toolkit signal. Tell the user which went where.

## Step 1 — Build the entry

Journal entries live in the machine-local, **global** store (signals target
the toolkit, so there is one store per machine, not per project):

```bash
dir="${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/journal"
mkdir -p "$dir"
target_file="$dir/$(date +%Y%m%d-%H%M%S)-{slug}.md"
```

`{slug}` is a short kebab-case summary of the signal (e.g.
`plan-missing-baseline-tests`). Never write under `$PWD/` or into any
repository tree.

## Step 2 — Write the entry

```markdown
---
date: {YYYY-MM-DD}
session_id: {$CLAUDE_SESSION_ID or "unknown"}
project: {$PWD}
target: {toolkit asset path, e.g. skills/plan — or "unknown"}
category: {mistake|gap|friction|pattern|question}
status: raw
---

## Signal
{1–5 lines: what happened, or what should improve. This is the only
mandatory section — keep it concrete enough that /my:retro can act on it
weeks later without this session's context.}

## Context
{optional: the exact user correction, error output, links}

## Suggested fix
{optional: concrete change to the toolkit asset}
```

Categories: `mistake` (a toolkit instruction produced wrong behavior),
`gap` (missing instruction/skill/rule), `friction` (workflow annoyance),
`pattern` (something worked well — codify it), `question` (unresolved).
Unknown `--category` values fall back to `gap` with a warning.

Infer category and target from the conversation when flags are absent. One
file per signal; if the same session surfaces several distinct signals,
write several files.

## Step 3 — Confirm

```
✅ Toolkit signal captured.
Path: {target_file}
Target: {target}  Category: {category}
Next: /my:retro clusters and promotes accumulated signals.
```

## Critical rules

- Journal writes go ONLY under `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/journal/`.
  Never inside a repository tree.
- Do not edit toolkit assets from this skill — capture only. Promotion is
  /my:retro's job (proposal → approval → apply).
- Keep entries short. A signal is a pointer, not a report.
- Dependencies: bash + coreutils only.

## Examples

```
/my:learn --category mistake --target skills/plan "plan が baseline テストをまた飛ばした"
/my:learn --category gap "DB マイグレーション用の skill が無い"
/my:learn   # infer signal, category, and target from the conversation
```
