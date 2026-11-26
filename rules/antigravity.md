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
  `my:diff-reviewer`, `my:verifier`) or a skill marked `context: fork` (the
  `review` skill runs as `reviewer`): run it in its own context with run-role,
  from your Orca terminal, with absolute paths:

  ```
  $HOME/.gemini/config/plugins/my/orca/bin/run-role <name> --out <result file> -- <inputs>
  ```

  `<name>` is the agent without `my:`. The inputs are what the skill gives the
  agent:
  - `diff-reviewer`: `--patch <patch> --hunks <hunks.tsv> --checklist <file>`
    (once per checklist), with the `pass1.json` path as `--out`. Never pass the
    plan or spec, neither its path nor its content.
  - `verifier`: the checkout path and the completion criteria.
  - `reviewer`: the review target and its options.

  The last line of the output is `[run-role] <name> exit=<n> <result file>`.
  Act on the exit code:
  - 0: read the result file and continue.
  - 1: run it once more; if it fails again, record the step as BLOCKED.
  - 2: stop and tell the user; the profile or the inputs are wrong.
  - 3, or run-role is missing: do the step yourself in this conversation,
    following `agents/<name>.md` in the plugin root, keep its return contract,
    and write `非隔離` (not isolated) in its result.
  - 4: the worker timed out or waited for an approval and was stopped; record
    the step as BLOCKED.

  For an agent with no file in `agents/`, such as `Explore`, do the step
  yourself and follow the brief the skill gives it.
- `CLAUDE.md`: also read `AGENTS.md` and `GEMINI.md`, which hold the same kind
  of instructions here.
