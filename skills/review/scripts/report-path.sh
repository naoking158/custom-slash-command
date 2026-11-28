#!/usr/bin/env bash
# report-path.sh — Print where a review writes its report, without the extension.
#
#   report-path.sh --type <type> --id <id> [--perspective <p>]
#                  [--report-dir <dir>] [--head <sha>] [--since <sha>]
#
# Without --report-dir the path is docs/reviews/<type>/<id>[--<p>], the same
# for every run, so a new review replaces the previous one.
#
# With --report-dir every run gets its own name, so earlier rounds stay:
#   <dir>/<type>/<id>[-<since7>..<head7> | -<head7>][-<k>][--<p>]
# --head is the commit the review read (a PR's head), --since the reviewed
# commit a delta review started from. When a .md, .json or .html of that name
# already exists, -2, -3 ... is added until none does.
#
# The caller appends .md / .json / .html. Prints one line; exit 0 on success,
# 2 on a usage error.
set -euo pipefail

usage() {
  echo "usage: report-path.sh --type <type> --id <id> [--perspective <p>] [--report-dir <dir>] [--head <sha>] [--since <sha>]" >&2
  exit 2
}

type="" id="" perspective="" dir="" head="" since=""
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case "$1" in
    --type) type="$2" ;;
    --id) id="$2" ;;
    --perspective) perspective="$2" ;;
    --report-dir) dir="$2" ;;
    --head) head="$2" ;;
    --since) since="$2" ;;
    *) echo "report-path.sh: unknown argument: $1" >&2; usage ;;
  esac
  shift 2
done
[ -n "$type" ] && [ -n "$id" ] || usage
if [ -n "$since" ] && [ -z "$head" ]; then
  echo "report-path.sh: --since needs --head" >&2
  usage
fi

suffix=""
[ -z "$perspective" ] || suffix="--$perspective"

if [ -z "$dir" ]; then
  echo "docs/reviews/$type/$id$suffix"
  exit 0
fi

base="$dir/$type/$id"
if [ -n "$since" ]; then
  base="$base-${since:0:7}..${head:0:7}"
elif [ -n "$head" ]; then
  base="$base-${head:0:7}"
fi

taken() {
  [ -e "$1$suffix.md" ] || [ -e "$1$suffix.json" ] || [ -e "$1$suffix.html" ]
}

stem="$base"
k=2
while taken "$stem"; do
  stem="$base-$k"
  k=$((k + 1))
done
echo "$stem$suffix"
