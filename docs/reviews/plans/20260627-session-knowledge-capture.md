# Review Report: 20260627-session-knowledge-capture (Plan)

## Metadata
- **Target**: plan / 20260627-session-knowledge-capture
- **Content-Type**: plan
- **Perspectives**: plan (content_type), maint (auto-applied)
- **Reviewed**: 2026-06-27
- **Input Files**:
  - `/Users/naoki/src/github.com/naoking158/custom-slash-command/docs/plans/features/20260627-session-knowledge-capture.md`
  - Cross-referenced spec: `/Users/naoki/src/github.com/naoking158/custom-slash-command/docs/specs/20260627-session-knowledge-capture.md`
  - Cross-referenced spec review: `/Users/naoki/src/github.com/naoking158/custom-slash-command/docs/reviews/specs/20260627-session-knowledge-capture.md`
  - Existing assets: `commands/my/*.md`, `prompts/_shared/{roles,processes}/`, `README.md`
- **Reviewer Note**: Output path follows the `~/.prompts/10_pipeline.md` convention (`docs/reviews/plans/{id}.md`) per the orchestrator instructions, rather than the per-perspective subdir layout from `8_review.md`.

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| Plan Content (Structure / Feasibility / Completeness / Clarity / Risk) | WARNING | 0 Critical, 4 Medium, 4 Low |
| Maintainability | PASS | 0 Critical, 1 Medium, 2 Low |

**Overall Assessment**: NEEDS_REVISION

The plan is comprehensive and well-aligned with the spec: 4 phases ordered correctly (Foundation → Core → Integration → Testing), each spec AC mapped to a concrete test or verification step, file paths concrete and consistent with §3.4 of the spec, and the US-004 AC-002 invariant (no edits to `commands/my/change.md` / `agents/changer.md`) is enforced via §2.3, §4.2, §5.2, and §6 rollback. No Critical issues. However there are several Medium-severity gaps — most notably a bug in the redact.sh skeleton (the nested `apply` closure mutates the outer `count` correctly only by side effect of dynamic scoping, but the `apply` definition inside `mask` is fragile under `set -euo pipefail` and the per-pattern `count` is also miscounted as "patterns matched" rather than "tokens masked"), an AC count discrepancy (21 vs actual 20), and missing/under-specified items around bats availability, $ARGUMENTS parsing, and `transcript_path` source.

---

## Detailed Findings

### [plan] Plan Content Review

#### Passed

**Structure**
- 4 phases (Foundation → Core Logic → Integration → Testing) are ordered correctly and respect inter-phase dependencies (e.g., `redact.sh` exists before `12_retro.md` references it; `prompts/11_learn.md` exists before `commands/my/learn.md` references it via `~/.prompts/11_learn.md`).
- Each phase has explicit step IDs (1.1–1.4, 2.1–2.5, 3.1–3.4, 4.1–4.6) and per-step Verification checklists with concrete commands.
- Dependencies between tasks are stated either implicitly via ordering or explicitly in Step 4 fixtures (e.g., 4.3/4.4 depend on `redact.sh` from 2.1 and prompts from 2.3/2.4).
- Phase completion is captured by the §5.2 Post-Implementation checklist.

**Feasibility**
- Technical approach is specific per task: §3 Step 2.1 lists exact `sed -E` patterns, exit codes, and a full Skeleton; §3 Step 2.3/2.4 specify the inline bash snippets for `session_id` resolution and `since` parsing; integration tests (4.3/4.4) describe per-case behavior with environment overrides (`HOME=$BATS_TMPDIR`).
- External dependencies (§4.1) are pinned: `bash` (with explicit macOS bash3 caveat), `jq`, `bats-core` (optional fallback), `coreutils`. NFR-006 compliance (no Python/Node) is restated.
- Integration points with the existing codebase are identified: §4.2 lists `commands/my/change.md`, `agents/changer.md`, `prompts/6_change.md`, `prompts/_shared/*` as untouched dependencies; §3 Step 3.4 explicitly verifies the `/my:change` handoff string format against the existing change command.
- Technical risks are flagged: macOS bash3 / `date -v`, bats-absent environment, frontmatter parse failure (backup-then-recreate strategy), `redact.sh` missing (warn-and-continue).

**Completeness**
- Error handling is woven through each step (Steps 1.1, 2.1 exit codes, 4.3 invalid category fallback, 4.4 invalid arguments / missing redact.sh).
- Test implementation tasks (§3 Phase 4) cover unit (`tests/redact/`), integration (`tests/journal/`), and manual E2E (Step 4.5) — directly mapping to Spec §9.1/9.2/9.3.
- Rollback plan (§6) lists exact files to `git rm` and explicitly protects machine-local journal data from deletion.
- Acceptance criteria are mapped 1:1 to tests in §5.3 (US-001..US-005), with per-AC test name references.
- Target file paths are exhaustively enumerated in §2.1 (Files to Create), §2.2 (Files to Modify), §2.3 (Files to Delete).

**Clarity**
- Most step descriptions are specific enough (e.g., §3 Step 1.3 contains the literal `.gitignore.journal-template` content; §3 Step 2.1 has the full skeleton).
- Ambiguous phrasing is largely avoided. Where it appears, it is bounded (e.g., "shell driver fallback" in §4.1 is explicitly out-of-scope for CI).
- "What/where/how" structure: §2 tables (what + where), §3 step Details (how).

**Risk Management**
- Breaking changes section is effectively empty by design — all changes are additive. §2.3 explicitly states no deletions and pins the no-modification constraint on `commands/my/change.md` / `agents/changer.md`.
- Backward compatibility is preserved (no schema changes to existing assets).
- Performance impact: §3 Step 2.1 enforces NFR-006 (no Python/Node) and uses `sed -E` multi-pass which is bounded by file size.
- Incremental deployment: the rollback procedure shows each artifact is independently removable.

**Spec ↔ Plan Cross-check (preserved invariants)**
- US-003 invariant ("never create `docs/journal/`") is restated 4+ times across §1.3, §2.3, §3 Step 1.1, §5.2, and is verifiable via `grep -r "docs/journal" .`.
- US-004 AC-002 (`/my:change` untouched) is enforced via §2.3 (no deletions), §3 Step 3.4 (verify diff), §4.2 (internal dependency table), §5.2 (`git diff` check), and §6 Rollback step 5.
- §3.4 path policy (`~/.claude/projects/<repo>/memory/journal/` only) is referenced in every prompt step (2.3, 2.4) and asserted at runtime in the bash snippet (`case "$target" in "$PWD"/*) exit 1`).
- NFR-006 (bash + jq only) is reasserted in §1.3, §3 Step 2.1, §4.1.

#### Warnings

- **[W001]** Bug-prone redact.sh skeleton: `apply` defined as nested function inside `mask`, with side-effecting `count` on outer scope.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` lines 235–256 (Step 2.1 Skeleton)
  - **Severity**: Medium
  - **Issue**: (1) Bash function definitions are not lexically scoped — defining `apply` inside `mask` makes `apply` a global function after `mask` is first invoked, leaking out of scope. With `set -euo pipefail`, this works but is brittle. (2) The semantics of `count` are wrong vs the stated stderr contract: the contract says `patterns=<sk:0,ghp:0,aws:0,home:1,env:0,deny:0>` (per-pattern counts), but the skeleton increments `count` by 1 per *pattern that fired*, not per *token masked*. The integration test fixture in Step 4.4 ("fixtures のうち 1 件に sk- を埋め込むと、その候補は `excluded` として出力から消える") only requires exit 2, so this hides at the integration level — but the per-pattern stderr breakdown the spec promises (Step 2.1 line 216) cannot be produced by the current skeleton. (3) Inside `apply`, the `txt="$(printf '%s' "$txt" | sed -E "$1")"` strips trailing newlines from the file — multi-line inputs will lose their final newline, affecting body section parsing downstream.
  - **Impact**: Either the stderr contract is unimplementable from this skeleton, or the implementer will write code that diverges from the verification step (`stderr の matched=N が 0 / 非 0 で適切に切り替わる`). Final-newline loss on multi-line piped journal text may corrupt subsequent retro parsing.
  - **Recommendation**: Either (a) downgrade the stderr contract to just `matched=<N>` (drop the per-pattern breakdown), or (b) replace the skeleton with a per-pattern-counting loop that uses `grep -cE` before each `sed -E`. Also add `printf '%s\n' "$txt"` (or use `cat <<<` with care) to preserve trailing newlines, and pull `apply` out as a top-level function for clarity.

- **[W002]** Acceptance Criteria count mismatch (21 vs 20).
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` line 728 ("§5.3 に全 21 個の AC (US-001: 5, US-002: 6, US-003: 3, US-004: 3, US-005: 3 — spec 確認) が列挙される")
  - **Severity**: Medium
  - **Issue**: The arithmetic in the parenthetical adds to 5+6+3+3+3 = 20, but the leading sentence says "全 21 個". Spec inspection confirms 20 ACs (US-001 has 5, US-002 has 6, US-003 has 3, US-004 has 3, US-005 has 3). §5.3 itself enumerates 20.
  - **Impact**: Verification checklist in §4.6 has an off-by-one assertion that will appear to fail or invite confusion.
  - **Recommendation**: Change "全 21 個" → "全 20 個" in §3 Step 4.6 Details / Verification.

- **[W003]** `transcript_path` is referenced as a Bash variable but its provenance is undocumented for the slash-command context.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` lines 401–406 (Step 2.3 `resolve_sid` bash snippet)
  - **Severity**: Medium
  - **Issue**: The plan reuses Spec §3.1 step 1's wording verbatim. Spec §3.1 says "`transcript_path` 環境変数 (もしくはツール経由で渡される `transcript_path` 値)" — i.e., the variable may not be exported as an env var; it may only be available via a Claude Code hook payload. The bash snippet `[[ -n "${transcript_path:-}" && -f "$transcript_path" ]]` only works if Claude Code exposes it via env. In the current MVP (no hook integration, manual `/my:learn`), there is no documented mechanism that exports `transcript_path` to the shell.
  - **Impact**: Step 4.3 integration test "session_id 取得不能 → `mv-YYYYMMDD-HHMMSS` 命名にフォールバック" may pass trivially because `transcript_path` is never set in practice — making fallback path #2 untested.
  - **Recommendation**: Either (a) drop transcript_path from the resolution chain for MVP and document the simplification, or (b) add an explicit step (in `prompts/11_learn.md`) instructing Claude to set `transcript_path` from the conversation tool context before calling the bash block.

- **[W004]** Missing explicit step for marking `scripts/redact.sh` executable in the build flow.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` Step 2.1 (Create), §5.2 (Verification only)
  - **Severity**: Medium
  - **Issue**: The Verification in Step 2.1 line 267 includes `chmod +x scripts/redact.sh` inline, and §5.2 line 767 checks `test -x scripts/redact.sh`, but no implementation step *commits* the executable bit. On git, file mode changes need to be staged with `git update-index --chmod=+x` or `git add` after `chmod`. If the implementer runs `chmod +x` only locally without staging the mode, the next clone will not have the bit set and `/my:retro` will fail with "permission denied".
  - **Impact**: After clone or CI checkout, `scripts/redact.sh` will not be executable, breaking US-002 AC-006 (redaction enforced before output) by triggering Edge case #7 (script "missing") on every run.
  - **Recommendation**: Add to Step 2.1 Details: "After creation, run `chmod +x scripts/redact.sh && git add --chmod=+x scripts/redact.sh` to ensure the executable bit is tracked in git."

- **[W005]** Step 4.6 §5.3 trace lacks individual checks for some spec ACs.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` §5.3, lines 775–805
  - **Severity**: Low
  - **Issue**: US-002 AC-002 ("--since options 7d/30d/YYYY-MM-DD") is mapped to a single test `since filters correctly`. Spec mentions three input shapes; the plan's Step 4.4 test cases cover only `--since 1d` (and `--since invalid` for error path). The other 2 formats (`30d`, explicit `YYYY-MM-DD`) are not exercised. Similarly, US-002 AC-002 default ("省略時は直近 14 日") is not verified.
  - **Impact**: The implementer could pass `since filters correctly` while accepting only `Nd` form; the YYYY-MM-DD branch in `parse_since` (Step 2.4 line 460) would not be regression-protected.
  - **Recommendation**: Expand Step 4.4 to add (a) `--since 2026-06-01` (date-form), (b) default-omit, (c) `--since 30d`.

- **[W006]** No explicit "tests run successfully without bats" fallback test for CI-less environments.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` Step 4.1 line 643, §4.1 (Dependencies table)
  - **Severity**: Low
  - **Issue**: The plan mentions a shell-driver fallback "if bats is unavailable" but doesn't include the driver script as a deliverable in §2.1, and there's no step to author it. §4.1 marks `bats-core` as "optional", but absent a fallback, the test suite is effectively bats-only.
  - **Impact**: Anyone without bats will be unable to verify the plan's verification commands, weakening the test strategy.
  - **Recommendation**: Either (a) commit `bats-core` as required and remove the fallback mention, or (b) add a Step 4.x to author the shell-driver fallback (e.g., `tests/run.sh` that sources the .bats files with a minimal shim).

- **[W007]** `<arguments>` parsing details for `/my:learn` and `/my:retro` are not specified.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` Step 2.3 lines 429–431, Step 2.4 lines 482–484, Step 3.1, Step 3.2
  - **Severity**: Low
  - **Issue**: The plan describes `--category`, `--confidence`, `--since`, `--min-recurrence` flags but does not document how `$ARGUMENTS` (the slash-command convention used by existing commands like `commands/my/research.md`) is parsed into those flags. Existing commands use `$ARGUMENTS` as a single string; flag extraction inside the prompt is implicit. Without explicit guidance, implementers may either parse them in bash inside the prompt or expect Claude to parse them — those have very different behaviors.
  - **Impact**: Inconsistent argument handling between commands; tests in Step 4.3 (e.g., `--category mistake` → frontmatter `categories: [mistake]`) need a parser to assert behavior, but no parser implementation is defined.
  - **Recommendation**: Either reference an existing example (does any command in `commands/my/` parse flags from `$ARGUMENTS`?) or add an explicit "Step 2.x: argument parser" with a small bash function (e.g., `parse_args`) reused by both prompts. If LLM is supposed to parse, state that explicitly in the `<process>` block of each prompt.

- **[W008]** `parse_since` `date -v -Nd` requires BSD date and `date -d` requires GNU date — guard against neither working.
  - **Location**: `docs/plans/features/20260627-session-knowledge-capture.md` Step 2.4 lines 457–462
  - **Severity**: Low
  - **Issue**: The snippet tries BSD (`date -v`) first, then falls back to GNU (`date -d`) via `||`. If both fail (e.g., busybox `date`), `since_date` will be empty (not `ERR`), and the subsequent `[[ "$since_date" == "ERR" ]]` will not trigger.
  - **Impact**: On non-BSD/non-GNU systems, `--since 7d` may silently produce empty `since_date`, then downstream filtering compares against empty string — likely empty result with no error.
  - **Recommendation**: After the `||`, validate that `since_date` matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}$` and set to `ERR` if not.

#### Issues

(none — no Critical issues in plan content)

---

### [maint] Maintainability Review

#### Passed
- **Naming**: File paths use kebab-case consistently (`learn.md`, `retro.md`, `journal-entry-example.md`, `.gitignore.journal-template`). Function names in the bash skeleton are verb-leading (`resolve_sid`, `mask`, `apply`, `read_input`, `parse_since`, `extract_fm`).
- **Naming**: Spec-derived terminology is preserved across plan (`session_id`, `recurrence`, `redaction_status`, `categories`) — no renaming drift.
- **Consistency**: Step structure (`**File:**`, `**Action:**`, `**Details:**`, `**Verification:**`) is uniform across all 14 steps.
- **Consistency**: Error/exit code conventions are stable (0=clean, 1=error, 2=matches/warning).
- **Code Organization**: Plan is partitioned cleanly into 7 top-level sections (Overview, Affected Files, Implementation Steps, Dependencies, Verification, Rollback, Effort).
- **Comments**: Each Step includes a "why" (cross-reference to Spec §) — not just "what".

#### Warnings

- **[W101]** Mixed Japanese/English in identifiers and comments without consistent guideline.
  - **Location**: Throughout the plan, especially `docs/plans/features/20260627-session-knowledge-capture.md` Step 2.3 prompt content (English) vs surrounding plan prose (Japanese).
  - **Severity**: Medium
  - **Issue**: The plan body is mostly Japanese, but content authored *for the prompts* (e.g., the literal `prompts/_shared/roles/learn.md` text at lines 281–296) is English. This is fine, but mixed-language identifiers can confuse grep/search workflows (e.g., README example commands use mixed JA strings like `"TS catch は unknown 必須"` and `"ts-error-handling: enforce unknown in catch"`).
  - **Impact**: Low — minor readability friction.
  - **Recommendation**: Add a one-liner to §1.3 stating "Plan and source-tree content is bilingual: prompts/commands/README in English (per existing convention in this repo); planning prose in Japanese."

#### Issues

(none)

---

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| Medium | Fix redact.sh skeleton: either drop per-pattern stderr contract or rewrite counting loop; preserve trailing newlines | plan §3 Step 2.1 (lines 218–264) |
| Medium | Correct "21 ACs" → "20 ACs" | plan §3 Step 4.6 (line 728) |
| Medium | Clarify `transcript_path` provenance — drop from MVP or document how Claude sets it | plan §3 Step 2.3 (lines 401–406) |
| Medium | Add explicit step to make `redact.sh` executable in tracked git state | plan §3 Step 2.1, §5.2 |
| Low | Expand Step 4.4 to cover `--since 30d`, `--since 2026-06-01`, default-omit | plan §3 Step 4.4 (lines 685–702) |
| Low | Either remove bats-fallback mention or commit a shell-driver fallback script | plan §3 Step 4.1 (line 643), §4.1 |
| Low | Specify `$ARGUMENTS` → flag parsing strategy (LLM-side vs bash-side) | plan §3 Steps 2.3, 2.4, 3.1, 3.2 |
| Low | Guard `parse_since` against non-BSD/non-GNU `date` | plan §3 Step 2.4 (lines 457–462) |
| Low | Add bilingual content guideline | plan §1.3 |

---

## Next Steps

- Status: **NEEDS_REVISION** (4 Medium + 4 Low + 1 maint Medium, no Critical, no Issues).
- Address the 4 Medium warnings (W001, W002, W003, W004) before running `/my:do`; Low warnings can be batched or deferred to a Phase 1.5 polish pass.
- Re-review path: `/my:review plan:20260627-session-knowledge-capture` after revisions.
- The plan is otherwise ready: structure, traceability, and spec-cross-check are strong. No Critical regressions vs the spec.
