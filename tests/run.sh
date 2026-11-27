#!/usr/bin/env bash
# run.sh — Run every bats suite with the bash on PATH, then with /bin/bash
# (3.2 on macOS, the shell Claude Code hooks run under there) when that is a
# different version, then the Go tests.
#
#   tests/run.sh [bats options]
#
# Exits non-zero when a run fails or bats or go is missing.
set -u
cd "$(dirname "$0")/.." || exit 2
command -v bats >/dev/null || { echo "run.sh: bats not found" >&2; exit 127; }
command -v go >/dev/null || { echo "run.sh: go not found" >&2; exit 127; }
status=0
on_path="$(bash -c 'echo $BASH_VERSION')"
echo "# bash on PATH: $on_path"
bats -r "$@" tests/ || status=1
if [ -x /bin/bash ] && [ "$(/bin/bash -c 'echo $BASH_VERSION')" != "$on_path" ]; then
  echo "# /bin/bash: $(/bin/bash -c 'echo $BASH_VERSION')"
  TEST_BASH=/bin/bash bats -r "$@" tests/ || status=1
fi
echo "# go test"
go test -count=1 ./... || status=1
exit "$status"
