#!/usr/bin/env bats
# Tests for the outbound-guard exception of scripts/ci/guardrail.sh.
#
# Contract under test:
#   - `tighten <base> <head>` passes a change of only outbound-guard's
#     source, added test cases and bin/ rebuilt from it, and holds one that
#     touches another file, rewrites a test, loosens a decision a test checks,
#     ships a binary not built from the source, or keeps the tests from
#     running.
#   - `gate` lets such a pull request through without the label only when it
#     comes from this repository, HEAD_SHA is its head, the checkout is the
#     base branch's tip and the head contains it.

load ../fake_bin

# The fixture is a repository holding this repository's Go module and
# build script, with bin/ built, on main; the tests add commits to it.
setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  local fixture="$BATS_FILE_TMPDIR/fixture"
  mkdir -p "$fixture/scripts"
  cp -R "$REPO_ROOT/go.mod" "$REPO_ROOT/cmd" "$REPO_ROOT/internal" "$fixture/"
  cp "$REPO_ROOT/scripts/build-bin.sh" "$fixture/scripts/"
  echo "fixture" >"$fixture/README.md"
  (
    cd "$fixture" &&
      scripts/build-bin.sh &&
      git init -q -b main &&
      git add -A &&
      git -c user.name=t -c user.email=t@example.com commit -q -m base
  )
}

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARDRAIL="$REPO_ROOT/scripts/ci/guardrail.sh"
  REPO="$BATS_TEST_TMPDIR/repo"
  cp -R "$BATS_FILE_TMPDIR/fixture" "$REPO"
  cd "$REPO" || return 1
  BASE="$(git rev-parse HEAD)"
  git checkout -q -b feature
}

# commit_head — commit the working tree on feature and set HEAD_COMMIT.
commit_head() {
  git add -A
  git -c user.name=t -c user.email=t@example.com commit -q -m head
  HEAD_COMMIT="$(git rev-parse HEAD)"
}

# append_case NAME BODY — append a case to the guardTests table.
append_case() {
  local file=internal/outboundguard/guard_test.go
  ADD="	{\"$1\", func(f *fx) {
		$2
	}}," awk '
    /^var guardTests = / { in_table = 1 }
    in_table && /^}$/ { print ENVIRON["ADD"]; in_table = 0 }
    { print }
  ' "$file" >"$file.new" && mv "$file.new" "$file"
}

# loosen_run — make Run allow everything.
loosen_run() {
  local file=internal/outboundguard/guard.go
  awk '{ print } /^func Run\(payload \[\]byte, env Env\) \(out string\) \{$/ { print "\tif len(payload) > 0 {\n\t\treturn \"\"\n\t}" }' \
    "$file" >"$file.new" && mv "$file.new" "$file"
  grep -q 'return ""' "$file"
}

@test "tighten: appended cases, a new source file and bin/ rebuilt from them pass" {
  append_case "a merge from an extra case is denied" 'f.guard(`gh pr merge 99`).deny()'
  printf 'package outboundguard\n\nvar extraWords = []string{"x"}\n\nfunc init() { _ = extraWords }\n' >internal/outboundguard/extra.go
  scripts/build-bin.sh
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"only tightens outbound-guard"* ]]
}

@test "tighten: a file outside outbound-guard's source and bin/ is held" {
  echo "more" >>README.md
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"README.md is outside it"* ]]
}

@test "tighten: rewriting an existing case is held" {
  local file=internal/outboundguard/guard_test.go
  grep -q 'f.guard(`gh pr ready 12`).deny()' "$file"
  sed 's/f.guard(`gh pr ready 12`).deny()/f.guard(`gh pr ready 12`).ask()/' "$file" >"$file.new" && mv "$file.new" "$file"
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"changes or removes the base's case"* ]]
}

@test "tighten: a case added in the middle of the table with a loop and a check passes" {
  local file=internal/outboundguard/guard_test.go
  ADD='	{"merges with a body are denied", func(f *fx) {
		for _, c := range []string{`gh pr merge 9 --body ok`, `gh pr merge 9 -s`} {
			f.guard(c).deny()
			if !strings.Contains(f.out, "deny") {
				f.t.Fatalf("command %q: %q", c, f.out)
			}
		}
	}},' awk '{ print } /^	\/\/ --- git push/ && !done { print ENVIRON["ADD"]; done = 1 }' "$file" >"$file.new" && mv "$file.new" "$file"
  grep -q "merges with a body are denied" "$file"
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 0 ]
}

@test "tighten: an added case that reaches past the fixture's helpers is held" {
  append_case "skipped" 'f.t.Skip()'
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"uses .Skip"* ]]
}

@test "tighten: a command the base denied that the head allows is held" {
  loosen_run
  scripts/build-bin.sh
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"go test of the head failed"* ]]
}

@test "tighten: a binary that is not built from the head's source is held" {
  printf 'package outboundguard\n\nfunc init() { _ = []string{"y"} }\n' >internal/outboundguard/extra.go
  scripts/build-bin.sh
  printf 'x' >>bin/my-toolkit-linux-amd64
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/my-toolkit-linux-amd64 is not what scripts/build-bin.sh builds"* ]]
}

@test "tighten: a binary that loses its executable bit is held" {
  chmod 644 bin/my-toolkit-darwin-arm64
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/my-toolkit-darwin-arm64 (M, mode 100644)"* ]]
}

@test "tighten: source for one platform only is held" {
  printf 'package outboundguard\n\nvar onDarwin = true\n' >internal/outboundguard/extra_darwin.go
  scripts/build-bin.sh
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ignores [extra_darwin.go]"* ]]
}

@test "tighten: source that imports a package the base does not is held" {
  printf 'package outboundguard\n\nimport "runtime"\n\nvar onDarwin = runtime.GOOS == "darwin"\n' >internal/outboundguard/extra.go
  scripts/build-bin.sh
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"imports runtime, which the base does not"* ]]
}

@test "tighten: code that exits before the tests run is held" {
  printf 'package outboundguard\n\nimport "os"\n\nfunc init() {\n\tif len(os.Args) > 0 {\n\t\tos.Exit(0)\n\t}\n}\n' \
    >internal/outboundguard/extra.go
  scripts/build-bin.sh
  commit_head
  run bash "$GUARDRAIL" tighten "$BASE" "$HEAD_COMMIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"go test passed 0 of the"* ]]
}

# gate_fixture — a head that passes tighten, an origin holding it as
# refs/pull/7/head, the repository back on main, and a gh stub answering for
# that pull request.
gate_fixture() {
  append_case "a merge from an extra case is denied" 'f.guard(`gh pr merge 99`).deny()'
  commit_head
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git push -q "$BATS_TEST_TMPDIR/origin.git" "main:main" "feature:refs/pull/7/head"
  git remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git checkout -q main
  export HEAD_SHA="$HEAD_COMMIT"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_FILES='[{"filename":"internal/outboundguard/guard_test.go"}]'
  export GH_HEAD_REPO=me/app GH_PR_HEAD="$HEAD_COMMIT" GH_BASE_TIP="$BASE" GH_COMPARE=ahead
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  fake_bin "$BATS_TEST_TMPDIR/bin/gh" <<'STUB'
#!/bin/bash
echo "$*" >>"$GH_LOG"
filter="." path=""
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter="$2"; shift ;;
    repos/*) path="$1" ;;
  esac
  shift
done
case "$path" in
  */pulls/*/files) json="$GH_FILES" ;;
  */pulls/*) json="{\"head\":{\"ref\":\"feature\",\"sha\":\"$GH_PR_HEAD\",\"repo\":{\"full_name\":\"$GH_HEAD_REPO\"}},\"base\":{\"ref\":\"main\"}}" ;;
  */issues/*/labels) json='[]' ;;
  */branches/main) json="{\"commit\":{\"sha\":\"$GH_BASE_TIP\"}}" ;;
  */compare/*) json="{\"status\":\"$GH_COMPARE\"}" ;;
  *) exit 1 ;;
esac
printf '%s' "$json" | jq -r "$filter"
STUB
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "gate: a pull request that only tightens outbound-guard passes without the label" {
  gate_fixture
  run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 0 ]
  [[ "$output" == *"add the label human-approved"* ]]
  [[ "$output" == *"only tightens outbound-guard"* ]]
}

@test "gate: without HEAD_SHA there is no exception" {
  gate_fixture
  unset HEAD_SHA
  run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  run grep -c compare "$GH_LOG"
  [ "$output" = 0 ]
}

@test "gate: a file outside the exception needs the label" {
  gate_fixture
  GH_FILES='[{"filename":"internal/outboundguard/guard.go"},{"filename":"scripts/hooks/outbound-guard.sh"}]' \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/hooks/outbound-guard.sh is outside it"* ]]
}

@test "gate: a head from a fork needs the label, and is not fetched" {
  gate_fixture
  GH_HEAD_REPO=someone/app run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"the head is in someone/app"* ]]
  run git rev-parse -q --verify FETCH_HEAD
  [ "$status" -ne 0 ]
}

@test "gate: a head other than the one CI was started for needs the label" {
  gate_fixture
  GH_PR_HEAD=0000000000000000000000000000000000000000 run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"the head is now 0000000000000000000000000000000000000000"* ]]
}

@test "gate: a checkout that is not the base branch's tip needs the label" {
  gate_fixture
  GH_BASE_TIP=1111111111111111111111111111111111111111 run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"not the tip 1111111111111111111111111111111111111111 of main"* ]]
}

@test "gate: a head that does not contain the base branch's tip needs the label" {
  gate_fixture
  GH_COMPARE=diverged run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"the head is diverged of main; update the branch"* ]]
}
