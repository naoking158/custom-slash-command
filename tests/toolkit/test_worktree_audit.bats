#!/usr/bin/env bats
# Tests for scripts/lib/worktree-audit.sh with stub gh and orca on PATH.
#
# Contract under test:
#   - Buckets, first match wins: hold-wip, hold-active (Orca pinned or
#     active), hold-open-pr, verify-recent-chat, review when the Orca list is
#     truncated and misses the worktree, safe (merged or PR merged/closed),
#     review.
#   - A recent session counts whether it ran in the worktree itself or in the
#     main checkout and mentioned the worktree's path.
#   - Orca rows match through symlinked paths; without orca the column is -.
#   - The audit changes no worktree, file or ref.
#   - Bad options and non-repositories exit 2.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  AUDIT="$REPO_ROOT/scripts/lib/worktree-audit.sh"
  TMP="$(cd "$(mktemp -d -t worktree-audit-test.XXXXXX)" && pwd -P)"
  mkdir -p "$TMP/bin" "$TMP/home"
  export HOME="$TMP/home"
  export PATH="$TMP/bin:$(path_without_orca)"
  if command -v orca >/dev/null; then return 1; fi
  echo '[]' >"$TMP/prs.json"
  cat >"$TMP/bin/gh" <<SH
#!/bin/bash
[ "\$1 \$2" = "pr list" ] || exit 64
cat "$TMP/prs.json"
SH
  chmod +x "$TMP/bin/gh"

  REPO="$TMP/repo"
  git init -q -b main "$REPO"
  git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

# path_without_orca — $PATH minus every directory holding an orca executable.
path_without_orca() {
  local dir out="" IFS=:
  for dir in $PATH; do
    [ -x "$dir/orca" ] && continue
    out="${out:+$out:}$dir"
  done
  printf '%s' "$out"
}

# add_wt NAME — a worktree on branch NAME with one commit not in main.
add_wt() {
  git -C "$REPO" worktree add -q -b "$1" "$TMP/$1"
  git -C "$TMP/$1" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m "$1"
}

# fake_orca WORKTREES_JSON [TRUNCATED] — a reachable orca listing WORKTREES_JSON.
fake_orca() {
  printf '{"ok":true,"result":{"truncated":%s,"worktrees":%s}}' "${2:-false}" "$1" >"$TMP/ps.json"
  cat >"$TMP/bin/orca" <<SH
#!/bin/bash
case "\$*" in
  "status --json") echo '{"ok":true,"result":{"runtime":{"reachable":true}}}' ;;
  "worktree ps --limit 500 --json") cat "$TMP/ps.json" ;;
  *) exit 64 ;;
esac
SH
  chmod +x "$TMP/bin/orca"
}

# field WORKTREE COLUMN — one column of the row for WORKTREE in $output.
field() {
  printf '%s\n' "$output" | awk -F'\t' -v w="$1" -v c="$2" '
    $NF == "WORKTREE" { for (i = 1; i <= NF; i++) if ($i == c) n = i }
    $NF == w { print $n }'
}

audit() {
  run "$AUDIT" -b main "$REPO"
  [ "$status" -eq 0 ]
}

@test "tracked edits make hold-wip" {
  add_wt wip
  echo x >"$TMP/wip/file"
  git -C "$TMP/wip" add file
  audit
  [ "$(field "$TMP/wip" DIRTY)" = "wip:1" ]
  [ "$(field "$TMP/wip" BUCKET)" = "hold-wip" ]
}

@test "untracked files only are scratch and do not hold" {
  add_wt scratch
  echo x >"$TMP/scratch/a"
  audit
  [ "$(field "$TMP/scratch" DIRTY)" = "scratch:1" ]
  [ "$(field "$TMP/scratch" BUCKET)" = "review" ]
}

@test "orca pinned and live terminals make hold-active" {
  add_wt pinned
  add_wt live
  fake_orca "[{\"path\":\"$TMP/pinned\",\"isPinned\":true},{\"path\":\"$TMP/live\",\"isPinned\":false,\"isActive\":false,\"liveTerminalCount\":1,\"agents\":[]}]"
  audit
  [ "$(field "$TMP/pinned" ORCA)" = "pinned" ]
  [ "$(field "$TMP/pinned" BUCKET)" = "hold-active" ]
  [ "$(field "$TMP/live" ORCA)" = "active(1term)" ]
  [ "$(field "$TMP/live" BUCKET)" = "hold-active" ]
}

@test "orca path through a symlink matches the worktree" {
  add_wt linked
  git -C "$REPO" merge -q --ff-only linked
  ln -s "$TMP" "$TMP/alias"
  fake_orca "[{\"path\":\"$TMP/alias/linked\",\"isPinned\":false,\"isActive\":true,\"liveTerminalCount\":0}]"
  audit
  [ "$(field "$TMP/linked" ORCA)" = "active(0term)" ]
  [ "$(field "$TMP/linked" BUCKET)" = "hold-active" ]
}

@test "open and draft PRs make hold-open-pr" {
  add_wt open
  add_wt draft
  echo '[{"number":1,"state":"OPEN","isDraft":false,"headRefName":"open"},{"number":2,"state":"OPEN","isDraft":true,"headRefName":"draft"}]' >"$TMP/prs.json"
  audit
  [ "$(field "$TMP/open" PR)" = "#1/open" ]
  [ "$(field "$TMP/open" BUCKET)" = "hold-open-pr" ]
  [ "$(field "$TMP/draft" PR)" = "#2/draft" ]
  [ "$(field "$TMP/draft" BUCKET)" = "hold-open-pr" ]
}

@test "session in the main checkout naming the worktree makes verify-recent-chat" {
  add_wt chat
  git -C "$REPO" merge -q --ff-only chat
  local d="$HOME/.claude/projects/$(printf '%s' "$REPO" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$d"
  printf '{"cwd":"%s"}\n' "$TMP/chat" >"$d/session.jsonl"
  audit
  [ "$(field "$TMP/chat" BUCKET)" = "verify-recent-chat" ]
}

@test "session started in the worktree makes verify-recent-chat" {
  add_wt own
  git -C "$REPO" merge -q --ff-only own
  local d="$HOME/.claude/projects/$(printf '%s' "$TMP/own" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$d"
  echo '{}' >"$d/session.jsonl"
  audit
  [ "$(field "$TMP/own" BUCKET)" = "verify-recent-chat" ]
}

@test "a sibling path with the same prefix is not a mention" {
  add_wt sib
  git -C "$REPO" merge -q --ff-only sib
  local d="$HOME/.claude/projects/$(printf '%s' "$REPO" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$d"
  printf '{"cwd":"%s"}\n' "$TMP/sib-2" >"$d/session.jsonl"
  audit
  [ "$(field "$TMP/sib" BUCKET)" = "safe" ]
}

@test "merged commits or a merged or closed PR make safe and the marker shows goal" {
  add_wt merged
  git -C "$REPO" merge -q --ff-only merged
  touch "$(git -C "$TMP/merged" rev-parse --absolute-git-dir)/my-autopilot-worktree"
  add_wt squashed
  add_wt closed
  echo '[{"number":3,"state":"MERGED","isDraft":false,"headRefName":"squashed"},{"number":4,"state":"CLOSED","isDraft":false,"headRefName":"closed"}]' >"$TMP/prs.json"
  audit
  [ "$(field "$TMP/merged" MERGED)" = "YES" ]
  [ "$(field "$TMP/merged" BUCKET)" = "safe" ]
  [ "$(field "$TMP/merged" AUTOPILOT)" = "goal" ]
  [ "$(field "$TMP/squashed" BUCKET)" = "safe" ]
  [ "$(field "$TMP/closed" BUCKET)" = "safe" ]
  [ "$(field "$TMP/closed" AUTOPILOT)" = "-" ]
}

@test "unmerged without PR or session is review" {
  add_wt lone
  audit
  [ "$(field "$TMP/lone" MERGED)" = "no" ]
  [ "$(field "$TMP/lone" PR)" = "-" ]
  [ "$(field "$TMP/lone" BUCKET)" = "review" ]
}

@test "without orca the column is - and the audit succeeds" {
  add_wt plain
  audit
  [ "$(field "$TMP/plain" ORCA)" = "-" ]
}

@test "a truncated orca list puts unlisted worktrees in review, not safe" {
  add_wt unlisted
  git -C "$REPO" merge -q --ff-only unlisted
  add_wt listed
  git -C "$REPO" merge -q --ff-only listed
  fake_orca "[{\"path\":\"$TMP/listed\",\"isPinned\":false,\"isActive\":false,\"liveTerminalCount\":0}]" true
  audit
  [[ "$output" == *"truncated"* ]]
  [ "$(field "$TMP/unlisted" ORCA)" = "?" ]
  [ "$(field "$TMP/unlisted" BUCKET)" = "review" ]
  [ "$(field "$TMP/listed" ORCA)" = "idle" ]
  [ "$(field "$TMP/listed" BUCKET)" = "safe" ]
}

@test "the audit changes no worktree, file or ref" {
  add_wt keep
  echo x >"$TMP/keep/file"
  git -C "$TMP/keep" add file
  echo y >"$TMP/keep/new"
  local before after
  before="$(git -C "$REPO" for-each-ref; git -C "$REPO" worktree list --porcelain; git -C "$TMP/keep" status --porcelain; ls -la "$TMP/keep")"
  audit
  after="$(git -C "$REPO" for-each-ref; git -C "$REPO" worktree list --porcelain; git -C "$TMP/keep" status --porcelain; ls -la "$TMP/keep")"
  [ "$before" = "$after" ]
}

@test "bad option and non-repository exit 2, help exits 0" {
  run "$AUDIT" --nope "$REPO"
  [ "$status" -eq 2 ]
  mkdir "$TMP/plain-dir"
  run "$AUDIT" "$TMP/plain-dir"
  [ "$status" -eq 2 ]
  run "$AUDIT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: worktree-audit.sh"* ]]
}
