# Research: PdM Toolkit (PRD / Product Spec / Backlog / Catchup)

## 1. Overview

The user recently became a PdM. Extend this toolkit with skills that support
day-to-day product-management work, reusing the existing SDD machinery
(templates, review loop, learn/retro) where it fits.

## 2. Problem Statement

Three concrete pains, stated by the user:

1. **PRD 作成が大変** — drafting PRDs from scratch is slow; structure and
   quality vary.
2. **仕様策定・バックログ起票が大変** — turning a PRD into a functional spec
   and then into well-formed tickets (title / context / acceptance criteria)
   is repetitive manual work.
3. **Slack / Notion の情報洪水** — decisions, mentions, and meeting notes are
   scattered; catching up and not dropping action items is stressful.

Constraint from the user: do **not** route work through `/my:pipeline` or
subagents that override the session model. All new skills must run inline in
the main loop.

## 3. Assumptions

- Notion is the team's document source of truth (Notion MCP is configured);
  PRDs should ultimately live there, but drafting locally in markdown is
  acceptable and enables the `/my:review` loop and git history.
- The backlog destination is not yet known (Notion DB / GitHub Issues /
  Jira / Linear are all plausible at work) → must be configurable, not
  hard-coded. Resolved at first run by a setup wizard.
- The user works primarily in Japanese; PdM artifacts are written in Japanese.
- Ticket creation and Slack posting are outward-facing → always draft-first,
  create only after explicit user approval.

## 4. Codebase Findings

### 4.1 Affected Areas

| Area | Files / Modules | Notes |
|------|-----------------|-------|
| Plugin manifest | `.claude-plugin/plugin.json` | namespace `my`; no change needed (skills are discovered from `skills/`) |
| Skills | `skills/*/SKILL.md` (+ `template.md`) | one dir per skill; frontmatter = `description` + `argument-hint`; assets referenced via `${CLAUDE_SKILL_DIR}` |
| Review loop | `skills/review/SKILL.md`, `skills/review/checklists/*.md` | target table + checklist selection are the extension points for PRD / product-spec review |
| Install | `scripts/install.sh` | `~/.claude/skills/my` symlinks to the repo — **repo edits apply live**, no re-install needed |
| Machine-local data | `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/` | established home for per-machine state (journal); PdM config/state should follow this precedent |
| Docs conventions | `docs/research|specs|plans|reviews/` | `YYYYMMDD-{kebab}.md`; single-brace placeholders |

### 4.2 Existing Patterns & Reusable Components

- **Interactive entry skills** (research/debug/change) may ask up to 3
  clarifying questions; transform skills never ask and record Assumptions.
  PRD interviewing should follow the same spirit: bounded question rounds,
  `TBD` + Open Questions instead of interrogation.
- **Review skill** (`skills/review/SKILL.md`) resolves `type:{id}` targets to
  paths and loads per-type + per-perspective checklists. Adding `prd:` /
  `pspec:` targets plus two checklist files gives PdM docs the full
  review-report loop for free.
- **Severity scale and PASS/NEEDS_REVISION** are toolkit-wide; PdM checklists
  must reuse them.
- **learn/retro loop** applies unchanged — PdM-skill friction gets journaled
  the same way.

### 4.3 Environment inventory (MCP / plugins available to the skills)

| Capability | Provider | Availability |
|------------|----------|--------------|
| Notion read/write/search, meeting notes | `notion` MCP (HTTP, `https://mcp.notion.com/mcp`, user-level config) | interactive sessions; likely headless after one-time OAuth (needs verification) |
| Slack search/read/post, canvases | `claude_ai_Slack` connector (claude.ai-managed) | **interactive + cloud routines only** — not available to local cron/headless runs |
| Gmail / Google Calendar / Drive | claude.ai connectors (auth tools present) | same as Slack; optional enrichment for catchup |
| Web search | `gemini-grounded-search` MCP, `tavily` (via `modular-mcp`), `mgrep --web` | local, works headless |
| Notion-flavored writing conventions | `writing-notion` skill (company plugin) | invoke when publishing to Notion |
| Japanese doc quality | `japanese-tech-writing` skill (company plugin) | apply to PRD/spec prose |
| Humanizing outbound text | `rewriting-ai-text` skill (company plugin) | for announcements (out of MVP scope) |
| GitHub Issues | `gh` CLI | works everywhere |

`modular-mcp` wraps dev-oriented servers only (playwright, serena, context7,
tavily, …) — no Slack/Notion there.

## 5. Requirements Analysis

### 5.1 Functional Requirements

- [ ] FR-001: `/my:prd` — guided PRD creation: gather context (Slack thread /
      Notion page / free text) → bounded interview → draft from template →
      self-check → save to workspace → optional Notion publish.
- [ ] FR-002: `/my:product-spec` — PRD → functional spec: user flows,
      functional requirements with IDs, edge-case sweep, acceptance criteria
      (Given/When/Then), measurement requirements.
- [ ] FR-003: `/my:backlog` — PRD/spec → epic/story decomposition with
      acceptance criteria and estimates → review table → file tickets to the
      configured destination (Notion DB / GitHub Issues) only after approval.
      Also a `quick` mode for one-off tickets from a sentence or Slack thread.
- [ ] FR-004: `/my:catchup` — digest of Slack mentions/threads/priority
      channels + Notion updates/meeting notes since last run, grouped by
      required-action / discussions / FYI, with links and proposed next
      actions; persists last-run timestamp.
- [ ] FR-005: `/my:pdm-setup` — first-run wizard producing a machine-local
      config (workspace dir, backlog destination + property mapping, priority
      Slack channels, digest preferences). All PdM skills read it and route
      to setup when missing.
- [ ] FR-006: `/my:review prd:{id}` and `pspec:{id}` — checklist review of
      PdM docs via the existing review skill.
- [ ] FR-007: Scheduled catchup — documented recipes for (a) claude.ai cloud
      routine (full Slack+Notion), (b) local launchd/cron headless run
      (Notion-only, degraded), (c) manual morning habit.

### 5.2 Non-Functional Requirements

- [ ] NFR-001: No subagent/pipeline execution paths — skills run inline
      (user's model-override constraint).
- [ ] NFR-002: Graceful degradation — every MCP dependency is optional; a
      missing server shrinks the output and says so, never fails the skill.
- [ ] NFR-003: Outward-facing writes (tickets, Slack posts, Notion publishes)
      are draft-first and approval-gated.
- [ ] NFR-004: Config/state live under
      `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/`, never in a project
      tree (matches learn/retro precedent).

## 6. External Research

Scheduling options compared (all claims from cited sources):

| Option | Slack | Notion | Runs when laptop closed | Setup cost |
|--------|-------|--------|--------------------------|------------|
| claude.ai cloud routine (`/schedule`) | ✅ connectors supported | ✅ | ✅ Anthropic-managed | low — one interactive command |
| Claude Desktop scheduled tasks | ✅ local connectors | ✅ | ❌ | low |
| Local `claude -p` via launchd/cron | ❌ (connector absent headless) | ✅ likely (user-level HTTP MCP after one-time OAuth) | ❌ | medium — allowlist + auth upkeep |

- Scheduled tasks / routines and their connector behavior:
  https://code.claude.com/docs/en/scheduled-tasks — skills marked
  `disable-model-invocation: true` and MCP prompts don't auto-run in
  scheduled tasks; underlying MCP tools do work.
- Connectors (Notion, Slack, Gmail, Calendar) remain functional in Claude
  Code routines: https://github.com/anthropics/claude-code/issues/53489
- Headless OAuth requires one interactive authentication first:
  https://www.ksred.com/claude-code-as-an-mcp-server-an-interesting-capability-worth-understanding
- PdM-with-Claude-Code practice (PRD skills, Socratic questioning, daily
  digest slash commands, MCP-driven ticket filing):
  https://snyk.io/articles/7-claude-skills-product-managers/ ,
  https://ccforpms.com/advanced/write-prd ,
  https://www.prodmgmt.world/resources/claude-code ,
  https://www.sachinrekhi.com/p/claude-code-for-product-managers
  Recurring advice adopted: ground PRDs in real inputs (files/threads), keep
  templates local in markdown for speed and git history, ask structured
  clarifying questions before drafting, always human-review before filing.

## 7. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Slack connector absent in a given session (headless, or user not authed) | catchup loses half its input | Medium | NFR-002: skill states what was skipped; cloud routine recipe for full coverage |
| Backlog destination mis-write (wrong DB / repo) | tickets land in the wrong place | Low | setup wizard confirms destination with a test query; approval gate before every batch |
| Notion OAuth token expiry breaks headless runs silently | scheduled digest stops | Medium | headless script logs to a file and the doc says how to re-auth; cloud routine unaffected |
| Interview fatigue (too many questions before drafting) | user stops using `/my:prd` | Medium | max 2 question rounds; everything else becomes `TBD` + Open Questions |
| Checklist sprawl in review skill | review quality dilutes | Low | reuse existing severity scale; two focused checklists only |

## 8. Open Questions

- [ ] Q1: What is the actual backlog destination (Notion DB URL / GitHub repo
      / other)? → resolved interactively by `/my:pdm-setup`, not blocking.
- [ ] Q2: Which Slack channels are priority for the digest? → same.
- [ ] Q3: Does the Notion HTTP MCP work under `claude -p` on this machine
      (OAuth cache)? → verify once when first enabling the local scheduled
      variant; cloud routine is the primary recommendation either way.

## 9. Recommendations

Build five inline skills — `pdm-setup`, `prd`, `product-spec`, `backlog`,
`catchup` — plus review-loop integration (`prd:` / `pspec:` targets, two
checklists) and scheduling assets (headless wrapper + launchd template +
routine recipe). Reuse existing conventions throughout: template files next
to skills, `YYYYMMDD-{kebab}` naming, machine-local config under
`~/.claude/my-toolkit/pdm/`, approval gates on outward writes. Skip the
`docs/specs/` stage for this feature: the deliverables are themselves
documents, and the plan can carry the full design without loss.

## 10. Next Steps

- [ ] Proceed to `docs/plans/features/20260711-pdm-toolkit.md`

---
**Size:** M
**Created:** 2026-07-11
**Status:** Approved
