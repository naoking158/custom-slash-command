#!/usr/bin/env bash
# render-report.sh — Render review.json into the toolkit's markdown report.
#
# review.json is the single source of truth (spec AS-04); this script is the
# only writer of docs/reviews/{type}/{id}.md for diff targets, so the report
# can never drift from the JSON the screen was built from. The section
# structure must stay identical to skills/review/template.md (AC-018).
#
# Usage: render-report.sh --review <json> --out <md>
#
# Exit codes:
#   0 = success
#   1 = bad arguments / input unreadable / invalid JSON
#
# Dependencies: bash, jq (NFR-001: no python/node).
set -euo pipefail

usage() {
  echo "usage: render-report.sh --review <json> --out <md>" >&2
}

REVIEW=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --review) [[ $# -ge 2 ]] || { usage; exit 1; }; REVIEW="$2"; shift 2 ;;
    --out)    [[ $# -ge 2 ]] || { usage; exit 1; }; OUT="$2";    shift 2 ;;
    *) echo "render-report.sh: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$REVIEW" || -z "$OUT" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$REVIEW" || ! -r "$REVIEW" ]]; then
  echo "render-report.sh: cannot read $REVIEW" >&2
  exit 1
fi

if ! jq -e . "$REVIEW" >/dev/null 2>&1; then
  echo "render-report.sh: $REVIEW is not valid JSON" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

# One jq program writes the whole document: ordering stays deterministic and
# there is no per-finding subshell loop to get the severity grouping wrong.
jq -r '
# Checklists that name the artifact type rather than a review perspective.
def content_type_lists: ["spec.md","plan.md","prd.md","product-spec.md","commit.md","pr.md"];

def finding_lines:
  ["- **[\(.id)]** \(.title)",
   "  - **Location**: \(.anchor.display) [\(.anchor.hunk)]",
   "  - **Impact**: \(.impact)",
   "  - **Recommendation**: \(.recommendation)"]
  + (if .plan_status == "justified"
     then ["  - **Note**: plan 上は意図的な変更だが、実装として改善を求める"]
     else [] end)
  + ["  - **Source**: Pass \(.source_pass)"];

def sev_section($sev; $findings):
  ([$findings[] | select(.severity == $sev)]) as $items
  | if ($items | length) == 0 then []
    else ["### \($sev)"] + ([$items[] | finding_lines] | add) + [""]
    end;

.meta as $m
| (.findings // []) as $f
| (($m.checklists // []) - content_type_lists | map(rtrimstr(".md"))) as $persp
| ((([$m.target.diff_command] + ($m.target.context_paths // []))
    | map(select(. != null and . != ""))) ) as $inputs
| ["Critical","High","Medium","Low"] as $order
|
[
  "# Review Report: \($m.id)",
  "",
  "## Metadata",
  "- **Target**: \($m.target.kind) / \($m.id)",
  "- **Content-Type**: diff",
  "- **Perspectives**: \(if ($persp | length) == 0 then "none" else ($persp | join(", ")) end)",
  "- **Reviewed**: \($m.reviewed_at)",
  "- **Input Files**: \(if ($inputs | length) == 0 then "none" else ($inputs | join(", ")) end)",
  "",
  "Checked: \(($m.checklists // []) | join(", "))",
  "",
  "## Findings",
  ""
]
+ (if ($f | length) == 0
   then ["No findings.", ""]
   else ([$order[] as $s | sev_section($s; $f)] | add) end)
+ [
  "## Action Items",
  "",
  "| Priority | Item | Location |",
  "|----------|------|----------|"
]
+ [$order[] as $s | $f[] | select(.severity == $s)
   | "| \(.severity) | \(.title) | \(.anchor.display) |"]
+ [
  "",
  "## Overall Assessment",
  "",
  "**\($m.assessment)**",
  "",
  "## Next Steps",
  "",
  "- If PASS: implement from the document (doc reviews) or commit and open a draft PR (code reviews)",
  "- If NEEDS_REVISION: address every Critical/High finding, then `/my:review \($m.id)` again"
]
| .[]
' "$REVIEW" > "$OUT"
