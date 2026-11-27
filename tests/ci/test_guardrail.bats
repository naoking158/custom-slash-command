#!/usr/bin/env bats
# Tests for scripts/ci/guardrail.sh.
#
# Contract under test:
#   - `paths` prints the guardrails among the names on stdin and fails when
#     there is one.
#   - `gate` passes a pull request that changes no guardrail and holds one
#     that does until it carries the label, added after the last push.

load ../fake_bin

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GUARDRAIL="$REPO_ROOT/scripts/ci/guardrail.sh"
  TMP="$(mktemp -d -t guardrail-test.XXXXXX)"
  export GH_LOG="$TMP/gh.log"
  export GH_FILES='[{"filename":"README.md"}]'
  export GH_LABELS='[]'
  export GH_EVENTS='[]'
  export GH_ACTIVITY='[{"timestamp":"2026-01-02T00:00:00Z"}]'
  mkdir -p "$TMP/bin"
  # The stub answers with GitHub's JSON and applies the --jq filter itself, so
  # the filters in guardrail.sh are part of what is tested.
  fake_bin "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
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
  */pulls/*) json='{"head":{"ref":"feature/x","repo":{"full_name":"me/fork"}}}' ;;
  */issues/*/labels) json="$GH_LABELS" ;;
  */issues/*/events) json="$GH_EVENTS" ;;
  */activity) [ -z "${GH_ACTIVITY_FAILS:-}" ] || exit 1; json="$GH_ACTIVITY" ;;
  *) exit 1 ;;
esac
printf '%s' "$json" | jq -r "$filter"
STUB
  PATH="$TMP/bin:$PATH"
  GUARDED='[{"filename":"README.md"},{"filename":"hooks.json"}]'
  LABELED='[{"name":"bug"},{"name":"human-approved"}]'
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# labeled_at TIME... — the events of a label added at each TIME.
labeled_at() {
  local time out=""
  for time in "$@"; do
    out="$out${out:+,}{\"event\":\"labeled\",\"label\":{\"name\":\"human-approved\"},\"created_at\":\"$time\"}"
  done
  printf '[{"event":"labeled","label":{"name":"bug"},"created_at":"2026-01-09T00:00:00Z"},%s]' "$out"
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

@test "paths: the check script, the CI definition and what applies the deny rules are guardrails" {
  for name in scripts/ci/guardrail.sh mise.toml tests/run.sh orca/settings/goal.deny.json orca/bin/start-goal \
    hooks.json scripts/lib/autonomy.sh scripts/lib/wait-ci.sh .claude/settings.json; do
    run bash -c 'echo "$2" | "$1" paths' _ "$GUARDRAIL" "$name"
    [ "$status" -eq 1 ]
  done
}

@test "gate: a pull request that changes no guardrail passes without reading labels" {
  run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 0 ]
  run grep -c labels "$GH_LOG"
  [ "$output" = 0 ]
}

@test "gate: a guardrail change without the label fails and names the files" {
  GH_FILES="$GUARDED" GH_LABELS='[{"name":"bug"}]' run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"  hooks.json"* ]]
  [[ "$output" != *"  README.md"* ]]
  [[ "$output" == *"add the label human-approved"* ]]
}

@test "gate: a guardrail file renamed away still counts under its old name" {
  GH_FILES='[{"filename":"docs/moved.sh","previous_filename":"scripts/hooks/outbound-guard.sh"}]' \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"  scripts/hooks/outbound-guard.sh"* ]]
}

@test "gate: the label added after the last push passes" {
  GH_FILES="$GUARDED" GH_LABELS="$LABELED" GH_EVENTS="$(labeled_at 2026-01-03T00:00:00Z)" \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 0 ]
  grep -q "repos/me/fork/activity -f ref=refs/heads/feature/x" "$GH_LOG"
}

@test "gate: a push after the label makes the approval stale" {
  GH_FILES="$GUARDED" GH_LABELS="$LABELED" GH_EVENTS="$(labeled_at 2026-01-01T00:00:00Z)" \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 1 ]
  [[ "$output" == *"remove the label and add it again"* ]]
}

@test "gate: the newest of several label events is the one compared" {
  GH_FILES="$GUARDED" GH_LABELS="$LABELED" \
    GH_EVENTS="$(labeled_at 2026-01-03T00:00:00Z 2026-01-01T00:00:00Z)" run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 0 ]
}

@test "gate: the label in another case counts as the label" {
  GH_FILES="$GUARDED" GH_LABELS='[{"name":"Human-Approved"}]' \
    GH_EVENTS='[{"event":"labeled","label":{"name":"Human-Approved"},"created_at":"2026-01-03T00:00:00Z"}]' \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 0 ]
}

@test "gate: when the push time cannot be read the check does not pass" {
  GH_FILES="$GUARDED" GH_LABELS="$LABELED" GH_EVENTS="$(labeled_at 2026-01-03T00:00:00Z)" GH_ACTIVITY_FAILS=1 \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 2 ]

  GH_FILES="$GUARDED" GH_LABELS="$LABELED" GH_EVENTS="$(labeled_at 2026-01-03T00:00:00Z)" GH_ACTIVITY='[]' \
    run bash "$GUARDRAIL" gate me/app 7
  [ "$status" -eq 2 ]
}
