# my — Claude Code SDD Toolkit

A Claude Code **plugin** implementing a Spec-Driven Development workflow
(Research → Spec → Plan → Do → Review), maintenance flows (debug / refactor /
change), a session-knowledge loop (learn / retro), and path-triggered
language rules.

## Skills

| Skill | Purpose | Output |
|-------|---------|--------|
| `/my:research` | Investigate requirements (codebase first, then external) | `docs/research/` |
| `/my:spec` | Specification from a research doc | `docs/specs/` |
| `/my:plan` | Implementation plan from a spec or analysis | `docs/plans/{type}/` |
| `/my:debug` | Reproduce-first bug analysis + auto fix plan | `docs/analysis/bugs/` + `docs/plans/fixes/` |
| `/my:refactor` | Refactoring analysis + plan (baseline tests first) | `docs/analysis/refactors/` + `docs/plans/refactors/` |
| `/my:change` | Change analysis + plan (minimal-diff changes) | `docs/analysis/changes/` + `docs/plans/changes/` |
| `/my:do` | Execute a plan, with real end-to-end verification | source code |
| `/my:review` | Checklist review of specs/plans/code/commits/PRs | `docs/reviews/{type}/` |
| `/my:pipeline` | Run the whole flow via isolated subagents | multiple `docs/` outputs |
| `/my:learn` | Capture a toolkit improvement signal to the machine-local journal | `~/.claude/my-toolkit/journal/` |
| `/my:retro` | Cluster signals, propose toolkit edits, apply approved ones | toolkit repo edits (approval-gated) |

Language rules (`skills/rules-{go,rails,react,typescript}/`) load
automatically when matching files are read — no invocation needed.

## Installation

```bash
git clone https://github.com/naoking158/custom-slash-command.git
cd custom-slash-command
./scripts/install.sh
```

The installer creates a single symlink and cleans up symlinks from the old
(pre-plugin) layout:

| Path | State |
|------|-------|
| `~/.claude/skills/my` → `<repo>` | created (skills-directory plugin, referenced in place — repo edits apply live) |
| `~/.prompts`, `~/.claude/commands`, `~/.claude/agents` | removed if they point into this repo (legacy layout) |

Restart Claude Code (or `/reload-plugins`) after installing. Verify with
`./scripts/install.sh --check`; remove with `--uninstall`. The installer
never overwrites real files or foreign symlinks (`--force` retargets a stray
symlink).

## Usage

### Feature flow

```bash
/my:research implement user authentication feature
/my:spec 20260705-user-auth
/my:plan 20260705-user-auth
/my:do 20260705-user-auth
/my:review code:20260705-user-auth
```

Size guidance: small, well-understood changes should go through `/my:change`
directly — `/my:research` will tell you so and stop.

### Maintenance flows

```bash
/my:debug login button not working     # reproduce → analyze → fix plan
/my:do 20260705-login-button-fix

/my:refactor auth-module               # baseline tests → analysis → plan
/my:do 20260705-auth-module

/my:change fix chat input width        # gap analysis → lean plan
/my:do 20260705-chat-input-width
```

### Pipeline

```bash
/my:pipeline "implement user authentication"              # research → spec → plan (reviewed)
/my:pipeline "新機能追加" --no-review                      # skip review cycles
/my:pipeline 20260705-user-auth --from spec --to plan     # resume mid-flow
/my:pipeline "ボタン改善" --flow change                    # change → do
/my:pipeline "payment" --from research --to do --no-review
```

| Option | Default | Description |
|--------|---------|-------------|
| `--flow` | `feature` | `feature` (research→spec→plan→do) / `change` (change→do) |
| `--from` / `--to` | feature: research→plan; change: change→do | step range |
| `--only <step>` | – | single step (exclusive with `--from`/`--to`) |
| `--review` / `--no-review` | review on | reviewer+fixer cycle per step (Critical/High findings are fixed) |

Each step runs in an isolated subagent; state passes only through files under
`docs/`.

### Review

```bash
/my:review spec:20260705-user-auth      # → docs/reviews/specs/20260705-user-auth.md
/my:review be:plan:20260705-user-auth   # → docs/reviews/plans/20260705-user-auth--be.md
/my:review code:20260705-user-auth      # reviews the diff for that work
/my:review commit:abc1234
/my:review pr:current
```

Perspectives: `fe:` `be:` `security:` `perf:` `doc:` `maint:`.
Severity scale (toolkit-wide): **Critical / High / Medium / Low**; the fixer
and pipeline act on Critical/High only. Assessment is PASS or NEEDS_REVISION.

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
             CLAUDE.md / SDD handoff) → propose diffs → apply approved →
             archive promoted signals, prune stale ones
```

```bash
/my:learn --category mistake --target skills/plan "baseline テストをまた飛ばした"
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
├── skills/                        # one directory per skill (SKILL.md + assets)
│   ├── research|spec|plan|debug|refactor|change/   # each with template.md
│   ├── do/  pipeline/  learn/
│   ├── review/                    # + template.md, checklists/
│   ├── retro/                     # + scripts/redact.sh, redact.denylist
│   └── rules-{go,rails,react,typescript}/          # SKILL.md index + references/
├── agents/                        # thin subagent shells (preload their skill)
├── hooks/hooks.json               # SessionEnd index + UserPromptSubmit correction capture
├── scripts/                       # install.sh, lib/, hooks/ (capture scripts)
├── tests/                         # bats: hooks / install / redact / toolkit
└── docs/                          # SDD artifacts of this repo itself
```

Design rules the repo follows:

- **One source of truth per phase**: all behavior lives in the skill's
  `SKILL.md`; agents are thin shells that preload the skill and define the
  return contract; templates/checklists sit next to their skill.
- **File-based handoff**: pipeline subagents receive paths + identifier,
  never content.
- **Naming**: outputs are `YYYYMMDD-{kebab-case-identifier}.md`; placeholders
  are single-brace `{id}`.
- Interactive entry skills (research/debug/refactor/change) may ask up to 3
  clarifying questions; forked/transform skills (spec/plan/review) never ask
  and record Assumptions instead.

## Development

```bash
bats -r tests/         # all suites
./scripts/install.sh --check
```

## License

MIT
