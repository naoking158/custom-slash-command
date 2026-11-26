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
  `my:diff-reviewer`, `my:verifier`, `my:adversary`, `my:trail-auditor`) or a skill marked `context: fork` (the
  `review` skill runs as `reviewer`): when an `orca` command is on PATH, run
  it in its own context with run-role, from your Orca terminal, with absolute
  paths:

  ```
  $HOME/.gemini/config/plugins/my/orca/bin/run-role <name> --out <result file> [--cwd <checkout>] -- <inputs>
  ```

  Without `orca` on PATH, handle the step as for exit 3 below.

  `<name>` is the agent without `my:`. If your own task came from run-role
  (it is an agent's instructions followed by a `## Reporting` section), you
  are that agent already: do its steps yourself, and use run-role only for a
  different agent it starts, such as `diff-reviewer` from `reviewer`.

  The inputs are what the skill gives the agent:
  - `diff-reviewer`: `--patch <patch> --hunks <hunks.tsv> --checklist <file>`
    (once per checklist), with the `pass1.json` path as `--out`. Never pass the
    plan or spec, neither its path nor its content.
  - `verifier`: the checkout path and the completion criteria. Put
    `--cwd <checkout>` before `--` when the checkout is an Orca workspace other
    than yours.
  - `reviewer`: the review target and its options.
  - `adversary`: the target, the intent and the throwaway worktree, each as an
    input (`"target: <range>" "intent: <text>" "worktree: <path>"`). The
    throwaway worktree is not an Orca workspace: never pass it as `--cwd`.
  - `trail-auditor`: the run's state directory (`"state: <path>"`) and,
    when there is one, the repository checkout.

  The last line of the output is `[run-role] <name> exit=<n> <result file>`.
  Act on the exit code:
  - 0: read the result file and continue.
  - 1: run it once more. If it fails again, treat it as exit 4.
  - 2: stop and report it; the profile or the inputs are wrong.
  - 3: Orca is not usable. For `diff-reviewer`, skip the plan-blind first
    pass: review in one pass and say in the report that the first pass was
    skipped because it could not be isolated. For the other agents, do the
    step yourself in this conversation, following `agents/<name>.md` in the
    plugin root, keep its return contract, and add a line `非隔離` (not
    isolated) right after the first line of its result.
  - 4: the worker timed out or waited for an approval and was stopped. For
    `verifier`, return BLOCKED with that cause. For `diff-reviewer`, fall back
    as for exit 3. For `reviewer`, stop and report that the review did not
    finish. For `adversary` and `trail-auditor`, do the step yourself as for
    exit 3, with the `非隔離` line.

  For an agent with no file in `agents/`, such as `Explore`, do the step
  yourself and follow the brief the skill gives it.
- `CLAUDE.md`: also read `AGENTS.md` and `GEMINI.md`, which hold the same kind
  of instructions here.
