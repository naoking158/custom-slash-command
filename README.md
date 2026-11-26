# my — personal Claude Code toolkit

A Claude Code **plugin** for working with autonomous agents: a review skill
with a diff review screen, an independent verifier agent, code-reading skills
(how / why / blast-radius), a generator for app verification skills, a guard
hook for pushes and outbound text, PdM skills, a session-knowledge loop
(learn / retro), working principles, and path-triggered language rules.
The same repository also loads in Google Antigravity as a plugin (see
[Antigravity](#antigravity)).

## Skills

| Skill | Purpose | Output |
|-------|---------|--------|
| `/my:autopilot` | Work toward a goal unattended: small PRs, each verified, AI-reviewed and fixed; merged on green in ship mode, stacked as drafts otherwise | PRs + `~/.local/state/autopilot/` log |
| `/my:review` | Checklist review of specs/plans/code/commits/PRs/PRDs | `docs/reviews/{type}/` |
| `/my:how` | Explain how part of a codebase works before changing it | answer with file references |
| `/my:why` | Explain why code is the way it is, from the commit and PR record | answer with citations |
| `/my:blast-radius` | Find what a change could break outside its diff, and prove it safe by running code | report |
| `/my:create-verification-skill` | Generate a `verify-<app>` skill that launches an app and drives it like a user | `.claude/skills/verify-<app>/` |
| `/my:learn` | Capture a toolkit improvement signal to the machine-local journal | `~/.claude/my-toolkit/journal/` |
| `/my:retro` | Cluster signals, propose toolkit edits, apply approved ones | toolkit repo edits (approval-gated) |
| `/my:pdm-setup` | One-time config for the PdM skills (workspace, backlog destination, channels) | `~/.claude/my-toolkit/pdm/config.md` |
| `/my:prd` | PRD from Slack/Notion context + bounded interview, self-checked | `{workspace}/docs/prd/` |
| `/my:product-spec` | PRD → 機能仕様 (edge-case sweep, Given/When/Then AC) | `{workspace}/docs/product-specs/` |
| `/my:backlog` | Spec/PRD → tickets; approval-gated filing to Notion DB / GitHub Issues | tickets + `{workspace}/docs/backlog/` |
| `/my:catchup` | Slack + Notion digest since last run (mentions, decisions, meeting action items) | `{workspace}/docs/catchup/` |

Language rules (`skills/rules-{go,rails,react,typescript}/`) load
automatically when matching files are read — no invocation needed.

## Agents

| Agent | Role |
|-------|------|
| `my:reviewer` | Runs `/my:review` in an isolated context |
| `my:diff-reviewer` | Plan-blind first pass of a two-pass diff review |
| `my:verifier` | Independent judge: runs the repo's `verify-<app>` skill against a checkout and returns PASS / FAIL / BLOCKED with evidence; never edits code |

## Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| `PreToolUse` | `outbound-guard.sh` | Denies force-pushes and pushes to the default branch; in strict repos also non-draft PRs, marking a PR ready and merging; blocks local paths, review IDs and untracked `docs/` paths in commit messages, PR/issue text and Notion writes |
| `SessionEnd` | `session-end.sh` | Appends a session index for `/my:retro` |
| `UserPromptSubmit` | `prompt-capture.sh` | Queues corrections for `/my:retro` |

These are Claude Code hooks (`hooks/hooks.json`). Antigravity reads the root
`hooks.json` instead, which runs `outbound-guard.sh` on `run_command` through
`antigravity-guard.sh`.

## Autonomy modes

Every repository is **strict** unless the machine-local
`~/.claude/my-toolkit/autonomy.conf` opts it into **ship** with a line
`ship <owner/name glob>`. Strict keeps PRs as drafts for a human to land;
ship lets the agent open normal PRs and merge them once CI is green.
`scripts/lib/autonomy.sh <dir>` prints a checkout's mode. The config stays
off the repository so it never names private repositories.

### Setup for `/my:autopilot`

1. Opt repositories into ship mode (skip for strict-only use):

   ```bash
   echo 'ship <your-github-user>/*' >> ~/.claude/my-toolkit/autonomy.conf
   ```

2. Allow the commands an unattended run needs, so it does not stall on a
   permission prompt. Put them in a **local, uncommitted** settings file:
   `~/.claude/settings.local.json` (every repository) or a repository's
   `.claude/settings.local.json` (that repository only). Never put them in a
   committed `.claude/settings.json`: that would let the agent merge PRs for
   everyone who clones the repository.

   ```json
   {
     "permissions": {
       "allow": [
         "Bash(gh pr create *)",
         "Bash(gh pr merge *)",
         "Bash(gh run list *)",
         "Bash(gh run watch *)",
         "Bash(gh run view *)",
         "Bash(git worktree *)"
       ]
     }
   }
   ```

   These allows are safe in strict repositories only because
   `outbound-guard.sh` still denies merges and non-draft PRs there. With the
   allows at the user level, keep the plugin's hooks enabled.

3. Give the repository a `verify-<app>` skill (`/my:create-verification-skill`)
   on its default branch, so each task can be verified in the real app.
   Without one, autopilot records every task as unverified.

## Rules

`rules/*.md` are working principles that apply in every session. Plugins
cannot ship rules, so `install.sh` links each file into `~/.claude/rules/`,
except the two Antigravity-only files:

- `rules/AGENTS.md` is a symlink to `principles.md`. Antigravity loads a
  plugin's `rules/AGENTS.md` as an always-on rule. The principles themselves
  carry no frontmatter, because Claude Code stops loading a rule whose
  frontmatter has no `paths`.
- `rules/antigravity.md` tells Antigravity how to read the Claude Code terms in
  the skills (`${CLAUDE_SKILL_DIR}`, `$ARGUMENTS`, tool names, agent launches).

## Installation

```bash
git clone https://github.com/naoking158/custom-slash-command.git
cd custom-slash-command
./scripts/install.sh
```

The installer creates these symlinks and cleans up symlinks from the old
(pre-plugin) layout:

| Path | State |
|------|-------|
| `~/.claude/skills/my` → `<repo>` | created (skills-directory plugin, referenced in place — repo edits apply live) |
| `~/.gemini/config/plugins/my` → `<repo>` | created (Antigravity plugin, referenced in place) |
| `~/.claude/rules/<f>.md` → `<repo>/rules/<f>.md` | created, one per rules file except `AGENTS.md` and `antigravity.md` |
| `~/.prompts`, `~/.claude/commands`, `~/.claude/agents` | removed if they point into this repo (legacy layout) |

Restart Claude Code (or `/reload-plugins`) and start a new Antigravity
conversation after installing. Verify with
`./scripts/install.sh --check`; remove with `--uninstall`. The installer
never overwrites real files or foreign symlinks (`--force` retargets a stray
symlink).

## Antigravity

The repository is also an Antigravity plugin: `.antigravity-plugin/plugin.json`
names it `my`, so the skills keep their `my:<skill>` names. `install.sh` links
it into `~/.gemini/config/plugins/`.

| Part | In Antigravity |
|------|----------------|
| Skills | Load from `skills/`; `rules/antigravity.md` maps the Claude Code terms |
| `rules/principles.md` | Always on, through `rules/AGENTS.md` |
| Outbound guard | Root `hooks.json` → `antigravity-guard.sh` on `run_command`. The guard's `ask` becomes `force_ask`; the Notion write check is not wired |
| Agents | Hidden (`mainAgent: false`, `subagent: false`): their tool lists use Claude Code tool names. With `orca` on PATH, a step that launches one runs it as an Orca worker through `orca/bin/run-role` (see [Orca](#orca)). Without `orca`, or when run-role exits 3 (Orca unreachable, or not in an Orca terminal), verifier and reviewer run in the same conversation with the result marked `非隔離`, and diff-reviewer is skipped (see the next row). `rules/antigravity.md` gives the handling of the other exit codes, including a timeout (4) |
| `/my:autopilot`, `/my:retro` | Not supported: they depend on Claude Code agents, background commands, or transcripts |
| Two-pass diff review | With Orca, the plan-blind first pass runs as a separate `diff-reviewer` worker. Without Orca, the first pass is skipped and the review runs in one pass |
| `SessionEnd` / `UserPromptSubmit` capture | Not wired: Antigravity has no matching event |

This setup follows the Antigravity docs and has not been run in Antigravity yet.
To check it:

```bash
agy plugin validate ~/.gemini/config/plugins/my
agy plugin list        # my should be enabled, with my:* skills
```

## Orca

`orca/` runs roles in their own context through [Orca](https://orca.dev)
orchestration workers. Nothing here is needed without an `orca` command;
`install.sh` only checks that `orca/bin/doctor` is executable when `orca` is on
PATH.

- `orca/bin/doctor`: run from an Orca terminal; checks that Orca is reachable
  and that both guards deny a push to `main`.
- `orca/bin/run-role <verifier|reviewer|diff-reviewer> --out <file> [--cwd <workspace>] -- <inputs>`:
  starts the role as a worker with the body of `agents/<name>.md`, waits for it
  from the shell, checks the result file, and releases the worker. Exit codes:
  0 result OK, 1 worker failed or bad result, 2 configuration error, 3 Orca
  unusable, 4 timed out (worker stopped). `rules/antigravity.md` is its only
  caller; Claude Code keeps using subagents.
- `orca/profiles/<name>.conf`: the harness and model per role, one
  `<role> <harness> <model>` line each. run-role reads the `verify` line for
  `verifier` and the `review` line for `reviewer` and `diff-reviewer`.
- A profile must be selected on any machine with `orca` on PATH: set
  `MY_ORCA_PROFILE`, or write a `profile <name>` line in
  `~/.claude/my-toolkit/orca.conf`. Without one, run-role exits 2 and
  Antigravity stops at every step that launches an agent.

## Usage

### PdM flow

```bash
/my:pdm-setup                          # 初回のみ: workspace / 起票先 / チャンネル
/my:catchup                            # 朝: 前回以降の Slack+Notion ダイジェスト
/my:prd "価格アラート機能"              # PRD ドラフト (インタビュー → 自己チェック)
/my:review prd:20260711-price-alert    # PRD checklist review
/my:product-spec 20260711-price-alert  # 機能仕様 (エッジケース網羅 + AC)
/my:review pspec:20260711-price-alert
/my:backlog 20260711-price-alert       # 分解 → 承認 → 起票 (Notion/GitHub)
/my:backlog quick "CSV出力が文字化けする" # 単発起票
```

PdM artifacts live in a dedicated workspace directory (configured by
`/my:pdm-setup`) so `prd:`/`pspec:` review targets resolve when run from it.
Ticket filing and Notion publishing are always draft-first and
approval-gated. Scheduled digests: see `scripts/pdm/README.md`
(claude.ai cloud routine = full Slack+Notion; local launchd = Notion-only).

### Review

```bash
/my:review spec:20260705-user-auth      # → docs/reviews/specs/20260705-user-auth.md
/my:review be:plan:20260705-user-auth   # → docs/reviews/plans/20260705-user-auth--be.md
/my:review code:20260705-user-auth      # reviews the diff for that work
/my:review commit:abc1234
/my:review pr:current
/my:review code:20260705-user-auth --no-screen   # markdown only
```

Perspectives: `fe:` `be:` `security:` `perf:` `doc:` `maint:`.
Severity scale (toolkit-wide): **Critical / High / Medium / Low**; only
Critical/High gate the assessment. Assessment is PASS or NEEDS_REVISION.

**Diff targets** (`code:` / `commit:` / `pr:`) additionally produce
`{id}.html` — a self-contained review screen you open with `file://` — and
`{id}.json`, the data both it and the report are generated from. The screen
shows the diff grouped by intent in risk order, with an explanation per group;
you approve group by group, triage each finding as 採用 / 却下, comment on any
line, and then generate one Markdown to paste back into the session that wrote
the code. Approval state lives in `localStorage` and is discarded when the
diff changes.

When the target has something to be deferential to — a plan, a spec, a commit
message, a PR body — the review runs **two passes**: a subagent reviews the
diff blind to all of it, then the main pass reconciles those findings against
the plan. A first-pass finding can be downgraded or marked as intentional, but
never dropped; that is machine-checked. Without such context there is nothing
to defer to, so it runs a single pass.

`--no-screen` restores the markdown-only behavior. Doc targets are unchanged.
`{id}.html` and `{id}.json` are gitignored as regenerable build artifacts.

### Improvement loop (learn / retro)

The toolkit improves itself through a capture-then-promote loop. Capture is
cheap and automatic; promotion is deliberate and approval-gated.

**Division of labor with native features** — project knowledge (facts about
the codebase you're working in) belongs to Claude Code's native auto memory;
`/insights` covers monthly workflow retrospectives. This loop handles the one
thing native features don't: **evidence that this toolkit's own assets should
change**, promoted into real edits of this repo.

```
[hooks]      SessionEnd → session index; UserPromptSubmit → correction queue
[/my:learn]  explicit capture: "this my:* asset misbehaved / is missing X"
[/my:retro]  cluster → classify (skill edit / rule / new skill / hook /
             CLAUDE.md) → propose diffs → apply approved →
             archive promoted signals, prune stale ones
```

```bash
/my:learn --category mistake --target skills/review "Medium の指摘を落とした"
/my:retro                 # cluster + propose + apply (with approval)
/my:retro --dry-run       # report only
/my:retro --deep          # also mine transcripts before their ~30-day expiry
```

All captured data is machine-local under `~/.claude/my-toolkit/` (journal
entries, `sessions.jsonl`, `corrections.jsonl`) and never enters a project
tree. `/my:retro` resolves the toolkit repo via `$CLAUDE_TOOLKIT_REPO`,
plugin env vars, or the `~/.claude/skills/my` symlink — never the current
directory. Text promoted into the repo passes `redact.sh` first.

## Repository structure

```
custom-slash-command/
├── .claude-plugin/plugin.json     # plugin manifest (namespace "my")
├── .antigravity-plugin/plugin.json # Antigravity plugin manifest (name "my")
├── skills/                        # one directory per skill (SKILL.md + assets)
│   ├── review/                    # + template.md, checklists/, review-json.md,
│   │                              #   scripts/ (diff-hunks, build-screen, render-report),
│   │                              #   assets/review-screen.html
│   ├── autopilot/                 # + goal-template.md
│   ├── how/  why/  blast-radius/
│   ├── create-verification-skill/ # + references/
│   ├── prd|product-spec|backlog|catchup/           # PdM flow, each with template.md
│   ├── learn/  pdm-setup/
│   ├── retro/                     # + scripts/redact.sh, redact.denylist
│   └── rules-{go,rails,react,typescript}/          # SKILL.md index + references/
├── agents/                        # reviewer, diff-reviewer, verifier
├── rules/                         # working principles, linked into ~/.claude/rules/;
│                                  #   AGENTS.md, antigravity.md for Antigravity only
├── hooks/hooks.json               # PreToolUse guard, SessionEnd index, UserPromptSubmit capture
├── hooks.json                     # Antigravity: PreToolUse guard on run_command
├── orca/                          # bin/doctor, bin/run-role, profiles/ (work, private)
├── scripts/                       # install.sh, lib/, hooks/, pdm/ (scheduling)
├── tests/                         # bats: hooks / install / orca / redact / review-screen / toolkit
└── docs/                          # design notes and reviews of this repo itself
```

Design rules the repo follows:

- **One source of truth per skill**: all behavior lives in the skill's
  `SKILL.md`; agents are thin shells that preload the skill and define the
  return contract; templates/checklists sit next to their skill.
- **Naming**: outputs are `YYYYMMDD-{kebab-case-identifier}.md`; placeholders
  are single-brace `{id}`.
- Forked skills (review) never ask questions and record assumptions instead.
- Third-party content keeps its license notice in `THIRD_PARTY_NOTICES.md`.

## Development

```bash
bats -r tests/         # all suites
./scripts/install.sh --check
```

## License

MIT
