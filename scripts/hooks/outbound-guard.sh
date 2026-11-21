#!/usr/bin/env bash
# outbound-guard.sh — PreToolUse hook: keep what leaves the machine reviewable.
#
# Bash:
#   - `gh pr create` must open a draft (--draft / -d). Draft PRs skip the
#     reviewer auto-assignment, so the author can self-review first.
#   - `gh pr ready` and API calls that mark a PR ready for review are denied.
#   - `git push` is denied for force / delete / mirror / --all pushes and for
#     pushes whose destination is the default branch (main, master, origin/HEAD).
#   - Outbound text (commit messages, PR / issue bodies and comments) must not
#     cite local working artifacts: review finding IDs (C001, H012 ...),
#     docs/reviews/ paths, absolute local paths, or docs/ paths that git does
#     not track.
# Notion MCP writes get the same leak check (without the git-tracked test).
#
# Autonomy modes. A repository is in `strict` mode unless the machine-local
# config ($MY_AUTONOMY_CONF, default ~/.claude/my-toolkit/autonomy.conf) has a
# line `ship <owner/name glob>` matching it. The repository is the one a gh
# command names with -R / --repo, else the origin of the command's workdir.
#   strict: the PR rules above apply and `gh pr merge` (or a merge through the
#           API) is denied; PRs stay drafts for a human to land.
#   ship:   non-draft PRs, `gh pr ready` and `gh pr merge` are allowed. Pushes
#           to the default branch, force pushes and the leak checks still apply.
#
# Emits a PreToolUse permissionDecision JSON on stdout when it objects;
# stays silent (allow by default) otherwise. Never exits non-zero.
# Dependencies: bash, jq, grep, sed, git.
set -u

payload="$(cat)" || exit 0
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"

decide() {
  jq -cn --arg d "$1" --arg r "outbound-guard: $2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

review_id_re='(^|[^A-Za-z0-9_])[CHML][0-9]{3}([^A-Za-z0-9_]|$)'
local_path_re='(/Users/|/home/[a-z]|~/|/private/tmp/|/tmp/claude)'

# leak_reason TEXT [REPO_DIR] — prints a reason when TEXT cites local artifacts.
leak_reason() {
  local text="$1" repo="${2:-}"
  if printf '%s' "$text" | grep -qE "$review_id_re"; then
    echo "review finding ID が含まれている。指摘の内容を変更の説明として書く"; return
  fi
  if printf '%s' "$text" | grep -qE 'docs/reviews/'; then
    echo "docs/reviews/ のパスが含まれている。ローカルのレビュー記録は外に出さない"; return
  fi
  if printf '%s' "$text" | grep -qE "$local_path_re"; then
    echo "ローカルの絶対パスが含まれている。読者が開けない場所を参照しない"; return
  fi
  [ -n "$repo" ] || return
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if ! git -C "$repo" ls-files --error-unmatch -- "$p" >/dev/null 2>&1 \
      && ! git -C "$repo" ls-files --error-unmatch -- "${p%/}/" >/dev/null 2>&1; then
      echo "git で追跡していない $p を参照している。ローカル文書は外に出さない"; return
    fi
  done < <(printf '%s' "$text" | grep -oE '(^|[^A-Za-z0-9_./-])docs/[A-Za-z0-9_./-]+' | sed -E 's#^[^d]*##; s#[.,]+$##' | sort -u)
}

if [ "$tool" != "Bash" ]; then
  case "$tool" in
    mcp__*notion-create-pages|mcp__*notion-update-page|mcp__*notion-create-comment|mcp__*notion-update-comment)
      text="$(printf '%s' "$payload" | jq -r '.tool_input | tostring' 2>/dev/null)"
      reason="$(leak_reason "$text")"
      [ -n "$reason" ] && decide deny "$reason"
      ;;
  esac
  exit 0
fi

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || exit 0

# Working directory the command acts on: `git -C <dir>`, else a leading `cd <dir>`, else cwd.
workdir="$cwd"
lead_cd="$(printf '%s' "$cmd" | sed -nE '1s#^[[:space:]]*cd[[:space:]]+("([^"]+)"|([^[:space:];&]+)).*#\2\3#p')"
[ -n "$lead_cd" ] && workdir="${lead_cd/#\~/$HOME}"
git_c="$(printf '%s' "$cmd" | sed -nE 's#.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|([^[:space:]]+)).*#\2\3#p' | head -n1)"
[ -n "$git_c" ] && workdir="${git_c/#\~/$HOME}"

# shellcheck source=../lib/autonomy.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/autonomy.sh"

# Command shape: heredoc bodies and quoted strings emptied, so that a message
# that mentions `gh pr create` or `git push` is not mistaken for running it.
shape="$(printf '%s' "$cmd" | perl -0777 -pe '
  s/(<<-?\s*(["\x27]?)(\w+)\2)([^\n]*)\n.*?\n[ \t]*\3[ \t]*(?=\n|\z)/$1$4/gs;
  s/"(?:[^"\\]|\\.)*"/""/gs;
  s/\x27[^\x27]*\x27/\x27\x27/gs;
')"

# --- PR state ------------------------------------------------------------------
target_repo="$(printf '%s' "$shape" | sed -nE 's#.*(^|[[:space:]])(-R|--repo)[[:space:]=]+([^[:space:];&|]+).*#\3#p' | head -n1)"
case "$target_repo" in
  "") target_repo="$(repo_slug "$workdir")" ;;
  *\"*|*\'*) target_repo="" ;;
esac
mode="$(autonomy_mode "$target_repo")"

if [ "$mode" = "strict" ]; then
if printf '%s' "$shape" | grep -qE '(^|[^A-Za-z0-9_-])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)'; then
  decide deny "このリポジトリでは PR をマージしない。draft のまま本人に渡す"
fi
if printf '%s' "$shape" | grep -qE 'gh[[:space:]]+api' \
  && printf '%s' "$cmd" | grep -qiE 'mergePullRequest|enablePullRequestAutoMerge|pulls/[0-9]+/merge'; then
  decide deny "API 経由でも PR をマージしない"
fi
if printf '%s' "$shape" | grep -qE '(^|[^A-Za-z0-9_-])gh[[:space:]]+pr[[:space:]]+ready([[:space:]]|$)'; then
  decide deny "PR を ready にしない。ready への変更は本人がセルフレビュー後に行う"
fi
if printf '%s' "$shape" | grep -qE 'gh[[:space:]]+api' \
  && printf '%s' "$cmd" | grep -qiE 'markPullRequestReadyForReview|"?draft"?[[:space:]]*[:=][[:space:]]*false'; then
  decide deny "API 経由でも PR を ready にしない"
fi
if printf '%s' "$shape" | grep -qE '(^|[^A-Za-z0-9_-])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
  create_seg="$(printf '%s' "$shape" | sed -nE 's#.*(gh[[:space:]]+pr[[:space:]]+create.*)#\1#p' | head -n1)"
  if printf '%s' "$create_seg" | grep -qE -- '--draft=(false|0)'; then
    decide deny "PR は draft で作る（--draft=false は使わない）"
  fi
  if ! printf '%s' "$create_seg" | grep -qE -- '(^|[[:space:]])(--draft|-d)([[:space:]=]|$)'; then
    decide deny "PR は draft で作る。gh pr create に --draft を付ける"
  fi
fi
fi

# --- git push ------------------------------------------------------------------
push_seg="$(printf '%s' "$shape" | grep -oE '(^|[^A-Za-z0-9_-])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]][^;&|]*)?' | head -n1)"
if [ -n "$push_seg" ]; then
  args="$(printf '%s' "$push_seg" | sed -E 's#.*push##')"
  protected="main master"
  default_ref="$(git -C "$workdir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"
  [ -n "$default_ref" ] && protected="$protected ${default_ref##*/}"
  positional=()
  for tok in $args; do
    case "$tok" in
      -f|--force|--force-with-lease|--force-with-lease=*|--force-if-includes|--mirror|--all|--delete|-d|--prune)
        decide deny "git push $tok は使わない（取り消せない、または既定の branch に及ぶ）" ;;
      --tags) decide ask "tag の push は deploy を起こしうる" ;;
      -*) ;;
      +*) decide deny "+ 付きの refspec は force-push になる" ;;
      *) positional+=("$tok") ;;
    esac
  done
  dests=()
  if [ "${#positional[@]}" -ge 2 ]; then
    for spec in "${positional[@]:1}"; do
      case "$spec" in :*) decide deny "refspec $spec は remote の branch を消す" ;; esac
      dst="${spec##*:}"; dst="${dst#refs/heads/}"
      [ "$dst" = "HEAD" ] && dst="$(git -C "$workdir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
      dests+=("$dst")
    done
  else
    cur="$(git -C "$workdir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -n "$cur" ] || decide ask "push 先の branch を判定できない"
    [ "$cur" = "HEAD" ] && decide deny "detached HEAD からは push しない"
    dests+=("$cur")
  fi
  for d in "${dests[@]}"; do
    for p in $protected; do
      [ "$d" = "$p" ] && decide deny "既定の branch（${d}）へは push しない。作業 branch から PR を出す"
    done
  done
fi

# --- outbound text ---------------------------------------------------------------
# Only the outbound commands themselves carry text out. Each one runs from its
# own name (an env prefix addresses the machine) to the next top-level ; && ||
# & or newline, plus the pipeline stages that feed it, with its quoted strings
# and heredoc bodies put back. The other commands on the line address the machine.
text="$(printf '%s' "$cmd" | perl -0777 -ne '
  my @lit;
  my $hold = sub { push @lit, $_[0]; "\x00" . $#lit . "\x00" };
  s/(<<-?\s*(["\x27]?)(\w+)\2)([^\n]*)\n(.*?)\n[ \t]*\3[ \t]*(?=\n|\z)/$1 . $hold->($5) . $4/gse;
  s/"(?:[^"\\]|\\.)*"/$hold->($&)/gse;
  s/\x27[^\x27]*\x27/$hold->($&)/gse;
  s/\\\n/ /g;
  my $out = qr/(?<![\w-])git(?:\s+-[Cc]\s+\S+)*\s+commit(?![\w-])|(?<![\w-])gh\s+(?:pr|issue)\s+(?:create|comment|edit|review)(?![\w-])/;
  for my $seg (split /&&|\|\||;|\n|(?<![<>|])&(?![>&])/) {
    my @stages = split /\|&?/, $seg;
    my ($k) = grep { $stages[$_] =~ $out } 0 .. $#stages;
    next unless defined $k;
    $stages[$k] =~ $out;
    my $s = join " | ", @stages[0 .. $k - 1], substr($stages[$k], $-[0]);
    1 while $s =~ s/\x00(\d+)\x00/$lit[$1]/g;
    print $s, "\n";
  }
')"
if [ -n "$text" ]; then
  for f in $(printf '%s' "$text" | grep -oE -- '(--body-file|--file|-F)[[:space:]=]+[^[:space:]]+' | sed -E 's#^(--body-file|--file|-F)[[:space:]=]+##'); do
    f="${f%\"}"; f="${f#\"}"; f="${f%\'}"; f="${f#\'}"
    case "$f" in /*|~*) ;; *) f="$workdir/$f" ;; esac
    f="${f/#\~/$HOME}"
    [ -f "$f" ] && text="$text"$'\n'"$(cat "$f")"
  done
  # Drop the parts that address the machine, not the reader.
  text="$(printf '%s' "$text" \
    | sed -E 's#-C[[:space:]]+("[^"]*"|[^[:space:]]+)##g' \
    | sed -E 's#(--body-file|--file|-F)[[:space:]=]+[^[:space:]]+##g')"
  reason="$(leak_reason "$text" "$workdir")"
  [ -n "$reason" ] && decide deny "$reason"
fi

exit 0
