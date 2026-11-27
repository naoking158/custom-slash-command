#!/usr/bin/env bash
# all-parallel.sh — Run every test once with the bash on PATH: the bats files
# through tests/parallel.sh and the Go packages through go test, side by side.
# tests/run.sh (bats under the bash on PATH and /bin/bash, then go test) stays
# the gate that CI runs.
#
#   tests/all-parallel.sh [-j N]
#
# Exit status: 0 when every test passed, 1 otherwise, 127 without go.
set -u
cd "$(dirname "$0")/.." || exit 2
command -v go >/dev/null || { echo "all-parallel.sh: go not found" >&2; exit 127; }
go_out="$(mktemp)"
trap 'rm -f "$go_out"' EXIT
go test -count=1 -v ./... >"$go_out" 2>&1 &
go_pid=$!
tests/parallel.sh "$@"
status=$?
wait "$go_pid" || status=1
# Count the tests that have no subtests: a parent passes when its subtests do.
counts="$(awk '$1 == "---" && ($2 == "PASS:" || $2 == "FAIL:") { r[$3] = $2 }
  END { for (n in r) for (m in r) if (index(m, n "/") == 1) { delete r[n]; break }
        for (n in r) { t++; if (r[n] == "FAIL:") f++ } printf "%d %d", t, f }' "$go_out")"
[ "${counts#* }" -eq 0 ] || grep -B2 -A20 -- '--- FAIL' "$go_out"
echo "# go test: ${counts% *} tests, ${counts#* } failed"
exit "$status"
