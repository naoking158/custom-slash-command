---
name: maintain-verification-skill
description: Periodic pass that keeps a repository's verify-<app> skill and feature map accurate — parallel source check per feature, single live verification run, and at most one PR of proven doc/harness fixes. Use for /my:maintain-verification-skill, "audit the verify skill", or when verify-<app> has drifted (verifyスキルの点検, 検証スキルの保守).
argument-hint: "[<repo path>]"
disable-model-invocation: true
---

# Maintain a verification skill

A feature map goes stale the moment the app changes. This is the upkeep pass for a `verify-<app>` skill made by `/my:create-verification-skill` (or any verification skill with a feature map). The unit of rigor is the feature: every feature file gets a source check and a live drive, without proving every sentence.

## Outcomes

End with exactly one, and say which:

- **clean**: every feature got source and live coverage and nothing needs fixing. No branch, no PR.
- **changed**: one PR of proven corrections to the verification skill.
- **blocked**: coverage did not finish, or a proven fix could not ship safely. Name what blocked it.

## Edit scope

Edit only the target `verify-<app>/` directory: its `SKILL.md`, `features/`, and the helper scripts it ships. Never edit product code. When the app no longer does what the map says, decide which it is:

- the map is wrong: **doc drift**, fix the map;
- the app is wrong: **product regression**, report it and leave the map saying what the app should do. Rewriting the map to match a bug hides the bug. When the repository keeps an autopilot `found.md`, offer the regression as a row for it.

## Pass

0. **Locate the target and the mode.** Look for `<repo>/.claude/skills/verify-*/`, then `~/.claude/skills/verify-*/`. Several candidates: ask which one. None: stop and point at `/my:create-verification-skill`; do not invent a target. Read the mode with `"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}/scripts/lib/autonomy.sh" <repo>` (`strict` or `ship`); step 6 needs it.

1. **Index hygiene.** Compare `features/README.md` with the `features/*.md` files that exist. Fix dead links, unlisted files, and duplicates. Lightweight; do not generate an inventory.

2. **Source wave.** Start one read-only `Explore` agent per feature file, all at once. Each reads the code (never the running app), edits nothing, and returns:
   - the feature as a user sees it;
   - the source entry points as `file:line`;
   - likely drift from the feature file, with citations, or `none`;
   - one live-verification recipe.

3. **Reconcile and sweep churn.** Check that every feature file has a returned summary. Merge overlapping recipes into as few app states as practical. Spot-check the cited drift; do not re-prove clean claims. Then list user-facing screens or commands added since the skill was last touched (`git log --stat <last commit touching verify-<app>/>..HEAD`) that the map lacks. Call one missing only with a concrete source path.

4. **Live pass.** Required even when the source looks clean. You drive, serially, following the skill's own Launch section (one long-lived instance for servers and UIs, a fresh session per drive for short-lived CLIs). Drive every feature at least once and hold three invariants the whole time:
   1. Run the doctor before the first drive, on every fresh session, and after any surprise. Where the doctor cannot see the failure (a stuck UI on a healthy process), reset to a known state or relaunch. A doctor failure caused by the skill's own text is drift: fix it within the edit scope and retry once, restarting only what the fix invalidated; a second failure makes the pass `blocked`.
   2. Evidence captured so far survives every cleanup. Check it at the skill's named location; do not assume.
   3. Clean up what each failed attempt left behind (processes, ports, scratch data) before the next one. On a shared instance, clean the residue, never the instance.

   A feature you cannot reach is `verified-unreachable` only with the concrete prerequisite (auth, permission, OS, external state) and the route you tried. A prerequisite the map does not mention is drift. Tear down after the last drive, re-proofs from step 5 included.

5. **Triage.** Fix only:
   - **doc drift**: a wrong or missing user-POV description in the map or `SKILL.md`;
   - **harness gap**: the app works but the skill's recipe or script cannot drive it. A fixed or new script is executable and its invocation is shown in the skill body. Drive it live again before it ships.

   A **product regression** goes in the report, not in this PR.

6. **Ship or stop.** `changed`: re-read every changed file, then open one PR that touches only `verify-<app>/` (`gh pr create --draft` when the mode is `strict`). `clean` or `blocked`: no PR.

Keep run notes (features covered, unreachable prerequisites, confirmed drift, outcome) under `${TMPDIR:-/tmp}`; never commit them.

**Reply:** the outcome, per feature the source and live coverage (`ok`, `drift fixed`, `verified-unreachable: <prerequisite>`, `regression`), the product regressions found, and the PR link when `changed`.

Adapted from pstack `maintain-verification-skill` (github.com/cursor/plugins, MIT).
