---
name: review
description: Review an artifact (spec, plan, code, commit, PR, PRD) against perspective checklists and write a review report. Use for any request to review, critique, or verify a document or a change — self-review and adversarial checks included — whether it is phrased in English or Japanese (レビュー, 検証).
argument-hint: "[perspective:]<target> [--no-screen]  e.g. code:user-auth, commit:abc1234, pr:current"
context: fork
agent: reviewer
---

# Review Phase

Review target: **$ARGUMENTS**

You are acting as a senior reviewer. Report every violation you find, each at
its honest severity, and nothing else — a review that lists 40 passed
checklist items and buries 2 real issues has failed. Filtering happens
downstream: only Critical/High gate the assessment.

## Severity scale (single source of truth for the toolkit)

| Severity | Meaning | Must be fixed before PASS |
|----------|---------|---------------------------|
| **Critical** | Security vulnerability, data loss, production-breaking | Yes |
| **High** | Blocking defect, missing requirement, broken contract | Yes |
| **Medium** | Should fix: perf concern, missing error handling, doc gap | No (reported only) |
| **Low** | Nice to have: style, minor optimization | No (reported only) |

Overall assessment: **PASS** (no Critical/High) | **NEEDS_REVISION**
(any Critical/High). Do not gate on Medium/Low counts.

## Step 1 — Resolve target and perspective

Perspective prefix (optional): `fe:` `be:` `security:` `perf:` `doc:` `maint:`

Target:

| Pattern | Source |
|---------|--------|
| `spec:{id}` | `docs/specs/{id}.md` |
| `plan:{id}` | search `docs/plans/*/{id}.md` |
| `prd:{id}` | `docs/prd/{id}.md` (run from the PdM workspace) |
| `pspec:{id}` | `docs/product-specs/{id}.md` (run from the PdM workspace) |
| `code:{id}` | **diff first**: `git -c core.quotepath=false diff` of the work done for `{id}` (uncommitted changes, or commits referencing `{id}`); fall back to the files listed in the plan's Affected Files only if no diff exists |
| `commit:{hash|range}` | `git -c core.quotepath=false show {hash}` / `… diff {range}` |
| `pr:{number|current}` | `gh pr diff {number}` (`current` → no argument) |
| `{id}` bare | auto-detect: spec → plan → code; if several exist, list them and require an explicit prefix |

`-c core.quotepath=false` keeps non-ASCII paths from being octal-escaped.
`gh pr diff` needs no equivalent — the GitHub API returns raw UTF-8 paths.

Target missing → error naming the exact paths checked and the command that
would create them, then stop.

`--no-screen` may appear anywhere in the arguments. It skips the two-pass
review, the JSON, and the HTML screen, leaving exactly the markdown-only
behavior. It is meaningful for `code:` / `commit:` / `pr:` only — on a doc
target, ignore it and report one line saying it applies to diff targets only.

## Step 2 — Select checklists

From `${CLAUDE_SKILL_DIR}/checklists/`:

1. Content-type checklist: `spec.md` for specs, `plan.md` for plans,
   `prd.md` for PRDs, `product-spec.md` for `pspec:` targets.
2. Perspective checklist, if a perspective was given (`fe.md`, `be.md`,
   `security.md`, `perf.md`, `doc.md`, `maint.md`). For code targets with no
   explicit perspective, pick by file type (frontend files → fe, server code →
   be, otherwise maint).
3. `maint.md` is added automatically unless the perspective is `security` or
   `perf`, or the target is a PdM doc (`prd:` / `pspec:`) — code
   maintainability items don't apply there.
4. `commit:` / `pr:` targets additionally load `commit.md` / `pr.md`.

Checklist items are tagged with their default severity. A checklist is a
lens, not a form: evaluate every item, but only violations appear in the
report. Skip items marked `[web]` when the project has no web/API surface.

### Check findings against what surrounds the diff

A diff alone hides fixes that live elsewhere. Before keeping a finding on a
diff target, check it here: in Pass 2, in a one-pass review, and with
`--no-screen`. Never hand any of this to the Pass 1 `diff-reviewer`; its
blindness is the point.

- `pr:` targets: read the base branch. When the base is another PR's branch
  (`gh pr view {number} --json baseRefName`), read that PR's diff too.
- Code the diff relies on but does not contain (a submodule, a vendored or
  generated copy, another repository): read the upstream default branch, not
  the pinned copy, and name the version you read in the finding.
- A finding the base or upstream already resolves: drop it in a one-pass or
  `--no-screen` review. In Pass 2 it stays, since Pass 1 findings are never
  deleted: lower it one step and say in `impact` where it is resolved.

## Step 3 — Diff targets: screen + two-pass

Applies to `code:` / `commit:` / `pr:` **without** `--no-screen`. Doc targets
and `--no-screen` skip straight to Step 4.

Scripts live in `${CLAUDE_SKILL_DIR}/scripts/`.

### 3.1 Save the diff

```bash
W="${TMPDIR:-/tmp}/my-review/{id}"; mkdir -p "$W"
```

Run the command from Step 1's table for this target kind and redirect it to
`$W/diff.patch`. Keep the exact command string — it becomes
`meta.target.diff_command`.

If that command exits non-zero (`gh` not authenticated, PR not found, no
network, bad hash), **stop there** and report the command and its stderr. Do
not report `レビュー対象の差分がありません`: that message means the diff was
retrieved and is empty, which has a different cause and a different fix.

### 3.2 Index it

```bash
"${CLAUDE_SKILL_DIR}/scripts/diff-hunks.sh" --diff "$W/diff.patch" --out "$W"
```

Exit 2 → report `レビュー対象の差分がありません` plus the exact command tried,
and stop without writing any output.

Then compute `meta.diff_sha`:

```bash
shasum -a 256 "$W/diff.patch" | cut -c1-12    # fallback: sha256sum
```

### 3.3 Decide the pass count

Look for context this review could be deferential to: a plan under
`docs/plans/*/{id}.md`, a spec at `docs/specs/{id}.md`, the commit message, or
the PR body.

**Context found → two passes.** Launch `diff-reviewer` with `Task`, passing
**only**: the path to `$W/diff.patch`, the path to `$W/hunks.tsv`, the
checklist paths from Step 2, and the output path `$W/pass1.json`. Never pass
the plan or spec — neither its path nor its content, and nothing that hints at
what it says. That barrier is the whole point of the first pass. Then read the
diff, the context, and `$W/pass1.json` yourself for Pass 2 and set
`meta.passes = 2`.

**No context → one pass.** Do the whole review yourself, set
`meta.passes = 1`, and omit `plan_check`.

Pass 2's obligations toward Pass 1:

- Never delete a Pass 1 finding. If the plan justifies it, set
  `plan_status: "justified"` and optionally drop the severity one step — but
  the finding stays.
- Add what only the plan reveals (unimplemented or deviated items) as
  `source_pass: 2` findings.
- Fill `plan_check[]`; every `missing` / `deviated` row needs a finding.
- Grouping, intent write-ups, and risk ranking are Pass 2's job either way.

### 3.4 Write `review.json`

Write `docs/reviews/{type}/{id}.json` following
`${CLAUDE_SKILL_DIR}/review-json.md`. That file is the contract; it is
machine-checked in the next step.

### 3.5 Build the screen

```bash
"${CLAUDE_SKILL_DIR}/scripts/build-screen.sh" \
  --diff "$W/diff.patch" --review docs/reviews/{type}/{id}.json \
  --out docs/reviews/{type}/{id}.html
```

Add `--pass1 "$W/pass1.json"` when `passes == 2`. If the HTML already exists,
report the path being overwritten on one line first.

- exit 3 → the JSON violates the contract. Fix the reported violations and
  retry **once**; if it still fails, stop and report.
- exit 4 → a Pass 1 finding was dropped. Restore the listed ids and redo
  Pass 2 **once**; if it still fails, stop and report.

### 3.6 Render the report

```bash
"${CLAUDE_SKILL_DIR}/scripts/render-report.sh" \
  --review docs/reviews/{type}/{id}.json --out docs/reviews/{type}/{id}.md
```

This replaces Step 4 for diff targets — do not hand-write the markdown as
well. With a perspective, all three outputs take the suffix:
`{id}--{perspective}.{md,json,html}`.

`{id}.json` and `{id}.html` are regenerable build artifacts and are
gitignored; `{id}.md` is the committed record.

## Step 4 — Write the report

For doc targets, and for diff targets run with `--no-screen`. (Diff targets
that went through Step 3 already have their report and skip this step.)

- Output: `docs/reviews/{type}/{id}.md`, where `{type}` ∈
  `specs | plans | code | commits | prs | research | changes | prd | product-specs`.
  With an explicit perspective: `docs/reviews/{type}/{id}--{perspective}.md`.
  (`commit:` targets use the short hash as `{id}`; `pr:` targets the number.)
- Structure: `${CLAUDE_SKILL_DIR}/template.md`.
- Every finding: severity, location (`file:line` where possible), impact, and
  a concrete recommendation.
- Doc targets produce no `.json` and no `.html`.

## Completion

Return / report:

- `output_path`
- Findings by severity: Critical {n} / High {n} / Medium {n} / Low {n} — with
  one-line summaries of every Critical/High finding inline
- `assessment`: PASS | NEEDS_REVISION
- `recommended`: the findings worth fixing now (every Critical/High, plus
  Medium/Low that are real and cheap to fix), and for each other finding a
  one-line reason to leave it. The user should not have to sort the list
  themselves.
- Diff targets that built a screen also return `screen_path` (an absolute
  `file://` URL), `json_path`, and `passes`. Tell the user to open the screen,
  work through it, and paste the generated Markdown back into the session
  where the work was done.
- Next step: NEEDS_REVISION → fix and re-review; PASS → proceed
  (implement from the document for doc reviews; commit and open a draft PR
  for code reviews). When the change is the user's own (their working tree,
  or a PR whose author is the `gh api user` login), the caller fixes the
  `recommended` findings and re-reviews without asking first; on someone
  else's PR, stop at the report.
