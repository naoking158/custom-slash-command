---
name: why
description: Explain why code is the way it is — design rationale, why an option was picked, when and why a regression came in, where a threshold came from — from the commit and PR record, with citations. Use for "why does X work this way", "why did we pick Y", postmortems and regressions, in English or Japanese (なぜこうなっている, 経緯, 理由). Use how for runtime behavior.
argument-hint: "<question>"
---

# Why

Answer from the record, not the code.

1. Find the change that introduced the target and each later change to it: `git log -S'<symbol>'`, `git log -L<start>,<end>:<file>`, `git blame -w -C`.
2. Read what the authors wrote: commit messages, then the PR (`gh pr list --search <sha> --state all`, `gh pr view <n> --comments`) and its review threads (`gh api repos/{owner}/{repo}/pulls/<n>/comments`).
3. If the trail is thin, look further: linked issues, ADRs in the repository, and Notion or Slack through their MCP search tools when connected.

Report:

- The answer, citing commits, PRs, and comments for each point.
- Your own inferences, marked as inferences.
- What the record does not answer.

Adapted from pstack `why` (github.com/cursor/plugins, MIT).
