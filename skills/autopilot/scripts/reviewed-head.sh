#!/usr/bin/env bash
# reviewed-head.sh — Tell whether a PR's head is covered by a passing review.
#
#   reviewed-head.sh <worktree> <reviews-dir> <pr> <sha> [<default-ref>]
#
# <reviews-dir> is where `my:review --report-dir` wrote, and the report names
# are the ones skills/review/scripts/report-path.sh gives. <sha> is covered
# when one of these holds:
#   - a PASS report of a full review of <sha>: prs/<pr>-<sha7>[-<k>].md
#   - a PASS report of a delta review that ends at <sha>,
#     prs/<pr>-<since7>..<sha7>[-<k>].md, where <since> is an ancestor of
#     <sha> and is itself covered
#   - with <default-ref>: <sha> is a merge of a commit of <default-ref> into a
#     covered commit, what the default branch brought in shares no file with
#     what the PR changes, and the merge's tree is the one git merges to (no
#     change made by hand in the merge commit)
#
# Prints the report that covers <sha> (with a note for the merge case) and
# exits 0; exits 1 with the reason on stderr when nothing covers it, 2 on a
# usage error or an unknown commit.
set -euo pipefail

if [ $# -lt 4 ] || [ $# -gt 5 ]; then
  echo "usage: reviewed-head.sh <worktree> <reviews-dir> <pr> <sha> [<default-ref>]" >&2
  exit 2
fi
repo="$1" dir="$2/prs" pr="$3" default_ref="${5:-}"

commit() {
  git -C "$repo" rev-parse --verify -q "$1^{commit}"
}

head="$(commit "$4")" || {
  echo "reviewed-head.sh: unknown commit: $4" >&2
  exit 2
}
if [ -n "$default_ref" ] && ! commit "$default_ref" >/dev/null; then
  echo "reviewed-head.sh: unknown ref: $default_ref" >&2
  exit 2
fi

# passed <report> — the report's verdict line says PASS and none says
# NEEDS_REVISION. A verdict line is `**PASS**` as template.md writes it, or
# `**Assessment**: PASS` and the like.
passed() {
  local verdicts
  [ -f "$1" ] || return 1
  verdicts="$(grep -Ex '\*\*(PASS|NEEDS_REVISION)\*\*|\*{0,2}(Overall )?Assessment\*{0,2}:? *\*{0,2}(PASS|NEEDS_REVISION)\*{0,2}' "$1")" || return 1
  case "$verdicts" in *NEEDS_REVISION*) return 1 ;; esac
}

# covered <full sha> — print the report that covers it.
covered() {
  local sha="$1" s7="${1:0:7}" f since parents p1 p2 report shared
  for f in "$dir/$pr-$s7.md" "$dir/$pr-$s7"-[0-9]*.md; do
    if passed "$f"; then
      echo "$f"
      return 0
    fi
  done
  for f in "$dir/$pr"-???????.."$s7".md "$dir/$pr"-???????.."$s7"-[0-9]*.md; do
    passed "$f" || continue
    since="${f##*/}"
    since="${since#"$pr"-}"
    since="$(commit "${since%%..*}")" || continue
    git -C "$repo" merge-base --is-ancestor "$since" "$sha" || continue
    covered "$since" >/dev/null || continue
    echo "$f"
    return 0
  done
  [ -n "$default_ref" ] || return 1
  read -r _ p1 p2 parents <<<"$(git -C "$repo" rev-list --parents -n 1 "$sha")"
  [ -n "${p2:-}" ] && [ -z "${parents:-}" ] || return 1
  git -C "$repo" merge-base --is-ancestor "$p2" "$default_ref" || return 1
  report="$(covered "$p1")" || return 1
  shared="$(comm -12 \
    <(git -C "$repo" diff --name-only --no-renames "$p1...$p2" | sort) \
    <(git -C "$repo" diff --name-only --no-renames "$p2...$p1" | sort))"
  [ -z "$shared" ] || return 1
  [ "$(git -C "$repo" merge-tree --write-tree "$p1" "$p2")" = "$(git -C "$repo" rev-parse "$sha^{tree}")" ] || return 1
  echo "$report (then a merge of $default_ref sharing no file: ${sha:0:7})"
}

if ! covered "$head"; then
  echo "reviewed-head.sh: no passing review covers ${head:0:7} of PR $pr in $dir" >&2
  exit 1
fi
