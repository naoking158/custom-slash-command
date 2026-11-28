#!/usr/bin/env bash
# sync-origin.sh — Fetch the toolkit repo's origin and bring its checkout up to
# date when that is safe, for /my:retro.
#
#   sync-origin.sh <toolkit_repo>
#
# Fetches origin, then fast-forwards the checkout to origin/<default> only when
# it is on the default branch, has no uncommitted changes to tracked files and
# is behind origin/<default> without commits of its own. Any other checkout is
# left as it is. The default branch is origin/HEAD, or what origin reports as
# HEAD when that ref is missing.
#
# Prints two lines:
#   base: origin/<default> <sha>      the ref and commit to judge signals on
#   checkout: updated <old>..<new> | current | kept (<reason>)
# When the fetch fails, a third line `fetch: failed (...)` follows and base is
# the remote-tracking ref as of the last successful fetch.
#
# Exit status: 0 fetched, 1 the fetch failed (base may be stale), 2 usage error,
# not a Git repository, or no default branch found.
# Dependencies: bash, git.
set -u

fail() {
  echo "sync-origin: $1" >&2
  exit 2
}

[ $# -eq 1 ] || fail "usage: sync-origin.sh <toolkit_repo>"
repo="$1"
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "$repo is not a Git checkout"
git -C "$repo" remote get-url origin >/dev/null 2>&1 || fail "$repo has no origin remote"

fetch_err="$(git -C "$repo" fetch --quiet origin 2>&1)"
fetched=$?

default="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"
default="${default#origin/}"
if [ -z "$default" ] && [ "$fetched" -eq 0 ]; then
  default="$(git -C "$repo" ls-remote --symref origin HEAD 2>/dev/null \
    | sed -n 's#^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$#\1#p')"
fi
[ -n "$default" ] || fail "cannot tell the default branch of origin"
base_sha="$(git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$default")" \
  || fail "origin/$default does not exist; fetch it first"

checkout_state() {
  local branch head
  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD)" || { echo "kept (detached HEAD)"; return; }
  [ "$branch" = "$default" ] || { echo "kept (on branch $branch, not $default)"; return; }
  [ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ] \
    || { echo "kept (uncommitted changes)"; return; }
  head="$(git -C "$repo" rev-parse HEAD)"
  [ "$head" != "$base_sha" ] || { echo "current"; return; }
  if ! git -C "$repo" merge-base --is-ancestor "$head" "$base_sha"; then
    if git -C "$repo" merge-base --is-ancestor "$base_sha" "$head"; then
      echo "kept (ahead of origin/$default)"
    else
      echo "kept (diverged from origin/$default)"
    fi
    return
  fi
  [ "$fetched" -eq 0 ] || { echo "kept (fetch failed)"; return; }
  if git -C "$repo" merge --ff-only --quiet "$base_sha" >/dev/null 2>&1; then
    echo "updated ${head:0:7}..${base_sha:0:7}"
  else
    echo "kept (fast-forward refused, e.g. an untracked file in the way)"
  fi
}

echo "base: origin/$default $base_sha"
echo "checkout: $(checkout_state)"
if [ "$fetched" -ne 0 ]; then
  echo "fetch: failed ($(printf '%s' "$fetch_err" | head -n 1))"
  exit 1
fi
exit 0
