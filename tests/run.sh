#!/usr/bin/env bash
# run.sh — Run every bats suite twice: with the bash on PATH, then with
# /bin/bash (3.2 on macOS), the shell Claude Code hooks run under there.
#
#   tests/run.sh [bats options]
#
# Exits non-zero when either run fails or bats is missing.
set -u
cd "$(dirname "$0")/.." || exit 2
command -v bats >/dev/null || { echo "run.sh: bats not found" >&2; exit 127; }
status=0
echo "# bash on PATH: $(bash -c 'echo $BASH_VERSION')"
bats -r "$@" tests/ || status=1
if [ -x /bin/bash ]; then
  echo "# /bin/bash: $(/bin/bash -c 'echo $BASH_VERSION')"
  TEST_BASH=/bin/bash bats -r "$@" tests/ || status=1
fi
exit "$status"
