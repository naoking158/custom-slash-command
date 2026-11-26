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
# Buckets, first match wins: hold-wip (tracked edits), hold-active (Orca pinned
# or active), hold-open-pr, verify-recent-chat (a session in the last 4 days),
# review (Orca list truncated and this worktree not in it), safe (merged into
# the base, or its PR merged or closed), review.
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
slug() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

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
  && raw=$(gh pr list --author "@me" --state all --limit 1000 --json number,state,isDraft,headRefName 2>/dev/null) \
  && printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
  printf '%s' "$raw" | jq '[.[] | {number, head: .headRefName,
    state: (if .isDraft == true and .state == "OPEN" then "draft" else (.state | ascii_downcase) end)}]' >"$tmp/prs.json"
fi

# Orca state by canonical path, fetched once. Only when the runtime answers.
orca_truncated=no
: >"$tmp/orca.tsv"
if command -v orca >/dev/null 2>&1 \
  && orca status --json 2>/dev/null | jq -e '.ok == true and .result.runtime.reachable == true' >/dev/null 2>&1 \
  && raw=$(orca worktree ps --limit 500 --json 2>/dev/null) \
  && printf '%s' "$raw" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1; then
  if printf '%s' "$raw" | jq -e '.result.truncated == true' >/dev/null 2>&1; then
    orca_truncated=yes
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
  /^worktree / { if (p != "") print p "\t" h "\t" b; p = substr($0, 10); h = ""; b = "" }
  /^HEAD /     { h = $2 }
  /^branch /   { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
  END          { if (p != "") print p "\t" h "\t" b }' >"$tmp/worktrees.tsv"

main_wt=$(head -1 "$tmp/worktrees.tsv" | cut -f1)
projects="$HOME/.claude/projects"
now=$(date +%s)

echo "# base: $base"
printf 'SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tORCA\tAUTOPILOT\tLAST_CHAT\tBUCKET\tWORKTREE\n'

tail -n +2 "$tmp/worktrees.tsv" | while IFS=$'\t' read -r wt head branch; do
  kb=$(du -sk "$wt" 2>/dev/null | awk '{print $1}')
  [ -n "$kb" ] || kb=0
  size=$(awk -v k="$kb" 'BEGIN { if (k >= 1048576) printf "%.1fG", k/1048576; else if (k >= 1024) printf "%.0fM", k/1024; else printf "%dK", k }')

  head_ts=$(git log -1 --format=%ct "$head" 2>/dev/null)
  if [ -n "$head_ts" ]; then age="$(( (now - head_ts) / 86400 ))d"; else age="?"; fi

  # A squash merge leaves the head outside the base, so PR state is the other signal.
  if git merge-base --is-ancestor "$head" "$base" 2>/dev/null; then merged=YES; else merged=no; fi

  if [ ! -d "$wt" ]; then
    dirty=missing
  else
    porcelain=$(git -C "$wt" status --porcelain 2>/dev/null)
    tracked=$(printf '%s\n' "$porcelain" | grep -v '^??' | grep -c . )
    untracked=$(printf '%s\n' "$porcelain" | grep -c '^??')
    if [ "$tracked" -gt 0 ]; then dirty="wip:$tracked"
    elif [ "$untracked" -gt 0 ]; then dirty="scratch:$untracked"
    else dirty=clean; fi
  fi

  if [ -z "$branch" ]; then remote=detached
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    if [ "$(git rev-parse "refs/remotes/origin/$branch")" = "$head" ]; then remote=pushed
    else remote="ahead$(git rev-list --count "refs/remotes/origin/$branch..$head" 2>/dev/null)"; fi
  else remote=no-remote; fi

  pr="-"
  if [ -n "$branch" ]; then
    pr=$(jq -r --arg b "$branch" '[.[] | select(.head == $b)] | first | if . then "#\(.number)/\(.state)" else "-" end' "$tmp/prs.json")
  fi

  cwt=$(canon "$wt")
  orca=$(awk -F'\t' -v p="$cwt" '$1 == p { print $2; exit }' "$tmp/orca.tsv")
  if [ -z "$orca" ]; then
    if [ "$orca_truncated" = yes ]; then orca="?"; else orca="-"; fi
  fi

  autopilot="-"
  gitdir=$(git -C "$wt" rev-parse --absolute-git-dir 2>/dev/null) && [ -e "$gitdir/my-autopilot-worktree" ] && autopilot=goal

  # Sessions started in the worktree are stored under its own slug; sessions in
  # the main checkout that touched it mention its path followed by / or a quote.
  own_ts=0; main_ts=0
  for d in "$projects/$(slug "$wt")" "$projects/$(slug "$cwt")"; do
    [ -d "$d" ] || continue
    t=$(find "$d" -type f -name '*.jsonl' 2>/dev/null | newest_ts)
    [ "$t" -gt "$own_ts" ] && own_ts="$t"
  done
  d="$projects/$(slug "$main_wt")"
  if [ -d "$d" ]; then
    main_ts=$(grep -rlF --include='*.jsonl' -e "$wt/" -e "$wt\"" "$d" 2>/dev/null | newest_ts)
  fi
  last_ts=$own_ts; [ "$main_ts" -gt "$last_ts" ] && last_ts=$main_ts
  if [ "$last_ts" -gt 0 ]; then last=$(fmt_day "$last_ts"); else last="-"; fi
  if [ "$last_ts" -gt 0 ] && [ $(( (now - last_ts) / 86400 )) -le 4 ]; then recent=yes; else recent=no; fi

  case "$dirty" in wip:*) bucket=hold-wip ;; *)
    case "$orca" in pinned|active*) bucket=hold-active ;; *)
      case "$pr" in */open|*/draft) bucket=hold-open-pr ;; *)
        if [ "$recent" = yes ]; then bucket=verify-recent-chat
        elif [ "$orca" = "?" ]; then bucket=review
        elif [ "$merged" = YES ]; then bucket=safe
        else case "$pr" in */merged|*/closed) bucket=safe ;; *) bucket=review ;; esac
        fi ;;
      esac ;;
    esac ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$kb" "$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$orca" "$autopilot" "$last" "$bucket" "$wt"
done | sort -t "$(printf '\t')" -k1,1 -rn | cut -f2-
