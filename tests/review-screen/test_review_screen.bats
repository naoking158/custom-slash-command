#!/usr/bin/env bats
# Unit tests for the diff review screen scripts — Spec §9.

# `run --separate-stderr` is needed to assert on the exit-3/exit-4 violation
# lines without stdout's success line getting mixed in.
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPTS="$REPO_ROOT/skills/review/scripts"
  TEMPLATE="$REPO_ROOT/skills/review/assets/review-screen.html"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  TMP="$(mktemp -d -t review-screen-test.XXXXXX)"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# payload_of — Extract the JSON payload block from a built HTML file.
payload_of() {
  awk '/<script id="review-payload"/{f=1;next} /^<\/script>/{f=0} f' "$1"
}

# --- diff-hunks.sh ------------------------------------------------------------

@test "diff-hunks: hunk count matches the patch's @@ lines" {
  run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/simple.patch" --out "$TMP/out"
  [ "$status" -eq 0 ]
  expected="$(grep -c '^@@' "$FIXTURES/simple.patch")"
  actual="$(wc -l < "$TMP/out/hunks.tsv" | tr -d ' ')"
  [ "$actual" -eq "$expected" ]
}

@test "diff-hunks: ids are zero-padded to 3 digits and sequential" {
  run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/simple.patch" --out "$TMP/out"
  [ "$status" -eq 0 ]
  [ "$(cut -f1 < "$TMP/out/hunks.tsv" | tr '\n' ' ')" = "h001 h002 h003 h004 h005 " ]
}

@test "diff-hunks: stats.json matches the fixture's known counts" {
  run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/simple.patch" --out "$TMP/out"
  [ "$status" -eq 0 ]
  run jq -e '.files==3 and .hunks==5 and .insertions==7 and .deletions==4' "$TMP/out/stats.json"
  [ "$status" -eq 0 ]
}

@test "diff-hunks: empty patch exits 2 and writes nothing" {
  run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/empty.patch" --out "$TMP/out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no hunks"* ]]
  [ ! -f "$TMP/out/hunks.tsv" ]
  [ ! -f "$TMP/out/stats.json" ]
}

@test "diff-hunks: new / deleted / renamed / binary paths resolve correctly" {
  run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/special.patch" --out "$TMP/out"
  [ "$status" -eq 0 ]
  # New file: path comes from the +++ b/ side (--- is /dev/null).
  [ "$(awk -F'\t' 'NR==1{print $2}' "$TMP/out/hunks.tsv")" = "src/new-file.ts" ]
  # Deleted file: path comes from the --- a/ side (+++ is /dev/null).
  [ "$(awk -F'\t' 'NR==2{print $2}' "$TMP/out/hunks.tsv")" = "src/gone.ts" ]
  # Rename: path is the b/ side.
  [ "$(awk -F'\t' 'NR==3{print $2}' "$TMP/out/hunks.tsv")" = "src/new-name.ts" ]
  # Binary file has no hunk but is still counted as a file.
  run jq -e '.files==4 and .hunks==3' "$TMP/out/stats.json"
  [ "$status" -eq 0 ]
}

@test "diff-hunks: a non-UTF-8 patch exits 1, not 2" {
  # awk exits 2 on a multibyte conversion failure, which would otherwise be
  # indistinguishable from "no hunks" and get reported as an empty diff.
  {
    printf 'diff --git a/bin/data b/bin/data\nindex 111..222 100644\n'
    printf -- '--- a/bin/data\n+++ b/bin/data\n@@ -1,1 +1,1 @@\n-old\n+'
    printf '\xff\xfe\x00\x80\n'
  } > "$TMP/nonutf8.patch"

  run "$SCRIPTS/diff-hunks.sh" --diff "$TMP/nonutf8.patch" --out "$TMP/out"
  [ "$status" -eq 1 ]
  [[ "$output" == *"non-UTF-8"* ]]

  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$TMP/nonutf8.patch" --review "$FIXTURES/review-script-tag.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"non-UTF-8"* ]]
}

@test "diff-hunks: 1200 hunks widen the id to 4 digits" {
  bash "$FIXTURES/gen-big-patch.sh" 1200 "$TMP/big.patch"
  run "$SCRIPTS/diff-hunks.sh" --diff "$TMP/big.patch" --out "$TMP/out"
  [ "$status" -eq 0 ]
  [ "$(head -1 "$TMP/out/hunks.tsv" | cut -f1)" = "h0001" ]
  [ "$(tail -1 "$TMP/out/hunks.tsv" | cut -f1)" = "h1200" ]
}

@test "diff-hunks: missing --diff argument exits 1" {
  run "$SCRIPTS/diff-hunks.sh" --out "$TMP/out"
  [ "$status" -eq 1 ]
  run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/simple.patch"
  [ "$status" -eq 1 ]
  run "$SCRIPTS/diff-hunks.sh" --diff "$TMP/does-not-exist.patch" --out "$TMP/out"
  [ "$status" -eq 1 ]
}

@test "diff-hunks: every TSV row has exactly 5 tab-separated columns" {
  # special.patch carries a tab inside a hunk header's function context, which
  # must be collapsed to a space so the TSV stays 5-column (plan A-P13).
  for p in simple special; do
    run "$SCRIPTS/diff-hunks.sh" --diff "$FIXTURES/$p.patch" --out "$TMP/out-$p"
    [ "$status" -eq 0 ]
    bad="$(awk -F'\t' 'NF!=5' "$TMP/out-$p/hunks.tsv" | wc -l | tr -d ' ')"
    [ "$bad" -eq 0 ]
  done
}

# --- build-screen.sh ----------------------------------------------------------

@test "build-screen: happy path splices exactly one payload block" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-valid.json" \
    --out "$TMP/s.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'id="review-payload"' "$TMP/s.html")" -eq 1 ]
  [ "$(grep -c '__MY_REVIEW_PAYLOAD__' "$TMP/s.html" || true)" -eq 0 ]
  run jq -e '.review.schema_version == 1 and (.diff | length) > 0' \
    <(payload_of "$TMP/s.html")
  [ "$status" -eq 0 ]
}

@test "build-screen: a diff containing </script> cannot terminate the block" {
  run "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/script-tag.patch" --review "$FIXTURES/review-script-tag.json" \
    --out "$TMP/t.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 0 ]
  [ "$(payload_of "$TMP/t.html" | grep -c '</script' || true)" -eq 0 ]
  # The payload still reparses, and the diff round-trips byte for byte.
  run jq -e . <(payload_of "$TMP/t.html")
  [ "$status" -eq 0 ]
  payload_of "$TMP/t.html" | jq -j '.diff' > "$TMP/roundtrip.patch"
  cmp "$TMP/roundtrip.patch" "$FIXTURES/script-tag.patch"
}

@test "build-screen: an unreferenced hunk exits 3 and names the id" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-unreferenced-hunk.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"h005"* ]]
}

@test "build-screen: a hunk referenced twice exits 3" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-dup-hunk.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"more than once"* ]]
}

@test "build-screen: a finding on a missing group exits 3" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-bad-group.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"unknown group"* ]]
}

@test "build-screen: a finding on a missing hunk exits 3" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-bad-hunk.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"unknown hunk"* ]]
}

@test "build-screen: an out-of-range severity exits 3" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-bad-severity.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"invalid severity"* ]]
}

@test "build-screen: Critical finding with assessment PASS exits 3" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-assessment-mismatch.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 3 ]
  [[ "$stderr" == *"NEEDS_REVISION"* ]]
}

@test "build-screen: wrong field types exit 3 rather than crashing jq" {
  for expr in '.groups[0].hunks = "h001"' '.findings[0].anchor = "src/auth.ts"' '.groups = {}'; do
    jq "$expr" "$FIXTURES/review-valid.json" > "$TMP/badtype.json"
    run --separate-stderr "$SCRIPTS/build-screen.sh" \
      --diff "$FIXTURES/simple.patch" --review "$TMP/badtype.json" \
      --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
    [ "$status" -eq 3 ]
    [[ "$stderr" == *"must be an"* ]]
  done
}

@test "build-screen: a template without the marker exits 1" {
  echo "<html><body>no marker here</body></html>" > "$TMP/bare.html"
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-valid.json" \
    --out "$TMP/x.html" --template "$TMP/bare.html"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"__MY_REVIEW_PAYLOAD__"* ]]
}

@test "build-screen: a dropped Pass 1 finding exits 4 and lists the id" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-valid.json" \
    --pass1 "$FIXTURES/pass1-missing.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 4 ]
  [[ "$stderr" == *"C009"* ]]
}

@test "build-screen: a fully carried-over Pass 1 exits 0" {
  run "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-valid.json" \
    --pass1 "$FIXTURES/pass1.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 0 ]
}

@test "build-screen: groups out of risk order warn but still exit 0" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-order-warn.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"warning"* ]]
  [[ "$stderr" == *"descending risk"* ]]
  [ -s "$TMP/x.html" ]
}

@test "build-screen: a stale meta.diff_sha warns but still exits 0" {
  jq '.meta.diff_sha = "deadbeefcafe"' "$FIXTURES/review-valid.json" > "$TMP/stale.json"
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$TMP/stale.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"diff_sha"* ]]
}

@test "build-screen: an empty diff exits 1" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/empty.patch" --review "$FIXTURES/review-valid.json" \
    --out "$TMP/x.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"empty diff"* ]]
}

@test "build-screen: last stdout line reports the absolute path" {
  run --separate-stderr "$SCRIPTS/build-screen.sh" \
    --diff "$FIXTURES/simple.patch" --review "$FIXTURES/review-valid.json" \
    --out "$TMP/s.html" --template "$FIXTURES/template-min.html"
  [ "$status" -eq 0 ]
  last="$(echo "$output" | tail -1)"
  [[ "$last" =~ ^\[review-screen\]\ wrote:\ / ]]
}

@test "build-screen: the hunk pattern is identical in the script and the template" {
  script_marker="$(grep -o 'HUNK_RE:.*' "$SCRIPTS/diff-hunks.sh" | head -1)"
  [ -n "$script_marker" ]

  # The marker comment and the awk literal it documents must not drift apart.
  first_pat="$(grep -oE '\^@@ [^/]*@@' "$SCRIPTS/diff-hunks.sh" | head -1)"
  last_pat="$(grep -oE '\^@@ [^/]*@@' "$SCRIPTS/diff-hunks.sh" | tail -1)"
  [ "$first_pat" = "$last_pat" ]

  # The template's JS re-implements the same rule; guard the two copies.
  [ -f "$TEMPLATE" ] || skip "template not built yet"
  template_marker="$(grep -o 'HUNK_RE:.*' "$TEMPLATE" | head -1)"
  [ "$script_marker" = "$template_marker" ]
}

# --- render-report.sh ---------------------------------------------------------

@test "render-report: output matches the golden report" {
  run "$SCRIPTS/render-report.sh" --review "$FIXTURES/review-valid.json" --out "$TMP/r.md"
  [ "$status" -eq 0 ]
  diff "$TMP/r.md" "$FIXTURES/expected-report.md"
}

@test "render-report: zero findings still produce a PASS report" {
  run "$SCRIPTS/render-report.sh" \
    --review "$FIXTURES/review-empty-findings.json" --out "$TMP/r.md"
  [ "$status" -eq 0 ]
  grep -q '^\*\*PASS\*\*' "$TMP/r.md"
  grep -q '^No findings\.$' "$TMP/r.md"
  ! grep -q '### Critical' "$TMP/r.md"
}

@test "render-report: a justified finding carries the plan note" {
  run "$SCRIPTS/render-report.sh" --review "$FIXTURES/review-valid.json" --out "$TMP/r.md"
  [ "$status" -eq 0 ]
  grep -q '\*\*Note\*\*: plan 上は意図的な変更だが、実装として改善を求める' "$TMP/r.md"
  grep -q '\*\*Source\*\*: Pass 1' "$TMP/r.md"
}

@test "render-report: template.md's five sections appear in order" {
  run "$SCRIPTS/render-report.sh" --review "$FIXTURES/review-valid.json" --out "$TMP/r.md"
  [ "$status" -eq 0 ]
  headings="$(grep '^## ' "$TMP/r.md" | tr '\n' '|')"
  [ "$headings" = "## Metadata|## Findings|## Action Items|## Overall Assessment|## Next Steps|" ]
}
