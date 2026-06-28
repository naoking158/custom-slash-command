#!/usr/bin/env bats
# Integration tests for scripts/install.sh.
#
# Each test redirects HOME to a temp dir so the user's real ~/.claude and
# ~/.prompts are untouched.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  INSTALL="$REPO_ROOT/scripts/install.sh"

  TMP="$(mktemp -d -t install-test.XXXXXX)"
  export HOME="$TMP"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

assert_links_to_repo() {
  local link="$1" want_dir="$2" want_real got_real
  want_real="$(cd "$REPO_ROOT/$want_dir" && pwd -P)"
  [ -L "$link" ]
  got_real="$(cd "$link" && pwd -P)"
  [ "$got_real" = "$want_real" ]
}

# ============================================================================
# fresh install
# ============================================================================

@test "install: fresh HOME creates all three symlinks" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/.prompts" prompts
  assert_links_to_repo "$HOME/.claude/commands" commands
  assert_links_to_repo "$HOME/.claude/agents" agents
}

@test "install: second run is idempotent and reports already linked" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  run "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
}

@test "install: creates ~/.claude/ when missing" {
  [ ! -e "$HOME/.claude" ]
  run "$INSTALL"
  [ "$status" -eq 0 ]
  [ -d "$HOME/.claude" ]
}

# ============================================================================
# --check
# ============================================================================

@test "check: empty HOME reports MISSING and exits non-zero" {
  run "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"* ]]
}

@test "check: after install reports OK and exits zero" {
  "$INSTALL" >/dev/null
  run "$INSTALL" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"All good"* ]]
}

# ============================================================================
# --uninstall
# ============================================================================

@test "uninstall: removes only links we manage" {
  "$INSTALL" >/dev/null
  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.prompts" ]
  [ ! -e "$HOME/.claude/commands" ]
  [ ! -e "$HOME/.claude/agents" ]
}

@test "uninstall: preserves real directory at a target path" {
  mkdir -p "$HOME/.claude/agents"
  echo "user file" > "$HOME/.claude/agents/keep.md"

  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [ -f "$HOME/.claude/agents/keep.md" ]
}

@test "uninstall: leaves foreign symlinks intact" {
  mkdir -p "$HOME/.claude" "$TMP/foreign"
  ln -s "$TMP/foreign" "$HOME/.claude/agents"

  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"not ours"* ]]
  [ -L "$HOME/.claude/agents" ]
  got_real="$(cd "$HOME/.claude/agents" && pwd -P)"
  expected_real="$(cd "$TMP/foreign" && pwd -P)"
  [ "$got_real" = "$expected_real" ]
}

# ============================================================================
# safety: real paths and foreign symlinks
# ============================================================================

@test "install: refuses to overwrite a real directory at a target" {
  mkdir -p "$HOME/.prompts"
  echo "user data" > "$HOME/.prompts/notes.md"

  run "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to touch"* ]] || [[ "$stderr" == *"refusing to touch"* ]]
  [ -f "$HOME/.prompts/notes.md" ]
  [ ! -L "$HOME/.prompts" ]
}

@test "install: fails on wrong symlink without --force" {
  mkdir -p "$HOME/.claude" "$TMP/elsewhere"
  ln -s "$TMP/elsewhere" "$HOME/.claude/agents"

  run "$INSTALL"
  [ "$status" -ne 0 ]
  # The link must be untouched.
  [ -L "$HOME/.claude/agents" ]
  got_real="$(cd "$HOME/.claude/agents" && pwd -P)"
  expected_real="$(cd "$TMP/elsewhere" && pwd -P)"
  [ "$got_real" = "$expected_real" ]
}

@test "install --force: replaces a wrong symlink" {
  mkdir -p "$HOME/.claude" "$TMP/elsewhere"
  ln -s "$TMP/elsewhere" "$HOME/.claude/agents"

  run "$INSTALL" --force
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/.claude/agents" agents
}

# ============================================================================
# CLI surface
# ============================================================================

@test "cli: unknown flag exits 2" {
  run "$INSTALL" --bogus
  [ "$status" -eq 2 ]
}

@test "cli: --help exits 0 with usage" {
  run "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
