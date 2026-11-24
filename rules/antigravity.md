---
trigger: always_on
---

# Following my:* skills in Antigravity

The skills of the `my` plugin are written for Claude Code. When you follow one,
read its Claude Code terms as follows.

- `${CLAUDE_SKILL_DIR}`: the folder that holds the SKILL.md you are following.
  Write that absolute path in its place before you run a command; your shell
  does not set the variable.
- `${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/my}` and `~/.claude/skills/my`:
  the root of the `my` plugin, `$HOME/.gemini/config/plugins/my`.
- `$ARGUMENTS`: the text the user typed after `/my:<skill>`.
- Tool names: Bash → `run_command`, Read → `view_file`, Write → `write_to_file`,
  Edit → `replace_file_content`, Glob → `find_by_name`, Grep → `grep_search`,
  AskUserQuestion → `ask_question`.
- A step that starts a Claude Code agent (`Agent`, `Task`, `my:reviewer`,
  `my:diff-reviewer`, `my:verifier`) or a skill marked `context: fork`: do the
  step yourself in this conversation, following `agents/<name>.md` in the plugin
  root (`<name>` without `my:`), and keep its return contract. For an agent with
  no file there, such as `Explore`, follow the brief the skill gives it.
- `CLAUDE.md`: also read `AGENTS.md` and `GEMINI.md`, which hold the same kind
  of instructions here.
