# Review Report: 20260627-session-knowledge-capture

## Metadata
- **Target**: spec / 20260627-session-knowledge-capture
- **Content-Type**: spec
- **Perspectives**: spec (content_type), maint (auto-applied)
- **Reviewed**: 2026-06-27
- **Input Files**:
  - `docs/specs/20260627-session-knowledge-capture.md`
  - Cross-referenced: `docs/research/20260627-session-knowledge-capture.md`
- **Reviewer Note**: Output path follows `~/.prompts/10_pipeline.md` convention (`docs/reviews/specs/{id}.md`) rather than the per-perspective subdir layout in `8_review.md`, as directed by the caller.

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| Spec Content (Completeness / Clarity / Correctness / Verifiability / Traceability) | WARNING | 2 Critical, 5 Medium, 3 Low |
| Maintainability | PASS | 0 Critical, 1 Medium, 2 Low |

**Overall Assessment**: NEEDS_REVISION

The spec is well-structured, faithfully implements the research design decisions (Q1/Q2/Q3/Q4/Q8 resolutions, two-layer raw vs promoted model, proposal-then-approval), and bounds MVP scope cleanly against Phase 2/3+. However, there are two **Critical** internal contradictions (path of the example file; `proposed` lifecycle state declared but unreachable in MVP) and several **Medium** ambiguities around `session_id` acquisition, `<repo>` normalization, and `recurrence` semantics that would block deterministic implementation without further clarification.

---

## Detailed Findings

### [spec] Spec Content Review

#### Passed
- **Completeness**: All required sections exist — Overview (§1), User Stories (§2), Interface (§3), Data Models (§4), System Flow (§5), Edge Cases (§6), Security (§7), Performance (§8), Testing (§9), Open Items (§10).
- **Completeness**: Each of the 5 user stories has explicit acceptance criteria (AC-001..AC-006) in checkbox form.
- **Completeness**: Scope table at §1.2 cleanly separates In Scope (MVP/Phase 1) from Out of Scope per phase.
- **Completeness**: Edge cases (§6) enumerate 15 scenarios with expected behavior + exit code mapping.
- **Completeness**: Constraints/assumptions documented (NFR-006 bash+jq only, MEMORY.md non-interference, Auto Memory coexistence).
- **Clarity**: Numerical NFRs are concrete (§8: `/my:learn` < 500ms, `/my:retro` < 5s for 100 entries, journal 1 entry < 8KB, cumulative < 50MB, redact.sh < 100ms, S/N ≥ 20%).
- **Clarity**: Category taxonomy enum (§4.3) is closed and exhaustively defined with example promotion targets.
- **Correctness (alignment with research)**: §1.2 / §1.3 explicitly cite Q1, Q2, Q4 resolutions; §10 carries forward unresolved Q3/Q5/Q6/Q7/Q9/Q10 with MVP-scope decisions; §3.4 path contract directly implements research §8.1 binding decision and Constraint 1.
- **Verifiability**: §9 Testing Strategy lists unit / integration / E2E / Phase-1-exit tests, each tied back to AC IDs or KPIs from research §8.4.
- **Traceability**: §1.3 References block lists Research Document, existing `commands/my/pipeline.md`, `commands/my/change.md`, `agents/changer.md`, and the prompt structural references.
- **Traceability**: Each design decision in the spec links to the originating Q-number (Q1/Q2/Q3/Q4/Q8) in research.

#### Warnings

- **[W001]** `<repo>` identifier normalization is deferred to plan phase but used as a binding path component throughout the spec.
  - **Location**: §3.1 step 2 (`<repo-sanitized>`), §3.4 table (`<repo>`), §10 last bullet
  - **Suggestion**: Pin the MVP rule in §3.4 (e.g., "MVP rule: `<repo> = basename $PWD`, no further sanitization") so AC-004 (US-001) and AC-002 (US-003) become testable against a deterministic path. The `<repo-sanitized>` / `<repo>` terminology drift (§3.1 uses one form, §3.4 the other) should also be unified.

- **[W002]** Recurrence semantics conflict between research intent and spec mechanics.
  - **Location**: §3.1 step 4 ("既存 entry なら `recurrence` を +1"), §4.1 (`recurrence: integer ≥ 1 同一テーマの出現回数`), §6 row 11 ("frontmatter の単純加算")
  - **Suggestion**: The schema doc says "同一テーマの出現回数" (theme recurrence) but the algorithm increments per `/my:learn` call against the same session file (write recurrence). Pick one model: either (a) keep simple per-call increment and rename the field's documented meaning to "capture count within session", or (b) keep theme semantics and add a dedupe step (e.g., compare `Learned` bullets). Without this disambiguation, `--min-recurrence` filter on `/my:retro` (§3.2 args) has undefined behavior.

- **[W003]** `session_id` acquisition mechanism is not concretely specified.
  - **Location**: §3.1 Behavior step 1 ("Claude Code の env / transcript_path から")
  - **Suggestion**: Name the actual environment variable / file location (e.g., `$CLAUDE_SESSION_ID`, or "parse from `transcript_path` filename"). This is referenced as the dedupe key (NFR-003) and as the filename component, so its source must be deterministic for AC-001 (US-001) to be testable.

- **[W004]** `proposed` lifecycle state is declared in schema and state diagram but is unreachable under MVP behavior.
  - **Location**: §4.1 (`status` enum includes `proposed`), §4.4 state diagram (`raw --> proposed: /my:retro が候補として抽出`), §3.2 Behavior (never writes back to journal), §2 US-004 AC-003 ("自動更新は行わない")
  - **Suggestion**: Either (a) mark `proposed` as "reserved for Phase 3, never written in MVP" in §4.1, or (b) add a step in §3.2 that flips entries to `proposed` when they appear in retro output. Currently the state diagram describes a transition that the implementation explicitly forbids, which fails Correctness ("No contradictions between requirements").

- **[W005]** AC-005 (US-001) says "5 body sections" but §4.1 defines 6 numbered body sections (5 required + 1 optional).
  - **Location**: §2 US-001 AC-005, §4.1 Body sections list ("順序固定, 全 5 セクション必須" — but items 1-6 are listed)
  - **Suggestion**: Either renumber §4.1 to make the optional 6th section unnumbered/lettered, or restate AC-005 as "5 required body sections (Suggested Actions is optional)". Same correction should propagate to §6 row 13 ("5 セクション全てが揃っていない").

- **[W006]** `redact.sh` "masked" vs "excluded" disposition rule is ambiguous.
  - **Location**: §3.3 (returns masked text + exit codes), §3.2 step 5 ("検出された候補は除外しつつ stderr に redacted count"), §6 row 8 ("該当候補は出力から除外")
  - **Suggestion**: Clarify: does `/my:retro` always exclude any candidate where `redact.sh` exits 2, or does it include the masked text when masking is "safe enough"? §4.2 RetroCandidate has `redaction_status: clean | masked | excluded`, implying `masked` is a valid output state, but §3.2 says "除外". Pin the rule (recommend: any exit 2 → `excluded` for MVP; downgrade to `masked` only when all matches are class L2 path replacements, in Phase 2).

- **[W007]** Performance requirement measurement methods are partly subjective ("手動計測").
  - **Location**: §8 table rows for `/my:learn`, `/my:retro`
  - **Suggestion**: Strengthen to a reproducible recipe (e.g., "`time bash -c '/my:learn ...'` measured 5 times, median < 500ms on M-series Mac, journal pre-populated with N=10 entries"). Optional for MVP but reduces interpretation risk.

#### Issues

- **[E001]** Direct contradiction between §1.2 (In Scope) and §3.4 + US-003 AC-001 on the location of the example file. **(Critical)**
  - **Location**: §1.2 row 5 lists "`docs/journal/EXAMPLE.md` (テンプレ例) と `.gitignore` テンプレ"; §3.4 path contract states "`docs/examples/journal-entry-example.md`"; §2 US-003 AC-001 explicitly says "`docs/journal/EXAMPLE.md` ではなく、`docs/examples/journal-entry-example.md`".
  - **Impact**: The In-Scope row directly contradicts the binding US-003 invariant (no `docs/journal/` directory at all). An implementer reading §1.2 in isolation would create the disallowed path. Violates the primary structural defense L1 of §7.3 and Correctness ("No contradictions between requirements").
  - **Recommendation**: Update §1.2 row to read `docs/examples/journal-entry-example.md` and `.gitignore.journal-template`. Add a one-line note next to it: "(repo 内 `docs/journal/` は作らない — US-003 invariant)."

- **[E002]** `proposed` status transition is contradictory between schema/state machine and implementation behavior. **(Critical)**
  - **Location**: §4.4 state diagram edge `raw --> proposed: /my:retro が候補として抽出`; vs §3.2 Behavior (no mutation), §2 US-004 AC-003 ("自動更新は行わない")
  - **Impact**: Either the state diagram is wrong, or `/my:retro` must be specified to write back. Implementers will pick one of two incompatible interpretations. Also affects testability: there is no AC that verifies the `raw → proposed` transition occurs, so any implementation passes vacuously.
  - **Recommendation**: For MVP, remove the `raw --> proposed` edge (or mark it dashed/labeled "Phase 3"). Replace `proposed` in §4.1 enum with a note that it is reserved. Keep `raw / promoted / archived` as the MVP-active set.

- **[E003]** Hook contract for "Auto Memory との共存" is asserted but the actual non-interference mechanism with MEMORY.md is not specified concretely. **(Medium)**
  - **Location**: §1.2 In-Scope last row ("Auto Memory との共存 (MEMORY.md 直接編集はしない)"), §6 row 15
  - **Impact**: §3.x never enumerates what `/my:learn` / `/my:retro` may or may not touch under `~/.claude/projects/<repo>/memory/`. Without an explicit allowlist, future maintainers could broaden the scope and start writing `MEMORY.md` (also under the same directory).
  - **Recommendation**: Add to §3.4 a one-line constraint: "Both commands write only under `~/.claude/projects/<repo>/memory/journal/`; `MEMORY.md` and any sibling files are read-only / untouched."

- **[E004]** `--min-recurrence` filter behavior is undefined when combined with the W002 ambiguity. **(Medium)**
  - **Location**: §3.2 Arguments table, §3.2 Behavior step 2
  - **Impact**: AC-002 of US-002 (the `--since` filter) is testable; `--min-recurrence` is not, because the meaning of `recurrence` itself is ambiguous (see W002). Edge case #9 only covers negative/non-numeric input, not zero or value-meaning.
  - **Recommendation**: After fixing W002, add an explicit example: "with `--min-recurrence 2`, an entry with frontmatter `recurrence: 1` is filtered out".

#### Other (Low)

- **[L001]** AC IDs reset per user story (AC-001..N within each US), making cross-story traceability harder.
  - **Location**: §2 (all user stories)
  - **Suggestion**: Optional — use composite IDs (e.g., `US-001-AC-001`) so test plans in §9 can cite them without ambiguity. §9.2 already uses constructions like "(AC-001/003)" which is currently ambiguous about which US.

- **[L002]** §1.2 row "Promotion 判定: 手動 (`/my:retro` レビューで人が選ぶ, Q3=(b))" — the parenthetical `Q3=(b)` is a useful traceability anchor; consider doing the same for the other rows (e.g., Q1 for the journal store row).
  - **Location**: §1.2
  - **Suggestion**: Add Q-anchors to In-Scope rows for completeness and traceability.

- **[L003]** §5 sequence diagrams use mixed Japanese and English participant names (`Claude as Claude Code (session)`, `Cmd`, `FS`). Fine, but the `FS` participant name differs across §5.1 (`~/.claude/projects/<repo>/memory/journal/`) and §5.2 (`journal store`).
  - **Location**: §5.1 / §5.2
  - **Suggestion**: Use the same `FS` label across diagrams for visual consistency.

---

### [maint] Maintainability Review

#### Passed
- **Naming**: Identifiers in the spec (e.g., `session_id`, `recurrence`, `categories`, `confidence`, `retro_candidate`, `redaction_status`) are descriptive, follow snake_case for fields and PascalCase for entities consistently.
- **Naming**: Boolean-like enums use semantically correct words (`raw / proposed / promoted / archived`, `clean / masked / excluded`) — no `isXxx` anti-patterns where unnecessary.
- **Comments / Prose**: Reasoning and "why" is captured in §1.1 Purpose and per-section rationale, not just "what". Citations to research Q-numbers explain decisions.
- **Readability**: Tables are consistent column-wise. Mermaid diagrams are kept short. Section nesting depth ≤ 3.
- **Code Organization**: Logical grouping is clean — schema (§4), flow (§5), edge cases (§6) are separated. No dead text / commented-out content.
- **Consistency**: Frontmatter field naming is consistent across §3.1 / §4.1 / §5. Argument tables use the same column layout in §3.1 and §3.2.

#### Warnings

- **[W101]** Terminology drift: `<repo>` vs `<repo-sanitized>` vs `<repo>` is used in different places. **(Medium)**
  - **Location**: §3.1 step 2 (`<repo-sanitized>`), §3.4 (`<repo>`), §3.2 step 1 (`<repo>`)
  - **Suggestion**: Pick one token (recommend `<repo>`) and define it once near §3.4, including the MVP normalization rule (`basename $PWD`). Mirrors W001.

#### Issues

- **[L101]** Markdown table in §4.1 uses pipe-escape `enum \`high \| medium \| low\`` which renders correctly but is visually noisy. **(Low)**
  - **Location**: §4.1 Frontmatter fields table
  - **Suggestion**: Consider extracting the enum descriptions into a small definition list below the table, leaving the table itself with just `enum` as the type.

- **[L102]** §10 Open Items mixes "decisions already taken (MVP scope-out)" and "decisions still to be made in plan phase" without visual separation. **(Low)**
  - **Location**: §10 bullets
  - **Suggestion**: Split into two subsections: "10.1 MVP scope-out (decided)" and "10.2 Deferred to plan phase". Currently `Q9` is marked as "実質 Yes" (decided) while the redact denylist is genuinely open — they should not share a flat bullet list.

---

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| Critical | Resolve example-file path contradiction (`docs/journal/EXAMPLE.md` vs `docs/examples/journal-entry-example.md`) — fix §1.2 row | §1.2 |
| Critical | Resolve `proposed` lifecycle state contradiction — either remove the transition in §4.4 or specify the write step in §3.2 | §3.2 / §4.1 / §4.4 |
| Medium | Pin `<repo>` normalization rule for MVP and unify `<repo-sanitized>` / `<repo>` usage | §3.1 / §3.4 / §10 |
| Medium | Define `recurrence` semantics (theme vs per-call) consistently across §3.1 / §4.1 / §6 row 11 | §3.1 / §4.1 / §6 |
| Medium | Specify concrete `session_id` source (env var name or transcript path parse) | §3.1 |
| Medium | Disambiguate `masked` vs `excluded` disposition rule in retro output | §3.2 / §3.3 / §4.2 / §6 |
| Medium | Reconcile "5 body sections" wording with §4.1's 6 numbered items | §2 US-001 AC-005 / §4.1 |
| Medium | Add explicit allowlist for files `/my:learn` / `/my:retro` may touch under `~/.claude/projects/<repo>/memory/` (MEMORY.md non-interference) | §3.4 |
| Medium | Define `--min-recurrence` filter behavior with a worked example (after recurrence semantics are fixed) | §3.2 |
| Low | Strengthen performance measurement methods beyond "手動計測" | §8 |
| Low | Use composite AC IDs (e.g., `US-001-AC-001`) for cross-document traceability | §2 / §9 |
| Low | Split §10 into "decided MVP scope-out" vs "deferred to plan" subsections | §10 |
| Low | Unify FS participant label across §5.1 / §5.2 sequence diagrams | §5 |

## Next Steps

- Address the 2 Critical issues (E001, E002) — these are blocking because they describe contradictory behavior the implementer cannot disambiguate without re-asking.
- Resolve the 5 Medium warnings/issues (W001-W007 subset, E003, E004) before kicking off `/my:plan` — they would otherwise become plan-phase rework or, worse, runtime ambiguity in tests.
- Low-priority items can be batched in a single editorial pass.

Recommended command:
- After revision: `/my:review spec:20260627-session-knowledge-capture` (re-review)
- Once PASS: `/my:plan 20260627-session-knowledge-capture`
