#!/usr/bin/env bash
# build-screen.sh — Validate review.json and assemble the single-file screen.
#
# Splices {diff, review} into the template's __MY_REVIEW_PAYLOAD__ marker
# (spec §3.4.2) after machine-checking that the reviewer's JSON is internally
# consistent with the diff it claims to describe (spec §3.2.3).
#
# Usage: build-screen.sh --diff <patch> --review <json> --out <html>
#                        [--template <html>] [--pass1 <json>]
#
# Exit codes:
#   0 = success (warnings may still have been printed)
#   1 = bad arguments / input unreadable / empty diff / non-UTF-8 diff
#   3 = schema or referential-integrity failure (validations 1-6)
#   4 = a Pass 1 finding is missing from the final result (validation 7)
#
# Stdout contract (last line): [review-screen] wrote: <abs-path> (<size>)
#
# Dependencies: bash, awk, sed, jq, shasum (NFR-001: no python/node).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "usage: build-screen.sh --diff <patch> --review <json> --out <html> [--template <html>] [--pass1 <json>]" >&2
}

err() { echo "build-screen.sh: $1" >&2; }

DIFF=""
REVIEW=""
OUT=""
TEMPLATE=""
PASS1=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff)     [[ $# -ge 2 ]] || { usage; exit 1; }; DIFF="$2";     shift 2 ;;
    --review)   [[ $# -ge 2 ]] || { usage; exit 1; }; REVIEW="$2";   shift 2 ;;
    --out)      [[ $# -ge 2 ]] || { usage; exit 1; }; OUT="$2";      shift 2 ;;
    --template) [[ $# -ge 2 ]] || { usage; exit 1; }; TEMPLATE="$2"; shift 2 ;;
    --pass1)    [[ $# -ge 2 ]] || { usage; exit 1; }; PASS1="$2";    shift 2 ;;
    *) err "unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$DIFF" || -z "$REVIEW" || -z "$OUT" ]]; then
  usage
  exit 1
fi

TEMPLATE="${TEMPLATE:-${CLAUDE_SKILL_DIR:-$SCRIPT_DIR/..}/assets/review-screen.html}"

check_readable() {
  if [[ ! -f "$1" || ! -r "$1" ]]; then
    err "cannot read $1"
    exit 1
  fi
}

check_readable "$DIFF"
check_readable "$REVIEW"
check_readable "$TEMPLATE"
if [[ -n "$PASS1" ]]; then check_readable "$PASS1"; fi

if ! grep -q '__MY_REVIEW_PAYLOAD__' "$TEMPLATE"; then
  err "template has no __MY_REVIEW_PAYLOAD__ marker: $TEMPLATE"
  exit 1
fi

WORK="$(mktemp -d -t build-screen.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# --- hunk id set ---------------------------------------------------------------
# Derived by the sibling script rather than re-parsed here, so the numbering
# rule has exactly one shell implementation (plan A-P5).
set +e
"$SCRIPT_DIR/diff-hunks.sh" --diff "$DIFF" --out "$WORK" >/dev/null 2>&1
dh_rc=$?
set -e
if (( dh_rc == 2 )); then
  err "empty diff"
  exit 1
fi
if (( dh_rc != 0 )); then
  err "non-UTF-8 diff (unsupported): $DIFF"
  exit 1
fi

IDS_JSON="$(cut -f1 "$WORK/hunks.tsv" | jq -Rn '[inputs]')"

# --- validation ----------------------------------------------------------------

if ! jq -e . "$REVIEW" >/dev/null 2>&1; then
  err "$REVIEW is not valid JSON"
  exit 3
fi

SCHEMA_PROG='
def missing($o; $prefix; $req):
  (($req - ($o | keys_unsorted)) | .[] | "\($prefix)\(.) is missing");

# Types are checked here, not just key presence: the referential program that
# runs next iterates these fields, and a wrong type there would abort jq with
# its own exit code instead of a clean exit 3.
def wrong_type($v; $name; $want):
  if ($v | type) == $want then empty
  else "\($name) must be \($want|if . == "array" then "an array" else "an object" end)" end;

(if (.schema_version? // null) != 1 then "schema_version must be 1" else empty end),
(if (.meta | type) != "object" then "meta must be an object"
 else missing(.meta; "meta.";
   ["id","title","target","reviewed_at","checklists","passes","assessment","diff_sha"]) end),
(if ((.meta.passes? // null) | IN(1,2)) then empty
 else "meta.passes must be 1 or 2" end),
(if ((.meta.assessment? // null) | IN("PASS","NEEDS_REVISION")) then empty
 else "meta.assessment must be PASS or NEEDS_REVISION" end),
missing(.; ""; ["stats","groups","ungrouped_hunks","findings"]),
(if has("stats") then wrong_type(.stats; "stats"; "object") else empty end),
(if has("groups") then wrong_type(.groups; "groups"; "array") else empty end),
(if has("ungrouped_hunks") then wrong_type(.ungrouped_hunks; "ungrouped_hunks"; "array") else empty end),
(if has("findings") then wrong_type(.findings; "findings"; "array") else empty end),
(if has("plan_check") then wrong_type(.plan_check; "plan_check"; "array") else empty end),
((.groups? // []) | if type == "array" then to_entries[] else empty end
 | select((.value | type) == "object")
 | (missing(.value; "groups[\(.key)].";
      ["id","title","summary","intent","intent_unclear","risk","tags","hunks"]),
    (.key as $i | .value
     | (if has("hunks") then wrong_type(.hunks; "groups[\($i)].hunks"; "array") else empty end),
       (if has("tags") then wrong_type(.tags; "groups[\($i)].tags"; "array") else empty end)))),
((.findings? // []) | if type == "array" then to_entries[] else empty end
 | select((.value | type) == "object")
 | (missing(.value; "findings[\(.key)].";
     ["id","severity","title","group","anchor","impact","recommendation","source_pass","plan_status"]),
    (.key as $i | .value
     | if has("anchor") then wrong_type(.anchor; "findings[\($i)].anchor"; "object") else empty end),
    (.key as $i | .value.anchor | select(type == "object")
     | missing(.; "findings[\($i)].anchor."; ["hunk","side","line","file","display"]))))
'

REF_PROG='
([.groups[].hunks[]] + .ungrouped_hunks) as $ref
| ($groups_ids) as $gids
|
# Validation 2 — coverage: exactly once each.
((($ids - ($ref | unique)) | .[] | "hunk \(.) is in the diff but not referenced by any group or ungrouped_hunks")),
(($ref | group_by(.) | map(select(length > 1) | .[0]) | .[] | "hunk \(.) is referenced more than once")),
(((($ref | unique) - $ids)) | .[] | "hunk \(.) is referenced but does not exist in the diff"),

# Validation 3 — findings point at a real group.
(.findings[] | select((.group | IN($gids[])) | not) | "finding \(.id) references unknown group \(.group)"),

# Validation 4 — findings anchor at a real hunk.
(.findings[] | select((.anchor.hunk | IN($ids[])) | not) | "finding \(.id) anchors at unknown hunk \(.anchor.hunk)"),

# Validation 5 — severity / risk vocabulary.
(.findings[] | select((.severity | IN("Critical","High","Medium","Low")) | not) | "finding \(.id) has invalid severity \(.severity)"),
(.groups[] | select((.risk | IN("Critical","High","Medium","Low")) | not) | "group \(.id) has invalid risk \(.risk)"),

# Validation 6 — assessment follows from the findings.
((([.findings[] | select(.severity == "Critical" or .severity == "High")] | length) > 0) as $blocking
 | if $blocking and .meta.assessment != "NEEDS_REVISION"
   then "meta.assessment must be NEEDS_REVISION when a Critical or High finding exists"
   elif ($blocking | not) and .meta.assessment != "PASS"
   then "meta.assessment must be PASS when no Critical or High finding exists"
   else empty end)
'

violations="$(jq -r "$SCHEMA_PROG" "$REVIEW")"

if [[ -z "$violations" ]]; then
  groups_ids="$(jq -c '[.groups[].id]' "$REVIEW")"
  violations="$(jq -r --argjson ids "$IDS_JSON" --argjson groups_ids "$groups_ids" "$REF_PROG" "$REVIEW")"
fi

if [[ -n "$violations" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && err "$line"
  done <<< "$violations"
  exit 3
fi

# Validation 7 runs only on a structurally sound document, so exit 3 and
# exit 4 stay disjoint and the caller always knows which retry path to take.
if [[ -n "$PASS1" ]]; then
  if ! jq -e . "$PASS1" >/dev/null 2>&1; then
    err "$PASS1 is not valid JSON"
    exit 1
  fi
  final_ids="$(jq -c '[.findings[].id]' "$REVIEW")"
  dropped="$(jq -r --argjson final "$final_ids" \
    '.findings[] | select((.id | IN($final[])) | not) | .id' "$PASS1")"
  if [[ -n "$dropped" ]]; then
    while IFS= read -r id; do
      [[ -n "$id" ]] && err "Pass 1 finding $id is missing from the final findings"
    done <<< "$dropped"
    exit 4
  fi
fi

# --- warnings (exit code unchanged) --------------------------------------------

WARN_PROG='
def rank: {"Critical":4,"High":3,"Medium":2,"Low":1}[.] // 0;
([.groups[].risk | rank]) as $r
| (if $r == ($r | sort | reverse) then empty
   else "warning: groups are not ordered by descending risk" end),
(.findings as $f
 | .groups[]
 | . as $g
 | select($g.intent_unclear == true)
 | select((([$f[] | select(.group == $g.id)]) | length) == 0)
 | "warning: group \($g.id) is marked intent_unclear but carries no findings")
'

while IFS= read -r line; do
  [[ -n "$line" ]] && err "$line"
done <<< "$(jq -r "$WARN_PROG" "$REVIEW")"

compute_sha() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -c1-12
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -c1-12
  fi
}

actual_sha="$(compute_sha "$DIFF")"
declared_sha="$(jq -r '.meta.diff_sha' "$REVIEW")"
if [[ -n "$actual_sha" && "$actual_sha" != "$declared_sha" ]]; then
  err "warning: meta.diff_sha ($declared_sha) does not match the diff ($actual_sha)"
fi

# --- assembly ------------------------------------------------------------------

# `</` -> `<\/` is a valid JSON string escape and makes it structurally
# impossible for diff content to terminate the payload <script> block.
if ! jq -n --rawfile diff "$DIFF" --slurpfile review "$REVIEW" \
     '{diff: $diff, review: $review[0]}' 2>/dev/null \
     | sed 's|</|<\\/|g' > "$WORK/payload.json"; then
  err "non-UTF-8 diff (unsupported): $DIFF"
  exit 1
fi

if [[ ! -s "$WORK/payload.json" ]]; then
  err "non-UTF-8 diff (unsupported): $DIFF"
  exit 1
fi

# awk, not sed: the payload is a single multi-megabyte line and would break
# sed's replacement-text metacharacter handling (spec §3.4.2).
awk -v pf="$WORK/payload.json" '
  /__MY_REVIEW_PAYLOAD__/ {
    while ((getline line < pf) > 0) print line
    close(pf)
    next
  }
  { print }
' "$TEMPLATE" > "$OUT"

out_dir="$(cd "$(dirname "$OUT")" && pwd)"
abs_out="$out_dir/$(basename "$OUT")"
size_h="$(wc -c < "$OUT" | awk '{
  b = $1
  if (b >= 1048576) printf "%.1fMB", b / 1048576
  else if (b >= 1024) printf "%dKB", b / 1024
  else printf "%dB", b
}')"

echo "[review-screen] wrote: $abs_out ($size_h)"
