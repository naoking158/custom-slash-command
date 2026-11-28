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
- `run_in_background`: run the command with `run_command` and a small
  `WaitMsBeforeAsync` (such as 500), so that it moves to the background at
  once. Do not poll it. A system message `Task id "<id>" finished with result:
  Command exited with code <n>.` arrives when it ends; `<n>` is its exit
  status. `manage_task` with `status` or `kill` acts on the running task.
- A step that starts a Claude Code agent (`Agent`, `Task`, `my:reviewer`,
  `my:diff-reviewer`, `my:verifier`, `my:adversary`, `my:trail-auditor`) or a
  skill marked `context: fork` (the `review` skill runs as `reviewer`): start
  the subagent of the same name without `my:` with `invoke_subagent`. The
  `my-agents` plugin provides them; each one reads its `agents/<name>.md` in
  the plugin root. Give it, in its task, the inputs the skill gives the agent,
  with absolute paths, and wait for its message: that message is the agent's
  result. Start several at once when the skill runs agents in parallel.

  If your own instructions are an `agents/<name>.md` file, you are that agent
  already: do its steps yourself, and start a subagent only for a different
  agent it starts, such as `diff-reviewer` from `reviewer`.

  The inputs are what the skill gives the agent:
  - `diff-reviewer`: the patch file, the hunks file, each checklist file and
    the `pass1.json` path to write. Never pass the plan or spec, neither its
    path nor its content.
  - `verifier`: the checkout path and the completion criteria.
  - `reviewer`: the review target and its options.
  - `adversary`: the target, the intent and the throwaway worktree.
  - `trail-auditor`: the run's state directory and, when there is one, the
    repository checkout.

  When `invoke_subagent` cannot start it (no such agent, or it fails to
  start), or it stops without a result: for `diff-reviewer`, skip the
  plan-blind first pass, review in one pass and say in the report that the
  first pass was skipped because it could not be isolated. For the other
  agents, do the step yourself in this conversation, following
  `agents/<name>.md`, keep its return contract, and add a line `非隔離` (not
  isolated) right after the first line of its result.

  For an agent with no file in `agents/`, such as `Explore`, start the
  built-in `research` subagent with the brief the skill gives it.
- `CLAUDE.md`: also read `AGENTS.md` and `GEMINI.md`, which hold the same kind
  of instructions here.
