# Research: Improvement Loop Redesign — learn/retro v2

- **Date:** 2026-07-06
- **Status:** Implemented (same day)
- **Scope:** The toolkit's self-improvement mechanism (learn / retro / hooks)
- **Supersedes:** the learn/retro design in
  [20260627-session-knowledge-capture.md](20260627-session-knowledge-capture.md)

## 1. Why redesign

Empirical result after ~10 days of the v1 loop (shipped 2026-06-27):

1. **The loop never closed once.** Exactly one journal entry existed, and it
   was written to `~/.claude/projects/<encoded-full-path>/memory/journal/`
   (Claude followed its system-prompt memory directive), while `/my:retro`
   globbed `~/.claude/projects/$(basename $PWD)/memory/journal/` — a
   directory Claude Code never creates. Learn wrote where retro didn't read.
2. **Zero `.sessions.log` files** — the SessionEnd marker hook used the same
   wrong basename scheme (and only became active with the plugin install).
3. **Capture friction was fatal.** Manual `/my:learn` was invoked once in
   10 days; `/my:retro` never. The promotion path (copy a `cd … &&
   /my:change` line, run `/my:do`, hand-flip `status: promoted`) was four
   manual steps for a one-line markdown edit.
4. **v1 competed with native features.** The one real journal entry was
   *project* knowledge (Homebrew tap trust behavior) — exactly what native
   auto memory now stores automatically, per repo, auto-loaded.

## 2. What the ecosystem does (web survey, 2026-07)

Recurring patterns across mature setups (claude-reflect, ECC "instincts",
Every's compound-engineering plugin, MindStudio learnings-loop, Superpowers,
a-c-m's reflection.md; official docs and the skill-creator eval loop):

1. **Two-stage capture-then-review.** Cheap automatic capture (hooks,
   correction regex on UserPromptSubmit, transcript mining) strictly
   separated from approval-gated promotion into config. Nobody auto-writes
   CLAUDE.md.
2. **The transcript is the raw material.** `~/.claude/projects/*.jsonl`
   mining recurs everywhere; strongest signals are user corrections and
   repeated cross-session requests. ~30-day transcript retention pushes
   toward continuous capture or timely batch mining.
3. **A promotion ladder, not one file:** session note → journal →
   CLAUDE.md (only if needed every session) → skill (on-demand procedure) →
   path-scoped rule → hook (when it must be deterministic). Official docs
   codify this ladder.
4. **Pruning is half the loop** — dated entries, dedup, decay, "would
   removing this cause mistakes?" test.
5. **Verify after promoting** — skill evals (official skill-creator
   benchmark mode), observe whether behavior actually shifts.

Native features (verified against official docs, 2026-07-06) that absorb
v1's territory:

- **Auto memory** (v2.1.59+, default on): per-repo `MEMORY.md` index
  (200 lines / 25KB auto-loaded) + topic files; plain markdown, user-editable.
- **`/insights`**: monthly session analysis with friction points and
  CLAUDE.md suggestions. **`/recap`** / session summaries.
- **Skills hot-reload** and official encouragement for Claude to author and
  edit its own skills.
- **Hooks**: `transcript_path`, `session_id`, `cwd` on all events. Caveat:
  SessionEnd default timeout is **1.5s** and plugin hooks cannot raise it —
  plugin-side SessionEnd work must be a single cheap command.

Defensible niche for a custom system: deterministic capture, structured
queryable journals, own cadence — and specifically for this repo,
**improvement of the distributed toolkit itself**, which no native feature
covers (auto memory improves a project's memory, not a plugin's prompts).

## 3. Decisions (binding)

| # | Decision |
|---|----------|
| D1 | **Scope the journal to toolkit signals only.** Project knowledge routes to native auto memory; `/my:learn`'s first step is that routing decision. |
| D2 | **One global store**: `~/.claude/my-toolkit/` (override `$MY_TOOLKIT_DATA`). Signals target the toolkit, so per-project stores were wrong. No basename/encoded-path guessing anywhere. |
| D3 | **Automatic capture via two hooks**: SessionEnd appends a session index line (`sessions.jsonl` — jq one-liner, safe under the 1.5s budget); UserPromptSubmit regex-captures correction-looking prompts (JP/EN) to `corrections.jsonl`. Both always exit 0. Logic lives in `scripts/hooks/*.sh` for bats coverage. |
| D4 | **`/my:learn` is model-invocable** (v1 was `disable-model-invocation: true`): Claude may capture a signal when the user corrects toolkit-driven behavior. Capture friction was the v1 killer. |
| D5 | **`/my:retro` applies approved edits directly** instead of emitting `cd … && /my:change` handoff lines. Skill/rule edits are small markdown changes; skills hot-reload makes them live immediately. The SDD change flow remains the escalation path for structural changes. Approval gate, redact-before-write, tests-on-script-changes, and the no-cwd-guessing rule are retained. |
| D6 | **Retro does the bookkeeping** (v1 required manual `status: promoted` flips): promoted/rejected entries move to `journal/archive/`, consumed corrections to `corrections.archive.jsonl`, and raw entries older than 60 days are proposed for archiving (pruning). |
| D7 | **Simplified schema**: one file per signal, frontmatter `date / session_id / project / target / category / status`; categories `mistake | gap | friction | pattern | question`; only `## Signal` is mandatory. Dropped: `recurrence` (retro counts clustered signals instead), `confidence`, `source_commits`, `tags`, the 5 mandatory body sections. |
| D8 | Toolkit repo resolution gains plugin-runtime priorities: `$CLAUDE_TOOLKIT_REPO` > `$CLAUDE_PLUGIN_ROOT` / `$CLAUDE_SKILL_DIR`-derived > `~/.claude/skills/my` symlink > abort. |

## 4. Out of scope / future

- **SessionStart injection** of top signals (claude-mem pattern): skipped —
  auto memory already injects project context; toolkit signals only matter
  at retro time.
- **Skill evals** (official skill-creator benchmark pattern) for this repo's
  skills: worth adopting once a skill accumulates repeated mistake-signals;
  retro can propose it as a rung.
- **`/insights` integration**: retro asks the user to paste relevant
  friction points; no programmatic access exists.
- Migration of v1 entries: the single existing entry is project knowledge —
  leave it to auto memory; no migration tooling needed.

## 5. References

- Community: github.com/BayramAnnakov/claude-reflect, github.com/affaan-m/ecc,
  every.to compound-engineering, mindstudio.ai learnings-loop,
  github.com/obra/superpowers, martinalderson.com self-improving-claude-md,
  gist a-c-m/reflection.md
- Official: code.claude.com/docs/en/{memory,best-practices,hooks,hooks-guide,
  skills,plugins,commands}, anthropic.com/engineering/equipping-agents-for-
  the-real-world-with-agent-skills, claude.com/blog/improving-skill-creator-
  test-measure-and-refine-agent-skills
