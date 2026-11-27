#!/usr/bin/env bash
# parallel.sh — Run bats files without bats: every @test becomes a shell
# function, and the tests of all files share one pool of N job slots, so a
# run takes about (total test time / N) however the tests are spread over
# files. Each test runs in its own forked subshell, after setup_file of its
# file has run once in the file's process.
#
#   tests/parallel.sh [-j N] [FILE.bats|DIR]...    (default: tests/, N: CPUs)
#
# Supports the part of bats this repository uses: setup/teardown,
# setup_file/teardown_file, run [-N|-!] [--separate-stderr] with $status
# $output $lines $stderr $stderr_lines, skip, load, bats_require_minimum_version,
# BATS_TEST_DIRNAME, BATS_TEST_FILENAME, BATS_TEST_TMPDIR, BATS_FILE_TMPDIR,
# BATS_SUITE_TMPDIR, and TEST_BASH (as tests/setup_suite.bash does).
# Output is TAP per file in file order. TIMING=1 adds each test's ms.
# Exit status: 0 when every test passed, 1 otherwise, 2 on usage error.
set -u

jobs=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j) jobs="${2:-}"; shift 2 ;;
    -j*) jobs="${1#-j}"; shift ;;
    -*) echo "usage: parallel.sh [-j N] [FILE.bats|DIR]..." >&2; exit 2 ;;
    *) break ;;
  esac
done
[ -n "$jobs" ] || jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
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
      -!) expect='!'; shift ;;
      --separate-stderr) sep=1; shift ;;
      --keep-empty-lines) shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  set +eE
  if [ "$sep" = 1 ]; then
    errf="$BATS_TEST_TMPDIR/.run-stderr"
    output="$("$@" 2>"$errf")"
    status=$?
    stderr="$(cat "$errf")"
    rm -f "$errf"
    __split stderr_lines "$stderr"
  else
    output="$("$@" 2>&1)"
    status=$?
  fi
  set -eE
  __split lines "$output"
  case "$expect" in
    "") ;;
    '!') [ "$status" -ne 0 ] || { echo "run -!: expected a non-zero status, got 0" >&2; return 1; } ;;
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

# run_file FILE OUTDIR — run the tests of FILE and write its TAP to OUTDIR/tap.
run_file() {
  local file="$1" out="$2" src n i t0
  BATS_TEST_DIRNAME="$(cd "$(dirname "$file")" && pwd)"
  BATS_TEST_FILENAME="$BATS_TEST_DIRNAME/$(basename "$file")"
  BATS_FILE_TMPDIR="$out/file.tmp"
  mkdir -p "$BATS_FILE_TMPDIR"
  export BATS_TEST_DIRNAME BATS_TEST_FILENAME BATS_FILE_TMPDIR
  src="$out/src.sh"
  awk -v names="$out/names" '
    /^@test "/ {
      n++; name = $0
      sub(/^@test "/, "", name); sub(/" *\{ *$/, "", name)
      gsub(/\\\$/, "$", name); gsub(/\\"/, "\"", name)
      print name > names; print "__t_" n "() {"; next
    }
    { print }' "$file" >"$src"
  : >>"$out/names"
  n=$(wc -l <"$out/names" | tr -d ' ')
  # shellcheck source=/dev/null
  . "$src"
  if declare -F setup_file >/dev/null; then
    # Runs in this process so that its exports reach the tests, as in bats.
    # A failing command ends the process through the EXIT trap.
    trap '{ echo "not ok 1 setup_file failed"; sed "s/^/# /" "$out/setup_file.log"; } >"$out/tap"' EXIT
    set -eE
    setup_file >"$out/setup_file.log" 2>&1
    set +eE
    trap - EXIT
  fi
  i=1
  while [ "$i" -le "$n" ]; do
    read -r -n 1 _ <&3
    (
      BATS_TEST_NUMBER=$i
      BATS_TEST_TMPDIR="$out/t$i.tmp"
      __skip_file="$out/t$i.skip"
      mkdir "$BATS_TEST_TMPDIR"
      export BATS_TEST_NUMBER BATS_TEST_TMPDIR
      [ -z "${TIMING:-}" ] || t0=$(__now_ms)
      (__test "$i") >"$out/t$i.log" 2>&1 </dev/null 3>&-
      echo $? >"$out/t$i.rc"
      [ -z "${t0:-}" ] || echo $(($(__now_ms) - t0)) >"$out/t$i.ms"
      printf x >&3
    ) &
    i=$((i + 1))
  done
  wait
  if declare -F teardown_file >/dev/null; then teardown_file >/dev/null 2>&1 || true; fi
  local fail=0 name rc msg ms
  i=1
  while IFS= read -r name; do
    rc=missing msg="" ms=""
    [ ! -f "$out/t$i.rc" ] || read -r rc <"$out/t$i.rc"
    if [ -s "$out/t$i.skip" ]; then
      read -r msg <"$out/t$i.skip"
      echo "ok $i $name # skip $msg"
    elif [ "$rc" = 0 ]; then
      [ ! -f "$out/t$i.ms" ] || read -r ms <"$out/t$i.ms"
      echo "ok $i $name${ms:+ # ${ms}ms}"
    else
      echo "not ok $i $name"
      sed 's/^/# /' "$out/t$i.log"
      fail=1
    fi
    i=$((i + 1))
  done <"$out/names" >"$out/tap"
  return $fail
}

k=0
for f in "${files[@]}"; do
  mkdir -p "$BATS_SUITE_TMPDIR/f$k"
  (run_file "$f" "$BATS_SUITE_TMPDIR/f$k") &
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
  expected=$((expected + $(grep -c '^@test ' "$f")))
  k=$((k + 1))
done
echo "# $total tests, $failed failed"
if [ "$total" -ne "$expected" ]; then
  echo "# the files hold $expected tests but $total reported" >&2
  exit 1
fi
[ "$failed" -eq 0 ]
