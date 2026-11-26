#!/usr/bin/env bash
# patch-id.sh — Print the stable patch-id of the diff between two refs.
#
#   scripts/lib/patch-id.sh <base-ref> <head-ref> [repo-dir]
#
# The id depends only on the change itself (`git patch-id --verbatim`, which
# unlike --stable keeps whitespace), so the same change on top of a different
# base prints the same id and a whitespace-only difference does not. A branch whose id
# is unchanged after merging its parent can keep its earlier review and verify
# verdicts. <base-ref> is expected to be an ancestor of <head-ref> (the parent
# branch after it was merged in): when the base moves on alone, the diff and
# so the id change too, which only makes earlier verdicts stale. An empty diff
# prints `empty`.
#
# Exit status: 0 printed the id, 2 usage error, invalid ref or not a repository.
# Dependencies: bash, git.
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "usage: patch-id.sh <base-ref> <head-ref> [repo-dir]" >&2
  exit 2
fi
base="$1" head="$2" repo="${3:-.}"

for ref in "$base" "$head"; do
  if ! git -C "$repo" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1; then
    echo "patch-id.sh: not a commit in $repo: $ref" >&2
    exit 2
  fi
done

id="$(git -C "$repo" diff --no-color --no-ext-diff "$base..$head" | git patch-id --verbatim | cut -d' ' -f1)"
printf '%s\n' "${id:-empty}"
