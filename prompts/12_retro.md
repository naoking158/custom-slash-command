# Retro Phase Prompt

<role>
@import _shared/roles/retro.md
</role>

<arguments>
| Arg | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `--since` | duration (`Nd`) or date (`YYYY-MM-DD`) | No | `14d` | Lower-bound on the entry date. Invalid value → exit 1 with usage (Edge case #6). |
| `--category` | category enum | No | (all) | Restrict output to a single category. |
| `--min-recurrence` | integer ≥ 1 | No | `1` | Skip entries with `recurrence` below this threshold. Negative / non-numeric → exit 1 (Edge case #9). |
</arguments>

<process>
@import _shared/processes/retro.md

### Inline implementation snippets (bash + jq, MVP)

```bash
# 1. Journal directory
repo="$(basename "$PWD")"
jdir="$HOME/.claude/projects/$repo/memory/journal"
if [[ ! -d "$jdir" ]]; then
  echo "No journal entries found at $jdir. Run /my:learn first."
  exit 0
fi

# 2. --since parsing (Nd | YYYY-MM-DD). Empty / malformed → ERR.
parse_since() {
  case "$1" in
    *d)
      # macOS uses `date -v -Nd`; GNU uses `date -d "N days ago"`.
      date -v -"${1%d}"d +%Y-%m-%d 2>/dev/null \
        || date -d "${1%d} days ago" +%Y-%m-%d
      ;;
    ????-??-??)
      echo "$1"
      ;;
    *)
      echo "ERR"
      ;;
  esac
}
since="${SINCE:-14d}"
since_date="$(parse_since "$since")"
if [[ "$since_date" == "ERR" ]]; then
  echo "usage: --since <Nd|YYYY-MM-DD>" >&2
  exit 1
fi

# 3. Frontmatter extraction — schema only contains simple `key: value` pairs
# and short YAML arrays; deep nesting is out of scope by design (§4.1).
extract_fm() {
  awk 'BEGIN{p=0} /^---$/{p++; next} p==1{print}' "$1"
}
```

### Toolkit repository resolution (spec §3.5)

This MUST follow the priority order strictly. **Never fall back to `$PWD` or any
cwd-derived path** — cwd is an arbitrary project, not the toolkit repo
(US-004 AC-004 / §7.4 threat model).

The shell implementation lives in `scripts/lib/toolkit.sh` (single source of
truth — tests at `tests/journal/test_retro.bats` exercise it directly). Source
it and call `resolve_toolkit_repo`:

```bash
# shellcheck source=../scripts/lib/toolkit.sh
. "$(dirname "$0")/../scripts/lib/toolkit.sh"   # or absolute path; see helper docs
toolkit_repo="$(resolve_toolkit_repo)" || true   # empty on failure; do NOT use $PWD
```

Equivalent inline form (kept here for readability; the source-of-truth is the
helper file above):

```bash
# Resolve <toolkit_repo>; NEVER fall back to $PWD (spec §3.5 forbidden).
resolve_toolkit_repo() {
  # Priority 1: ~/.claude/commands symlink
  local link target parent
  link="$HOME/.claude/commands"
  if [ -L "$link" ]; then
    target="$(readlink "$link")"
    # Resolve relative symlinks against the symlink's own directory.
    case "$target" in
      /*) ;;
      *) target="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")" ;;
    esac
    parent="$(dirname "$target")"
    if [ -d "$target" ] && [ "$(basename "$target")" = "commands" ] && [ -d "$parent" ]; then
      printf '%s' "$parent"
      return 0
    fi
  fi
  # Priority 2: $CLAUDE_TOOLKIT_REPO env override
  if [ -n "${CLAUDE_TOOLKIT_REPO:-}" ] && [ -d "$CLAUDE_TOOLKIT_REPO" ]; then
    printf '%s' "$CLAUDE_TOOLKIT_REPO"
    return 0
  fi
  # Resolution failure — caller emits placeholder + guidance (US-004 AC-004).
  printf ''
  return 1
}
```

### Redaction handling (spec §3.3)

```bash
# Pipe each candidate's renderable text through scripts/redact.sh.
# Disposition (MVP):
#   exit 0 → redaction_status: clean   (include candidate)
#   exit 2 → redaction_status: excluded (drop candidate, log to stderr)
#   missing → warn, continue without redaction (Edge case #7)
```
</process>

<rules>
<critical>
- This command is **read-only**. Do not mutate any journal file, any `MEMORY.md`,
  any file under `<toolkit_repo>/`, or anything under `$PWD/`. Status flips
  (`raw → promoted`) are done by the user, not by this command
  (US-002 AC-004, US-004 AC-002).
- `scripts/redact.sh` exit 2 means a secret was matched; the affected candidate
  MUST be excluded from output with `redaction_status: excluded`. `masked` is
  reserved for Phase 2 and must not be emitted in MVP.
- `scripts/redact.sh` missing → warn on stderr and continue without redaction
  (Edge case #7).
- **Do NOT guess `<toolkit_repo>` from `$PWD` or any cwd-derived path** (Spec §3.5 /
  US-004 AC-004). When `resolve_toolkit_repo` returns empty, emit the literal
  string `<TOOLKIT_REPO>` as a placeholder and include the replacement guide in
  the footer.
- The `/my:change` handoff line MUST always be prefixed with `cd <toolkit_repo>`,
  e.g.:
      cd <toolkit_repo> \
        && /my:change "<title>"
  Bare `/my:change "..."` lines (without the leading `cd`) are FORBIDDEN — they
  would cause promotion artifacts to land in the user's current project
  (US-004 AC-001 / §7.4).
- Duplicate detection (Step 5 of the process) MUST grep under `<toolkit_repo>/`
  only. Do not grep under `$PWD/`.
</critical>

@import _shared/output-constraints.md
@import _shared/quality-standards.md
</rules>

<edge-cases>
- #5: Journal directory is empty / missing → `No journal entries found at <path>. Run /my:learn first.` and exit 0.
- #6: `--since` parse failure → exit 1 with `usage: --since <Nd|YYYY-MM-DD>` on stderr.
- #7: `scripts/redact.sh` not found → stderr warning, continue without redaction.
- #8: `scripts/redact.sh` exits 2 → drop the candidate, set `redaction_status: excluded`, log to stderr.
- #9: `--min-recurrence` negative or non-numeric → exit 1 with usage.
- #10: Entry has an unknown category value → treat as `domain-knowledge` and warn (rendered under that group).
- #12: Candidate matches an existing asset → annotate with `(possible duplicate of <path>)` and sort to the end of its group.
- #13: Entry is missing one of the 5 body sections → continue with the missing section treated as empty; warn.
- Toolkit symlink absent / not pointing at a `commands/` directory → resolution
  failure, emit `<TOOLKIT_REPO>` placeholder and replacement guide.
- `$CLAUDE_TOOLKIT_REPO` set but pointing at a non-existent directory →
  resolution failure (treat the same as symlink absent; do NOT fall back to cwd).
</edge-cases>

<output>
<example name="resolved">
<input>/my:retro --since 14d</input>
<result>
# Retrospective: last 14 days (12 entries scanned)
Toolkit repo: /Users/naoki/src/github.com/naoking158/custom-slash-command

## mistake (3 candidates)

### M1. "TypeScript の error union 型を `unknown` で受けない"
- Source: 2026-06-20-3f4b.md, 2026-06-25-7a06.md (recurrence: 2)
- Target asset: rules/typescript/ts-error-handling.md (possible duplicate of rules/typescript/ts-strict-null.md)
- Change summary: "error catch 句に `unknown` 型注釈を明示する例を追記"
- Next:
    cd /Users/naoki/src/github.com/naoking158/custom-slash-command \
      && /my:change "ts-error-handling: enforce unknown in catch"

## pattern (5 candidates)
...

---
Tip 1: Always run the command above **with the leading `cd`**. Dropping the
`cd` causes `/my:change` to scaffold `docs/analysis/changes/` and
`docs/plans/changes/` under the wrong project (US-004 AC-001 / §7.4).
Tip 2: After a successful promotion, manually flip the journal frontmatter
from `status: raw` to `status: promoted`.
</result>
</example>

<example name="failed">
<input>/my:retro --since 14d   # (no ~/.claude/commands symlink, no $CLAUDE_TOOLKIT_REPO)</input>
<result>
# Retrospective: last 14 days (12 entries scanned)
Toolkit repo: <TOOLKIT_REPO>  (⚠️ 自動解決に失敗)

## mistake (3 candidates)

### M1. "TypeScript の error union 型を `unknown` で受けない"
- Source: 2026-06-20-3f4b.md, 2026-06-25-7a06.md (recurrence: 2)
- Target asset: rules/typescript/ts-error-handling.md (duplicate check skipped: toolkit repo not resolved)
- Change summary: "error catch 句に `unknown` 型注釈を明示する例を追記"
- Next:
    cd <TOOLKIT_REPO> \
      && /my:change "ts-error-handling: enforce unknown in catch"

---
Tip 1: Always run the command above **with the leading `cd`**. Dropping the
`cd` causes `/my:change` to scaffold `docs/analysis/changes/` and
`docs/plans/changes/` under the wrong project (US-004 AC-001 / §7.4).
Tip 2: After a successful promotion, manually flip the journal frontmatter
from `status: raw` to `status: promoted`.

⚠️ Toolkit repo の自動解決に失敗しました。
次のいずれかで対処してください:
  1. `ln -s <custom-slash-command absolute path>/commands ~/.claude/commands` で symlink を張る
  2. 上記コマンドの `<TOOLKIT_REPO>` を手で置き換える
cwd を toolkit と推測して置換することは行いません (US-004 AC-004)。
</result>
</example>
</output>
