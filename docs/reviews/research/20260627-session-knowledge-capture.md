# Review Report: 20260627-session-knowledge-capture

## Metadata
- **Target**: research / 20260627-session-knowledge-capture
- **Content-Type**: research (no formal checklist; nearest applicable = doc + maint)
- **Perspectives**: maint (primary), doc (secondary)
- **Reviewed**: 2026-06-27
- **Input Files**: `docs/research/20260627-session-knowledge-capture.md`

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| Completeness (template coverage, technical investigation) | PASS | 0 |
| Clarity (language, terminology, structure) | PASS with minor WARN | 1 W |
| Options Analysis (trade-offs, recommendation) | PASS | 0 |
| Open Questions (explicit flagging) | PASS | 0 |
| Repo Specificity (custom-slash-command alignment) | WARN | 2 W |
| Risk & Mitigation (identification + countermeasures) | WARN | 2 W |
| Maintainability of the artifact itself | PASS with WARN | 2 W |
| Internal consistency (cross-references, schema fields) | ISSUE | 1 E |

**Counts**:
- Passed checklist items: 18
- Warnings: 7
- Issues: 1

**Overall Assessment**: NEEDS_REVISION (single low-impact internal inconsistency + several Medium suggestions; no Critical blockers)

## Detailed Findings

### [research] Research Content Review

#### Passed
- Section coverage matches `prompts/templates/research_template.md` 1:1 (Overview / Problem / Requirements / Stakeholders / Technical Investigation / Risks / Open Questions / Recommendations / Next Steps).
- Functional + Non-Functional requirements are split, numbered (FR-001..009, NFR-001..006), and each has a single, testable assertion.
- Stakeholder table includes the future-self / future-user perspective, which is appropriate for a distributed-asset repo.
- 5.1 cites concrete community precedents (`claude-mem`, `claude-improve`, MindStudio learnings loop, `self-improving-agent`, hookify) with what to borrow from each — strong precedent grounding.
- 5.2 options table evaluates 7 alternatives (A-G) with explicit pros/cons and an explicit recommendation per row, plus a recommended composition diagram.
- Risk table includes both Impact and Likelihood columns and a Mitigation column for every row — matches template.
- 10 open questions are flagged explicitly with `Q1..Q10`, each phrased as an actionable decision, and section 9 names which subset must be resolved before `/my:spec`.
- Recommendation includes a phased rollout (MVP → Phase 4) with verification criteria per phase — gives the spec writer a clear scoping anchor.
- Design philosophy section (8.4) is explicitly aligned with the repo's stated principles (markdown-only, proposal-then-approval, SDD-pipeline-integrated).

#### Warnings

- **[W001]** Schema field list in FR-002 is **inconsistent** with the schema in section 8.1.
  - **Location**: `docs/research/20260627-session-knowledge-capture.md:47-48` vs `:264-294`
  - **FR-002 fields**: `date / session_id / category / context / what_happened / lesson / suggested_action / confidence`
  - **8.1 frontmatter fields**: `session_id / date / project / categories / confidence / recurrence / status` + body sections `Request / Investigated / Learned / Completed / Next Steps / Suggested Actions`
  - **Severity**: Medium — downstream spec/plan author will have to guess which is canonical; readers cannot verify what NFR-003 (idempotency on session_id) implies because the field appears in both forms (`category` vs `categories`, `what_happened` vs `Investigated`, etc.).
  - **Suggestion**: Pick one canonical schema and have FR-002 reference section 8.1 by name (e.g. "the schema defined in 8.1") instead of restating a divergent field list.

- **[W002]** Q4 raises a foundational ambiguity that is **deferred** to spec rather than answered in research, but the artifact's title and Problem Statement both promise to improve "skills". Without resolving this, the spec phase will inherit scope drift.
  - **Location**: `:229-232` (Q4) and `:1` (title) / `:8` (problem statement).
  - **Severity**: Medium — the repo currently has no `skills/` directory (verified: `ls /Users/naoki/src/github.com/naoking158/custom-slash-command` shows `agents/ commands/ docs/ prompts/ rules/` only). Calling them "skills" risks confusing future readers vs. the Anthropic SKILL.md concept.
  - **Suggestion**: Either rename the target throughout to "improve commands/agents/prompts/rules" (the actual assets), or pre-decide in section 8 that `skills/` will be introduced. The current wording oscillates between both.

- **[W003]** No concrete success metric / KPI is defined. The "stakeholder needs" table lists outcomes (`同じ訂正を Claude に二度言わなくて済む`) but there is no measurable indicator (e.g. `# of duplicate corrections / week`, `# of journal entries promoted to rules/ per month`).
  - **Location**: `:91-99` and `:328-333`
  - **Severity**: Medium — Phase 1 verification criteria ("5 件 journal が溜まるか") is volume-based, not value-based. Without a value KPI the loop cannot tell "noise" from "signal".
  - **Suggestion**: Add a brief subsection (e.g. 8.5 "Success Signals") with 2-3 measurable indicators.

- **[W004]** The risk row "journal が肥大化して意味のないノイズで埋まる" is rated `Likelihood: High` but the proposed mitigations rely heavily on the user diligently running `/my:retro` and on a not-yet-specified "lesson が無いセッション" detection.
  - **Location**: `:206`
  - **Severity**: Medium — for a High-likelihood/High-impact risk, the mitigation is essentially "trust the human" + "TBD heuristic". This deserves either a concrete heuristic (e.g. `if transcript has no edits/corrections/git commits, skip`) or a downgraded likelihood with rationale.
  - **Suggestion**: Either (a) specify the noise-detection heuristic now, or (b) acknowledge the risk is partly accepted in MVP and re-evaluated in Phase 3.

- **[W005]** Privacy / secret-leakage risk (`:204`) is correctly flagged as High-impact but the mitigation "redaction チェック step を入れる" is vague. The repo's distribution model (GitHub public) makes this the single highest-stakes risk.
  - **Location**: `:204`
  - **Severity**: Medium — "redaction check" is hand-wavy. Concrete suggestions: list patterns (API keys, paths under `/Users/`, env values), name the script that will perform it, decide whether journal stays machine-local by default (recommended by Constraint 1 — make it a hard decision, not soft).
  - **Suggestion**: Promote Constraint 1's recommendation ("journal は `~/.claude/projects/...` に置く") to a binding decision in section 8.1 so the mitigation becomes structural (out-of-repo by design) rather than procedural.

- **[W006]** Reference to `claude-mem` Stop hook generating a 5-item summary (`:134`) implies an LLM call — but Constraint 5 (`:191-193`) explicitly forbids Python/Node deps and notes `claude -p` spawn as a "last resort". This tension is not resolved in 5.2 options A-G.
  - **Location**: `:134` vs `:191-193` vs Q2 at `:220-223`
  - **Severity**: Medium — Q2 acknowledges the question, but the options table doesn't surface `claude -p` as its own choice. A reader can't tell from 5.2 alone whether the recommended Option A includes LLM-based summarization or just timestamp+session_id skeleton.
  - **Suggestion**: Split Option A into A1 (skeleton-only fallback) and A2 (`claude -p` summarization), or annotate Option A with the Q2 trade-off so the recommendation is self-contained.

- **[W007]** Mermaid-style architecture diagram in 5.2 (`:163-173`) uses arrows (`→`, `↓`) but mixes them inconsistently (some `→`, some `↓`), and the flow `[change flow] → [SessionStart hook]` is conceptually a loop rather than a linear "next step". Reads as if SessionStart is the consequence of `change flow`, which is misleading.
  - **Location**: `:163-173`
  - **Severity**: Low — the prose around the diagram makes the intent clear, but the diagram itself misrepresents.
  - **Suggestion**: Add a closing arrow back to "next session" (or write `[SessionStart hook] → (次セッション)` as a separate loop closure), or convert to a numbered list.

#### Issues

- **[E001]** Internal cross-reference inconsistency: the journal directory layout is described **three different ways** across the document.
  - **Location**:
    - FR-003 at `:54`: `docs/journal/YYYY-MM-DD-{session}.md` **or** `~/.claude/projects/<repo>/memory/`
    - Constraint 1 at `:178-183`: recommends `~/.claude/projects/<repo>/memory/journal/`, suggests `.gitignore` for `docs/journal/`
    - Section 8.1 at `:256`: recommended path `~/.claude/projects/<repo>/memory/journal/YYYY-MM-DD-{session_id}.md`, plus `docs/journal/EXAMPLE.md` for distribution
  - **Impact**: The downstream `specifier` agent will see three "canonical" answers in the same document and is likely to either pick the wrong one or ask the user. Open Question Q1 also re-opens this (`:216-219`) creating a fourth signal that this is unresolved — yet Section 9 lists Q1 in the "must decide before spec" set, implying it _is_ being resolved here.
  - **Recommendation**: Pick **one** path in section 8.1 (recommended: machine-local `~/.claude/projects/<repo>/memory/journal/`) and have FR-003, Constraint 1, and Q1 all explicitly defer to it ("Decision: see 8.1"). If Q1 is genuinely undecided, remove it from the section 9 "must decide" list and acknowledge the spec phase will branch on it.

### [maint] Maintainability Review (applied to the document itself)

#### Passed
- Naming of sections is consistent and follows the research_template ordering.
- Identifiers (FR-NNN, NFR-NNN, Q1-Q10) use a stable scheme that downstream artifacts can reference.
- Markdown structure (headings, tables, lists) renders cleanly; no broken syntax.
- Japanese / English code-switching is intentional and consistent (Japanese for narrative, English for identifiers/code/paths) — matches the rest of the repo's prompts.
- File path references use absolute or repo-relative paths, never bare names.
- Document length (360 lines) is proportionate to scope; no obvious filler.
- Tables use the same column ordering as the template.
- Status footer (`**Status:** Draft`) follows the template.

#### Warnings

- **[W008]** Some prose lines exceed comfortable reading width (Japanese soft-wrapped at irregular columns 60-80). Not strictly a bug but harms diff-readability when later phases edit the file.
  - **Location**: throughout, e.g. `:5-8`, `:36-39`
  - **Severity**: Low
  - **Suggestion**: Normalize wrap target (e.g. 80 cols) on next revision; mostly a polish item.

- **[W009]** Section 5.1 community-research table cites versions/behaviors of community projects (`claude-mem`, `claude-improve`) without dated source URLs. Future maintainers cannot verify the "9-signal taxonomy" claim or check if upstream changed.
  - **Location**: `:132-138`
  - **Severity**: Low
  - **Suggestion**: Add a footnote or links column. Even commit hashes / dates would help.

#### Issues
(none)

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| Critical (High) | _none — no blocking issues_ | — |
| Medium | [E001] Reconcile journal-path inconsistency across FR-003 / Constraint 1 / 8.1 / Q1 — pick one canonical and have others reference it | `:54`, `:178-183`, `:256`, `:216-219` |
| Medium | [W001] Reconcile schema fields in FR-002 with section 8.1 (or have FR-002 defer) | `:47-48` vs `:264-294` |
| Medium | [W002] Resolve "skill" terminology vs actual asset directories (commands/agents/prompts/rules) | `:1`, `:8`, `:229-232` |
| Medium | [W003] Add 2-3 measurable success signals beyond volume | `:91-99`, `:328-333` |
| Medium | [W004] Tighten "journal noise" mitigation with a concrete heuristic | `:206` |
| Medium | [W005] Promote Constraint 1's machine-local recommendation to a binding decision; make redaction concrete | `:204`, `:178-183` |
| Medium | [W006] Surface `claude -p` LLM-summarization as an explicit sub-option in 5.2 (or fold into Q2 resolution) | `:134`, `:191-193`, `:220-223` |
| Low | [W007] Fix architecture diagram direction inconsistencies / close the loop visually | `:163-173` |
| Low | [W008] Normalize line-wrap width for diff stability | throughout |
| Low | [W009] Add source links/dates to community-precedent table | `:132-138` |

## Next Steps

- **Overall Assessment**: NEEDS_REVISION
- Address Medium-priority items above before proceeding to `/my:spec`. The single Issue (E001) and the Medium Warnings (W001-W006) all concern decisions that the `specifier` agent will need; resolving them in research keeps the spec phase from re-litigating them.
- Low-priority items (W007-W009) are polish — defer if time-bound.
- After revision: `/my:review research:20260627-session-knowledge-capture` to re-confirm.
- When PASS: continue with `/my:spec 20260627-session-knowledge-capture`.
