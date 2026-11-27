#!/usr/bin/env bash
# parallel.sh — Run bats files without bats: every @test becomes a shell
# function, and the tests of all files share one pool of N job slots, so a
# run takes about (total test time / N) however the tests are spread over
# files. Each test runs in its own forked subshell, after setup_file of its
# file has run once in the file's process.
#
#   tests/parallel.sh [-j N] [FILE.bats|DIR]...    (default: tests/, N: 2 x CPUs)
#
# Supports the part of bats this repository uses: setup/teardown,
# setup_file/teardown_file, run [-N|!] [--separate-stderr] with $status
# $output $lines $stderr $stderr_lines, skip, load, bats_require_minimum_version,
# BATS_TEST_DIRNAME, BATS_TEST_FILENAME, BATS_TEST_TMPDIR, BATS_FILE_TMPDIR,
# BATS_SUITE_TMPDIR, and TEST_BASH (as tests/setup_suite.bash does).
# Output is TAP per file in file order. TIMING=1 adds each test's ms.
# Exit status: 0 when every test passed, 1 otherwise, 2 on usage error.
set -u

jobs=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j) [ $# -ge 2 ] || { echo "parallel.sh: -j needs a value" >&2; exit 2; }; jobs="$2"; shift 2 ;;
    -j*) jobs="${1#-j}"; shift ;;
    -*) echo "usage: parallel.sh [-j N] [FILE.bats|DIR]..." >&2; exit 2 ;;
    *) break ;;
  esac
done
[ -n "$jobs" ] || jobs=$((2 * $(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)))
case "$jobs" in '' | *[!0-9]* | 0) echo "parallel.sh: -j needs a positive number" >&2; exit 2 ;; esac
[ $# -gt 0 ] || set -- "$(cd "$(dirname "$0")" && pwd)"

files=()
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$arg" -name '*.bats' -type f | LC_ALL=C sort)
  elif [ -f "$arg" ]; then files+=("$arg")
  else echo "parallel.sh: no such file or directory: $arg" >&2; exit 2; fi
done
[ ${#files[@]} -gt 0 ] || { echo "parallel.sh: no .bats files" >&2; exit 2; }

BATS_SUITE_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/parallel-bats.XXXXXX")"
export BATS_SUITE_TMPDIR
trap 'rm -rf "$BATS_SUITE_TMPDIR"' EXIT
if [ -n "${TEST_BASH:-}" ]; then
  [ -x "$TEST_BASH" ] || { echo "TEST_BASH is not an executable: $TEST_BASH" >&2; exit 2; }
  mkdir -p "$BATS_SUITE_TMPDIR/test-bash"
  ln -sf "$TEST_BASH" "$BATS_SUITE_TMPDIR/test-bash/bash"
  export PATH="$BATS_SUITE_TMPDIR/test-bash:$PATH"
fi

# Job slots: a FIFO holding one byte per free slot. A test takes a byte before
# it starts and puts it back when it ends.
mkfifo "$BATS_SUITE_TMPDIR/slots"
exec 3<>"$BATS_SUITE_TMPDIR/slots"
i=0
while [ "$i" -lt "$jobs" ]; do printf x >&3; i=$((i + 1)); done

bats_require_minimum_version() { :; }
load() {
  local f="$BATS_TEST_DIRNAME/$1"
  [ -f "$f.bash" ] && f="$f.bash"
  # shellcheck source=/dev/null
  . "$f"
}
skip() {
  printf '%s\n' "${1:-skipped}" >"$__skip_file"
  exit 0
}

# __split NAME TEXT — NAME=(lines of TEXT), without empty lines (as bats).
__split() {
  local __l __a=()
  while IFS= read -r __l || [ -n "$__l" ]; do
    [ -n "$__l" ] && __a+=("$__l")
  done <<<"$2"
  eval "$1=(\"\${__a[@]+\"\${__a[@]}\"}\")"
}

run() {
  local expect="" sep=0 errf
  while :; do
    case "${1:-}" in
      -[0-9]*) expect="${1#-}"; shift ;;
      !) expect='!'; shift ;;
      --separate-stderr) sep=1; shift ;;
      --keep-empty-lines) echo "run: --keep-empty-lines is not supported by tests/parallel.sh" >&2; return 1 ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  set +eE
  if [ "$sep" = 1 ]; then
    errf="${BATS_TEST_TMPDIR%.tmp}.stderr"
    output="$("$@" 2>"$errf")"
    status=$?
    stderr=""
    IFS= read -r -d '' stderr <"$errf"
    while [ "${stderr%$'\n'}" != "$stderr" ]; do stderr="${stderr%$'\n'}"; done
    __split stderr_lines "$stderr"
  else
    output="$("$@" 2>&1)"
    status=$?
  fi
  set -eE
  __split lines "$output"
  case "$expect" in
    "") ;;
    '!') [ "$status" -ne 0 ] || { echo "run !: expected a non-zero status, got 0" >&2; return 1; } ;;
    *) [ "$status" -eq "$expect" ] || { echo "run -$expect: got status $status, output: $output" >&2; return 1; } ;;
  esac
  return 0
}

# __test I — setup, test I and teardown in the current subshell.
__test() {
  __rc=0
  trap '__rc=$?; if declare -F teardown >/dev/null; then teardown || __rc=1; fi; exit $__rc' EXIT
  set -eE
  if declare -F setup >/dev/null; then setup; fi
  "__t_$1"
}

# __now_ms — milliseconds since the epoch; nothing before bash 5.
__now_ms() {
  [ -n "${EPOCHREALTIME:-}" ] || return 0
  local t="${EPOCHREALTIME/[.,]/}"
  echo $((t / 1000))
}

# __stop_test_groups — stop the process group of every running test and exit.
__stop_test_groups() {
  local pid
  for pid in $(jobs -p); do kill -TERM -- "-$pid" 2>/dev/null; done
  exit 130
}

# run_file FILE OUTDIR — run the tests of FILE and write its TAP to OUTDIR/tap.
run_file() {
  local __file="$1" __out="$2" __src __n __i __t0
  set +u
  BATS_TEST_DIRNAME="$(cd "$(dirname "$__file")" && pwd)"
  BATS_TEST_FILENAME="$BATS_TEST_DIRNAME/$(basename "$__file")"
  BATS_FILE_TMPDIR="$__out/file.tmp"
  export BATS_TEST_DIRNAME BATS_TEST_FILENAME BATS_FILE_TMPDIR
  __src="$__out/src.sh"
  awk -v names="$__out/names" '
    /^@test "/ {
      n++; name = $0
      sub(/^@test "/, "", name); sub(/" *\{ *$/, "", name)
      gsub(/\\\$/, "$", name); gsub(/\\"/, "\"", name)
      print name > names; print "__t_" n "() {"; next
    }
    { print }' "$__file" >"$__src"
  : >>"$__out/names"
  __n=0
  local __dirs=("$BATS_FILE_TMPDIR") __name
  while IFS= read -r __name; do
    __n=$((__n + 1))
    __dirs+=("$__out/t$__n.tmp")
  done <"$__out/names"
  mkdir "${__dirs[@]}"
  # shellcheck source=/dev/null
  . "$__src"
  if declare -F setup_file >/dev/null; then
    # Runs in this process so that its exports reach the tests, as in bats.
    # A failing command ends the process through the EXIT trap.
    trap '{ echo "not ok 1 setup_file failed"; sed "s/^/# /" "$__out/setup_file.log"; } >"$__out/tap"' EXIT
    set -eE
    setup_file >"$__out/setup_file.log" 2>&1
    set +eE
    trap - EXIT
  fi
  # Each test runs in its own process group, so that an interrupt stops the
  # commands it started as well.
  set -m
  trap __stop_test_groups INT TERM
  __i=1
  while [ "$__i" -le "$__n" ]; do
    read -r -n 1 _ <&3
    (
      BATS_TEST_NUMBER=$__i
      BATS_TEST_TMPDIR="$__out/t$__i.tmp"
      __skip_file="$__out/t$__i.skip"
      export BATS_TEST_NUMBER BATS_TEST_TMPDIR
      [ -z "${TIMING:-}" ] || __t0=$(__now_ms)
      (__test "$__i") >"$__out/t$__i.log" 2>&1 </dev/null 3>&-
      echo $? >"$__out/t$__i.rc"
      [ -z "${__t0:-}" ] || echo $(($(__now_ms) - __t0)) >"$__out/t$__i.ms"
      printf x >&3
    ) &
    __i=$((__i + 1))
  done
  wait
  set +m
  if declare -F teardown_file >/dev/null && ! (set -eE; teardown_file) >"$__out/teardown_file.log" 2>&1; then
    : >"$__out/teardown_file.failed"
  fi
  local __fail=0 __rc __msg __ms
  __i=1
  while IFS= read -r __name; do
    __rc=missing __msg="" __ms=""
    [ ! -f "$__out/t$__i.rc" ] || read -r __rc <"$__out/t$__i.rc"
    if [ -s "$__out/t$__i.skip" ]; then
      read -r __msg <"$__out/t$__i.skip"
      echo "ok $__i $__name # skip $__msg"
    elif [ "$__rc" = 0 ]; then
      [ ! -f "$__out/t$__i.ms" ] || read -r __ms <"$__out/t$__i.ms"
      echo "ok $__i $__name${__ms:+ # ${__ms}ms}"
    else
      echo "not ok $__i $__name"
      sed 's/^/# /' "$__out/t$__i.log"
      __fail=1
    fi
    __i=$((__i + 1))
  done <"$__out/names" >"$__out/tap"
  return $__fail
}

trap 'kill $(jobs -p) 2>/dev/null; exit 130' INT TERM
outs=()
k=0
while [ "$k" -lt ${#files[@]} ]; do
  outs+=("$BATS_SUITE_TMPDIR/f$k")
  k=$((k + 1))
done
mkdir "${outs[@]}"
k=0
for f in "${files[@]}"; do
  # bash reports a failed setpgid of a test's process group on stderr; the
  # file's other errors are shown after the run.
  (run_file "$f" "$BATS_SUITE_TMPDIR/f$k") 2>"$BATS_SUITE_TMPDIR/f$k/stderr" &
  k=$((k + 1))
done
wait

total=0 failed=0 expected=0
k=0
for f in "${files[@]}"; do
  echo "# $f"
  while IFS= read -r line; do
    printf '%s\n' "$line"
    case "$line" in
      "ok "*) total=$((total + 1)) ;;
      "not ok "*) total=$((total + 1)) failed=$((failed + 1)) ;;
    esac
  done <"$BATS_SUITE_TMPDIR/f$k/tap"
  while IFS= read -r line; do
    case "$line" in *"child setpgid"*) ;; *) printf '%s\n' "$line" >&2 ;; esac
  done <"$BATS_SUITE_TMPDIR/f$k/stderr"
  expected=$((expected + $(grep -c '^@test ' "$f")))
  if [ -f "$BATS_SUITE_TMPDIR/f$k/teardown_file.failed" ]; then
    echo "# teardown_file of $f failed:"
    sed 's/^/# /' "$BATS_SUITE_TMPDIR/f$k/teardown_file.log"
    failed=$((failed + 1))
  fi
  k=$((k + 1))
done
echo "# $total tests, $failed failed"
if [ "$total" -ne "$expected" ]; then
  echo "# the files hold $expected tests but $total reported" >&2
  exit 1
fi
[ "$failed" -eq 0 ]
