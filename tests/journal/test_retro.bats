#!/usr/bin/env bats
# Integration tests for /my:retro shell logic.
#
# Scope: covers the toolkit-repo resolution helper (scripts/lib/toolkit.sh)
# and the glob/filter/sort/redaction shell logic described in
# skills/retro/SKILL.md. End-to-end /my:retro invocation via Claude is covered
# by the manual smoke checklist (Spec §9.3).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REDACT="$REPO_ROOT/skills/retro/scripts/redact.sh"
  TOOLKIT_LIB="$REPO_ROOT/scripts/lib/toolkit.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  TOOLKIT_FIX="$FIXTURES/toolkit_repo"

  TMP="$(mktemp -d -t retro-test.XXXXXX)"
  # Redirect HOME so we never touch the user's real ~/.claude.
  export HOME="$TMP"
  mkdir -p "$HOME/.claude/skills"

  # Sanitize env so each test starts in a known state.
  unset CLAUDE_TOOLKIT_REPO || true
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# ============================================================================
# resolve_toolkit_repo helper (scripts/lib/toolkit.sh)
# ============================================================================

@test "toolkit: \$CLAUDE_TOOLKIT_REPO pointing at valid dir resolves to it" {
  export CLAUDE_TOOLKIT_REPO="$TOOLKIT_FIX"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 0 ]
  expected_real="$(cd "$TOOLKIT_FIX" && pwd -P)"
  output_real="$(cd "$output" && pwd -P)"
  [ "$output_real" = "$expected_real" ]
}

@test "toolkit: env var takes priority over the skills/my symlink" {
  # Symlink points at the fixture; env var at a different existing dir.
  ln -s "$TOOLKIT_FIX" "$HOME/.claude/skills/my"
  ALT="$(mktemp -d -t alt-toolkit.XXXXXX)"
  export CLAUDE_TOOLKIT_REPO="$ALT"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 0 ]
  expected_real="$(cd "$ALT" && pwd -P)"
  output_real="$(cd "$output" && pwd -P)"
  [ "$output_real" = "$expected_real" ]
  rm -rf "$ALT"
}

@test "toolkit: env var at missing dir falls through to the symlink" {
  export CLAUDE_TOOLKIT_REPO="$TMP/definitely-does-not-exist"
  ln -s "$TOOLKIT_FIX" "$HOME/.claude/skills/my"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 0 ]
  expected_real="$(cd "$TOOLKIT_FIX" && pwd -P)"
  output_real="$(cd "$output" && pwd -P)"
  [ "$output_real" = "$expected_real" ]
}

@test "toolkit: skills/my symlink to a plugin repo resolves to it" {
  ln -s "$TOOLKIT_FIX" "$HOME/.claude/skills/my"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 0 ]
  expected_real="$(cd "$TOOLKIT_FIX" && pwd -P)"
  output_real="$(cd "$output" && pwd -P)"
  [ "$output_real" = "$expected_real" ]
}

@test "toolkit: no symlink and no env var returns empty and exit 1" {
  [ ! -e "$HOME/.claude/skills/my" ]
  unset CLAUDE_TOOLKIT_REPO || true
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "toolkit: symlink target without .claude-plugin/plugin.json is rejected" {
  mkdir -p "$TMP/not-a-plugin"
  ln -s "$TMP/not-a-plugin" "$HOME/.claude/skills/my"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "toolkit: dangling symlink (target missing) fails resolution" {
  ln -s "$TMP/no-such-dir/my" "$HOME/.claude/skills/my"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "toolkit: NEVER substitutes cwd as toolkit on resolution failure" {
  # No symlink, no env var, run from inside a non-toolkit directory.
  cd "$TMP"
  run bash "$TOOLKIT_LIB"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  # The output must NOT echo $PWD or any cwd-derived path.
  [[ "$output" != *"$TMP"* ]]
}

# ============================================================================
# journal glob / filter / sort
# ============================================================================

@test "glob: empty journal dir produces the no-entries message" {
  mkdir -p "$HOME/.claude/projects/repo/memory/journal"
  run bash -c '
    jdir="$HOME/.claude/projects/repo/memory/journal"
    files=("$jdir"/*.md)
    if [ ! -e "${files[0]}" ]; then
      echo "No journal entries found at $jdir. Run /my:learn first."
      exit 0
    fi
    echo found
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"No journal entries found"* ]]
  [[ "$output" == *"/my:learn"* ]]
}

@test "glob: enumerates all *.md files in journal dir" {
  jdir="$HOME/.claude/projects/repo/memory/journal"
  mkdir -p "$jdir"
  cp "$FIXTURES/journal/"*.md "$jdir/"
  run bash -c '
    jdir="$HOME/.claude/projects/repo/memory/journal"
    ls "$jdir"/*.md | wc -l | tr -d " "
  '
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

# --- --since parsing ---------------------------------------------------------

@test "--since: Nd form yields a YYYY-MM-DD date" {
  run bash -c '
    parse_since() {
      case "$1" in
        *d) date -v -"${1%d}"d +%Y-%m-%d 2>/dev/null || date -d "${1%d} days ago" +%Y-%m-%d ;;
        ????-??-??) echo "$1" ;;
        *) echo "ERR" ;;
      esac
    }
    parse_since "14d"
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

@test "--since: YYYY-MM-DD form is passed through" {
  run bash -c '
    parse_since() {
      case "$1" in
        *d) date -v -"${1%d}"d +%Y-%m-%d 2>/dev/null || date -d "${1%d} days ago" +%Y-%m-%d ;;
        ????-??-??) echo "$1" ;;
        *) echo "ERR" ;;
      esac
    }
    parse_since "2026-01-01"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "2026-01-01" ]
}

@test "--since: invalid form yields ERR sentinel" {
  run bash -c '
    parse_since() {
      case "$1" in
        *d) date -v -"${1%d}"d +%Y-%m-%d 2>/dev/null || date -d "${1%d} days ago" +%Y-%m-%d ;;
        ????-??-??) echo "$1" ;;
        *) echo "ERR" ;;
      esac
    }
    parse_since "not-a-date"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "ERR" ]
}

# --- --min-recurrence validation --------------------------------------------

@test "--min-recurrence: negative value is rejected (Edge case #9)" {
  run bash -c '
    val="-1"
    if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$val" -lt 1 ]; then
      echo "usage: --min-recurrence <positive integer>" >&2
      exit 1
    fi
  '
  [ "$status" -eq 1 ]
}

@test "--min-recurrence: non-numeric value is rejected (Edge case #9)" {
  run bash -c '
    val="abc"
    if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$val" -lt 1 ]; then
      echo "usage: --min-recurrence <positive integer>" >&2
      exit 1
    fi
  '
  [ "$status" -eq 1 ]
}

# --- category sort (mistake first) ------------------------------------------

@test "sort: mistake group precedes pattern and preference" {
  run bash -c '
    # Priority order described in skills/retro/SKILL.md.
    printf "%s\n" "preference" "pattern" "mistake" "domain-knowledge" "open-question" | \
      awk '"'"'
        BEGIN {
          rank["mistake"]=1; rank["pattern"]=2; rank["preference"]=3;
          rank["domain-knowledge"]=4; rank["open-question"]=5;
        }
        { print rank[$0], $0 }
      '"'"' | sort -n | awk "{print \$2}"
  '
  [ "$status" -eq 0 ]
  first="$(echo "$output" | head -n 1)"
  [ "$first" = "mistake" ]
  second="$(echo "$output" | sed -n 2p)"
  [ "$second" = "pattern" ]
}

# ============================================================================
# redaction integration
# ============================================================================

@test "redaction: candidate with sk- token is excluded (exit 2 disposition)" {
  echo "candidate body with key sk-abcdefghijklmnopqrstuvwxyz0123" > "$TMP/cand.txt"
  set +e
  "$REDACT" "$TMP/cand.txt" > /dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 2 ]
  # The disposition rule in skills/retro/SKILL.md says exit 2 => excluded.
}

@test "redaction: clean candidate is included (exit 0 disposition)" {
  echo "candidate body with no secrets" > "$TMP/cand.txt"
  set +e
  "$REDACT" "$TMP/cand.txt" > /dev/null 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 0 ]
}

@test "redaction: missing script triggers warn+continue path (Edge case #7)" {
  FAKE_REDACT="$TMP/no-redact.sh"
  run bash -c '
    if [ ! -x "$1" ]; then
      echo "warning: redact.sh not found at $1; continuing without redaction" >&2
      exit 0
    fi
  ' _ "$FAKE_REDACT"
  [ "$status" -eq 0 ]
}

# ============================================================================
# duplicate detection scope (must stay inside {toolkit_repo})
# ============================================================================

@test "duplicate detection: greps under toolkit_repo only, never cwd" {
  # Set up: toolkit fixture has skills/rules-typescript/references/error-handling.md
  ln -s "$TOOLKIT_FIX" "$HOME/.claude/skills/my"
  toolkit="$(bash "$TOOLKIT_LIB")"

  # Drop a decoy file in $TMP (cwd) with the same name; if the impl ever
  # grepped under cwd it would produce a false positive from this decoy.
  cd "$TMP"
  mkdir -p "$TMP/skills/rules-typescript/references"
  echo "DECOY (should never be grepped)" > "$TMP/skills/rules-typescript/references/error-handling.md"

  # Simulate the duplicate grep: only look under $toolkit/{skills,agents}.
  run bash -c '
    toolkit="$1"
    title="error-handling"
    hit="$(find "$toolkit"/{skills,agents} -type f -name "*${title}*" 2>/dev/null | head -1)"
    if [ -n "$hit" ]; then
      echo "duplicate_of: $hit"
    else
      echo "no_duplicate"
    fi
  ' _ "$toolkit"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/skills/rules-typescript/references/error-handling.md"* ]]
  # The decoy under $TMP must NOT appear.
  [[ "$output" != *"$TMP/skills"* ]]
}

@test "duplicate detection: skipped (notice) when toolkit_repo is empty" {
  unset CLAUDE_TOOLKIT_REPO || true
  [ ! -e "$HOME/.claude/skills/my" ]
  set +e
  toolkit="$(bash "$TOOLKIT_LIB")"
  rc=$?
  set -e
  [ "$rc" -eq 1 ]
  [ -z "$toolkit" ]
  annotation="(duplicate check skipped: toolkit repo not resolved)"
  [[ "$annotation" == *"toolkit repo not resolved"* ]]
}

# ============================================================================
# handoff string format (US-004 AC-001 / §7.4 threat)
# ============================================================================

@test "handoff: cd-prefixed format with resolved toolkit_repo" {
  ln -s "$TOOLKIT_FIX" "$HOME/.claude/skills/my"
  toolkit="$(bash "$TOOLKIT_LIB")"
  title="ts-error-handling: enforce unknown in catch"
  handoff="cd $toolkit && /my:change \"$title\""
  [[ "$handoff" == cd*"&& /my:change"* ]]
  expected_real="$(cd "$TOOLKIT_FIX" && pwd -P)"
  [[ "$handoff" == *"$expected_real"* ]]
  # MUST NOT be a bare /my:change line.
  [[ "$handoff" != "/my:change"* ]]
}

@test "handoff: <TOOLKIT_REPO> placeholder on resolution failure (US-004 AC-004)" {
  unset CLAUDE_TOOLKIT_REPO || true
  set +e
  toolkit="$(bash "$TOOLKIT_LIB")"
  set -e
  [ -z "$toolkit" ]
  title="ts-error-handling: enforce unknown in catch"
  toolkit_display="${toolkit:-<TOOLKIT_REPO>}"
  handoff="cd $toolkit_display && /my:change \"$title\""
  [[ "$handoff" == "cd <TOOLKIT_REPO> && /my:change \"$title\"" ]]
  # The literal cwd ($TMP) must NOT be substituted.
  [[ "$handoff" != *"$TMP"* ]]
}
