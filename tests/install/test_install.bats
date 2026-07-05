#!/usr/bin/env bats
# Integration tests for scripts/install.sh (plugin symlink + legacy cleanup).
#
# Each test redirects HOME to a temp dir so the user's real ~/.claude is
# untouched.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  INSTALL="$REPO_ROOT/scripts/install.sh"
  PLUGIN_LINK=".claude/skills/my"

  TMP="$(mktemp -d -t install-test.XXXXXX)"
  export HOME="$TMP"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

assert_links_to_repo() {
  local link="$1" want_real got_real
  want_real="$(cd "$REPO_ROOT" && pwd -P)"
  [ -L "$link" ]
  got_real="$(cd "$link" && pwd -P)"
  [ "$got_real" = "$want_real" ]
}

# ============================================================================
# fresh install
# ============================================================================

@test "install: fresh HOME creates the plugin symlink" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/$PLUGIN_LINK"
}

@test "install: second run is idempotent and reports already linked" {
  run "$INSTALL"
  [ "$status" -eq 0 ]
  run "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
}

@test "install: creates ~/.claude/skills/ when missing" {
  [ ! -e "$HOME/.claude" ]
  run "$INSTALL"
  [ "$status" -eq 0 ]
  [ -d "$HOME/.claude/skills" ]
}

# ============================================================================
# legacy symlink cleanup
# ============================================================================

@test "install: removes legacy symlinks pointing into the repo" {
  mkdir -p "$HOME/.claude"
  ln -s "$REPO_ROOT/prompts"  "$HOME/.prompts"
  ln -s "$REPO_ROOT/commands" "$HOME/.claude/commands"
  ln -s "$REPO_ROOT/agents"   "$HOME/.claude/agents"

  run "$INSTALL"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.prompts" ] && [ ! -L "$HOME/.prompts" ]
  [ ! -e "$HOME/.claude/commands" ] && [ ! -L "$HOME/.claude/commands" ]
  [ ! -e "$HOME/.claude/agents" ] && [ ! -L "$HOME/.claude/agents" ]
}

@test "install: leaves foreign legacy symlinks and real dirs intact" {
  mkdir -p "$HOME/.claude" "$TMP/foreign"
  ln -s "$TMP/foreign" "$HOME/.claude/commands"
  mkdir -p "$HOME/.claude/agents"
  echo "user file" > "$HOME/.claude/agents/keep.md"

  run "$INSTALL"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/commands" ]
  [ -f "$HOME/.claude/agents/keep.md" ]
}

@test "check: legacy symlink into repo fails the check" {
  "$INSTALL" >/dev/null
  ln -s "$REPO_ROOT/prompts" "$HOME/.prompts"

  run "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"LEGACY"* ]]
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

@test "uninstall: removes the plugin symlink" {
  "$INSTALL" >/dev/null
  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/$PLUGIN_LINK" ] && [ ! -L "$HOME/$PLUGIN_LINK" ]
}

@test "uninstall: preserves a real directory at the target path" {
  mkdir -p "$HOME/$PLUGIN_LINK"
  echo "user file" > "$HOME/$PLUGIN_LINK/keep.md"

  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [ -f "$HOME/$PLUGIN_LINK/keep.md" ]
}

@test "uninstall: leaves foreign symlinks intact" {
  mkdir -p "$HOME/.claude/skills" "$TMP/foreign"
  ln -s "$TMP/foreign" "$HOME/$PLUGIN_LINK"

  run "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"not ours"* ]]
  [ -L "$HOME/$PLUGIN_LINK" ]
  got_real="$(cd "$HOME/$PLUGIN_LINK" && pwd -P)"
  expected_real="$(cd "$TMP/foreign" && pwd -P)"
  [ "$got_real" = "$expected_real" ]
}

# ============================================================================
# safety: real paths and foreign symlinks
# ============================================================================

@test "install: refuses to overwrite a real directory at the target" {
  mkdir -p "$HOME/$PLUGIN_LINK"
  echo "user data" > "$HOME/$PLUGIN_LINK/notes.md"

  run "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to touch"* ]]
  [ -f "$HOME/$PLUGIN_LINK/notes.md" ]
  [ ! -L "$HOME/$PLUGIN_LINK" ]
}

@test "install: fails on wrong symlink without --force" {
  mkdir -p "$HOME/.claude/skills" "$TMP/elsewhere"
  ln -s "$TMP/elsewhere" "$HOME/$PLUGIN_LINK"

  run "$INSTALL"
  [ "$status" -ne 0 ]
  # The link must be untouched.
  [ -L "$HOME/$PLUGIN_LINK" ]
  got_real="$(cd "$HOME/$PLUGIN_LINK" && pwd -P)"
  expected_real="$(cd "$TMP/elsewhere" && pwd -P)"
  [ "$got_real" = "$expected_real" ]
}

@test "install --force: replaces a wrong symlink" {
  mkdir -p "$HOME/.claude/skills" "$TMP/elsewhere"
  ln -s "$TMP/elsewhere" "$HOME/$PLUGIN_LINK"

  run "$INSTALL" --force
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/$PLUGIN_LINK"
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
