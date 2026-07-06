#!/usr/bin/env bats
# Tests for resolve_toolkit_repo (scripts/lib/toolkit.sh).
#
# Priority: $CLAUDE_TOOLKIT_REPO > plugin env vars (CLAUDE_PLUGIN_ROOT /
# CLAUDE_SKILL_DIR) > ~/.claude/skills/my symlink > failure (exit 1, empty).
# Falling back to $PWD is forbidden in all cases.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  TOOLKIT_LIB="$REPO_ROOT/scripts/lib/toolkit.sh"

  TMP="$(mktemp -d -t resolve-test.XXXXXX)"
  export HOME="$TMP"
  mkdir -p "$HOME/.claude/skills"

  # Minimal fake toolkit repo (has the plugin manifest marker).
  FAKE_REPO="$TMP/fake-toolkit"
  mkdir -p "$FAKE_REPO/.claude-plugin" "$FAKE_REPO/skills/retro"
  echo '{"name":"my"}' > "$FAKE_REPO/.claude-plugin/plugin.json"

  unset CLAUDE_TOOLKIT_REPO CLAUDE_PLUGIN_ROOT CLAUDE_SKILL_DIR || true
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

resolved() { bash "$TOOLKIT_LIB"; }
real() { (cd "$1" && pwd -P); }

@test "resolve: \$CLAUDE_TOOLKIT_REPO wins over everything" {
  export CLAUDE_TOOLKIT_REPO="$FAKE_REPO"
  export CLAUDE_PLUGIN_ROOT="$TMP/somewhere-else"
  run resolved
  [ "$status" -eq 0 ]
  [ "$(real "$output")" = "$(real "$FAKE_REPO")" ]
}

@test "resolve: \$CLAUDE_PLUGIN_ROOT with plugin.json resolves" {
  export CLAUDE_PLUGIN_ROOT="$FAKE_REPO"
  run resolved
  [ "$status" -eq 0 ]
  [ "$(real "$output")" = "$(real "$FAKE_REPO")" ]
}

@test "resolve: \$CLAUDE_PLUGIN_ROOT without plugin.json is rejected" {
  mkdir -p "$TMP/not-a-plugin"
  export CLAUDE_PLUGIN_ROOT="$TMP/not-a-plugin"
  run resolved
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "resolve: \$CLAUDE_SKILL_DIR two levels under the repo resolves" {
  export CLAUDE_SKILL_DIR="$FAKE_REPO/skills/retro"
  run resolved
  [ "$status" -eq 0 ]
  [ "$(real "$output")" = "$(real "$FAKE_REPO")" ]
}

@test "resolve: skills/my symlink to a plugin repo resolves" {
  ln -s "$FAKE_REPO" "$HOME/.claude/skills/my"
  run resolved
  [ "$status" -eq 0 ]
  [ "$(real "$output")" = "$(real "$FAKE_REPO")" ]
}

@test "resolve: env var at missing dir falls through to the symlink" {
  export CLAUDE_TOOLKIT_REPO="$TMP/does-not-exist"
  ln -s "$FAKE_REPO" "$HOME/.claude/skills/my"
  run resolved
  [ "$status" -eq 0 ]
  [ "$(real "$output")" = "$(real "$FAKE_REPO")" ]
}

@test "resolve: symlink target without plugin.json is rejected" {
  mkdir -p "$TMP/not-a-plugin"
  ln -s "$TMP/not-a-plugin" "$HOME/.claude/skills/my"
  run resolved
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "resolve: dangling symlink fails resolution" {
  ln -s "$TMP/no-such-dir/my" "$HOME/.claude/skills/my"
  run resolved
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "resolve: NEVER substitutes cwd on failure" {
  cd "$TMP"
  run resolved
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
