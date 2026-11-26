---
name: correct
description: Find mistakes agents keep repeating in a target repository and encode structural fixes (architecture -> types -> lint/CI -> tests -> docs last), proving each new check fails on a real past mistake. Use for /my:correct or recurring repo mistakes (再発防止, 構造で防ぐ). Do NOT use for my:* toolkit bugs (use /my:learn and /my:retro).
argument-hint: "[--since <Nd|YYYY-MM-DD>] [--dry-run] [<repo path>]"
disable-model-invocation: true
---

# Correct

People keep correcting agents in this repository for the same mistakes. Change the repository so that the next agent cannot make them.

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles. Design the repository so that a change that looks right from one file is right for the whole repository.

**Boundary.** This skill changes the target product repository. A mistake in a `my:*` skill, agent, hook or rule goes to `/my:learn`, and `/my:retro` decides on it; do not fix the toolkit here.

## 1. Mine the mistake classes

In the target repository (default: the current one), over `--since` (default `60d`), read the sources below. First turn `--since` into a date `<date>` (YYYY-MM-DD; `60d` is 60 days before today): `git log --since=60d` matches nothing, without an error.

- `git log --since=<date>`: reverts and the commits that fix an earlier change;
- `gh pr list --state all --limit 1000 --search "updated:>=<date>"` (the default limit is 30) and the review comments on those PRs;
- the agent instruction files: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`;
- comments that explain a workaround (`workaround`, `HACK`, `do not remove`, `must`, `don't`);
- `~/.local/state/autopilot/<owner>-<name>/found.md`, when it exists.

Group the mistakes into classes. A class counts once it has happened twice, or once when the user names it.

## 2. Pick the highest level that works

For each class, take the first level that can stop it:

1. **Architecture**: give each piece of state one owner and each task one supported way. Hide internals so the wrong import fails. Replace hand-synced lists with one source of truth. Delete the old paths and dead code an agent would copy.
2. **Types**: make the bad state impossible to write.
3. **Lint / CI**: when bad code still compiles, add a lint rule or CI script whose error message names the file, type or function to use instead. When the pattern is already common, fail only on code a change adds (a ratchet), not on what is there.
4. **Behavioral test**: a test that fails when the mistake comes back and survives a refactor that keeps the behavior. Fix or delete a test that still passes when its behavior breaks, or fails when only the internals change.
5. **Prose, last**: a line in `CLAUDE.md` / `AGENTS.md`, only for a judgment call. Nothing fails when an agent skips it.

## 3. Propose

For each class, show: the evidence (commits, PRs, files), the level picked, why each higher level does not work, and the change, including the rows step 5 adds to or deletes from the enforcement table. Ask which classes to apply; edit `CLAUDE.md` / `AGENTS.md` only as approved here. `--dry-run` stops here.

## 4. Fix and prove

Fix the approved classes, most frequent first, one commit per class. Prove that each new type, lint, CI check or test fails on a real past mistake: revert the fix locally or rebuild the original case, watch the check fail, then restore it and watch it pass. Run the same command locally and in CI. Open the PR as `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/autonomy.sh" <repo>` says; the first word of its output is the mode: `strict` → `gh pr create --draft`, `ship` → `gh pr create`. Either way, leave merging to the user.

An exception to a new check goes on the offending line with a reason, an expiry date and the name of the human who approved it.

## 5. Keep the enforcement table

Keep a table in the repository's `CLAUDE.md` (or `AGENTS.md`) that pairs each rule with what enforces it: `architecture`, `type`, `lint`, `ci`, `test` or `prose-only`. When a rule's mistake can no longer happen, delete its prose line. When someone corrects an agent for a rule already in the table as `prose-only`, that is a repeat: fix it at the highest level in the same change.

**Reply:** each class with its evidence, the level picked and why no higher level worked, the proof that the check fails on the past mistake, and the PR link.

Adapted from pstack `correct` (github.com/cursor/plugins, MIT).
