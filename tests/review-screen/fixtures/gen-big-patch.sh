#!/usr/bin/env bash
# gen-big-patch.sh — Emit a synthetic unified diff with exactly <n> hunks.
#
# Large patches are generated rather than committed, so the repo stays small.
# Used by the 4-digit hunk-id width test (1200 hunks) and the §8 perf run
# (268 hunks).
#
# Usage: gen-big-patch.sh <n> <out-file>
#
# Exit codes:
#   0 = wrote <out-file>
#   1 = bad arguments
#
# Dependencies: bash, awk (NFR-001: no python/node).
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: gen-big-patch.sh <n> <out-file>" >&2
  exit 1
fi

n="$1"
out="$2"

if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
  echo "gen-big-patch.sh: <n> must be a positive integer" >&2
  exit 1
fi

awk -v n="$n" 'BEGIN {
  per_file = 4
  h = 0
  f = 0
  while (h < n) {
    f++
    printf "diff --git a/src/gen%04d.ts b/src/gen%04d.ts\n", f, f
    printf "index 1111111..2222222 100644\n"
    printf "--- a/src/gen%04d.ts\n", f
    printf "+++ b/src/gen%04d.ts\n", f
    for (k = 0; k < per_file && h < n; k++) {
      h++
      start = 1 + k * 20
      printf "@@ -%d,3 +%d,4 @@ function gen%d()\n", start, start, h
      printf " const keep%d = %d;\n", h, h
      printf "-const old%d = %d;\n", h, h
      printf "+const new%d = %d;\n", h, h
      printf "+const extra%d = %d;\n", h, h
      printf " return keep%d;\n", h
    }
  }
}' > "$out"
