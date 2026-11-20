# `review.json` contract

The single artifact the reviewer writes for a diff target. The screen
(`{id}.html`) and the report (`{id}.md`) are both generated from it, so
anything not in here does not exist downstream.

`build-screen.sh` machine-checks this contract and refuses to build on a
violation, listing every offending line. Fix the JSON, do not work around the
check.

## Four hard rules

1. **Hunk ids come from `hunks.tsv`.** Never invent, renumber, or guess one.
2. **Every hunk appears exactly once** across `groups[].hunks` and
   `ungrouped_hunks` — no gaps, no duplicates. This is what makes the screen a
   complete view of the diff (AC-006).
3. **No diff text in the JSON.** No source lines, no line-number listings, no
   quoted code blocks. The screen already holds the raw diff; your output must
   scale with the number of groups and findings, not with the size of the diff
   (NFR-003).
4. **A Pass 1 finding is never deleted.** Pass 2 may relabel it
   (`plan_status: "justified"`) or drop its severity by one step, but every
   `id` from `pass1.json` must still be present in `findings[]`. This is
   verified; a missing id fails the build with exit 4.

## Top level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | int | ✓ | `1` |
| `meta` | object | ✓ | see below |
| `stats` | object | ✓ | `stats.json` copied verbatim |
| `groups[]` | array | ✓ | display order = descending risk |
| `ungrouped_hunks` | string[] | ✓ | hunks in no group (may be empty) |
| `findings[]` | array | ✓ | may be empty |
| `plan_check[]` | array | – | Pass 2 only; omit when there is no plan |

### `meta`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✓ | `{id}` without any perspective suffix |
| `title` | string | ✓ | screen header title, in Japanese |
| `target` | object | ✓ | `{kind, spec, diff_command, context_paths[]}`; `kind` is `code` \| `commit` \| `pr` |
| `reviewed_at` | string | ✓ | ISO 8601 |
| `checklists` | string[] | ✓ | checklist file names actually used |
| `passes` | int | ✓ | `1` or `2` |
| `assessment` | enum | ✓ | `PASS` \| `NEEDS_REVISION` |
| `diff_sha` | string | ✓ | first 12 hex chars of the patch's SHA-256 |

`assessment` is derived, not chosen: any Critical or High finding →
`NEEDS_REVISION`, otherwise `PASS`.

`meta.target.diff_command` is the exact command that produced the patch — it
appears in the report's Input Files line.

### `groups[]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✓ | `g1`, `g2`, … |
| `title` | string | ✓ | short Japanese phrase naming the intent |
| `summary` | string | ✓ | one-line summary for the list view |
| `intent` | string | ✓ | the `意図:` paragraph; include the caveats a reader should carry into the diff |
| `intent_unclear` | bool | ✓ | `true` when the intent could not be read off the change — then `intent` explains *why not*, and the screen shows a 要改善 label |
| `risk` | enum | ✓ | `Critical` \| `High` \| `Medium` \| `Low` |
| `tags` | string[] | ✓ | `refactor` / `feat` / `fix` / `test` / `docs` / `chore` … |
| `hunks` | string[] | ✓ | member hunk ids |

Order `groups[]` by descending risk. The screen renders the array as given and
never re-sorts it, so the order you write is the order the reviewer reads.

### `findings[]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✓ | `C001` / `H001` / `M001` / `L001` |
| `severity` | enum | ✓ | `Critical` \| `High` \| `Medium` \| `Low` |
| `title` | string | ✓ | one-line name of the problem |
| `group` | string | ✓ | an existing `groups[].id` |
| `anchor` | object | ✓ | `{hunk, side, line, file, display}` |
| `impact` | string | ✓ | what breaks — the report's Impact |
| `recommendation` | string | ✓ | a concrete fix |
| `source_pass` | int | ✓ | `1` \| `2` |
| `plan_status` | enum | ✓ | `none` \| `justified` |

`plan_status: "justified"` means the plan accounts for the change but the
implementation still deserves improvement. Both the screen and the report
print the note `plan 上は意図的な変更だが、実装として改善を求める` for it.

`anchor.side` is `new` or `old`; `anchor.line` is a line number on that side.
`anchor.display` is the human-readable position that lands in the generated
feedback verbatim — format it as `{file}（{新|旧}L{line}〜）`.

### `plan_check[]`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `item` | string | ✓ | the plan item, quoted closely enough to find |
| `status` | enum | ✓ | `implemented` \| `missing` \| `deviated` \| `extra` |
| `note` | string | – | why |
| `hunks` | string[] | – | supporting hunk ids |

`missing` and `deviated` rows must each have a corresponding finding — an
unmet plan item that produces no finding is invisible in the report.

## `pass1.json`

The plan-blind first pass writes a strict subset: `schema_version` plus
`findings[]` carrying only `id`, `severity`, `title`, `anchor`, `impact`, and
`recommendation`. `group`, `source_pass`, and `plan_status` are assigned by
Pass 2, which also does the grouping, the intent write-up, and the risk
ranking — those need a view of the whole diff.

## Minimal valid example

```json
{
  "schema_version": 1,
  "meta": {
    "id": "20260725-user-auth",
    "title": "認証リファクタの未ステージ差分レビュー",
    "target": {
      "kind": "code",
      "spec": "docs/specs/20260725-user-auth.md",
      "diff_command": "git -c core.quotepath=false diff",
      "context_paths": []
    },
    "reviewed_at": "2026-07-25T14:20:00+09:00",
    "checklists": ["be.md", "maint.md"],
    "passes": 1,
    "assessment": "PASS",
    "diff_sha": "35e60d914d98"
  },
  "stats": { "files": 1, "hunks": 2, "insertions": 9, "deletions": 3 },
  "groups": [
    {
      "id": "g1",
      "title": "URL・ホスト判定の共通基盤",
      "summary": "散らばっていたホスト判定を 1 か所に寄せた",
      "intent": "同じホスト判定が 3 か所にあり、片方だけ直る事故が起きていたため共通化している。",
      "intent_unclear": false,
      "risk": "Low",
      "tags": ["refactor"],
      "hunks": ["h001", "h002"]
    }
  ],
  "ungrouped_hunks": [],
  "findings": []
}
```
