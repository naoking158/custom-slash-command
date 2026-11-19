---
description: Generate a verification skill (verify-<app>) that launches an app and drives it the way a user does, so agents can prove behavior with evidence. Use for /my:create-verification-skill, "make a verify skill for this repo", or when a project has no scripted way to prove UI, CLI, or service behavior.
argument-hint: "[<repo path>] [--personal]"
disable-model-invocation: true
---

# Create a verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as a skill tailored to the repo. Write it for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

**Where it goes.** A team repository's skill belongs in `<repo>/.claude/skills/verify-<app>/`, but adding it there is a team change. With `--personal`, or when the repo has no such skill yet and the team has not agreed to one, write it to `~/.claude/skills/verify-<app>/`, prove it, and propose it to the team as a draft PR afterwards.

## 1. Interview the repo, not the user

Answer these from the codebase; ask the user only what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI, an API, a mobile app, a library? Pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's documented dev command (package scripts, Makefile, README). Note ports, env vars, seed data, auth, and the upstream services it needs (and whether those run locally or are shared development instances).
- **Drive:** how can an agent interact with it programmatically? Existing harnesses first: Playwright specs and their login helpers, scripts, curl-able or grpcurl-able endpoints. Then a generic recipe: `playwright-cli` for web, a tmux session for CLI, plain HTTP for services.
- **Observe:** what evidence can be captured? Screenshots, ARIA snapshots, terminal transcripts, response bodies, logs, exit codes, DB state.
- **Isolate:** can two instances run side by side (ports, data dirs, profiles)? Does verification write to a shared database? If isolation is impossible, say so in the generated skill and restrict writes to dedicated test users or fixtures.

If the checkout doesn't build or start as-is, fix that first or report it precisely; a skill written against a broken base teaches wrong steps.

## 2. Generate the skill

Write `verify-<app>/SKILL.md` with YAML frontmatter (`name: verify-<app>` and a `description` that names the app, the surface, and when to reach for it) and these sections, each grounded in what the interview found, with no placeholders left:

- **Launch:** the exact commands that start the app for verification and how to tell it is ready. Ready means usable, not just that a process answers: a page renders real data, an RPC returns a row. Include teardown.
- **Doctor:** one read-only check that answers "is this instance worth driving?": processes up, ports owned by this run, right build, credentials and sessions valid. Run it first whenever anything looks off.
- **Drive:** the harness recipe with real selectors and commands from this repo. Prefer stable handles (ARIA roles and names, data attributes, route paths) over coordinates and DOM position.
- **Evidence:** what to capture and where it goes. Exercise the real user path, not internal setters or test-only endpoints. Capture the action and the resulting state, not just the final screen. Verify side effects (rows written, messages sent) alongside what is visible. Use mocks only where a production boundary already isolates the external system.
- **Cleanup:** tear down what this run started. Never kill by process name. Never delete shared data the run did not create. Cleanup removes instances and scratch state, never the evidence, which survives in a location the skill names.
- **Helpers:** any script the skill ships is executable and its invocation is shown in the skill body.

## 3. Seed the feature map

Create `verify-<app>/features/README.md` plus one file per user-facing feature (the top 3 to 5 to start, from routes, commands, menus, or docs). Follow [`references/feature-map-example/`](references/feature-map-example/): a README index, and per feature an H1, one paragraph, and the four H2s `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>`, and `Gotchas`. If test data lacks a precondition a journey needs, the journey reports a failure and the reason goes in `Gotchas`. Never weaken the journey to make it pass.

## 4. Prove the generated skill before handing it over

Run its own instructions end to end once: launch, doctor, drive ONE mapped feature, capture evidence, clean up. After cleanup, confirm the evidence still exists at the named location. Fix what fails, and run the cleanup after every failed attempt so broken runs don't strand processes and ports. A generated skill that was never executed is a draft, not a deliverable.

When an agent cannot verify, record which of the three causes stopped it: it did not know how to start the app, it had no way to drive it, or it lacked test data. That tells the user what to provide next.

## 5. Keep it honest

When a feature changes, rerun its journey and update its file in the same change. A map entry that no longer matches the app is worse than none.

Adapted from pstack `create-verification-skill` (github.com/cursor/plugins, MIT).
