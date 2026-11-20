# Implementation Plan: 解説つき diff レビュー画面

## 1. Overview

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260725-diff-review-screen.md`

### 1.2 References

- Research: `docs/research/20260725-diff-review-screen.md`
- Existing skill under change: `skills/review/SKILL.md`, `skills/review/template.md`
- Precedent for skill-local scripts: `skills/retro/scripts/redact.sh`
- Precedent for a self-contained (non skill-preloading) agent: `agents/fixer.md`
- Test conventions: `tests/redact/test_redact.bats`, `tests/hooks/test_hooks.bats`

### 1.3 Implementation Strategy

Build the spec's 3-layer split bottom-up, so each layer is verifiable before
the next one depends on it:

1. **Extraction (deterministic shell)** — `diff-hunks.sh` turns a saved patch
   into `hunks.tsv` + `stats.json`. No git call, so fixtures drive the tests.
2. **Assembly (deterministic shell)** — `build-screen.sh` validates
   `review.json`, splices the payload into the template; `render-report.sh`
   renders the md. Both are tested against a *minimal stub template fixture*,
   so this phase does not wait on the real HTML.
3. **Presentation** — the single-file `review-screen.html` template.
4. **Integration** — `agents/diff-reviewer.md` (plan-blind Pass 1),
   `agents/reviewer.md` (+`Task`, +`screen_path`), `skills/review/SKILL.md`
   (`--no-screen`, diff-target branch), docs.

Two mechanics were empirically de-risked before writing this plan, on this
machine (jq 1.8.2, BWK awk 20200816, BSD sed, macOS 24.6):

- `jq -n --rawfile … | sed 's|</|<\\/|g'` over a 2.2 MB patch produced a
  2.3 MB payload whose largest line is ~2.3 MB; sed handled it in 0.02s with
  no truncation, and `</script` count in the output was 0.
- The awk marker splice (`getline line < payload_file`) handled that same
  2.3 MB single line in 0.05s, left 0 occurrences of the marker, and the
  extracted block re-parsed cleanly with `jq -e`.

**Assumptions** (resolved here; the spec left these open or unstated):

- **A-P1.** `bats` is **not installed on this machine** (`command -v bats`
  fails; not in nix profile or brew). `brew install bats-core` is a
  prerequisite (§4.1). Every non-test step below therefore also carries a
  bats-free verification command.
- **A-P2.** `agents/diff-reviewer.md` is **self-contained** — no `skills:`
  preload — following `agents/fixer.md`. Preloading `my:review` would inject
  plan/spec-aware instructions into Pass 1 and break AS-01's information
  barrier.
- **A-P3.** The `review.json` contract lives in a new
  `skills/review/review-json.md`, referenced from SKILL.md via
  `${CLAUDE_SKILL_DIR}/review-json.md`. This matches the existing
  `checklists/` + `template.md` precedent and keeps SKILL.md lean; inlining a
  30-row schema table into SKILL.md would double its length.
- **A-P4.** `diff_sha` is computed with `shasum -a 256 <file> | cut -c1-12`
  (present on macOS and most Linux), falling back to `sha256sum`.
  `build-screen.sh` re-computes it and emits a **warning** on mismatch rather
  than exit 3, because spec §3.2.3 fixes the exit-3 set to validations 1–6.
- **A-P5.** The hunk-numbering rule is implemented once in shell:
  `build-screen.sh` **invokes its sibling `diff-hunks.sh`** to derive the id
  set rather than re-parsing the patch. The template's JS is the only second
  implementation; both carry an identical `HUNK_RE:` marker comment and a
  bats test asserts the two marker strings are byte-identical.
- **A-P6.** The payload keeps the spec's exact 2-key shape (`{diff, review}`).
  Adding a third `hunks` key would have removed the JS/shell duplication but
  deviates from §3.4.2; the marker-string test in A-P5 covers the risk instead.
- **A-P7.** A repo-level `.gitignore` is added (this repo dogfoods
  `docs/reviews/`). Spec AS-06 phrases gitignore as optional; applying it here
  and documenting it in README is the concrete form of that recommendation.
- **A-P8.** Word-level intra-line highlighting visible in catnose's
  screenshot is **out of scope** — spec §5.3 specifies line-level `+`/`−`
  backgrounds only.
- **A-P9.** `groups[].caution` (spec §10 open item) is **not** added; 注意点
  stays inside `groups[].intent` as §4.1 specifies.
- **A-P10.** Hunk-header recognition uses the strict pattern
  `^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@`, not bare `^@@`, so a patch
  that itself contains diff text cannot inflate the count. On the spec's
  fixtures this is equal to `grep -c '^@@'` (spec §9's assertion still holds).
- **A-P11.** The skill runs git with `-c core.quotepath=false` so non-ASCII
  paths are not octal-escaped in the saved patch. `gh pr diff` (the `pr:`
  path) has no equivalent flag and needs none — it returns the GitHub API's
  diff, whose paths are already raw UTF-8. So the flag is git-only, not a
  universal precondition of `diff.patch`.
- **A-P12.** `render-report.sh` runs **after** `build-screen.sh`, so the md is
  only ever written from an already-validated JSON.
- **A-P13.** Tabs inside a hunk header's trailing function context are
  converted to single spaces before being written to the TSV `hunk_header`
  column, so the TSV stays 5-column.

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose |
|-----------|---------|
| `skills/review/scripts/diff-hunks.sh` | Layer 1: patch → `hunks.tsv` + `stats.json` (spec §3.2.2) |
| `skills/review/scripts/build-screen.sh` | Layer 3a: validate `review.json` + splice payload → HTML (spec §3.2.3) |
| `skills/review/scripts/render-report.sh` | Layer 3b: `review.json` → md matching `template.md` (spec §3.2.4) |
| `skills/review/assets/review-screen.html` | Single-file screen template, CSS+JS inlined (spec §5.3) |
| `skills/review/review-json.md` | `review.json` / `pass1.json` contract the reviewer writes against (A-P3) |
| `agents/diff-reviewer.md` | Plan-blind Pass 1 subagent (spec AS-01) |
| `tests/review-screen/test_review_screen.bats` | Single bats suite for all three scripts (spec §9) |
| `tests/review-screen/fixtures/*` | Patch + JSON + golden-md fixtures (enumerated in Step 1.1) |
| `.gitignore` | Ignore regenerable `docs/reviews/**/*.{html,json}` (A-P7) |

### 2.2 Files to Modify

| File Path | Changes Required |
|-----------|------------------|
| `skills/review/SKILL.md` | `argument-hint` += `[--no-screen]`; new Step 3.5 diff-target branch (save patch → hunks → Pass 1/2 → build → render); doc-target passthrough; error-recovery rules from spec §6 |
| `agents/reviewer.md` | `tools:` += `Task`; return contract += `screen_path`, `json_path`, `passes` |
| `README.md` | Review section: HTML screen, `--no-screen`, 2-pass behavior; repo-structure tree += `assets/`, `scripts/`, `tests/review-screen` |

### 2.3 Files to Delete

N/A: the change is purely additive plus three in-place edits.

---

## 3. Implementation Steps

### Phase 1: Foundation — deterministic extraction

#### Step 1.1: Test fixtures
**File:** `tests/review-screen/fixtures/` (new directory)
**Action:** Create

**Details:**

Patch fixtures (hand-written, small, with *known* expected stats):

- `simple.patch` — 3 files, 5 hunks, known insertions/deletions.
- `empty.patch` — 0 bytes.
- `special.patch` — one new file (`--- /dev/null`), one deleted file
  (`+++ /dev/null`), one rename (`rename from`/`rename to` + a hunk), one
  binary change (`Binary files a/logo.png and b/logo.png differ`).
- `script-tag.patch` — added lines containing `</script>`, `<!--`, `&`, `\`,
  and a `</script >` variant.

`gen-big-patch.sh <n> <out>` — emits a synthetic patch with exactly `n`
hunks. Used for the 1200-hunk width test and the 268-hunk perf measurement;
keeps large blobs out of git.

JSON fixtures (all reference hunk ids that exist in `simple.patch`):

- `review-valid.json` — 2 groups, 2 findings (one `plan_status:"justified"`,
  `source_pass:1`), `plan_check[]` present, `assessment:"NEEDS_REVISION"`.
- `review-empty-findings.json` — `findings: []`, `assessment:"PASS"`.
- `review-unreferenced-hunk.json` — one hunk in neither `groups[].hunks` nor
  `ungrouped_hunks`.
- `review-dup-hunk.json` — one hunk listed in two groups.
- `review-bad-group.json` — a finding whose `group` does not exist.
- `review-bad-hunk.json` — a finding whose `anchor.hunk` does not exist.
- `review-bad-severity.json` — `severity: "Blocker"`.
- `review-assessment-mismatch.json` — a Critical finding with
  `assessment:"PASS"`.
- `review-order-warn.json` — valid, but `groups` ordered Low → Critical.
- `pass1.json` — 2 findings, both ids present in `review-valid.json`.
- `pass1-missing.json` — adds a third finding id absent from
  `review-valid.json`.

Other:

- `template-min.html` — 6-line stub carrying only the
  `<script id="review-payload" …>` block and the `__MY_REVIEW_PAYLOAD__`
  marker, so Phase 2 does not depend on Phase 3 (A-P5/A-P6).
- `expected-report.md` — golden output of `render-report.sh` for
  `review-valid.json`.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
test ! -s tests/review-screen/fixtures/empty.patch && \
test "$(grep -c '^@@' tests/review-screen/fixtures/simple.patch)" = "5" && \
grep -q '</script>' tests/review-screen/fixtures/script-tag.patch && \
grep -q 'Binary files' tests/review-screen/fixtures/special.patch && \
grep -q 'rename from' tests/review-screen/fixtures/special.patch && \
for f in tests/review-screen/fixtures/*.json; do jq -e . "$f" >/dev/null || echo "BAD JSON: $f"; done && \
bash tests/review-screen/fixtures/gen-big-patch.sh 1200 /tmp/big.patch && \
test "$(grep -c '^@@' /tmp/big.patch)" = "1200" && echo OK
```

#### Step 1.2: `diff-hunks.sh`
**File:** `skills/review/scripts/diff-hunks.sh`
**Action:** Create

**Details:**

- `#!/usr/bin/env bash`, `set -euo pipefail`, header comment block in the
  style of `redact.sh` (purpose, usage, exit codes, dependency line
  "bash, awk, jq — no python/node").
- Args: `--diff <patch-file> --out <dir>`; anything else → exit 1 with a
  one-line usage on stderr. Unreadable patch → exit 1. `mkdir -p` the out dir.
- Carry the marker comment, byte-identical to the one the template will hold
  (A-P5):
  `# HUNK_RE: ^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@`
- Pass 1: `total=$(grep -cE '<HUNK_RE>' "$patch" || true)`. `total == 0` →
  exit 2 with `diff-hunks.sh: no hunks in <patch>` on stderr (covers the
  empty-patch and binary-only cases).
- `width = max(3, ${#total})`.
- Pass 2 (single `awk -v width=…`), maintaining:
  - `cur_new` from `+++ b/<path>` (strip the `b/` prefix); if the line is
    `+++ /dev/null`, fall back to the `--- a/<path>` value.
  - `rename_from` captured from `rename from <path>`, reset at each
    `^diff --git`.
  - On a `HUNK_RE` match: `n++`; `hunk_id = sprintf("h%0*d", width, n)`;
    parse `old_start` / `new_start` from the header; `gsub(/\t/, " ")` on the
    header text (A-P13); print the 5 TSV columns.
  - Counters: `files` += 1 per `^diff --git`; `insertions` += 1 per `^\+`
    excluding `^\+\+\+`; `deletions` += 1 per `^-` excluding `^---`.
- `stats.json` written with `jq -n --argjson …` so the numbers are real JSON
  numbers, keys in the spec's order: `files`, `hunks`, `insertions`,
  `deletions`.
- `chmod +x` the script.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
rm -rf /tmp/dh && bash skills/review/scripts/diff-hunks.sh \
  --diff tests/review-screen/fixtures/simple.patch --out /tmp/dh && \
test "$(wc -l < /tmp/dh/hunks.tsv | tr -d ' ')" = "$(grep -c '^@@' tests/review-screen/fixtures/simple.patch)" && \
test "$(head -1 /tmp/dh/hunks.tsv | cut -f1)" = "h001" && \
test "$(awk -F'\t' 'NF!=5' /tmp/dh/hunks.tsv | wc -l | tr -d ' ')" = "0" && \
jq -e '.files>0 and .hunks==5 and (.insertions|type=="number") and (.deletions|type=="number")' /tmp/dh/stats.json && \
bash skills/review/scripts/diff-hunks.sh --diff tests/review-screen/fixtures/empty.patch --out /tmp/dh2; test "$?" -eq 2 && \
bash skills/review/scripts/diff-hunks.sh --diff /tmp/big.patch --out /tmp/dh3 && \
test "$(head -1 /tmp/dh3/hunks.tsv | cut -f1)" = "h0001" && echo OK
```

#### Step 1.3: bats section for `diff-hunks.sh`
**File:** `tests/review-screen/test_review_screen.bats`
**Action:** Create

**Details:**

`setup()`/`teardown()` copied from `tests/redact/test_redact.bats`
(`REPO_ROOT` from `$BATS_TEST_DIRNAME/../..`, `FIXTURES`, `TMP` via
`mktemp -d -t review-screen-test.XXXXXX`). Add
`SCRIPTS="$REPO_ROOT/skills/review/scripts"`. Section comment banner
`# --- diff-hunks.sh -----` as in `test_hooks.bats`.

Tests (spec §9):

1. hunk count equals `grep -c '^@@' simple.patch`
2. ids run `h001`…, zero-padded to 3
3. `stats.json` matches the fixture's known `files`/`hunks`/`insertions`/`deletions`
4. empty patch → exit 2, stderr mentions `no hunks`
5. `special.patch`: new-file path comes from `+++ b/`, deleted-file path from
   `--- a/`, renamed path is the `b/` side, binary file contributes to
   `files` but produces no hunk row
6. 1200-hunk generated patch → ids are 4-digit (`h0001`, `h1200`)
7. missing `--diff` argument → exit 1
8. every TSV row has exactly 5 tab-separated columns

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
bats tests/review-screen/test_review_screen.bats
```

---

### Phase 2: Core — assembly scripts

#### Step 2.1: `build-screen.sh`
**File:** `skills/review/scripts/build-screen.sh`
**Action:** Create

**Details:**

- Same header/`set -euo pipefail` conventions.
  `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`.
- Args: `--diff <patch> --review <json> --out <html> [--template <html>]
  [--pass1 <json>]`. `--template` default:
  `${CLAUDE_SKILL_DIR:-$SCRIPT_DIR/..}/assets/review-screen.html`.
  Bad args / unreadable input → exit 1.
- **Hunk id set** — call `"$SCRIPT_DIR/diff-hunks.sh" --diff "$DIFF" --out
  "$WORK"` into a `mktemp -d` and read column 1 of `hunks.tsv` (A-P5). Its
  exit 2 (empty patch) propagates as exit 1 with
  `build-screen.sh: empty diff`.
- Collect violations into an array; print each on its own stderr line
  prefixed `build-screen.sh: `; exit with the highest applicable code.
- **Validations 1–6 → exit 3:**
  1. `jq -e` schema program asserting `schema_version == 1`; `meta` has
     `id`, `title`, `target`, `reviewed_at`, `checklists`, `passes`,
     `assessment`, `diff_sha`; `meta.passes` ∈ `[1,2]`; `meta.assessment` ∈
     `["PASS","NEEDS_REVISION"]`; top level has `stats`, `groups`,
     `ungrouped_hunks`, `findings`; every group has all 8 required keys;
     every finding has all 9 required keys including
     `anchor.{hunk,side,line,file,display}`.
  2. Coverage: the multiset `groups[].hunks + ungrouped_hunks` equals the id
     set from `hunks.tsv` **exactly once each**. Report unreferenced ids and
     duplicated ids separately, listing the ids (AC-006).
  3. `findings[].group` ∈ `groups[].id`.
  4. `findings[].anchor.hunk` ∈ the id set.
  5. `findings[].severity` ∈ `Critical|High|Medium|Low`; `groups[].risk` too.
  6. `assessment == "NEEDS_REVISION"` iff any finding is Critical or High.
- **Validation 7 → exit 4:** with `--pass1`, every `pass1.json`
  `findings[].id` must appear in `findings[].id`. Missing ids are listed on
  stderr (AC-008).
- **Warnings → stderr, exit unchanged:** `groups` not in descending risk
  order; a group with `intent_unclear: true` and zero findings;
  `meta.diff_sha` != first 12 chars of the recomputed SHA-256 (A-P4, using
  `shasum -a 256` with a `sha256sum` fallback).
- **Assembly** (only after validation passes):
  ```sh
  jq -n --rawfile diff "$DIFF" --slurpfile review "$REVIEW" \
     '{diff:$diff, review:$review[0]}' | sed 's|</|<\\/|g' > "$WORK/payload.json"
  awk -v pf="$WORK/payload.json" '
    /__MY_REVIEW_PAYLOAD__/ { while ((getline line < pf) > 0) print line; close(pf); next }
    { print }
  ' "$TEMPLATE" > "$OUT"
  ```
  A non-UTF-8 patch makes `jq --rawfile` fail → exit 1 with
  `build-screen.sh: non-UTF-8 diff (unsupported)` (spec §6).
- Final stdout line: `[review-screen] wrote: <abs-path> (<size>)` where size
  is `wc -c` humanized (e.g. `412KB`).
- `trap 'rm -rf "$WORK"' EXIT`; `chmod +x`.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
F=tests/review-screen/fixtures && \
bash skills/review/scripts/build-screen.sh --diff $F/simple.patch \
  --review $F/review-valid.json --out /tmp/s.html --template $F/template-min.html && \
test "$(grep -c '__MY_REVIEW_PAYLOAD__' /tmp/s.html)" = "0" && \
test "$(grep -c 'id="review-payload"' /tmp/s.html)" = "1" && \
awk '/<script id="review-payload"/{f=1;next} /^<\/script>/{f=0} f' /tmp/s.html \
  | jq -e '.review.schema_version==1 and (.diff|length)>0' && \
bash skills/review/scripts/build-screen.sh --diff $F/simple.patch --review $F/review-unreferenced-hunk.json --out /tmp/x.html --template $F/template-min.html; test "$?" -eq 3 && \
bash skills/review/scripts/build-screen.sh --diff $F/simple.patch --review $F/review-valid.json --pass1 $F/pass1-missing.json --out /tmp/x.html --template $F/template-min.html; test "$?" -eq 4 && \
bash skills/review/scripts/build-screen.sh --diff $F/script-tag.patch --review $F/review-valid.json --out /tmp/t.html --template $F/template-min.html 2>/dev/null; \
awk '/<script id="review-payload"/{f=1;next} /^<\/script>/{f=0} f' /tmp/t.html | grep -c '</script' | grep -qx 0 && echo OK
```
(The `script-tag.patch` leg needs its own `review-*.json` whose hunk ids
match that patch — add `review-script-tag.json` to the fixtures in Step 1.1
if `review-valid.json` does not cover it.)

#### Step 2.2: `render-report.sh`
**File:** `skills/review/scripts/render-report.sh`
**Action:** Create

**Details:**

- Args: `--review <json> --out <md>`; exit 0 / 1 only.
- Emits exactly the section structure of `skills/review/template.md`
  (AC-018): `# Review Report: {meta.id}`, `## Metadata`, `Checked:`,
  `## Findings` with `### Critical|High|Medium|Low` subsections,
  `## Action Items`, `## Overall Assessment`, `## Next Steps`.
- Metadata mapping: `Target` ← `meta.target.kind` / `meta.id`;
  `Content-Type` ← `"diff"`; `Perspectives` ← `meta.checklists` minus the
  content-type entries, or `none`; `Reviewed` ← `meta.reviewed_at`;
  `Input Files` ← `meta.target.diff_command` plus `meta.target.context_paths`.
  `Checked:` ← `meta.checklists` joined with `, `.
- Finding rendering: `- **[{id}]** {title}` /
  `- **Location**: {anchor.display} [{anchor.hunk}]` /
  `- **Impact**: {impact}` / `- **Recommendation**: {recommendation}`.
  Append `- **Note**: plan 上は意図的な変更だが、実装として改善を求める` when
  `plan_status == "justified"` (AC-009), and
  `- **Source**: Pass {source_pass}` (AC-011).
- Severity subsections with zero findings are omitted (template.md's own
  rule). All-empty `findings` → `## Findings` with the single line
  `No findings.`, and an empty Action Items table body.
- Action Items rows are generated Critical→Low from `title` + `anchor.display`.
- Implementation is a single `jq -r` program writing the whole document
  (avoids per-finding subshell loops and keeps ordering deterministic).
- `chmod +x`.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
F=tests/review-screen/fixtures && \
bash skills/review/scripts/render-report.sh --review $F/review-valid.json --out /tmp/r.md && \
diff /tmp/r.md $F/expected-report.md && \
for h in '## Metadata' '## Findings' '## Action Items' '## Overall Assessment' '## Next Steps'; do \
  grep -qF "$h" /tmp/r.md || echo "MISSING SECTION: $h"; done && \
bash skills/review/scripts/render-report.sh --review $F/review-empty-findings.json --out /tmp/r2.md && \
grep -q '^\*\*PASS\*\*' /tmp/r2.md && echo OK
```

#### Step 2.3: bats sections for `build-screen.sh` and `render-report.sh`
**File:** `tests/review-screen/test_review_screen.bats`
**Action:** Modify

**Details:**

Append two banner-separated sections. `build-screen.sh` tests (spec §9):

1. happy path — exactly one `<script id="review-payload"`, zero
   `__MY_REVIEW_PAYLOAD__`
2. `script-tag.patch` — zero `</script` inside the payload block, and the
   extracted block passes `jq -e .`
3. unreferenced hunk → exit 3, stderr names the hunk id
4. duplicated hunk → exit 3
5. finding referencing a missing group → exit 3
6. finding referencing a missing hunk → exit 3
7. out-of-range severity → exit 3
8. Critical finding + `assessment: PASS` → exit 3
9. `--pass1` with a missing id → exit 4, stderr lists the id
10. `--pass1` fully covered → exit 0
11. non-risk-descending group order → exit 0 **and** stderr contains a warning
12. empty patch → exit 1
13. stdout's last line matches `^\[review-screen\] wrote: /`

`render-report.sh` tests:

14. golden comparison against `expected-report.md`
15. zero findings → `**PASS**` present, no `### Critical` subsection
16. `plan_status: "justified"` finding renders the 備考 note
17. all five `template.md` headings present, in order

Plus the cross-implementation guard (A-P5), placed in the build-screen
section:

18. the `HUNK_RE:` marker line in `diff-hunks.sh` and the one in
    `assets/review-screen.html` carry byte-identical pattern text
    (skipped with `skip` if the template does not exist yet, so this suite
    stays green until Phase 3 lands).

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
bats tests/review-screen/test_review_screen.bats
```

---

### Phase 3: Core — the review screen template

All five steps edit the same file. After each, re-run the structural guard
below; it is the executable proof that the file stays self-contained and
XSS-free (spec §7).

#### Step 3.1: Skeleton, CSS, payload bootstrap, header, section 01
**File:** `skills/review/assets/review-screen.html`
**Action:** Create

**Details:**

- Full standalone document: `<!doctype html>`, `<meta charset="utf-8">`,
  `<meta name="viewport">`, one inline `<style>`, one inline `<script>` (plus
  the payload `<script type="application/json">`). No `http(s)://`
  references, no webfonts — system font stack only.
- The payload block, verbatim per spec §3.4.2:
  ```html
  <script id="review-payload" type="application/json">
  __MY_REVIEW_PAYLOAD__
  </script>
  ```
- Bootstrap: `const DATA = JSON.parse(document.getElementById('review-payload').textContent)`
  → `DATA.diff` (raw unified diff string), `DATA.review`.
- Hunk index built in JS by splitting `DATA.diff` on the marker regex,
  carrying the identical marker comment
  `// HUNK_RE: ^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@` and the same
  width rule `Math.max(3, String(total).length)`. Store
  `{id, file, header, oldStart, newStart, lines[]}` per hunk.
- Sticky header: `DIFF REVIEW` / `review.meta.title` /
  `{stats.files} files / {stats.hunks} hunks +{insertions} −{deletions}` /
  progress bar / `承認 n/N` / `?` help toggle.
- Section `01 / 変更グループ一覧`: rows rendered **in `review.groups` array
  order, never re-sorted** (AC-003), each with title, `summary`, tags,
  `{hunks.length} hunks`, a Japanese risk label mapped from the 4-level value
  (`Critical`→`要注意(Critical)`, `High`→`要注意(High)`, `Medium`→`注意`,
  `Low`→`低リスク`) while the underlying value stays 4-level (AS-03), finding
  count, and a left risk accent bar. Row click scrolls to the `02` card.
- Every text insertion uses `textContent` / `createElement`. A single
  `el(tag, cls, text)` helper is the only DOM constructor.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
T=skills/review/assets/review-screen.html && \
test "$(grep -c 'id="review-payload"' $T)" = "1" && \
test "$(grep -c '__MY_REVIEW_PAYLOAD__' $T)" = "1" && \
! grep -nE 'https?://|innerHTML|outerHTML|document\.write|insertAdjacentHTML|new Function|[^a-zA-Z_]eval\(' $T && \
grep -q 'HUNK_RE:' $T && \
grep -q '承認' $T && grep -q '01 / 変更グループ一覧' $T && echo OK
```

#### Step 3.2: Section 02 — group detail cards and the diff renderer
**File:** `skills/review/assets/review-screen.html`
**Action:** Modify

**Details:**

- One card per group, same order as `01`. Card head: risk label + title +
  `☐ 確認して承認` checkbox. Body: `意図:` paragraph from `groups[].intent`
  (AC-004); a `要改善` badge when `intent_unclear === true` (AC-005).
- Under the intent, the group's hunks in `groups[].hunks` order. Each hunk
  gets a header row `{hunk_id}  {file}  {@@ header}` and, for renames, the
  `old → new` pair.
- Diff table per hunk: two line-number columns (old / new) plus a `+`/`−`
  gutter and the content cell. Line numbers are computed from `oldStart`/
  `newStart`; added lines advance only the new counter, deleted only the old,
  context both. Added/deleted rows get pale backgrounds. Content cells are
  `white-space: pre` with `overflow-x: auto` **on the row container only**, so
  a minified line scrolls locally and the page body never scrolls
  horizontally (spec §6).
- Groups with more than 10 hunks render their hunks collapsed by default;
  a `▸ n hunks を表示` toggle expands them.
- Findings whose `anchor.hunk` is in this group render inline directly under
  the anchored hunk (severity chip + title + jump-back link to `03`).
- Binary-change entries (a file in `stats` with no hunks) render as a
  `バイナリ変更: {path}` line only.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
T=skills/review/assets/review-screen.html && \
! grep -nE 'https?://|innerHTML|outerHTML|document\.write|insertAdjacentHTML|new Function|[^a-zA-Z_]eval\(' $T && \
grep -q '02 / 変更グループ詳細' $T && grep -q '要改善' $T && grep -q '確認して承認' $T && \
F=tests/review-screen/fixtures && \
bash skills/review/scripts/build-screen.sh --diff $F/simple.patch --review $F/review-valid.json --out /tmp/real.html --template $T && \
awk '/<script id="review-payload"/{f=1;next} /^<\/script>/{f=0} f' /tmp/real.html | jq -e '.review.groups|length>0' && echo OK
```

#### Step 3.3: Sections 03 and 04
**File:** `skills/review/assets/review-screen.html`
**Action:** Modify

**Details:**

- `03 / 指摘一覧`: findings sorted Critical → Low. Each row shows the
  severity chip, `id`, title, `Pass {source_pass}` badge (AC-011), the
  `plan 上は意図的な変更だが、実装として改善を求める` note when
  `plan_status === "justified"` (AC-009), `anchor.display`, and a jump link
  to the anchored hunk in `02`.
- Filters above the list: severity multi-select, `未判定のみ`,
  `指摘のあるグループのみ` (the last one also filters section `02`).
- `04 / plan 照合`: a table of `plan_check[]`
  (item / status / note / hunks) with per-status chips. When `plan_check` is
  absent or empty, render the single line `N/A: plan なし`.
- Keyboard handlers: `?` toggles the help overlay, `j`/`k` move between
  hunks, `a` approves the current group.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
T=skills/review/assets/review-screen.html && \
! grep -nE 'https?://|innerHTML|outerHTML|document\.write|insertAdjacentHTML|new Function|[^a-zA-Z_]eval\(' $T && \
grep -q '03 / 指摘一覧' $T && grep -q '04 / plan 照合' $T && \
grep -q 'N/A: plan なし' $T && grep -q 'plan 上は意図的な変更だが' $T && \
grep -q "source_pass" $T && echo OK
```

#### Step 3.4: State layer — approval, triage, comments, localStorage
**File:** `skills/review/assets/review-screen.html`
**Action:** Modify

**Details:**

- In-memory state object exactly as spec §3.4.3:
  `{approved:{}, triage:{}, rejectReasons:{}, comments:[]}`.
- Storage key `my-review:{meta.id}:{meta.diff_sha}`. On load: read that key;
  then scan `localStorage` for other `my-review:{meta.id}:` prefixed keys,
  delete them, and if any existed show the banner
  `前回の差分と変わったため状態を破棄しました` at the top (AC-017).
- Every mutation persists synchronously via a single `save()`; wrap
  `localStorage` access in try/catch — on failure show
  `この環境では状態が保存されません` once and keep the UI working (spec §6).
- Triage: each finding has a 3-state control (`未判定` default / `採用` /
  `却下`); choosing `却下` reveals a one-line reason input bound to
  `rejectReasons[id]` (AC-012).
- Approval: the group checkbox writes `approved[groupId]`, updates the header
  counter `承認 n/N` and the progress bar, and collapses the card (AC-013,
  spec §5.3).
- Comments: a 💬 affordance on each group card, each diff line, and each
  finding. Clicking opens a small inline textarea; saving appends
  `{anchor, body, at}` to `comments`. `anchor` is
  `{kind:"group"|"hunkline"|"finding", id, hunk, side, line}`. Any target
  with at least one comment shows a persistent marker (AC-014).

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
T=skills/review/assets/review-screen.html && \
! grep -nE 'https?://|innerHTML|outerHTML|document\.write|insertAdjacentHTML|new Function|[^a-zA-Z_]eval\(' $T && \
grep -q 'my-review:' $T && grep -q 'diff_sha' $T && \
grep -q '前回の差分と変わったため状態を破棄しました' $T && \
grep -q 'この環境では状態が保存されません' $T && \
grep -q 'rejectReasons' $T && grep -q 'localStorage' $T && echo OK
```

#### Step 3.5: Section 05 — feedback assembly and clipboard
**File:** `skills/review/assets/review-screen.html`
**Action:** Modify

**Details:**

- Count chips `採用 n` / `却下 n` / `未判定 n` / `コメント n`, live-updated
  (AC-015).
- `フィードバックを生成` builds the Markdown of spec §3.5, exactly:
  `# レビューフィードバック: {meta.title}`, `## 依頼` (the two fixed bullet
  lines), `## 採用された指摘` (numbered, `### {n}. [{severity}] {title}` +
  `場所` / `変更グループの意図` / optional `備考` when
  `plan_status === "justified"` / `指摘` / `改善案`),
  `## レビュアーのコメント` (`### C-{n}. {anchor display} [{anchor}]`),
  `## 対応不要と判断した指摘` (`- [{severity}] {title} — 却下理由: {reason}`).
- Untriaged findings are never emitted. Empty sections are dropped heading
  and all. Zero adopted + zero comments →
  `レビューの結果、修正依頼はありません。` as the entire output.
- Result renders into a read-only `<textarea>` preview.
  `クリップボードにコピー` uses `navigator.clipboard.writeText`; on rejection
  or absence, select the textarea's contents and show
  `手動でコピーしてください` (AC-016).

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
T=skills/review/assets/review-screen.html && \
! grep -nE 'https?://|innerHTML|outerHTML|document\.write|insertAdjacentHTML|new Function|[^a-zA-Z_]eval\(' $T && \
grep -q '05 / フィードバック組み立て' $T && \
grep -q '# レビューフィードバック' $T && grep -q '## 依頼' $T && \
grep -q '## 採用された指摘' $T && grep -q '## レビュアーのコメント' $T && \
grep -q '## 対応不要と判断した指摘' $T && \
grep -q 'レビューの結果、修正依頼はありません。' $T && \
grep -q 'navigator.clipboard' $T && grep -q '<textarea' $T && echo OK
```

---

### Phase 4: Integration — agents, skill, docs

#### Step 4.1: Plan-blind Pass 1 subagent
**File:** `agents/diff-reviewer.md`
**Action:** Create

**Details:**

- Frontmatter: `name: diff-reviewer`,
  `description: "First-pass diff reviewer. Reviews a unified diff on its own merits against checklists and writes pass1.json."`,
  `tools: Read, Glob, Grep, Write, Bash`, `model: inherit`. **No `skills:`
  key** (A-P2).
- Body: read the patch and `hunks.tsv` at the given paths, evaluate against
  the given checklist paths, write `pass1.json` with `schema_version: 1` and
  `findings[]` limited to `id`, `severity`, `title`, `anchor`, `impact`,
  `recommendation` (spec §4.2) — explicitly **not** `group` or `plan_status`.
- State the id convention (`C001`/`H001`/`M001`/`L001`) and the anchor shape
  including `display` = `{file}（{新|旧}L{line}〜）`.
- Contains **no** reference to `docs/plans/`, `docs/specs/`,
  `docs/analysis/`, commit messages, or PR descriptions (AC-007).
- Return contract: `pass1_path`, finding counts by severity.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
grep -q '^name: diff-reviewer' agents/diff-reviewer.md && \
grep -q 'pass1.json' agents/diff-reviewer.md && \
grep -q 'hunks.tsv' agents/diff-reviewer.md && \
! grep -qE 'docs/(plans|specs|analysis)/|commit message|PR description|^skills:' agents/diff-reviewer.md && echo OK
```

#### Step 4.2: reviewer agent contract
**File:** `agents/reviewer.md`
**Action:** Modify

**Details:**

- `tools:` becomes `Read, Glob, Grep, Write, Bash, Task` (AS-01 requires
  launching a subagent).
- Return contract gains `screen_path` (absolute `file://` path), `json_path`,
  and `passes` (1 or 2), alongside the existing `output_path`, per-severity
  counts, and `assessment`. Note that the three new values are emitted only
  for diff targets.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
grep -qE '^tools:.*\bTask\b' agents/reviewer.md && \
grep -q 'screen_path' agents/reviewer.md && \
grep -q 'passes' agents/reviewer.md && echo OK
```

#### Step 4.3: `review.json` contract document
**File:** `skills/review/review-json.md`
**Action:** Create

**Details:**

Transcribe spec §4.1 and §4.2 as the authoring contract the reviewer follows:
the full field table, the `pass1.json` subset, the `anchor.display` format
`{file}（{新|旧}L{line}〜）`, and the four hard rules —

- hunk ids come from `hunks.tsv`, never invented;
- every hunk appears exactly once across `groups[].hunks` and
  `ungrouped_hunks`;
- no diff text, line contents, or line-number listings in the JSON (NFR-003);
- Pass 2 may re-label or downgrade a Pass 1 finding but must never delete one.

Include one minimal valid example document.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
for k in schema_version diff_sha ungrouped_hunks intent_unclear source_pass plan_status plan_check anchor pass1.json; do \
  grep -qF "$k" skills/review/review-json.md || echo "MISSING: $k"; done; \
grep -q '（' skills/review/review-json.md && echo OK
```

#### Step 4.4: Wire the flow into the review skill
**File:** `skills/review/SKILL.md`
**Action:** Modify

**Details:**

- Frontmatter `argument-hint` →
  `"[perspective:]<target> [--no-screen]  e.g. code:user-auth, commit:abc1234, pr:current"`.
- Step 1 gains `--no-screen` parsing: meaningful for `code:`/`commit:`/`pr:`
  only; on a doc target, ignore it and report one line saying it applies to
  diff targets only (AC-020, spec §6).
- New **Step 3.5 — diff targets: screen + two-pass** placed before the
  existing Step 3, applying only to `code:`/`commit:`/`pr:` and only without
  `--no-screen`:
  1. `W="${TMPDIR:-/tmp}/my-review/{id}"; mkdir -p "$W"`; save the diff to
     `$W/diff.patch` using the per-target command from Step 1's table
     (spec §3.2.1) — `git -c core.quotepath=false diff …` for `code:`,
     `git -c core.quotepath=false show|diff …` for `commit:`,
     **`gh pr diff …` for `pr:`** (no quotepath flag; A-P11).
     Record the exact command string as `meta.target.diff_command`.
     - The command exiting non-zero (`gh` unauthenticated, PR not found, no
       network, bad hash) → stop right there, showing the command and its
       stderr. Do **not** say `レビュー対象の差分がありません` — that message
       is reserved for step 2's empty-diff case, which has a different cause
       and a different fix (spec §6).
  2. `diff-hunks.sh --diff "$W/diff.patch" --out "$W"`. Exit 2 → report
     `レビュー対象の差分がありません` plus the exact command tried, and stop
     without writing any output (spec §6).
  3. `meta.diff_sha` = `shasum -a 256 "$W/diff.patch" | cut -c1-12`
     (fallback `sha256sum`) (A-P4).
  4. **Context probe (AS-02):** look for a plan (`docs/plans/*/{id}.md`), a
     spec (`docs/specs/{id}.md`), a commit message, or a PR description.
     - Found → launch `diff-reviewer` via `Task` with **only** the paths to
       `$W/diff.patch`, `$W/hunks.tsv`, the selected checklists, and the
       output path `$W/pass1.json`. Never pass plan/spec paths or content
       (AC-007). Then Pass 2 reads the diff, the context, and
       `$W/pass1.json`; `meta.passes = 2`.
     - Not found → single pass; `meta.passes = 1`; omit `plan_check`
       (AC-010).
  5. Write `docs/reviews/{type}/{id}.json` per
     `${CLAUDE_SKILL_DIR}/review-json.md`.
  6. `build-screen.sh --diff … --review … --out docs/reviews/{type}/{id}.html`
     plus `--pass1 "$W/pass1.json"` when `passes == 2`. Report the overwrite
     target on one line first if the HTML already exists.
     - exit 3 → fix the reported violations in the JSON and retry **once**;
       still failing → stop and report.
     - exit 4 → restore the listed Pass 1 finding ids and redo Pass 2
       **once**; still failing → stop and report.
  7. `render-report.sh --review … --out docs/reviews/{type}/{id}.md`
     (A-P12) — this replaces hand-writing the md for diff targets.
  8. Perspective suffix applies to all three outputs:
     `{id}--{perspective}.{md,json,html}`.
- Step 3 stays authoritative for doc targets and for `--no-screen`; add one
  sentence saying doc targets produce no `.json` and no `.html` (AC-019).
- Completion section gains `screen_path` (as a `file://` absolute path),
  `json_path`, and `passes`, and the instruction to tell the user to open the
  screen and paste the generated Markdown back into the working session.
- Add a note that `docs/reviews/**/*.{html,json}` are regenerable build
  artifacts and can be gitignored (AS-06).

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
S=skills/review/SKILL.md && \
grep -q -- '--no-screen' $S && \
for k in diff-hunks.sh build-screen.sh render-report.sh diff-reviewer review-json.md pass1.json diff_sha core.quotepath 'gh pr diff'; do \
  grep -qF "$k" $S || echo "MISSING: $k"; done; \
grep -q 'argument-hint:.*--no-screen' $S && \
grep -q 'screen_path' $S && echo OK
```

#### Step 4.5: Docs and gitignore
**Files:** `README.md`, `.gitignore`
**Action:** Modify / Create

**Details:**

- `.gitignore` (new, A-P7):
  ```
  # Regenerable review build artifacts (the .md report is the committed one)
  docs/reviews/**/*.html
  docs/reviews/**/*.json
  ```
- README **Review** section: note that `code:`/`commit:`/`pr:` also produce
  `{id}.html` (a self-contained screen opened with `file://`) and `{id}.json`;
  that diff reviews run two passes when a plan/spec/commit message/PR body
  exists, with Pass 1 plan-blind; that `--no-screen` restores md-only
  behavior; and that doc targets are unchanged.
- README **Repository structure** tree: add
  `skills/review/{assets/,scripts/,review-json.md}` and
  `tests/review-screen/`. Update the `tests/` comment from
  "hooks / install / redact / toolkit" to include `review-screen`.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
git check-ignore -q docs/reviews/code/x.html && \
git check-ignore -q docs/reviews/code/x.json && \
! git check-ignore -q docs/reviews/code/x.md && \
grep -q -- '--no-screen' README.md && \
grep -q 'review-screen' README.md && \
grep -q 'assets/' README.md && echo OK
```

---

### Phase 5: Verification

#### Step 5.1: Full suite and doc-target regression
**Files:** none (verification only)
**Action:** Verify

**Details:**

- Run every bats suite; the three pre-existing suites must stay green
  (nothing they cover was touched).
- Un-skip the `HUNK_RE` cross-implementation test from Step 2.3 now that the
  template exists.
- AC-019: run a doc review (`/my:review spec:20260725-diff-review-screen`)
  and confirm no `.html`/`.json` was produced under a doc review type, and
  that the md is unchanged in structure.

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
bats -r tests/ && \
./scripts/install.sh --check && \
find docs/reviews/specs docs/reviews/plans docs/reviews/research \
     -name '*.html' -o -name '*.json' 2>/dev/null | grep . && \
  echo "FAIL: doc target produced screen artifacts" || echo "OK: doc targets clean"
```

#### Step 5.2: End-to-end run, performance, manual browser checklist
**Files:** none (verification only)
**Action:** Verify

**Details:**

- Real run against this repo's own diff:
  `/my:review code:20260725-diff-review-screen`, then
  `/my:review code:20260725-diff-review-screen --no-screen` to confirm the
  escape hatch produces md only (AC-020).
- Performance (spec §8): `diff-hunks.sh` < 500ms and `build-screen.sh` < 3s
  on a 268-hunk patch.
- Manual browser checklist (spec §9, bats-out-of-scope): open the HTML in
  Chrome and Safari and confirm — DevTools Network is empty (AC-001);
  approve / triage / comment survive a reload; regenerating with a changed
  `diff_sha` shows the discard banner (AC-017); `フィードバックを生成`
  output matches spec §3.5 and copies in one click (AC-016).

**Verification:**
```bash
cd "$(git rev-parse --show-toplevel)" && \
bash tests/review-screen/fixtures/gen-big-patch.sh 268 /tmp/perf.patch && \
time bash skills/review/scripts/diff-hunks.sh --diff /tmp/perf.patch --out /tmp/perf && \
time bash skills/review/scripts/build-screen.sh --diff /tmp/perf.patch \
  --review tests/review-screen/fixtures/review-valid.json --out /tmp/perf.html \
  --template skills/review/assets/review-screen.html 2>/dev/null; \
ls -la docs/reviews/code/20260725-diff-review-screen.md \
       docs/reviews/code/20260725-diff-review-screen.json \
       docs/reviews/code/20260725-diff-review-screen.html && \
open docs/reviews/code/20260725-diff-review-screen.html
```
(The perf `build-screen.sh` leg needs a `review-*.json` whose hunk ids cover
the 268-hunk patch; generate it with a jq one-liner from
`/tmp/perf/hunks.tsv` rather than committing a fixture.)

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

Runtime: **none added** (NFR-001). `bash`, `awk`, `git`, `jq`, `shasum` are
already required by the toolkit; `jq` is already used by
`scripts/hooks/*.sh` and `skills/retro/SKILL.md`.

Development only:

| Package | Version | Purpose |
|---------|---------|---------|
| `bats-core` | 1.10+ | Test runner. **Not currently installed on this machine** (A-P1) — `brew install bats-core` before Step 1.3. Every non-test step also has a bats-free verification command. |

### 4.2 Internal Dependencies

- `skills/review/checklists/*` — Pass 1 and Pass 2 both select from the
  existing set; no checklist content changes.
- `skills/review/template.md` — remains the authority for the md section
  structure; `render-report.sh` must track it (AC-018).
- `agents/fixer.md` and `skills/pipeline/SKILL.md` — **unchanged on purpose**;
  the fixer keeps reading `docs/reviews/{type}/{id}.md` (AC-018), and the
  pipeline only reviews non-`do` doc steps, so it never reaches this branch.
- `${CLAUDE_SKILL_DIR}` resolution — already used at `skills/review/SKILL.md`
  lines 50 and 73; the new `assets/`, `scripts/`, and `review-json.md` are
  reachable the same way, so `scripts/install.sh` needs no change.

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Source document reviewed (`docs/specs/20260725-diff-review-screen.md`)
- [ ] `brew install bats-core` (A-P1); `bats --version` succeeds
- [ ] `jq --version` ≥ 1.6, `shasum -a 256` works

### 5.2 Post-Implementation
- [ ] Full test suite passing (command: `bats -r tests/`)
- [ ] Plugin state clean (command: `./scripts/install.sh --check`)
- [ ] Template self-containment guard passes (the `! grep -nE 'https?://|innerHTML|…'` command from Phase 3)
- [ ] Changed behavior exercised end-to-end (Step 5.2: real `code:` review, screen opened in a browser, feedback Markdown pasted back)

### 5.3 Acceptance Criteria Verification

- [ ] AC-001 (self-contained HTML, empty Network) → Steps 3.1, 2.1; manual leg of 5.2
- [ ] AC-002 (section 01 row contents) → Step 3.1
- [ ] AC-003 (order = `groups` array order, no re-sort) → Step 3.1
- [ ] AC-004 (section 02 `意図:` + 2-column line numbers) → Step 3.2
- [ ] AC-005 (`intent_unclear` → 要改善) → Step 3.2
- [ ] AC-006 (every hunk covered exactly once, else exit 3) → Step 2.1 (validation 2), test 3/4 of Step 2.3
- [ ] AC-007 (Pass 1 in `diff-reviewer`, no plan in the prompt) → Steps 4.1, 4.4
- [ ] AC-008 (Pass 1 ids all survive, else exit 4 + id list) → Step 2.1 (validation 7), test 9 of Step 2.3
- [ ] AC-009 (`plan_status: justified` note in screen and md) → Steps 3.3, 2.2
- [ ] AC-010 (no context → `meta.passes == 1`) → Step 4.4 (context probe)
- [ ] AC-011 (`source_pass` shown) → Step 3.3
- [ ] AC-012 (3-state triage + reject reason) → Step 3.4
- [ ] AC-013 (group approve + `承認 n/N` + progress bar) → Step 3.4
- [ ] AC-014 (comments on group / line / finding, persistent marker) → Step 3.4
- [ ] AC-015 (section 05 count chips) → Step 3.5
- [ ] AC-016 (generate Markdown + clipboard + textarea fallback) → Step 3.5
- [ ] AC-017 (state restored; `diff_sha` change discards + banner) → Step 3.4
- [ ] AC-018 (md matches `template.md` sections) → Step 2.2, tests 14/17 of Step 2.3
- [ ] AC-019 (doc targets byte-identical, no HTML/JSON) → Steps 4.4, 5.1
- [ ] AC-020 (`--no-screen` = current single-pass md-only behavior) → Steps 4.4, 5.2

---

## 6. Rollback Plan

The change is additive plus three in-place edits, so rollback is mechanical:

```bash
git checkout -- skills/review/SKILL.md agents/reviewer.md README.md
rm -rf skills/review/scripts skills/review/assets skills/review/review-json.md \
       agents/diff-reviewer.md tests/review-screen .gitignore
bats -r tests/          # three original suites must be green
```

Partial rollback without reverting code: `--no-screen` disables Pass 1, the
JSON, and the HTML, leaving exactly today's behavior — so a regression found
in production use can be worked around immediately, and per-phase rollback is
possible because Phases 1–3 are unreachable until Step 4.4 wires them in.

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| 1 — Extraction | Medium | awk state machine over patch edge cases (rename / dev-null / binary); fixtures must have hand-verified expected stats |
| 2 — Assembly scripts | Medium | Mostly jq validation programs; the payload/awk mechanics are already de-risked (§1.3) |
| 3 — HTML template | **High** | Largest single artifact and the repo's first HTML/JS asset; diff renderer + state layer + Markdown assembly, all with a `textContent`-only constraint and no browser test harness |
| 4 — Integration | Medium | Prose-only, but AS-01's information barrier and the exit-3/exit-4 retry rules must be stated precisely |
| 5 — Verification | Low | Runs the suites, then a manual browser pass |

---
**Size:** L
**Created:** 2026-07-25
**Status:** Draft
