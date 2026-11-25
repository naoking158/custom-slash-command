#!/usr/bin/env bats
# Frontmatter that lets Antigravity load this repository as a plugin without
# changing what Claude Code loads.
#
# Contract under test:
#   - Every skill names itself after its folder (Antigravity requires it).
#   - Agents are not offered to Antigravity: their tool lists use Claude Code
#     tool names, which can hang an Antigravity subagent. Their tools are a
#     YAML list; Antigravity skips an agent whose tools is a string.
#   - Antigravity's always-on rule rules/AGENTS.md carries the principles, and
#     the principles file has no frontmatter (Claude Code drops a rule whose
#     frontmatter lacks paths).
#   - rules/antigravity.md is an always-on rule for Antigravity.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

frontmatter() {
  awk 'NR==1 && /^---$/ {p=1; next} p && /^---$/ {exit} p' "$1"
}

@test "every SKILL.md has a name matching its folder" {
  local f want
  for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    want="$(basename "$(dirname "$f")")"
    frontmatter "$f" | grep -qx "name: $want" || { echo "missing name: $f"; return 1; }
  done
}

@test "every agent is hidden from Antigravity" {
  local f
  for f in "$REPO_ROOT"/agents/*.md; do
    frontmatter "$f" | grep -qx 'mainAgent: false' || { echo "mainAgent: $f"; return 1; }
    frontmatter "$f" | grep -qx 'subagent: false' || { echo "subagent: $f"; return 1; }
    ! frontmatter "$f" | grep -qE '^tools: .+' || { echo "tools must be a YAML list: $f"; return 1; }
  done
}

@test "rules/AGENTS.md is the principles file and the principles have no frontmatter" {
  [ "$(readlink "$REPO_ROOT/rules/AGENTS.md")" = "principles.md" ]
  [ "$(head -n1 "$REPO_ROOT/rules/principles.md")" != "---" ]
}

@test "rules/antigravity.md is always on in Antigravity" {
  frontmatter "$REPO_ROOT/rules/antigravity.md" | grep -qx 'trigger: always_on'
}
