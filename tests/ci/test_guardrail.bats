#!/usr/bin/env bats
# Tests for scripts/ci/guardrail.sh.
#
# Contract under test:
#   - `paths` prints the guardrails among the names on stdin and fails when
#     there is one.
#   - `gate` passes a pull request that changes no guardrail, holds one that
#     does until it carries the label, and removes the label when new commits
#     arrive.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARDRAIL="$REPO_ROOT/scripts/ci/guardrail.sh"
  TMP="$(mktemp -d -t guardrail-test.XXXXXX)"
  export GH_LOG="$TMP/gh.log"
  export GH_FILES="README.md"
  export GH_LABELS=""
  mkdir -p "$TMP/bin"
  cat >"$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
case "$*" in
  *"--method DELETE"*) [ -z "${GH_DELETE_FAILS:-}" ] || exit 1 ;;
  *"/pulls/"*"/files"*) for name in $GH_FILES; do echo "$name"; done ;;
  *"/issues/"*"/labels"*) for name in $GH_LABELS; do echo "$name"; done ;;
esac
STUB
  chmod +x "$TMP/bin/gh"
  PATH="$TMP/bin:$PATH"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

@test "paths: prints the guardrails and exits 1" {
  run bash -c 'printf "%s\n" README.md scripts/hooks/outbound-guard.sh .github/workflows/ci.yml skills/autopilot/SKILL.md skills/autopilot/goal-template.md | "$1" paths' _ "$GUARDRAIL"
  [ "$status" -eq 1 ]
  [ "$output" = "scripts/hooks/outbound-guard.sh
.github/workflows/ci.yml
skills/autopilot/SKILL.md" ]
}

@test "paths: exits 0 and prints nothing when no guardrail is named" {
  run bash -c 'printf "%s\n" README.md skills/review/SKILL.md scripts/lib/toolkit.sh | "$1" paths' _ "$GUARDRAIL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "paths: the check script, the CI task definitions and the goal deny rules are guardrails" {
  for name in scripts/ci/guardrail.sh mise.toml tests/run.sh orca/settings/goal.deny.json hooks.json scripts/lib/autonomy.sh; do
    run bash -c 'echo "$2" | "$1" paths' _ "$GUARDRAIL" "$name"
    [ "$status" -eq 1 ]
  done
}

@test "gate: a pull request that changes no guardrail passes without reading labels" {
  run "$GUARDRAIL" gate me/app 7 opened
  [ "$status" -eq 0 ]
  ! grep -q labels "$GH_LOG"
}

@test "gate: a guardrail change without the label fails and names the files" {
  GH_FILES="README.md hooks.json" GH_LABELS="bug" run "$GUARDRAIL" gate me/app 7 opened
  [ "$status" -eq 1 ]
  [[ "$output" == *"  hooks.json"* ]]
  [[ "$output" == *"human-approved"* ]]
}

@test "gate: a guardrail change with the label passes" {
  GH_FILES="hooks.json" GH_LABELS="bug human-approved" run "$GUARDRAIL" gate me/app 7 labeled
  [ "$status" -eq 0 ]
}

@test "gate: new commits remove the label and the check fails again" {
  GH_FILES="hooks.json" GH_LABELS="human-approved" run "$GUARDRAIL" gate me/app 7 synchronize
  [ "$status" -eq 1 ]
  grep -q -- "--method DELETE repos/me/app/issues/7/labels/human-approved" "$GH_LOG"
}

@test "gate: when the label cannot be removed the check does not pass" {
  GH_FILES="hooks.json" GH_LABELS="human-approved" GH_DELETE_FAILS=1 run "$GUARDRAIL" gate me/app 7 synchronize
  [ "$status" -eq 2 ]
}

@test "gate: new commits on a pull request without guardrail changes leave labels alone" {
  GH_LABELS="human-approved" run "$GUARDRAIL" gate me/app 7 synchronize
  [ "$status" -eq 0 ]
  ! grep -q DELETE "$GH_LOG"
}
