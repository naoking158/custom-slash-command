#!/usr/bin/env bash
# outbound-guard.sh — PreToolUse hook: keep what leaves the machine reviewable.
#
# Bash:
#   - `gh pr create` must open a draft (--draft / -d). Draft PRs skip the
#     reviewer auto-assignment, so the author can self-review first.
#   - `gh pr ready` and API calls that mark a PR ready for review are denied.
#   - Adding the label `human-approved` with `gh pr` / `gh issue`, renaming a
#     label to it, and every label write through `gh api` are denied in every
#     mode: the label records a person's approval of a guardrail change. A
#     command hidden in a quoted string or a script is not read (see below).
#   - `git push` is denied for force / delete / mirror / --all pushes and for
#     pushes whose destination is the default branch (main, master, origin/HEAD).
#   - Outbound text must not cite local working artifacts: review finding IDs
#     (C001, H012 ...), docs/reviews/ paths, absolute local paths, or docs/
#     paths that git does not track. Outbound text is a commit message, a PR /
#     issue body, comment or review, a merge commit's subject and body, a
#     close / reopen comment, release notes and asset labels, and gist files.
#     The files the body options name (-F, --file, --body-file, --notes-file,
#     the files of `gh gist`) are read and checked too; a body file the hook
#     cannot read, or one the same line writes, is denied. --attach images are
#     not read; their alt text and file name, which go in the body, are.
#   - `gh api` calls that write (--method / -X other than GET, or fields and
#     --input without a method) get the same check over their fields, the
#     stages that pipe into them, and the files --input / -F k=@file send. A
#     file the hook cannot read yet (written on the same line) is denied.
# Notion MCP writes get the same leak check (without the git-tracked test).
#
# Options are read as git (parse-options) and gh (pflag) read them: short
# options grouped in one word (-qF file, -mTEXT), abbreviated git long options
# (--fil), and quoted options ("-R", "--draft=false").
#
# Every push and PR command on the line is judged, each in the directory it
# runs in: the session cwd, moved by the `cd`s before the command (with the
# NAME=value assignments made earlier on the line expanded) and by its own
# `git -C`. A git that the line points at another repository or work tree
# (--git-dir, --work-tree, core.worktree, a GIT_DIR / GIT_WORK_TREE /
# GIT_CONFIG* assignment on the line) runs in a directory the line does not
# show. A push or PR command whose directory or arguments the line does not
# show (`cd "$(mktemp -d)"`, a refspec from a command substitution) is denied
# with the way to rewrite it: judging it in the session cwd would apply another
# repository's rules. A `case` statement makes the rest of its line such a
# line: its patterns end in `)` with no `(`, so the scopes cannot be followed.
# Not read: a command inside a quoted string (`bash -c "git push"`,
# `out="$(git push)"`).
#
# Autonomy modes. A repository is in `strict` mode unless the machine-local
# config ($MY_AUTONOMY_CONF, default ~/.claude/my-toolkit/autonomy.conf) has a
# line `ship <owner/name glob>` matching it and scripts/lib/autonomy.sh has
# recorded that GitHub protects its default branch. The repository is the one a gh
# command names with -R / --repo, else the origin of the directory it runs in.
#   strict: the PR rules above apply and `gh pr merge` (or a merge through the
#           API) is denied; PRs stay drafts for a human to land.
#   ship:   non-draft PRs, `gh pr ready` and `gh pr merge` are allowed. Pushes
#           to the default branch, force pushes and the leak checks still apply.
#
# Emits a PreToolUse permissionDecision JSON on stdout when it objects;
# stays silent (allow by default) otherwise. Never exits non-zero.
#
# The rules run in bin/my-toolkit-<os>-<arch> (built from cmd/my-toolkit and
# internal/outboundguard). Without a binary for this machine, or when it does
# not run, the hook cannot read the command: it then denies a call that looks
# outbound (see scripts/lib/guard-deps.sh) and stays silent for the rest.
# Dependencies: bash, git; grep when the binary is missing.
set -u

here="${BASH_SOURCE[0]%/*}"
[ "$here" != "${BASH_SOURCE[0]}" ] || here=.
case "${OSTYPE:-}" in darwin*) os=darwin ;; linux*) os=linux ;; *) os=unknown ;; esac
case "${HOSTTYPE:-}" in arm64 | aarch64) arch=arm64 ;; x86_64 | amd64) arch=amd64 ;; *) arch=unknown ;; esac
bin="$here/../../bin/my-toolkit-$os-$arch"

IFS= read -r -d '' payload || [ -n "$payload" ] || exit 0
if [ -x "$bin" ]; then
  "$bin" outbound-guard "$here/../lib" <<<"$payload" && exit 0
fi

# shellcheck source=../lib/guard-deps.sh
. "$here/../lib/guard-deps.sh"
looks_outbound "$payload" \
  && printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
    "outbound-guard: bin/my-toolkit-$os-$arch を実行できず、外へ出すコマンドを検査できない。このマシン向けのバイナリを入れてからやり直す"
exit 0
