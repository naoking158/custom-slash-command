#!/usr/bin/env bash
# Read-only worktree audit. Classifies every git worktree except the main one
# by size, age, merge state, uncommitted work, remote and PR state, Orca state,
# autopilot marker and the newest Claude Code session that worked in it, and
# suggests a bucket. Deletes nothing; deletion is the human-gated step of
# /my:worktree-cleanup. The only write is a best-effort `git fetch` of the base.
#
# Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]
#   repo-path defaults to the current directory.
#   -b sets the ref MERGED checks against. Without it: origin/HEAD, then
#   origin/main, origin/master, HEAD.
#
# Buckets, first match wins: hold-wip (tracked edits), hold-locked (git
# worktree lock), hold-active (Orca pinned
# or active), hold-open-pr, verify-recent-chat (a session in the last 4 days),
# review (Orca state unknown: orca installed but unreachable, or its list
# truncated without this worktree; or git status failed), safe (merged into the base, or its PR merged or closed and the
# worktree has no commit beyond the PR's head), review.
#
# Exit: 0 table printed, 2 bad option, not a git repository or no base ref.
set -u

base=""
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--base) [ $# -ge 2 ] || { echo "error: $1 needs a ref" >&2; exit 2; }; base="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    -*) echo "error: unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -le 1 ] || { echo "error: one repo-path at most" >&2; exit 2; }

repo="${1:-.}"
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "error: not a git repository: $repo" >&2; exit 2; }
cd "$repo" || exit 2
export GIT_OPTIONAL_LOCKS=0

if [ -z "$base" ]; then
  for cand in "$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master HEAD; do
    [ -n "$cand" ] && git rev-parse --verify --quiet "$cand^{commit}" >/dev/null && { base="$cand"; break; }
  done
  echo "warn: no -b given; MERGED checks against $base" >&2
fi
case "$base" in
  origin/*) git fetch origin "+refs/heads/${base#origin/}:refs/remotes/$base" --quiet 2>/dev/null \
    || echo "warn: could not fetch $base; MERGED may be stale" >&2 ;;
esac
git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo "error: base ref not found: $base" >&2; exit 2; }

if stat -c %Y / >/dev/null 2>&1; then
  mtime() { stat -c %Y "$1"; }
  fmt_day() { date -d "@$1" '+%Y-%m-%d'; }
else
  mtime() { stat -f %m "$1"; }
  fmt_day() { date -r "$1" '+%Y-%m-%d'; }
fi

# canon PATH — physical path of an existing directory, else PATH unchanged.
canon() { if [ -d "$1" ]; then (cd "$1" && pwd -P); else printf '%s\n' "$1"; fi; }

# slug PATH — the Claude Code projects directory name for a working directory.
slug() { printf '%s' "${1//[^A-Za-z0-9]/-}"; }

# regex_quote TEXT — TEXT with ERE metacharacters escaped.
regex_quote() {
  local s="$1" out="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      '[' | ']' | '\' | '.' | '*' | '^' | '$' | '+' | '?' | '(' | ')' | '{' | '}' | '|') out="$out\\$c" ;;
      *) out="$out$c" ;;
    esac
  done
  printf '%s' "$out"
}

# newest_ts FILE... on stdin — the largest mtime among the listed files, or 0.
newest_ts() {
  local f t max=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    t=$(mtime "$f" 2>/dev/null) || continue
    [ "$t" -gt "$max" ] && max="$t"
  done
  echo "$max"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# PR state by head branch: open, draft, merged or closed. Empty when gh cannot read.
echo '[]' >"$tmp/prs.json"
if command -v gh >/dev/null 2>&1 \
  && raw=$(gh pr list --author "@me" --state all --limit 1000 --json number,state,isDraft,headRefName,headRefOid 2>/dev/null) \
  && printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
  printf '%s' "$raw" | jq '[.[] | {number, head: .headRefName, oid: .headRefOid,
    state: (if .isDraft == true and .state == "OPEN" then "draft" else (.state | ascii_downcase) end)}]' >"$tmp/prs.json"
fi
# One row per PR: head branch, #number/state, head oid.
jq -r '.[] | [.head, "#\(.number)/\(.state)", (.oid // "")] | @tsv' "$tmp/prs.json" >"$tmp/prs.tsv"

# Orca state by canonical path, fetched once. Without orca the column is -;
# with an orca that does not answer, every worktree's Orca state is unknown.
orca_unknown=no
: >"$tmp/orca.tsv"
if command -v orca >/dev/null 2>&1 && ! {
  orca status --json 2>/dev/null | jq -e '.ok == true and .result.runtime.reachable == true' >/dev/null 2>&1 \
  && raw=$(orca worktree ps --limit 500 --json 2>/dev/null) \
  && printf '%s' "$raw" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1; }; then
  orca_unknown=yes
  echo "warn: orca is installed but its worktree list is unavailable; every worktree is put in review" >&2
elif command -v orca >/dev/null 2>&1; then
  if printf '%s' "$raw" | jq -e '.result.truncated == true' >/dev/null 2>&1; then
    orca_unknown=yes
    echo "warn: orca worktree list is truncated; worktrees missing from it are put in review" >&2
  fi
  printf '%s' "$raw" | jq -r '.result.worktrees[] | [.path,
      (if .isPinned == true then "pinned"
       elif .isActive == true or (.liveTerminalCount // 0) > 0 or ((.agents // []) | length) > 0
       then "active(\(.liveTerminalCount // 0)term)"
       else "idle" end)] | @tsv' |
    while IFS=$'\t' read -r p s; do printf '%s\t%s\n' "$(canon "$p")" "$s"; done >"$tmp/orca.tsv"
fi

git worktree list --porcelain | awk '
  /^worktree / { if (p != "") print p "\t" h "\t" l "\t" b; p = substr($0, 10); h = ""; l = "-"; b = "" }
  /^locked/    { l = "locked" }
  /^HEAD /     { h = $2 }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
  END          { if (p != "") print p "\t" h "\t" l "\t" b }' >"$tmp/worktrees.tsv"

projects="$HOME/.claude/projects"
# Claude Code session directories of every worktree, the main one included.
while IFS=$'\t' read -r p _; do
  for q in "$p" "$(canon "$p")"; do
    d="$projects/$(slug "$q")"
    [ -d "$d" ] && printf '%s\n' "$d"
  done
done <"$tmp/worktrees.tsv" | sort -u >"$tmp/sessiondirs"
now=$(date +%s)

echo "# base: $base"
printf 'SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tORCA\tAUTOPILOT\tLAST_CHAT\tBUCKET\tWORKTREE\n'

tail -n +2 "$tmp/worktrees.tsv" | while IFS=$'\t' read -r wt head lock branch; do
  kb=$(du -sk "$wt" 2>/dev/null | awk '{print $1}')
  [ -n "$kb" ] || kb=0
  size=$(awk -v k="$kb" 'BEGIN { if (k >= 1048576) printf "%.1fG", k/1048576; else if (k >= 1024) printf "%.0fM", k/1024; else printf "%dK", k }')

  head_ts=$(git log -1 --format=%ct "$head" 2>/dev/null)
  if [ -n "$head_ts" ]; then age="$(( (now - head_ts) / 86400 ))d"; else age="?"; fi

  # A squash merge leaves the head outside the base, so PR state is the other signal.
  if git merge-base --is-ancestor "$head" "$base" 2>/dev/null; then merged=YES; else merged=no; fi

  if [ ! -d "$wt" ]; then
    dirty=missing
  elif ! porcelain=$(git -C "$wt" status --porcelain 2>/dev/null); then
    dirty=unknown
  else
    tracked=0 untracked=0
    while IFS= read -r line; do
      case "$line" in
        '??'*) untracked=$((untracked + 1)) ;;
        '') ;;
        *) tracked=$((tracked + 1)) ;;
      esac
    done <<<"$porcelain"
    if [ "$tracked" -gt 0 ]; then dirty="wip:$tracked"
    elif [ "$untracked" -gt 0 ]; then dirty="scratch:$untracked"
    else dirty=clean; fi
  fi

  if [ -z "$branch" ]; then remote=detached
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    upstream=$(git rev-parse "refs/remotes/origin/$branch")
    if [ "$upstream" = "$head" ]; then remote=pushed
    else
      ahead=$(git rev-list --count "$upstream..$head" 2>/dev/null)
      behind=$(git rev-list --count "$head..$upstream" 2>/dev/null)
      remote="ahead${ahead:-?}/behind${behind:-?}"
    fi
  else remote=no-remote; fi

  # The PR state speaks for the worktree only when the PR's head contains it.
  pr="-"; pr_covers=no
  if [ -n "$branch" ]; then
    pr_oid=""
    while IFS=$'\t' read -r pr_head pr_state pr_head_oid; do
      if [ "$pr_head" = "$branch" ]; then pr=$pr_state pr_oid=$pr_head_oid; break; fi
    done <"$tmp/prs.tsv"
    [ -n "$pr_oid" ] && git merge-base --is-ancestor "$head" "$pr_oid" 2>/dev/null && pr_covers=yes
  fi

  cwt=$(canon "$wt")
  orca=""
  while IFS=$'\t' read -r orca_path orca_state; do
    if [ "$orca_path" = "$cwt" ]; then orca=$orca_state; break; fi
  done <"$tmp/orca.tsv"
  if [ -z "$orca" ]; then
    if [ "$orca_unknown" = yes ]; then orca="?"; else orca="-"; fi
  fi

  autopilot="-"
  gitdir=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) && [ -e "$gitdir/my-autopilot-worktree" ] && autopilot=goal

  # Sessions started in the worktree are stored under its own slug. A session
  # elsewhere worked in it when it names a file inside it, quotes the path, or
  # runs `cd <wt>` / `-C <wt>`; a bare listing of the path does not count.
  own_ts=0; mention_ts=0
  paths="($(regex_quote "$wt")|$(regex_quote "$cwt"))"
  mention_re="$paths"'(/|\\?")|(cd |-C )(\\?"|'"'"')?'"$paths"'([^A-Za-z0-9._-]|$)'
  for d in "$projects/$(slug "$wt")" "$projects/$(slug "$cwt")"; do
    [ -d "$d" ] || continue
    t=$(find "$d" -type f -name '*.jsonl' 2>/dev/null | newest_ts)
    [ "$t" -gt "$own_ts" ] && own_ts="$t"
  done
  while IFS= read -r d; do
    t=$(grep -rlF --include='*.jsonl' -e "$wt" -e "$cwt" "$d" 2>/dev/null \
      | while IFS= read -r f; do grep -qE "$mention_re" "$f" && printf '%s\n' "$f"; done | newest_ts)
    [ "$t" -gt "$mention_ts" ] && mention_ts="$t"
  done <"$tmp/sessiondirs"
  last_ts=$own_ts; [ "$mention_ts" -gt "$last_ts" ] && last_ts=$mention_ts
  if [ "$last_ts" -gt 0 ]; then last=$(fmt_day "$last_ts"); else last="-"; fi
  if [ "$last_ts" -gt 0 ] && [ $(( (now - last_ts) / 86400 )) -le 4 ]; then recent=yes; else recent=no; fi

  case "$dirty" in wip:*) bucket=hold-wip ;; *)
    if [ "$lock" = locked ]; then bucket=hold-locked; else
    case "$orca" in pinned|active*) bucket=hold-active ;; *)
      case "$pr" in */open|*/draft) bucket=hold-open-pr ;; *)
        if [ "$recent" = yes ]; then bucket=verify-recent-chat
        elif [ "$orca" = "?" ] || [ "$dirty" = unknown ]; then bucket=review
        elif [ "$merged" = YES ]; then bucket=safe
        elif [ "$pr_covers" = yes ]; then
          case "$pr" in */merged|*/closed) bucket=safe ;; *) bucket=review ;; esac
        else bucket=review
        fi ;;
      esac ;;
    esac
    fi ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$kb" "$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$orca" "$autopilot" "$last" "$bucket" "$wt"
done | sort -t "$(printf '\t')" -k1,1 -rn | cut -f2-
