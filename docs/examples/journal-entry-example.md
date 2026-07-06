# Journal entry example

A journal entry is one **toolkit improvement signal**, stored machine-locally
at `~/.claude/my-toolkit/journal/{YYYYMMDD-HHMMSS}-{slug}.md` (never inside a
repository tree). Project knowledge does NOT go here — native auto memory
keeps that per project.

Example: `20260706-153012-plan-missing-baseline-tests.md`

```markdown
---
date: 2026-07-06
session_id: 7a063d83-1234-4abc-89de-f0123456789a
project: /Users/me/src/github.com/me/webapp
target: skills/plan
category: mistake
status: raw
---

## Signal
/my:plan produced a refactor plan without a baseline-test step again; the
user had to ask for it manually. Second time this month (see
20260618-101502-plan-missing-baseline-tests.md).

## Context
User: 「またベースラインのテストが計画に入ってない。リファクタ前に必ず入れて」

## Suggested fix
skills/plan/SKILL.md: make the baseline-test step unconditional for
refactor-type plans instead of "when tests exist".
```

Field notes:

- `target` — the toolkit asset the signal points at (`skills/...`,
  `agents/...`, `hooks`, `CLAUDE.md`), or `unknown`.
- `category` — `mistake | gap | friction | pattern | question`.
- `status` — `raw` (default) → `promoted` or `archived`, flipped by
  `/my:retro` when it applies or retires the signal.
- `## Signal` is the only mandatory section; `## Context` and
  `## Suggested fix` are optional.
