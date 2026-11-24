---
name: blast-radius
description: Find what a change could break outside its diff before it ships, and prove the one fact it is safe because of by running real code instead of writing it up. Use before opening a PR for a change to shared code, for "blast radius of X", "what could this break", or reviewing a small diff you don't trust, in English or Japanese (影響範囲, 何が壊れる).
argument-hint: "[<diff, commit, branch, or PR>]  default: the current branch against its base"
---

# Blast radius

Find what a change breaks somewhere else, before it ships. `how` tells you what the code does and `why` tells you why it is shaped that way; this tells you what it breaks elsewhere.

Listing callers is not the job; grep does that in a second. The job is the breakage grep won't show.

## Don't trust your own writeup

A writeup that sounds right reads as convincing whether or not it is true. Find the one or two facts the whole change depends on and prove them by running code.

For each fact the change's safety depends on, get it as far down this list as is cheap, and say where it stopped:

1. You said so. Worthless on its own.
2. You pointed at the line: a real `file:line`, or the library's own source.
3. You showed the bad case can't happen, walking the failure step by step.
4. You ran it: a script or test that calls the real code and fails loudly if you are wrong.
5. You reproduced it in the running app (use the repo's `verify-<app>` skill when one exists).

Step 4 is usually one small script that imports the same library the app ships and calls the exact function you are worried about.

## Steps

1. **Read the change.** The diff, the symbols it adds, changes, and deletes, and what it now does differently, including what the diff doesn't spell out. Pull the PR and its commits if there is one.
2. **Find the one fact it is safe because of.** Most changes that look risky are safe because of a single fact ("this call only drops cache entries that are already dead"). If it holds, most risky cases clear at once. Spend your time here, not on a long list of maybes.
3. **Look where grep stops.** Read the source of the library you call at its pinned version. Work out when things run: transactions and their boundaries, goroutines, React render and effect timing, loader and action order. Follow what a symbol search misses: a proto field and every client that decodes it, a GraphQL field the BFF exposes, a DB column another service reads, a feature flag, a batch job, code three hops downstream, another repository reading the same bytes.
4. **Be honest about each risk.** Give it a real likelihood and a real cost. Keep confirmed risks; list checked-and-cleared ones separately. Cite a real `file:line`; a search that finds nothing is still an answer. Never invent a caller or an API.
5. **Prove the one fact.** Write a script or test that runs the real code, run it, and paste what happened.
6. **For a wide change, get a second opinion.** Give a fresh `Agent` the same question without your conclusion and merge the answers.

## What to hand back

- **What it does.** What changed, including the part that isn't obvious.
- **The one fact it is safe because of.** State it, say which step you got it to, and show the proof. If you couldn't prove it, write "unproven".
- **Risks.** For each: how it breaks, the `file:line`, how likely and how bad, and how to check. Paste the proof for the ones that matter.
- **Cleared.** What you checked and why it is fine.
- **Before you merge.** The cheapest test or repro that catches the real bug, including the script you wrote.

Adapted from pstack `blast-radius` (github.com/cursor/plugins, MIT).
