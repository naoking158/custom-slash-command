# Suite setup for `bats -r tests/`.
#
# TEST_BASH=<path> runs every script the tests start through `bash` or a
# `#!/usr/bin/env bash` shebang with that bash instead of the first one on
# PATH. macOS hooks run under /bin/bash 3.2, so run the suite once more with
# TEST_BASH=/bin/bash (tests/run.sh does both). bats picks this file up only
# when given the tests/ directory itself (`bats -r tests/`); a run of one
# subdirectory or file ignores TEST_BASH.

setup_suite() {
  [ -n "${TEST_BASH:-}" ] || return 0
  [ -x "$TEST_BASH" ] || {
    echo "TEST_BASH is not an executable: $TEST_BASH" >&2
    return 1
  }
  mkdir -p "$BATS_SUITE_TMPDIR/test-bash"
  ln -sf "$TEST_BASH" "$BATS_SUITE_TMPDIR/test-bash/bash"
  export PATH="$BATS_SUITE_TMPDIR/test-bash:$PATH"
}
