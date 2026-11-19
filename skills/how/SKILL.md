---
description: Explain how part of a codebase works — subsystem architecture, runtime flow, where something lives, which package or layer owns it — before changing it. Use for "how does X work", code walkthroughs, onboarding to an unfamiliar area, and placement questions ("where should this live", "is this the right layer"), in English or Japanese (どう動いている, 仕組み, どこに置くべき). Use why for motivation and history.
argument-hint: "<question>"
---

# How

Answer "how does X work?" from the code. If the scope is ambiguous, state your interpretation and proceed; the user can redirect.

## 1. Explain

Spawn one `Agent` with `subagent_type: "Explore"` that explores and explains in one pass. Give it the user's question and this brief:

> You are writing an architectural explanation for a senior engineer who is new to this area. Explore the codebase and write an explanation they could read and walk away with a solid mental model, well enough to start working in it confidently. Cite real `file:line` locations for each claim. You have read-only access.

For a question that spans repositories (for example a frontend screen backed by a backend RPC), name every repository path in the brief so the agent follows the call across them.

## 2. Present

Present the agent's explanation. Light edits for clarity or for context from the conversation are fine; do not substantially rewrite it.

Adapted from pstack `how` (github.com/cursor/plugins, MIT).
