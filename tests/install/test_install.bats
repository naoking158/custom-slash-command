#!/usr/bin/env bats
# Integration tests for scripts/install.sh (plugin symlink + legacy cleanup).
#
# Each test redirects HOME to a temp dir so the user's real ~/.claude is
# untouched.

load ../fake_bin

setup() {
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  INSTALL="$REPO_ROOT/scripts/install.sh"
  PLUGIN_LINK=".claude/skills/my"

  TMP="$BATS_TEST_TMPDIR"
  export HOME="$TMP"
  unset MY_ORCA_PROFILE
  FAKE_BIN="$TMP/bin"
  mkdir -p "$FAKE_BIN"
  export PATH="$FAKE_BIN:$(path_without_orca)"
  if command -v orca >/dev/null; then return 1; fi
}

# path_without_orca — $PATH minus every directory holding an orca executable.
path_without_orca() {
  local dir out="" IFS=:
  for dir in $PATH; do
    [ -x "$dir/orca" ] && continue
    out="${out:+$out:}$dir"
  done
  printf '%s' "$out"
}

# fake_orca — put an orca on PATH that fails if install.sh ever runs it.
fake_orca() {
  printf '#!/bin/bash\nexit 99\n' | fake_bin "$FAKE_BIN/orca"
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
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/$PLUGIN_LINK"
}

@test "install: fresh HOME also links the repo as an Antigravity plugin" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/.gemini/config/plugins/my"
}

@test "install: links the Antigravity subagents plugin to antigravity-agents" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(cd "$HOME/.gemini/config/plugins/my-agents" && pwd -P)" = "$(cd "$REPO_ROOT/antigravity-agents" && pwd -P)" ]
  bash "$INSTALL" --uninstall >/dev/null
  [ ! -L "$HOME/.gemini/config/plugins/my-agents" ]
}

@test "check: a missing Antigravity plugin link fails the check" {
  bash "$INSTALL" >/dev/null
  rm "$HOME/.gemini/config/plugins/my"
  run bash "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"*".gemini/config/plugins/my"* ]]
}

@test "uninstall: removes the Antigravity plugin link" {
  bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.gemini/config/plugins/my" ]
  [ ! -L "$HOME/.gemini/config/plugins/my" ]
}

@test "install: second run is idempotent and reports already linked" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
}

@test "install: creates ~/.claude/skills/ when missing" {
  [ ! -e "$HOME/.claude" ]
  run bash "$INSTALL"
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

  run bash "$INSTALL"
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

  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/commands" ]
  [ -f "$HOME/.claude/agents/keep.md" ]
}

@test "check: legacy symlink into repo fails the check" {
  bash "$INSTALL" >/dev/null
  ln -s "$REPO_ROOT/prompts" "$HOME/.prompts"

  run bash "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"LEGACY"* ]]
}

# ============================================================================
# --check
# ============================================================================

@test "check: empty HOME reports MISSING and exits non-zero" {
  run bash "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"* ]]
}

@test "check: after install reports OK and exits zero" {
  bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"All good"* ]]
}

# ============================================================================
# --uninstall
# ============================================================================

@test "uninstall: removes the plugin symlink" {
  bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/$PLUGIN_LINK" ] && [ ! -L "$HOME/$PLUGIN_LINK" ]
}

@test "uninstall: preserves a real directory at the target path" {
  mkdir -p "$HOME/$PLUGIN_LINK"
  echo "user file" > "$HOME/$PLUGIN_LINK/keep.md"

  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [ -f "$HOME/$PLUGIN_LINK/keep.md" ]
}

@test "uninstall: leaves foreign symlinks intact" {
  mkdir -p "$HOME/.claude/skills" "$TMP/foreign"
  ln -s "$TMP/foreign" "$HOME/$PLUGIN_LINK"

  run bash "$INSTALL" --uninstall
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

  run bash "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to touch"* ]]
  [ -f "$HOME/$PLUGIN_LINK/notes.md" ]
  [ ! -L "$HOME/$PLUGIN_LINK" ]
}

@test "install: fails on wrong symlink without --force" {
  mkdir -p "$HOME/.claude/skills" "$TMP/elsewhere"
  ln -s "$TMP/elsewhere" "$HOME/$PLUGIN_LINK"

  run bash "$INSTALL"
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

  run bash "$INSTALL" --force
  [ "$status" -eq 0 ]
  assert_links_to_repo "$HOME/$PLUGIN_LINK"
}

# ============================================================================
# CLI surface
# ============================================================================

@test "cli: unknown flag exits 2" {
  run bash "$INSTALL" --bogus
  [ "$status" -eq 2 ]
}

@test "cli: --help exits 0 with usage" {
  run bash "$INSTALL" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# ============================================================================
# rules file links
# ============================================================================

@test "install: links each rules file into ~/.claude/rules" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.claude/rules/principles.md" ]
  [ "$(readlink "$HOME/.claude/rules/principles.md")" = "$REPO_ROOT/rules/principles.md" ]
}

@test "install: does not link the Antigravity-only rules for Claude Code" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/rules/AGENTS.md" ]
  [ ! -e "$HOME/.claude/rules/antigravity.md" ]
}

@test "install: refuses to overwrite a real rules file" {
  mkdir -p "$HOME/.claude/rules"
  echo mine > "$HOME/.claude/rules/principles.md"
  run bash "$INSTALL"
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.claude/rules/principles.md")" = "mine" ]
}

@test "uninstall: removes rules links and keeps other rules files" {
  run bash "$INSTALL"
  echo mine > "$HOME/.claude/rules/other.md"
  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/rules/principles.md" ]
  [ -f "$HOME/.claude/rules/other.md" ]
}

# ============================================================================
# Orca layer (only when an orca command is on PATH)
# ============================================================================

@test "orca absent: install and check say nothing about Orca" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" != *"doctor"* ]]
  run bash "$INSTALL" --check
  [ "$status" -eq 0 ]
  [[ "$output" != *"doctor"* ]]
}

# select_profile NAME — write `profile NAME` to the machine-local orca.conf.
select_profile() {
  mkdir -p "$HOME/.claude/my-toolkit"
  printf 'profile %s\n' "$1" >"$HOME/.claude/my-toolkit/orca.conf"
}

@test "orca present: install and check point at orca/bin/doctor" {
  fake_orca
  select_profile work
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"run $REPO_ROOT/orca/bin/doctor from an Orca terminal"* ]]
  run bash "$INSTALL" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"orca/bin/doctor"* ]]
  [[ "$output" == *"Orca profile: work"* ]]
}

@test "orca present without a profile: install and check fail and say how to select one" {
  fake_orca
  run bash "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"*"Orca profile not selected"*".claude/my-toolkit/orca.conf"*"private"* ]]
  run bash "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"*"Orca profile not selected"* ]]
}

@test "orca present: MY_ORCA_PROFILE selects the profile" {
  fake_orca
  export MY_ORCA_PROFILE=private
  bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orca profile: private"* ]]
}

@test "orca present with an unknown profile: check fails" {
  fake_orca
  select_profile nope
  MY_ORCA_PROFILE=work bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"*"'nope'"* ]]
}

@test "orca present: install and check fail when orca/bin/doctor is missing" {
  fake_orca
  mkdir -p "$TMP/tree/scripts"
  cp "$INSTALL" "$TMP/tree/scripts/install.sh"
  run "$TMP/tree/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"*"orca/bin/doctor"* ]]
  run "$TMP/tree/scripts/install.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"*"orca/bin/doctor"* ]]
}

@test "orca present: uninstall leaves the Orca layer alone" {
  fake_orca
  select_profile work
  bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" != *"doctor"* ]]
}

# ============================================================================
# Antigravity allow rules

agy_settings() { printf '%s' "$HOME/.gemini/antigravity-cli/settings.json"; }

@test "agy rules: install adds the allow rules and keeps the user's settings" {
  mkdir -p "$HOME/.gemini/antigravity-cli"
  printf '{"colorScheme":"dark","permissions":{"allow":["command(make)"],"deny":["command(sudo)"]}}' >"$(agy_settings)"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  jq -e '.colorScheme == "dark" and .permissions.deny == ["command(sudo)"]
    and .permissions.allow[0] == "command(make)"
    and (.permissions.allow | index("command(git status)") and index("command(gh pr view)"))' "$(agy_settings)"
  jq -e --arg d "$HOME/.local/state/autopilot" '.permissions.allow | index("write_file(\($d))")' "$(agy_settings)"
  [ "$(stat -f %Lp "$(agy_settings)" 2>/dev/null || stat -c %a "$(agy_settings)")" = 600 ]
  run bash "$INSTALL"
  [ "$(jq '[.permissions.allow[] | select(. == "command(git status)")] | length' "$(agy_settings)")" -eq 1 ]
}

@test "agy rules: check fails when a rule is missing, uninstall removes only ours" {
  mkdir -p "$HOME/.gemini/antigravity-cli"
  printf '{"permissions":{"allow":["command(make)"]}}' >"$(agy_settings)"
  bash "$INSTALL" >/dev/null
  run bash "$INSTALL" --check
  [ "$status" -eq 0 ]
  jq '.permissions.allow -= ["command(git commit)"]' "$(agy_settings)" >"$TMP/s" && mv "$TMP/s" "$(agy_settings)"
  run bash "$INSTALL" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"*"command(git commit)"* ]]
  run bash "$INSTALL" --uninstall
  [ "$status" -eq 0 ]
  [ "$(jq -c '.permissions.allow' "$(agy_settings)")" = '["command(make)"]' ]
}

@test "agy rules: a settings file that is not a JSON object is left alone" {
  mkdir -p "$HOME/.gemini/antigravity-cli"
  printf 'not json' >"$(agy_settings)"
  run bash "$INSTALL"
  [ "$status" -ne 0 ]
  [ "$(cat "$(agy_settings)")" = "not json" ]
}

@test "agy rules: without Antigravity no settings file is created" {
  if command -v agy >/dev/null; then skip "agy is on PATH"; fi
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ ! -e "$(agy_settings)" ]
}
