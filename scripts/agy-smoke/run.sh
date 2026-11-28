#!/usr/bin/env bash
# run.sh — Run every my:* skill once in Antigravity (`agy -p`) and list the
# ones that stop, are denied a tool, or act on Claude Code terms agy lacks.
#
# Usage:
#   scripts/agy-smoke/run.sh [--plugin <dir>] [--out <dir>] [--jobs <n>]
#                            [--timeout <sec>] [--model <slug>] [<skill>...]
#
#   --plugin   plugin checkout to test (default: the checkout holding this
#              script). agy loads it as `my` from a throwaway HOME whose
#              .gemini links to the real one except config/plugins, so the
#              installed copy is not used and not changed. ~/.local/state
#              (autopilot's state) stays inside <out>/home.
#   --out      output directory (default: a new mktemp directory).
#   --jobs     cases run in parallel (default 4).
#   --timeout  agy --print-timeout per case, in seconds (default 900).
#   --model    agy --model (default: agy's own choice).
#   <skill>    run only these cases from cases.tsv.
#
# Each case runs `/my:<skill> <arguments>` from cases.tsv in a fresh fixture
# repository (fixture.sh) with:
#   - MY_TOOLKIT_DATA and ~/.claude/my-toolkit pointing at <out>/data, so the
#     Stop hook and the skills do not write the real toolkit data; it holds
#     copies of orca.conf and autonomy.conf and a draft-only PdM config whose
#     workspace is <out>/pdm-workspace;
#   - an `orca` on PATH that always fails, so run-role answers exit 3 and the
#     skill takes its in-conversation fallback instead of starting workers;
#   - --settings that deny MCP tools, pushes, PR/issue creation and gh api,
#     and, on a nix machine, let the terminal sandbox read the nix store (its
#     shell lives there; without the grant every command leaves the sandbox).
#
# Output: <out>/summary.tsv (one line per case) and, per case,
# <out>/cases/<skill>/{stream.jsonl,stderr.txt,transcript.jsonl,summary.json}.
# Flags in summary.tsv:
#   NO_SKILL   the prompt did not expand to the skill
#   TIMEOUT    no result event (print timeout or crash)
#   STOPPED    the result is not SUCCESS or has an empty response
#   DENIED     a tool call was refused (headless auto-deny or a hook)
#   ERRORS     a tool call failed
#   ASKED      the agent called ask_question (it would wait for a person)
#   CC_TERMS   a tool call or the answer carries a Claude Code term (a
#              ${CLAUDE_SKILL_DIR} the same command does not assign counts)
# A case with none of them is OK. The last line is `[agy-smoke] <out>`.
#
# Exit codes: 0 every case OK, 1 a case was flagged, 2 usage error.
# Dependencies: bash, jq, git, agy, xargs, mktemp.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CC_TERMS='\$\{?CLAUDE_(?:SKILL_DIR|PLUGIN_ROOT)|\.claude/skills/my|subagent_type|AskUserQuestion|TodoWrite|run_in_background|permission_denials|claude -p|\bAgent tool\b|\bTask tool\b|\.claude/settings'

usage() { sed -n '2,/^# Dependencies/s/^# \{0,1\}//p' "$0"; }
die() { printf 'agy-smoke: %s\n' "$*" >&2; exit 2; }

# settings_json — the --settings object each case runs with.
settings_json() {
  local allow='[]'
  [ -d /nix/store ] && allow='["read_file(/nix/store)","read_file(/run/current-system)","read_file(/etc/profiles)"]'
  jq -cn --argjson allow "$allow" '{permissions: {allow: $allow, deny: [
    "mcp(*)", "command(git push)", "command(gh pr create)", "command(gh pr merge)",
    "command(gh pr ready)", "command(gh issue create)", "command(gh api)"]}}'
}

# make_home DIR PLUGIN DATA — a HOME for agy that loads PLUGIN as `my`.
make_home() {
  local h="$1" plugin="$2" data="$3" f b
  mkdir -p "$h/.gemini/config/plugins" "$h/.claude"
  for f in "$HOME"/.gemini/* "$HOME"/.gemini/.[!.]*; do
    [ -e "$f" ] || continue
    b="${f##*/}"
    [ "$b" = config ] || ln -s "$f" "$h/.gemini/$b"
  done
  for f in "$HOME"/.gemini/config/*; do
    b="${f##*/}"
    [ "$b" = plugins ] || ln -s "$f" "$h/.gemini/config/$b"
  done
  ln -s "$plugin" "$h/.gemini/config/plugins/my"
  for b in Library .gitconfig .config .local/bin .local/share .local/lib; do
    [ -e "$HOME/$b" ] || continue
    mkdir -p "$(dirname "$h/$b")"
    ln -s "$HOME/$b" "$h/$b"
  done
  ln -s "$data" "$h/.claude/my-toolkit"
}

# summarize SKILL DIR — print the case's summary JSON.
summarize() {
  local skill="$1" d="$2" denied
  denied="$(grep -c 'auto-denied' "$d/stderr.txt" 2>/dev/null)"
  jq -sc --arg skill "$skill" --arg terms "$CC_TERMS" --argjson denied "${denied:-0}" \
    --slurpfile tr <(cat "$d/transcript.jsonl" 2>/dev/null || true) '
    ([.[] | select(.event == "step_update" and .step_update.state != "ACTIVE")
      | .step_update]) as $steps
    | ([.[] | select(.event == "result") | .result] | first) as $r
    | ([$steps[] | select(.state == "ERROR") | .tool_info.error.message // .error // "error"]) as $errs
    | ([$steps[] | select(.step_type == "tool") | .tool_info.parameters | tostring]
       + [($r.response // "")]) as $texts
    | ([$texts[] | select(test("CLAUDE_(SKILL_DIR|PLUGIN_ROOT)=") | not) | [scan($terms)] | .[]] | unique) as $found
    | (($tr | first // {}).content // "" | contains("(my:" + $skill + ") skill")) as $loaded
    | {skill: $skill,
       status: ($r.status // "NO_RESULT"),
       seconds: (($r.duration_seconds // 0) | floor),
       tools: ([$steps[] | select(.step_type == "tool")] | length),
       denied: ($denied + ([$errs[] | select(test("denied|permission"; "i"))] | length)),
       errors: ([$errs[] | select(test("denied|permission"; "i") | not)] | length),
       asked: ([$steps[] | select(.tool_name == "ask_question")] | length),
       run_role: ([$steps[] | select(.step_type == "tool") | .tool_info.parameters.CommandLine // ""
                   | select(test("run-role"))] | length),
       cc_terms: $found,
       first_error: ($errs | first // "" | .[0:160]),
       answer: (($r.response // "") | gsub("\\s+"; " ") | .[0:160])}
    | .flags = ([
        (if $loaded then empty else "NO_SKILL" end),
        (if .status == "NO_RESULT" then "TIMEOUT" else empty end),
        (if .status != "NO_RESULT" and (.status != "SUCCESS" or (($r.response // "") | length) == 0)
         then "STOPPED" else empty end),
        (if .denied > 0 then "DENIED" else empty end),
        (if .errors > 0 then "ERRORS" else empty end),
        (if .asked > 0 then "ASKED" else empty end),
        (if ($found | length) > 0 then "CC_TERMS" else empty end)])
    ' "$d/stream.jsonl" 2>/dev/null
}

# run_case SKILL — run one case under $OUT/cases/SKILL and print its summary.
run_case() {
  local skill="$1" args d cid model_args=()
  args="$(awk -F '\t' -v s="$skill" '$1 == s { print $2; exit }' "$here/cases.tsv")"
  d="$OUT/cases/$skill"
  mkdir -p "$d"
  "$here/fixture.sh" "$d/fx" >/dev/null 2>&1 || { echo "{\"skill\":\"$skill\",\"flags\":[\"FIXTURE\"]}" >"$d/summary.json"; return; }
  [ -n "$MODEL" ] && model_args=(--model "$MODEL")
  (cd "$d/fx/repo" && HOME="$OUT/home" MY_TOOLKIT_DATA="$OUT/data" PATH="$OUT/stub:$PATH" \
    agy -p "/my:$skill${args:+ $args}" --output-format stream-json \
      --print-timeout "${TIMEOUT}s" --settings "$OUT/settings.json" "${model_args[@]}" \
      >"$d/stream.jsonl" 2>"$d/stderr.txt" </dev/null)
  cid="$(jq -r 'select(.event == "init") | .conversation_id' "$d/stream.jsonl" 2>/dev/null | head -n1)"
  [ -n "$cid" ] && cp "$HOME/.gemini/antigravity-cli/brain/$cid/.system_generated/logs/transcript_full.jsonl" \
    "$d/transcript.jsonl" 2>/dev/null
  summarize "$skill" "$d" >"$d/summary.json"
}

if [ "${1:-}" = --case ]; then
  OUT="$2" TIMEOUT="$3" MODEL="$4"
  run_case "$5"
  exit 0
fi

plugin="$(cd "$here/../.." && pwd -P)" out="" jobs=4 timeout=900 model=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --plugin|--out|--jobs|--timeout|--model)
      [ $# -ge 2 ] || die "$1 needs a value"
      case "$1" in
        --plugin) plugin="$(cd "$2" && pwd -P)" || die "no such directory: $2" ;;
        --out) out="$2" ;;
        --jobs) jobs="$2" ;;
        --timeout) timeout="$2" ;;
        --model) model="$2" ;;
      esac
      shift 2 ;;
    -*) die "unknown option: $1" ;;
    *) break ;;
  esac
done
for c in jq git agy xargs; do command -v "$c" >/dev/null 2>&1 || die "$c not found"; done
[ -f "$plugin/.antigravity-plugin/plugin.json" ] || die "not a plugin checkout: $plugin"
case "$jobs$timeout" in *[!0-9]*) die "--jobs and --timeout take numbers" ;; esac

all="$(awk -F '\t' '!/^#/ && NF { print $1 }' "$here/cases.tsv")"
if [ $# -gt 0 ]; then
  for s in "$@"; do printf '%s\n' "$all" | grep -qx -- "$s" || die "no case for skill: $s"; done
  selected="$(printf '%s\n' "$@")"
else
  selected="$all"
fi

[ -n "$out" ] || out="$(mktemp -d "${TMPDIR:-/tmp}/agy-smoke.XXXXXX")"
mkdir -p "$out/data" "$out/stub" "$out/cases" || die "cannot create $out"
out="$(cd "$out" && pwd -P)"
for f in orca.conf autonomy.conf; do
  [ -f "$HOME/.claude/my-toolkit/$f" ] && cp "$HOME/.claude/my-toolkit/$f" "$out/data/"
done
mkdir -p "$out/data/pdm" "$out/pdm-workspace"
printf '# PdM Config\nupdated: %s\n\n## workspace\npath: %s\n\n## backlog\ndestination: draft-only\n\n## digest\ndefault_window: 24h\ndelivery: file\n' \
  "$(date +%F)" "$out/pdm-workspace" >"$out/data/pdm/config.md"
printf '#!/bin/sh\necho "orca: disabled by agy-smoke" >&2\nexit 1\n' >"$out/stub/orca"
chmod +x "$out/stub/orca"
make_home "$out/home" "$plugin" "$out/data"
settings_json >"$out/settings.json"

printf 'agy-smoke: plugin %s (%s), agy %s, %s case(s), output %s\n' "$plugin" \
  "$(git -C "$plugin" rev-parse --short HEAD 2>/dev/null)" "$(agy --version 2>/dev/null)" \
  "$(printf '%s\n' "$selected" | grep -c .)" "$out" >&2
printf '%s\n' "$selected" | xargs -P "$jobs" -I{} "$0" --case "$out" "$timeout" "$model" {}

status=0
{
  printf 'skill\tflags\tstatus\tseconds\ttools\tdenied\terrors\tasked\trun_role\tcc_terms\tfirst_error\tanswer\n'
  for s in $selected; do
    jq -r '[.skill, ((.flags // []) | if length == 0 then "OK" else join(",") end), .status, .seconds,
            .tools, .denied, .errors, .asked, .run_role, ((.cc_terms // []) | join(" ")),
            (.first_error // "" | gsub("[\t\n]"; " ")), (.answer // "")] | map(tostring) | join("\t")' \
      "$out/cases/$s/summary.json" 2>/dev/null || printf '%s\tNO_SUMMARY\n' "$s"
  done
} >"$out/summary.tsv"
awk -F '\t' 'NR > 1 && $2 != "OK" { bad = 1 } END { exit bad }' "$out/summary.tsv" || status=1
cut -f1-10 "$out/summary.tsv" | column -t -s "$(printf '\t')" 2>/dev/null || cut -f1-10 "$out/summary.tsv"
printf '[agy-smoke] %s\n' "$out"
exit "$status"
