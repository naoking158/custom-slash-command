#!/usr/bin/env bash
# autopilot-metrics.sh — Count the effect metrics of /my:autopilot runs for /my:retro.
#
#   autopilot-metrics.sh [--since <Nd|YYYY-MM-DD>] [--until YYYY-MM-DD]
#                        [--state-dir DIR] [--checkout PATH]... [--repo OWNER/NAME]...
#
# Metrics, over the period --since..--until (inclusive; Nd is the N days ending
# on --until; default the last 28 days):
#   1. review rounds per change     autopilot tasks.tsv or progress logs
#   2. verify outcomes              autopilot tasks.tsv or progress logs
#   3. human pushback on auto/ PRs  gh
#   4. reverts of auto/ PRs         git history of each --checkout
#
# Progress logs live in <state-dir>/<owner>-<name>/<goal>/ (default state dir
# ~/.local/state/autopilot). A goal is in the period when the date on the
# `Started:` line of its goal.md is; its repository is the `Repository:` line.
# A task logged in the goal's tasks.tsv (written by autopilot's log-task.sh) is
# read from there: the last row of its task_id wins, review_rounds is the count
# and verify the outcome (fail and unknown values are 不明). Other tasks are
# read from progress.md, where only task heading sections (`## Task 2: ...`,
# `### T3 ...`, `### 1. ...`) count; a numeric task_id and a heading's task
# number name the same task.
# Within a task, the review count is the largest of `review rN`, `rN:`,
# `round N`, `N rounds`, `review N 回` on lines mentioning review; the verify
# outcome comes from lines starting with `verify`, in the order unverified
# (unverified / skill なし / スキルなし), BLOCKED, FAIL then PASS, PASS.
# Anything else is reported as 不明 rather than counted.
#
# Human pushback: auto/ PRs created in the period that carry an issue comment
# or a COMMENTED / CHANGES_REQUESTED review whose author is neither the PR's
# author nor a bot (REST user.type).
# Reverts: commits on origin/HEAD (HEAD when absent) committed in the period
# whose `This reverts commit <sha>` names an auto/ PR's merge commit, or whose
# `Revert "... (#N)"` subject names an auto/ PR.
#
# gh is used read-only. A repository whose PR list gh cannot read, or that has
# no --checkout for the git metric, is reported under 不明のリポジトリ.
#
# Exit status: 0 printed the report, 2 usage error.
# Environment: MY_METRICS_TODAY (YYYY-MM-DD) overrides today, for tests.
# Dependencies: bash, jq, git, gh.
set -u -o pipefail

usage() {
  echo "usage: autopilot-metrics.sh [--since <Nd|YYYY-MM-DD>] [--until YYYY-MM-DD] [--state-dir DIR] [--checkout PATH]... [--repo OWNER/NAME]..." >&2
  exit 2
}

is_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }

since_arg="28d" until="" state_dir="$HOME/.local/state/autopilot"
checkouts=() only_repos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --since) [ $# -ge 2 ] || usage; since_arg="$2"; shift 2 ;;
    --until) [ $# -ge 2 ] || usage; until="$2"; shift 2 ;;
    --state-dir) [ $# -ge 2 ] || usage; state_dir="$2"; shift 2 ;;
    --checkout) [ $# -ge 2 ] || usage; checkouts+=("$2"); shift 2 ;;
    --repo) [ $# -ge 2 ] || usage; only_repos+=("$2"); shift 2 ;;
    *) usage ;;
  esac
done

today="${MY_METRICS_TODAY:-$(date +%Y-%m-%d)}"
is_date "$today" || usage
[ -n "$until" ] || until="$today"
is_date "$until" || usage
if [[ "$since_arg" =~ ^[0-9]+d$ ]]; then
  since="$(jq -nr --arg t "$until" --argjson n "${since_arg%d}" \
    '($t + "T00:00:00Z" | fromdateiso8601) - ($n - 1) * 86400 | strftime("%Y-%m-%d")')"
elif is_date "$since_arg"; then
  since="$since_arg"
else
  usage
fi

# repo_wanted <owner/name> — true when no --repo was given or it is one of them.
repo_wanted() {
  [ ${#only_repos[@]} -eq 0 ] && return 0
  local r
  for r in "${only_repos[@]}"; do [ "$r" = "$1" ] && return 0; done
  return 1
}

# parse_goal <goal dir> — one JSON object: the goal's repository, start date,
# and one {rounds, verify} per task from tasks.tsv and progress.md.
parse_goal() {
  local goal_md="$1/goal.md" progress="$1/progress.md" tsv="$1/tasks.tsv" head="" rows=""
  [ -f "$goal_md" ] && head="$(cat "$goal_md")"
  [ -f "$tsv" ] && rows="$(cat "$tsv")"
  { [ -f "$progress" ] && cat "$progress"; } | jq -Rs --arg goal "$head" --arg tsv "$rows" '
    def norm: if test("^[0-9]+$") then tonumber | tostring else . end;
    def heading_level: capture("^(?<h>#+) ").h | length;
    def task_number:
      (capture("^#+ +(?:[Tt]ask|T) *(?<n>[0-9]+)") // capture("^#+ +(?<n>[0-9]+)\\.") // null)
      | if . then .n else null end;
    def rounds:
      [ .[] | select(test("review|round"; "i"))
        | ( [ scan("review:? *r([0-9]+)"; "i"), scan("(?:^|[^A-Za-z0-9])r([0-9]+):"),
              scan("round *([0-9]+)"; "i"), scan("([0-9]+) *rounds?"; "i"),
              scan("review[^0-9\\n]{0,3}([0-9]+) *回"; "i") ]
            | .[] | .[0] | tonumber ) ]
      | if length == 0 then null else max end;
    def verify:
      [ .[] | select(test("^\\s*[-*]?\\s*verify"; "i")) ] | join("\n")
      | if . == "" then "unknown"
        elif test("unverified|skill ?なし|スキルなし"; "i") then "unverified"
        elif test("BLOCKED") then "blocked"
        elif test("FAIL[\\s\\S]*PASS") then "pass_after_fix"
        elif test("FAIL") then "unknown"
        elif test("PASS") then "pass"
        else "unknown" end;
    ( split("\n")
      | reduce .[] as $l ({cur: null, lvl: 0, tasks: {}};
          if ($l | test("^#+ ")) and (.cur == null or ($l | heading_level) <= .lvl) then
            ($l | task_number) as $n
            | if $n then .cur = $n | .lvl = ($l | heading_level) | .tasks[$n] += []
              else .cur = null end
          elif .cur then .tasks[.cur] += [$l]
          else . end)
      | .tasks | with_entries(.key |= norm | .value |= {rounds: rounds, verify: verify}) ) as $tasks
    | ( $tsv | split("\n") | map(rtrimstr("\r") | select(test("\\S")) | split("\t") | map(ltrimstr("\u0027")))
        | (.[0] // []) as $h
        | ($h | index("task_id")) as $id
        | ($h | index("review_rounds")) as $rc
        | ($h | index("verify")) as $vc
        | if $id == null then {}
          else reduce .[1:][] as $row ({};
              def cell($c): if $c == null then "" else $row[$c] // "" end;
              (cell($id) | norm) as $k
              | if $k == "" then .
                else .[$k] = {
                  rounds: (cell($rc) | if test("^[0-9]+$") then tonumber else null end),
                  verify: (cell($vc) | if IN("pass", "pass_after_fix", "blocked", "unverified") then . else "unknown" end) }
                end)
          end ) as $logged
    | {
        repo: ($goal | capture("Repository: *(?<r>[^ \\n]+)").r // null),
        started: ($goal | capture("Started: *(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})").d // null),
        tasks: [ ($tasks + $logged)[] ]
      }'
}

goals_json="$(
  for dir in "$state_dir"/*/*/; do
    [ -f "$dir/goal.md" ] || [ -f "$dir/progress.md" ] || continue
    parse_goal "${dir%/}"
  done | jq -s '.'
)"
[ -n "$goals_json" ] || goals_json="[]"

only_json="$(printf '%s\n' ${only_repos[@]+"${only_repos[@]}"} | jq -Rsc 'split("\n") | map(select(. != ""))')"
progress_json="$(jq -c --arg s "$since" --arg u "$until" --argjson only "$only_json" '
  map(select(($only | length) == 0 or (.repo as $r | $only | index($r))))
  | { undated: map(select(.started == null)) | length,
      goals: map(select(.started != null and .started >= $s and .started <= $u)) }
  | .no_tasks = (.goals | map(select(.tasks | length == 0)) | length)
  | .repos = (.goals | map(.repo | select(. != null)) | unique)
  | .tasks = [.goals[].tasks[]]' <<<"$goals_json")"

# checkout_repo <path> — owner/name from the checkout's origin URL, or empty.
checkout_repo() {
  git -C "$1" remote get-url origin 2>/dev/null |
    sed -nE 's#^.*github\.com[:/]+([^/]+/[^/]+)$#\1#p' | sed -E 's#\.git$##'
}

checkout_pairs=""
for c in ${checkouts[@]+"${checkouts[@]}"}; do
  r="$(checkout_repo "$c")"
  [ -n "$r" ] || { echo "autopilot-metrics.sh: no GitHub origin in $c" >&2; continue; }
  repo_wanted "$r" || continue
  checkout_pairs="$checkout_pairs$r"$'\t'"$c"$'\n'
done

repos="$( { jq -r '.repos[]' <<<"$progress_json"
            printf '%s' "$checkout_pairs" | cut -f1
            printf '%s\n' ${only_repos[@]+"${only_repos[@]}"}; } | sed '/^$/d' | sort -u)"
# pr_is_auto <owner/name> <number|sha> — prints true/false: whether the PR
# with that number, or containing that commit, came from an auto/ branch.
pr_is_auto() {
  local heads
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    heads="$(gh pr view "$2" -R "$1" --json headRefName -q .headRefName 2>/dev/null)" || return 1
  else
    heads="$(gh pr list -R "$1" --state all --search "$2" --json headRefName -q '.[].headRefName' 2>/dev/null)" || return 1
  fi
  if printf '%s\n' "$heads" | grep -q '^auto/'; then echo true; else echo false; fi
}

# human_pushback <owner/name> <number> <PR author> — prints true/false: whether
# someone other than the PR author, and not a bot, commented on the PR or left
# a COMMENTED / CHANGES_REQUESTED review. Bots are told by the REST user.type.
human_pushback() {
  local filter='map(select(.user.type != "Bot" and .user.login != $a and
    ((.state // "COMMENTED") == "COMMENTED" or .state == "CHANGES_REQUESTED"))) | length'
  local c r
  c="$(gh api --paginate "repos/$1/issues/$2/comments" 2>/dev/null | jq -s --arg a "$3" "add // [] | $filter")" || return 1
  r="$(gh api --paginate "repos/$1/pulls/$2/reviews" 2>/dev/null | jq -s --arg a "$3" "add // [] | $filter")" || return 1
  [ -n "$c" ] && [ -n "$r" ] || return 1
  if [ "$c" -gt 0 ] || [ "$r" -gt 0 ]; then echo true; else echo false; fi
}

# repo_metrics <owner/name> — one JSON object with the gh and git counts of one repository.
repo_metrics() {
  local repo="$1" prs created checkout ref target linked number author human
  local reverts=0 unlinked=0 pushback=0 has_git=false
  if ! prs="$(gh pr list -R "$repo" --state all --limit 1000 --search "created:$since..$until" \
      --json number,headRefName,state,createdAt,author,comments,reviews 2>/dev/null)" ||
     ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$prs"; then
    jq -nc --arg r "$repo" '{repo: $r, gh: false, git: false}'
    return
  fi
  checkout="$(printf '%s' "$checkout_pairs" | awk -F'\t' -v r="$repo" '$1 == r { print $2; exit }')"
  if [ -n "$checkout" ]; then
    has_git=true
    ref=origin/HEAD
    git -C "$checkout" rev-parse -q --verify "$ref" >/dev/null || ref=HEAD
    while IFS= read -r target; do
      [ -n "$target" ] || continue
      if ! linked="$(pr_is_auto "$repo" "$target")"; then has_git=false; break; fi
      if [ "$linked" = true ]; then reverts=$((reverts + 1)); else unlinked=$((unlinked + 1)); fi
    done < <(git -C "$checkout" log "$ref" --since="$since 00:00:00" \
               --format='%H%x1f%cs%x1f%s%x1f%b%x1e' 2>/dev/null |
             jq -Rsr --arg s "$since" --arg u "$until" '
               split("\u001e")[] | ltrimstr("\n") | select(. != "") | split("\u001f")
               | {date: .[1], subject: .[2], body: (.[3] // "")}
               | select(.date >= $s and .date <= $u)
               | ((.subject | capture("^Revert \"(?<s>.*)\"").s | capture("\\(#(?<n>[0-9]+)\\)$").n)
                  // (.body | capture("This reverts commit (?<sha>[0-9a-f]{7,40})").sha)
                  // empty)')
  fi
  created="$(jq -c --arg s "$since" --arg u "$until" '
    map(select((.headRefName | startswith("auto/")) and .createdAt[0:10] >= $s and .createdAt[0:10] <= $u))' <<<"$prs")"
  while IFS=$'\t' read -r number author; do
    [ -n "$number" ] || continue
    if ! human="$(human_pushback "$repo" "$number" "$author")"; then
      jq -nc --arg r "$repo" '{repo: $r, gh: false, git: false}'
      return
    fi
    [ "$human" = true ] && pushback=$((pushback + 1))
  done < <(jq -r '.[] | .author.login as $a
      | select([ (.comments[]?), (.reviews[]? | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED")) ]
               | any(.author.login != $a))
      | [.number, $a] | @tsv' <<<"$created")
  jq -c --arg r "$repo" --argjson git "$has_git" --argjson pushback "$pushback" \
    --argjson reverts "$reverts" --argjson unlinked "$unlinked" '
    { repo: $r, gh: true, git: $git, reverts: $reverts, unlinked: $unlinked, pushback: $pushback,
      auto_prs: length, closed: map(select(.state == "CLOSED")) | length }' <<<"$created"
}

repo_json="$(
  while IFS= read -r repo; do
    [ -n "$repo" ] && repo_metrics "$repo"
  done <<<"$repos" | jq -s '.'
)"
[ -n "$repo_json" ] || repo_json="[]"

jq -rn --arg s "$since" --arg u "$until" --argjson p "$progress_json" --argjson r "$repo_json" '
  def count(f): map(select(f)) | length;
  def names: if length == 0 then "" else "（" + (map(.repo) | join(", ")) + "）" end;
  ($p.tasks | map(.rounds | select(. != null))) as $rounds
  | ($r | map(select(.gh))) as $gh
  | ($r | map(select(.gh and .git))) as $git
  | ($r | map(select(.gh | not))) as $no_gh
  | ($r | map(select(.gh and (.git | not)))) as $no_git
  | "期間: \($s)..\($u)",
    "進行の記録: ゴール \($p.goals | length)、タスク \($p.tasks | length)（Started が読めないゴール \($p.undated)、タスクの見出しがないゴール \($p.no_tasks)）",
    "レビューの往復数: 読めた \($rounds | length)"
      + (if ($rounds | length) > 0 then
           "（" + ($rounds | group_by(.) | map("\(.[0])回 \(length)") | join("、"))
           + "、平均 \(($rounds | add) / ($rounds | length) * 100 | round / 100)）"
         else "" end)
      + "、不明 \($p.tasks | count(.rounds == null))",
    "verify: PASS \($p.tasks | count(.verify == "pass"))、修正後に PASS \($p.tasks | count(.verify == "pass_after_fix"))、BLOCKED \($p.tasks | count(.verify == "blocked"))、未検証 \($p.tasks | count(.verify == "unverified"))、不明 \($p.tasks | count(.verify == "unknown"))",
    "人間の差し戻し: auto/ の PR \($gh | map(.auto_prs) | add // 0)、人間のコメントか変更要求 \($gh | map(.pushback) | add // 0)、マージせずに閉じた \($gh | map(.closed) | add // 0)、不明のリポジトリ \($no_gh | length)\($no_gh | names)",
    "マージ後の手戻り: auto/ の PR を取り消したコミット \($git | map(.reverts) | add // 0)、auto/ と結びつかない revert \($git | map(.unlinked) | add // 0)、不明のリポジトリ \(($no_gh + $no_git) | length)\(($no_gh + $no_git) | names)"'
