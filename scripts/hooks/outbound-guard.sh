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
#   - `gh api` calls that write (--method / -X other than GET, or fields and
#     --input without a method) get the same check over their fields, the
#     stages that pipe into them, and the files --input / -F k=@file send. A
#     file the hook cannot read yet (written on the same line) is denied.
# Notion MCP writes get the same leak check (without the git-tracked test).
#
# Every push and PR command on the line is judged, each in the directory it
# runs in: the session cwd, moved by the `cd`s before the command (with the
# NAME=value assignments made earlier on the line expanded) and by its own
# `git -C`. A push or PR command whose directory or arguments the line does not
# show (`cd "$(mktemp -d)"`, a refspec from a command substitution) is denied
# with the way to rewrite it: judging it in the session cwd would apply another
# repository's rules. A `case` statement makes the rest of its line such a
# line: its patterns end in `)` with no `(`, so the scopes cannot be followed.
# Not read: a command inside a quoted string (`bash -c "git push"`,
# `out="$(git push)"`), and git options other than -C / -c before the
# subcommand.
#
# Autonomy modes. A repository is in `strict` mode unless the machine-local
# config ($MY_AUTONOMY_CONF, default ~/.claude/my-toolkit/autonomy.conf) has a
# line `ship <owner/name glob>` matching it. The repository is the one a gh
# command names with -R / --repo, else the origin of the directory it runs in.
#   strict: the PR rules above apply and `gh pr merge` (or a merge through the
#           API) is denied; PRs stay drafts for a human to land.
#   ship:   non-draft PRs, `gh pr ready` and `gh pr merge` are allowed. Pushes
#           to the default branch, force pushes and the leak checks still apply.
#
# Emits a PreToolUse permissionDecision JSON on stdout when it objects;
# stays silent (allow by default) otherwise. Never exits non-zero.
# Dependencies: bash, jq, grep, sed, git.
set -uf

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

# shellcheck source=../lib/autonomy.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/autonomy.sh"

# The commands on the line that send something out, one per line:
#   push <TAB> dir <TAB> its arguments, quotes removed and assignments expanded
#   pr   <TAB> dir <TAB> the gh command, quoted strings and $( ) emptied; it
#                      ends in " ?" when the line cuts its arguments short
#   text <TAB> dir <TAB> git | gh, for each command that carries a message
# dir is where the command runs, "?" when the line does not show it and
# "?case" when a case statement precedes it; a push
# argument the line does not show is "?" as well. Heredoc bodies, quoted
# strings and comments are set aside first, so that a message that mentions
# `gh pr create` or `git push` is not mistaken for running it.
commands="$(printf '%s' "$cmd" | CWD="$cwd" perl -0777 -ne '
  my (@lit, @saved, $opaque);
  my %var = (HOME => $ENV{HOME});
  my $dir = length $ENV{CWD} ? $ENV{CWD} : undef;
  my $hold = sub { push @lit, [@_]; "\x00" . $#lit . "\x00" };
  s/(<<-?\s*(["\x27]?)(\w+)\2)([^\n]*)\n.*?\n[ \t]*\3[ \t]*(?=\n|\z)/$1$4/gs;
  s/\\.|\$\x27((?:[^\x27\\]|\\.)*)\x27|"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27|(?<![^\s;&|()])#[^\n]*/
    defined $1 ? $hold->($1, 0) : defined $2 ? $hold->($2, 1) : defined $3 ? $hold->($3, 0) : substr($&, 0, 1) eq "#" ? "" : $&/gse;
  s/\\\n/ /g;
  my $value = sub {
    my ($word, $out) = ($_[0], "");
    $word =~ s/^~(?=\/|$)/$ENV{HOME}/;
    for my $part (split /(\x00\d+\x00)/, $word) {
      my ($s, $expand) = $part =~ /^\x00(\d+)\x00$/ ? @{ $lit[$1] } : ($part, 1);
      if ($expand) {
        return undef if $s =~ /`|\$\(/;
        my $known = 1;
        $s =~ s/\$\{(\w+)\}|\$(\w+)/my $n = defined $1 ? $1 : $2; defined $var{$n} ? $var{$n} : do { $known = 0; "" }/ge;
        return undef if !$known || $s =~ /\$/;
      }
      $out .= $s;
    }
    $out;
  };
  my $enter = sub {
    my ($base, $path) = ($_[0], $value->($_[1]));
    return undef unless defined $path && length $path && $path ne "-";
    $path =~ /^\// ? $path : defined $base ? "$base/$path" : undef;
  };
  my $emit = sub {
    my ($text, $at, $cut) = @_;
    my $unknown = $opaque ? "?case" : "?";
    $at = undef if $opaque;
    if ($text =~ /(?<![\w-])git((?:\s+-[Cc]\s+\S+)*)\s+push(?![\w-])([^)]*)/) {
      my ($opts, $args) = ($1, $2);
      my $in = $opts =~ /\s-C\s+(\S+)/ ? $enter->($at, $1) : $at;
      my @args = map { my $v = $value->($_); defined $v && $v !~ /[\s<>()]|\{.*,.*\}/ ? $v : "?" } split " ", $args;
      print join("\t", "push", defined $in ? $in : $unknown, "@args"), "\n";
    }
    while ($text =~ /(?<![\w-])gh\s+(?:pr\s+(?:create|new|merge|ready)|api)(?![\w-])/g) {
      my $gh = substr($text, $-[0]);
      1 while $gh =~ s/\([^()]*\)/ /;
      my $closed = $gh =~ s/\).*$//s;
      $gh =~ s/\x00(\d+)\x00/$lit[$1][1] ? q("") : "\x27\x27"/ge;
      $gh .= " ?" if $cut && !$closed;
      $gh =~ s/\s+/ /g;
      $gh =~ s/ $//;
      print join("\t", "pr", defined $at ? $at : $unknown, $gh), "\n";
    }
    if ($text =~ /(?<![\w-])git((?:\s+-[Cc]\s+\S+)*)\s+commit(?![\w-])/) {
      my $in = $1 =~ /\s-C\s+(\S+)/ ? $enter->($at, $1) : $at;
      print join("\t", "text", defined $in ? $in : $unknown, "git"), "\n";
    } elsif ($text =~ /(?<![\w-])gh\s+(?:pr|issue)\s+(?:create|new|comment|edit|review)(?![\w-])/) {
      print join("\t", "text", defined $at ? $at : $unknown, "gh"), "\n";
    }
  };
  my $moves = qr/(?<![\w.\/-])(?:cd|pushd|popd)(?![\w.\/-])/;
  my $moved = sub { my $flat = $_[0]; 1 while $flat =~ s/\([^()]*\)/ /; $flat =~ $moves };
  my $command = sub {
    my ($text) = @_;
    $text =~ s/^\s+|\s+$//g;
    $text =~ s/^(?:(?:if|then|elif|else|while|until|do|time|!|\{|builtin|command)\s+)+//;
    $opaque = 1 if $text =~ /^case\s/;
    if ($text =~ /^(?:(?:export|declare|local|readonly|typeset)\s+(?:-\w+\s+)*)?((?:\w+=\S*(?:\s+|$))+)$/) {
      my $assignments = $1;
      $var{$1} = $value->($2) while $assignments =~ /(\w+)=(\S*)/g;
    } elsif ($text =~ /^cd(?:\s+(?:-[LP]\s+|--\s+)*(\S+))?$/) {
      $dir = defined $1 ? $enter->($dir, $1) : $ENV{HOME};
    } elsif ($text =~ /^pushd\s+(\S+)$/) {
      $dir = $enter->($dir, $1);
    } else {
      $dir = undef if $moved->($text);
      $var{$1} = undef while $text =~ /(?:^|\s)(\w+)=/g;
      $var{$1} = undef if $text =~ /^for\s+(\w+)\s/;
      if ($text =~ /^read\s+(.*)/) { $var{$_} = undef for grep { /^\w+$/ } split " ", $1 }
      $emit->($text, $dir, 0);
    }
  };
  for my $seg (split /&&|\|\||;|\n|(?<!>)\|&?|(?<![<>|&])&(?![>&])/) {
    $seg =~ s/(?:(?:(?<!\S)\d+)?(?:>>|>\||>&|>|<<<|<<-?|<&|<>|<)|&>>?)\s*[^\s()<>&|;]+//g;
    my (@open, @close);
    while ($seg =~ /([()])/g) {
      if ($1 eq "(") { push @open, $-[0] } elsif (@open) { pop @open } else { push @close, $-[0] }
    }
    my ($from, @pieces) = (0);
    for my $at (@close, @open) {
      push @pieces, substr($seg, $from, $at - $from);
      $from = $at + 1;
    }
    push @pieces, substr($seg, $from);
    for my $i (0 .. $#pieces) {
      my $piece = $pieces[$i];
      if ($i < @close) {
        if ($i == 0) { $command->($piece) } else { $emit->($piece, $dir, 0); $dir = undef if $moved->($piece) }
        if (@saved) { ($dir, my $v) = @{ pop @saved }; %var = %$v }
      } elsif ($i < $#pieces) {
        $emit->($piece, $dir, 1);
        my %outer = %var;
        $outer{$1} = undef while $piece =~ /(?:^|\s)(\w+)=/g;
        push @saved, [$moved->($piece) ? undef : $dir, \%outer];
      } elsif (@close && !@open) {
        $emit->($piece, $dir, 0);
        $dir = undef if $moved->($piece);
      } else {
        $command->($piece);
      }
    }
  }
')"

# --- PR state ------------------------------------------------------------------
# judge_pr DIR COMMAND — deny what a strict repository does not allow.
judge_pr() {
  local dir="$1" gh="$2" reason="" repo cut="" hint="-R <owner/name> を付けるか cd <絶対パス> で始める"
  case "$gh" in *" ?") cut=1; gh="${gh%" ?"}" ;; esac
  case "$gh" in
    "gh pr merge"|"gh pr merge "*) reason="このリポジトリでは PR をマージしない。draft のまま本人に渡す" ;;
    "gh pr ready"|"gh pr ready "*) reason="PR を ready にしない。ready への変更は本人がセルフレビュー後に行う" ;;
    "gh pr create"|"gh pr create "*|"gh pr new"|"gh pr new "*)
      if printf '%s' "$gh" | grep -qE -- '--draft=(false|0)'; then
        reason="PR は draft で作る（--draft=false は使わない）"
      elif ! printf '%s' "$gh" | grep -qE -- '(^|[[:space:]])(--draft|-d)([[:space:]=]|$)'; then
        reason="PR は draft で作る。gh pr create に --draft を付ける"
      fi ;;
    "gh api"|"gh api "*)
      hint="cd <絶対パス> で始める"
      if printf '%s' "$cmd" | grep -qiE 'mergePullRequest|enablePullRequestAutoMerge|pulls/[0-9]+/merge'; then
        reason="API 経由でも PR をマージしない"
      elif printf '%s' "$cmd" | grep -qiE 'markPullRequestReadyForReview|"?draft"?[[:space:]]*[:=][[:space:]]*false'; then
        reason="API 経由でも PR を ready にしない"
      fi ;;
  esac
  [ -n "$reason" ] || return 0
  [ -z "$cut" ] || decide deny "gh の引数を判定できない。command substitution を使わず値を直接書く"
  repo="$(printf '%s' "$gh" | sed -nE 's#.*(^|[[:space:]])(-R|--repo)[[:space:]=]+([^[:space:]]+).*#\3#p')"
  case "$repo" in
    "")
      case "$dir" in
        "?case") decide deny "case 文と同じ行では gh を実行するリポジトリを判定できない。-R <owner/name> を付けるか別のコマンドに分ける" ;;
        "?") decide deny "gh を実行するリポジトリを判定できない。$hint" ;;
      esac
      repo="$(repo_slug "$dir")" ;;
    *\"*|*\'*) repo="" ;;
  esac
  [ "$(autonomy_mode "$repo")" = "strict" ] && decide deny "$reason"
  return 0
}

# --- git push ------------------------------------------------------------------
# judge_push DIR ARGS — deny force pushes and pushes to the default branch.
judge_push() {
  local dir="$1" tok cur dst p default_ref tags="" protected="main master"
  local unknown_dir="git push を実行する directory を判定できない。cd <絶対パス> で始めるか git -C <絶対パス> push と書く"
  local -a positional=() dests=()
  for tok in $2; do
    case "$tok" in
      -f|--force|--force-with-lease|--force-with-lease=*|--force-if-includes|--mirror|--all|--delete|-d|--prune)
        decide deny "git push $tok は使わない（取り消せない、または既定の branch に及ぶ）" ;;
      --tags) tags=1; pending_ask="tag の push は deploy を起こしうる" ;;
      "?") decide deny "git push の引数を判定できない。remote と branch を直接書く" ;;
      -*) ;;
      +*) decide deny "+ 付きの refspec は force-push になる" ;;
      *) positional+=("$tok") ;;
    esac
  done
  case "$dir" in
    "?case") decide deny "case 文と同じ行では git push を実行する directory を判定できない。別のコマンドに分けるか git -C <絶対パス> push と書く" ;;
    "?") decide deny "$unknown_dir" ;;
  esac
  default_ref="$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"
  [ -n "$default_ref" ] && protected="$protected ${default_ref##*/}"
  if [ "${#positional[@]}" -ge 2 ]; then
    for tok in "${positional[@]:1}"; do
      case "$tok" in :*) decide deny "refspec $tok は remote の branch を消す" ;; esac
      dst="${tok##*:}"; dst="${dst#refs/heads/}"
      [ "$dst" = "HEAD" ] && dst="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
      dests+=("$dst")
    done
  elif [ -z "$tags" ]; then
    cur="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -n "$cur" ] || decide deny "$unknown_dir"
    [ "$cur" = "HEAD" ] && decide deny "detached HEAD からは push しない"
    dests+=("$cur")
  fi
  for dst in ${dests[@]+"${dests[@]}"}; do
    for p in $protected; do
      [ "$dst" = "$p" ] && decide deny "既定の branch（${dst}）へは push しない。作業 branch から PR を出す"
    done
  done
  return 0
}

text_dir=""
api_dir=""
pending_ask=""
while IFS=$'\t' read -r kind dir rest; do
  case "$kind" in
    pr)
      case "$rest:$dir" in "gh api"*:\?*) ;; "gh api"*) [ -n "$api_dir" ] || api_dir="$dir" ;; esac
      judge_pr "$dir" "$rest" ;;
    push) judge_push "$dir" "$rest" ;;
    text)
      case "$dir" in
        "?case") [ "$rest" != "gh" ] || decide deny "case 文と同じ行では gh を実行する directory を判定できない。別のコマンドに分ける" ;;
        "?") [ "$rest" != "gh" ] || decide deny "gh を実行する directory を判定できない。cd <絶対パス> で始める" ;;
        *) [ -n "$text_dir" ] || text_dir="$dir" ;;
      esac ;;
  esac
done <<<"$commands"

# --- outbound text ---------------------------------------------------------------
# Only the outbound commands themselves carry text out. Each one runs from its
# own name (an env prefix addresses the machine) to the next top-level ; && ||
# & or newline, plus the pipeline stages that feed it, with its quoted strings
# and heredoc bodies put back. The other commands on the line address the machine.
text="$(printf '%s' "$cmd" | perl -0777 -ne '
  my @lit;
  my $hold = sub { push @lit, $_[0]; "\x00" . $#lit . "\x00" };
  s/(<<-?\s*(["\x27]?)(\w+)\2)([^\n]*)\n(.*?)\n[ \t]*\3[ \t]*(?=\n|\z)/$1 . $hold->($5) . $4/gse;
  s/\\.|\$\x27(?:[^\x27\\]|\\.)*\x27|"(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27|(?<![^\s;&|()])#[^\n]*/
    my $m = $&; $m =~ m{^\\}s ? $m : $m =~ m{^#} ? "" : $hold->($m)/gse;
  s/\\\n/ /g;
  my $out = qr/(?<![\w-])git(?:\s+-[Cc]\s+\S+)*\s+commit(?![\w-])|(?<![\w-])gh\s+(?:pr|issue)\s+(?:create|new|comment|edit|review)(?![\w-])/;
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
  read_args=()
  while IFS= read -r arg; do
    f="$(printf '%s' "$arg" | sed -E 's#^(--body-file|--file|-F)[[:space:]=]+##')"
    f="${f%\"}"; f="${f#\"}"; f="${f%\'}"; f="${f#\'}"
    case "$f" in
      -|/dev/stdin|/dev/fd/*) continue ;;
      /*|~*|\$*)
        f="${f/#\~/$HOME}"
        { [ -f "$f" ] && [ -r "$f" ]; } \
          || decide deny "本文のファイル ${f##*/} を読めない。ファイルを書くコマンドと送るコマンドを別の Bash 呼び出しに分け、パスを直接書く" ;;
      *)
        if [ ! -f "$text_dir/$f" ]; then
          case "$cmd" in
            *">$f"*|*"> $f"*|*"tee $f"*|*"tee -a $f"*)
              decide deny "本文のファイル $f を読めない。ファイルを書くコマンドと送るコマンドを別の Bash 呼び出しに分ける" ;;
          esac
          continue
        fi
        f="$text_dir/$f" ;;
    esac
    text="$text"$'\n'"$(cat "$f")"
    read_args+=("$arg")
  done < <(printf '%s' "$text" | grep -oE -- '(--body-file|--file|-F)[[:space:]=]+[^[:space:]]+')
  # Drop the parts that address the machine, not the reader: -C paths and the
  # arguments that named a file read above.
  for arg in ${read_args[@]+"${read_args[@]}"}; do text="${text//"$arg"/}"; done
  text="$(printf '%s' "$text" | sed -E 's#-C[[:space:]]+("[^"]*"|[^[:space:]]+)##g')"
  reason="$(leak_reason "$text" "$text_dir")"
  [ -n "$reason" ] && decide deny "$reason"
fi

# --- gh api writes ---------------------------------------------------------------
# For each `gh api` that writes: a line "\x02<file>" per file it sends, then its
# text (the stages piping into it and its own arguments, quoted strings and
# heredoc bodies put back) without the arguments that name those files.
api="$(printf '%s' "$cmd" | perl -0777 -ne '
  my @lit;
  my $hold = sub { push @lit, [@_]; "\x00" . $#lit . "\x00" };
  s/(<<-?\s*(["\x27]?)(\w+)\2)([^\n]*)\n(.*?)\n[ \t]*\3[ \t]*(?=\n|\z)/$1 . $hold->($5, $5) . $4/gse;
  s/\\.|\$\x27((?:[^\x27\\]|\\.)*)\x27|"((?:[^"\\]|\\.)*)"|\x27([^\x27]*)\x27|(?<![^\s;&|()])#[^\n]*/
    my ($m, $c) = ($&, defined $1 ? $1 : defined $2 ? $2 : $3);
    $m =~ m{^\\}s ? $m : $m =~ m{^#} ? "" : $hold->($m, $c)/gse;
  s/\\\n/ /g;
  my $put = sub { my ($s, $i) = @_; 1 while $s =~ s/\x00(\d+)\x00/$lit[$1][$i]/g; $s };
  my $word = qr/(?:\x00\d+\x00|[^\s\x00])+/;
  for my $seg (split /&&|\|\||;|\n|(?<![<>|])&(?![>&])/) {
    my @stages = split /\|&?/, $seg;
    for my $k (0 .. $#stages) {
      next unless $stages[$k] =~ /(?<![\w-])gh\s+api(?![\w-])/;
      my $gh = substr($stages[$k], $-[0]);
      my ($method) = $gh =~ /(?<!\S)(?:--method|-X)(?:\s+|=)?($word)/;
      next unless defined $method ? $put->($method, 1) !~ /^(?:GET|HEAD)$/i
        : $gh =~ /(?<!\S)(?:--input|--field|--raw-field|-[fF])/;
      my $stdin;
      while ($gh =~ /(?<!\S)--input(?:\s+|=)($word)/g) {
        my $f = $put->($1, 1);
        if ($f eq "-") { $stdin = 1 } else { print "\x02$f\n" }
      }
      while ($gh =~ /(?<!\S)(?:--field|-F)(?:\s+|=)?($word)/g) {
        my $v = $put->($1, 1);
        next unless $v =~ /^[^=]*=@(.+)$/s;
        if ($1 eq "-") { $stdin = 1 } else { print "\x02$1\n" }
      }
      if ($stdin) {
        while ($gh =~ /(?<![<\d])<(?![<(&])\s*($word)/g) { print "\x02", $put->($1, 1), "\n" }
        $gh =~ s/(?<![<\d])<(?![<(&])\s*$word//g;
      }
      $gh =~ s/(?<!\S)--input(?:\s+|=)$word//g;
      $gh =~ s/(?<!\S)((?:--field|-F)(?:\s+|=)?)($word)/$put->($2, 1) =~ m{^[^=]*=@} ? "" : "$1$2"/ge;
      print $put->(join(" | ", @stages[0 .. $k - 1], $gh), 0), "\n";
    }
  }
')"
if [ -n "$api" ]; then
  api_text="$(printf '%s\n' "$api" | grep -v $'^\x02')"
  while IFS= read -r f; do
    f="${f#$'\x02'}"
    f="${f/#\~/$HOME}"
    case "$f" in /*) ;; *) [ -z "$api_dir" ] || f="$api_dir/$f" ;; esac
    { [ -f "$f" ] && [ -r "$f" ]; } \
      || decide deny "gh api が送るファイル ${f##*/} を読めない。ファイルを書くコマンドと gh api を別の Bash 呼び出しに分け、パスを直接書く"
    api_text="$api_text"$'\n'"$(cat "$f")"$'\n'"$(jq -r '.. | strings' "$f" 2>/dev/null)"
  done < <(printf '%s\n' "$api" | grep $'^\x02')
  # JSON escapes such as \n would hide the boundary before a review ID.
  api_text="$(printf '%s' "$api_text" | sed -E 's/\\[nrt]/ /g')"
  reason="$(leak_reason "$api_text" "$api_dir")"
  [ -n "$reason" ] && decide deny "$reason"
fi

[ -n "$pending_ask" ] && decide ask "$pending_ask"

exit 0
