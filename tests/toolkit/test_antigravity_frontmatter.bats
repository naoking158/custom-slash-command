#!/usr/bin/env bats
# Frontmatter that lets Antigravity load this repository as a plugin without
# changing what Claude Code loads.
#
# Contract under test:
#   - Every skill names itself after its folder (Antigravity requires it).
#   - agents/ is hidden from Antigravity: its tool lists use Claude Code tool
#     names, which Antigravity refuses to start. Their tools are a YAML list;
#     Antigravity skips an agent whose tools is a string.
#   - antigravity-agents/agents/ offers each of those agents to Antigravity as
#     a subagent of the same name, with only Antigravity tool names, and sends
#     it to the agents/ file for its instructions. Claude Code never reads
#     antigravity-agents/ (it reads agents/ recursively, so the copies cannot
#     live there).
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
  while IFS= read -r f; do
    want="$(basename "$(dirname "$f")")"
    frontmatter "$f" | grep -qx "name: $want" || { echo "missing name: $f"; return 1; }
  done < <(printf '%s\n' "$REPO_ROOT"/skills/*/SKILL.md)
}

@test "every agent is hidden from Antigravity" {
  local f
  while IFS= read -r f; do
    frontmatter "$f" | grep -qx 'mainAgent: false' || { echo "mainAgent: $f"; return 1; }
    frontmatter "$f" | grep -qx 'subagent: false' || { echo "subagent: $f"; return 1; }
    ! frontmatter "$f" | grep -qE '^tools: .+' || { echo "tools must be a YAML list: $f"; return 1; }
  done < <(printf '%s\n' "$REPO_ROOT"/agents/*.md)
}

@test "rules/AGENTS.md is the principles file and the principles have no frontmatter" {
  [ "$(readlink "$REPO_ROOT/rules/AGENTS.md")" = "principles.md" ]
  [ "$(head -n1 "$REPO_ROOT/rules/principles.md")" != "---" ]
}

@test "rules/antigravity.md is always on in Antigravity" {
  frontmatter "$REPO_ROOT/rules/antigravity.md" | grep -qx 'trigger: always_on'
}

@test "every agent has an Antigravity subagent of the same name with Antigravity tools only" {
  local f n copy tools
  local agy='run_command|command_status|manage_task|view_file|list_dir|find_by_name|grep_search|write_to_file|invoke_subagent|manage_subagents'
  while IFS= read -r f; do
    n="$(basename "$f" .md)"
    copy="$REPO_ROOT/antigravity-agents/agents/$n.md"
    [ -f "$copy" ] || { echo "no Antigravity copy: $n"; return 1; }
    frontmatter "$copy" | grep -qx "name: $n" || { echo "name: $copy"; return 1; }
    frontmatter "$copy" | grep -qx 'subagent: true' || { echo "subagent: $copy"; return 1; }
    frontmatter "$copy" | grep -qx 'mainAgent: false' || { echo "mainAgent: $copy"; return 1; }
    tools="$(frontmatter "$copy" | awk '/^tools:/ {t=1; next} t && /^  - / {print $2; next} {t=0}')"
    [ -n "$tools" ] || { echo "no tools: $copy"; return 1; }
    ! printf '%s\n' "$tools" | grep -vxE "$agy" || { echo "not an Antigravity tool in $copy"; return 1; }
    grep -qF "plugins/my/agents/$n.md" "$copy" || { echo "does not point at agents/$n.md: $copy"; return 1; }
  done < <(printf '%s\n' "$REPO_ROOT"/agents/*.md)
}

@test "antigravity-agents is an Antigravity plugin named my-agents" {
  jq -e '.name == "my-agents"' "$REPO_ROOT/antigravity-agents/.antigravity-plugin/plugin.json" >/dev/null
}
