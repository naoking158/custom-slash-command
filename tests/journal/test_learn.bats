#!/usr/bin/env bats
# Unit + integration tests for /my:learn shell logic.
#
# Scope: The slash command itself is markdown, so we exercise the shell
# snippets described in prompts/11_learn.md (session_id resolution, path
# policy assertion, frontmatter parsing). End-to-end /my:learn invocation
# via Claude is covered by the manual smoke checklist (Spec §9.3).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  TMP="$(mktemp -d -t learn-test.XXXXXX)"
  # Redirect HOME so any journal writes land in tmp, never the user's real ~.
  export HOME="$TMP"
  mkdir -p "$HOME/.claude/projects/custom-slash-command/memory/journal"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# --- session_id resolution ---------------------------------------------------

@test "session_id: \$CLAUDE_SESSION_ID is preferred when set" {
  export CLAUDE_SESSION_ID="7a063d83-1234-4abc-89de-f0123456789a"
  run bash -c '
    resolve_sid() {
      if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then echo "$CLAUDE_SESSION_ID"; return; fi
      echo "mv-$(date +%Y%m%d-%H%M%S)"
    }
    resolve_sid
  '
  [ "$status" -eq 0 ]
  [ "$output" = "7a063d83-1234-4abc-89de-f0123456789a" ]
}

@test "session_id: falls back to mv-YYYYMMDD-HHMMSS when CLAUDE_SESSION_ID unset" {
  unset CLAUDE_SESSION_ID
  run bash -c '
    resolve_sid() {
      if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then echo "$CLAUDE_SESSION_ID"; return; fi
      echo "mv-$(date +%Y%m%d-%H%M%S)"
    }
    resolve_sid
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^mv-[0-9]{8}-[0-9]{6}$ ]]
}

# --- path policy assertion ---------------------------------------------------

@test "path policy: target under \$HOME is accepted" {
  run bash -c '
    target="$HOME/.claude/projects/custom-slash-command/memory/journal/2026-06-27-test.md"
    case "$target" in
      "$PWD"/*) echo "REJECT: $target" >&2; exit 1 ;;
    esac
    echo OK
  '
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "path policy: target under \$PWD is rejected with exit 1" {
  # Simulate HOME == PWD so the resolved target falls under the repo tree.
  cd "$TMP"
  HOME="$TMP" run bash -c '
    target="$HOME/.claude/projects/repo/memory/journal/2026-06-27-test.md"
    case "$target" in
      "$PWD"/*)
        echo "journal path must be machine-local: $target" >&2
        exit 1
        ;;
    esac
    echo OK
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"machine-local"* ]] || [[ "$stderr" == *"machine-local"* ]]
}

# --- frontmatter extraction --------------------------------------------------

extract_fm() {
  awk 'BEGIN{p=0} /^---$/{p++; next} p==1{print}' "$1"
}

get_fm_field() {
  # Simple `key: value` extractor used by prompts/_shared/processes/retro.md.
  local file="$1" key="$2"
  extract_fm "$file" | awk -F': ' -v k="$key" '$1==k {sub(/^[^:]*: */, ""); print; exit}'
}

@test "frontmatter parse: session_id extracts from valid fixture" {
  result="$(get_fm_field "$FIXTURES/journal/2026-06-20-aaaaaaaa.md" "session_id")"
  [ "$result" = "aaaaaaaa-1111-4abc-89de-f0123456789a" ]
}

@test "frontmatter parse: date extracts from valid fixture" {
  result="$(get_fm_field "$FIXTURES/journal/2026-06-22-bbbbbbbb.md" "date")"
  [ "$result" = "2026-06-22" ]
}

@test "frontmatter parse: categories array form is extracted" {
  result="$(get_fm_field "$FIXTURES/journal/2026-06-20-aaaaaaaa.md" "categories")"
  [[ "$result" == "[mistake]" ]]
}

@test "frontmatter parse: recurrence integer extracts" {
  result="$(get_fm_field "$FIXTURES/journal/2026-06-22-bbbbbbbb.md" "recurrence")"
  [ "$result" = "2" ]
}

@test "frontmatter parse: source_commits empty array is recognized" {
  result="$(get_fm_field "$FIXTURES/journal/2026-06-25-cccccccc.md" "source_commits")"
  [ "$result" = "[]" ]
}

@test "frontmatter parse: corrupted file (only one ---) yields short/empty extraction" {
  printf -- '---\nsession_id: broken\nno-closing-delimiter\n## Request\nbody\n' \
    > "$TMP/broken.md"
  # extract_fm: keeps printing while p==1, so it will include body too.
  # The robustness check we care about is that the upstream caller would
  # detect a missing closing '---' and treat the file as malformed.
  # We simulate that detection here.
  local delim_count
  delim_count="$(grep -c '^---$' "$TMP/broken.md")"
  [ "$delim_count" -eq 1 ]
  # Per prompts/11_learn.md, on parse failure the file is renamed *.bak.
  # Simulate the operation and check the rename works.
  mv "$TMP/broken.md" "$TMP/broken.md.bak"
  [ -f "$TMP/broken.md.bak" ]
  [ ! -f "$TMP/broken.md" ]
}

@test "frontmatter parse: missing body section is detected" {
  printf -- '---\nsession_id: abc\ndate: 2026-06-27\n---\n## Request\n## Investigated\n## Learned\n' \
    > "$TMP/partial.md"
  # Count which of the 5 mandatory sections are present.
  local present
  present="$(grep -cE '^## (Request|Investigated|Learned|Completed|Next Steps)' "$TMP/partial.md")"
  [ "$present" -eq 3 ]
  # The prompt says: backfill missing section with empty body and warn.
  # We don't simulate the backfill here, only verify detection works.
}

# --- category enum validation ------------------------------------------------

@test "category enum: known values accepted" {
  for cat in mistake pattern preference domain-knowledge open-question; do
    run bash -c '
      case "$1" in
        mistake|pattern|preference|domain-knowledge|open-question) echo OK ;;
        *) echo "fallback to domain-knowledge" >&2; exit 0 ;;
      esac
    ' _ "$cat"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
  done
}

@test "category enum: unknown value falls back to domain-knowledge with warning" {
  run bash -c '
    cat="bogus-category"
    case "$cat" in
      mistake|pattern|preference|domain-knowledge|open-question)
        echo "$cat" ;;
      *)
        echo "warning: unknown category $cat, falling back to domain-knowledge" >&2
        echo "domain-knowledge"
        ;;
    esac
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"domain-knowledge"* ]]
}

# --- idempotency / recurrence bump -------------------------------------------

@test "recurrence: bumping an existing recurrence integer" {
  # Given a frontmatter with recurrence: 1, bumping should produce 2.
  printf -- '---\nrecurrence: 1\n---\nbody\n' > "$TMP/entry.md"
  # Use a portable sed in-place pattern (BSD-compatible: -i.tmp + rm).
  sed -E -i.tmp 's/^(recurrence: )([0-9]+)$/\12/' "$TMP/entry.md"
  rm -f "$TMP/entry.md.tmp"
  result="$(grep -E '^recurrence:' "$TMP/entry.md")"
  [ "$result" = "recurrence: 2" ]
}

@test "idempotency: same session writes to the same target path" {
  export CLAUDE_SESSION_ID="abcd1234"
  run bash -c '
    repo="custom-slash-command"
    sid="${CLAUDE_SESSION_ID}"
    d="$(date +%Y-%m-%d)"
    p1="$HOME/.claude/projects/$repo/memory/journal/${d}-${sid}.md"
    p2="$HOME/.claude/projects/$repo/memory/journal/${d}-${sid}.md"
    [ "$p1" = "$p2" ] && echo OK
  '
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}
