# Implementation Plan: Session Knowledge Capture & Asset Self-Improvement (MVP)

## 1. Overview

Claude Code セッション中に得た知見 (mistake / pattern / preference / domain-knowledge / open-question) を machine-local の journal に蓄積し、人手レビュー (`/my:retro`) を経て既存 SDD パイプライン (`/my:change` → `/my:do`) で本リポジトリのアセット (`commands/`, `agents/`, `prompts/`, `rules/`) に反映する仕組みの MVP を実装する。

本 MVP は次の 9 成果物で構成する:
- 2 つの slash command (`commands/my/learn.md`, `commands/my/retro.md`)
- 2 つの backing prompt (`prompts/11_learn.md`, `prompts/12_retro.md`)
- 共有の role / process 抜き出し (`prompts/_shared/roles/{learn,retro}.md`, `prompts/_shared/processes/{learn,retro}.md`)
- redaction shell script + deny-list (`scripts/redact.sh`, `scripts/redact.denylist`)
- journal example (`docs/examples/journal-entry-example.md`)
- `.gitignore` テンプレ (`.gitignore.journal-template`)
- README 追記 (commands 一覧 / セットアップ手順)
- bats ベースのユニット & インテグレーションテスト (`tests/redact/`, `tests/journal/`)

Hook 自動化, LLM 要約 spawn, 独立 subagent 化, recurrence 自動昇格は **本 MVP のスコープ外** (Phase 2 以降)。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260627-session-knowledge-capture.md`

### 1.2 References
- Specification: `docs/specs/20260627-session-knowledge-capture.md`
- Research: `docs/research/20260627-session-knowledge-capture.md`
- Spec review: `docs/reviews/specs/20260627-session-knowledge-capture.md` (NEEDS_REVISION 指摘は本 plan で吸収)
- Existing pipeline command: `commands/my/pipeline.md`
- Existing change flow: `commands/my/change.md`, `agents/changer.md`, `prompts/6_change.md`
- Existing prompt 構造の参考: `prompts/1_research.md`, `prompts/_shared/roles/research.md`, `prompts/_shared/processes/research.md`
- 共有制約: `prompts/_shared/{file-naming-rules,output-constraints,quality-standards,placeholders}.md`

### 1.3 Implementation Strategy

4 フェーズの逐次実装:

1. **Foundation** — ディレクトリ作成 (`scripts/`, `docs/examples/`, `tests/`)、journal example, `.gitignore.journal-template`, redaction 用 deny-list 雛形。
2. **Core Logic** — `scripts/redact.sh` 実装、`prompts/11_learn.md` / `prompts/12_retro.md` + 共有 role/process 作成、frontmatter parse/write のための bash + jq スニペットを prompt 内に明文化。
3. **Integration** — `commands/my/learn.md` / `commands/my/retro.md` 追加。README に commands 一覧 / setup / journal 運用ガイドを追記。`/my:change` ハンドオフ文字列を retro 出力に組み込む。
4. **Testing** — `bats` (互換 shell driver でも可) で redact.sh の単体テスト, journal write/append の冪等性テスト, `/my:retro` の glob / sort / redaction 統合テスト、最後に E2E manual smoke checklist。

**設計原則:**
- Spec §3.4 path policy (`~/.claude/projects/<repo>/memory/journal/` のみ書き込み、`MEMORY.md` は read-only) を全コマンドで厳守。
- リポジトリ内 `docs/journal/` を絶対に作らない (US-003 invariant)。example は `docs/examples/journal-entry-example.md` のみ。
- 追加依存は `bash` + `jq` のみ (NFR-006)。Python/Node は使わない。
- `/my:retro` は read-only。journal の status 書き換えは MVP では手動運用 (US-004 AC-003)。
- **`/my:retro` の `<toolkit_repo>` 解決は Spec §3.5 (symlink → env var → 失敗) に従う。cwd 推測は禁止 (US-004 AC-004 / §7.4 threat)。出力には必ず `cd <toolkit_repo> && /my:change "..."` 形式の安全コマンドを出す**。
- Spec review 指摘 (E001/E002/W001..W007) は spec 側で既に解消済み (spec §10 / §3.4 / §4.1 / §6 行 11 を確認)。本 plan は解消後の spec を正とする。

**言語ポリシー (bilingual content guideline):**
- 本 plan / spec / research の散文は日本語で書く。
- ソースツリー成果物 (`commands/my/*.md`, `prompts/**/*.md`, `scripts/*.sh`, `README.md`, テスト名) は既存リポジトリ慣習に倣い英語で書く。
- 例: README の使用例コード行内に日本語 (例: `"TS catch は unknown 必須"`) が現れるのは許容するが、識別子・関数名・テスト名・出力フォーマットの固定文字列は英語で統一する。これは grep / search を一貫して動作させるため。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `commands/my/learn.md` | `/my:learn` slash command 定義 (Spec §3.1) | High |
| `commands/my/retro.md` | `/my:retro` slash command 定義 (Spec §3.2) | High |
| `prompts/11_learn.md` | `/my:learn` の backing prompt (role/process/output 仕様 XML) | High |
| `prompts/12_retro.md` | `/my:retro` の backing prompt | High |
| `prompts/_shared/roles/learn.md` | Learn 役割定義 (Session Knowledge Capturer) | Medium |
| `prompts/_shared/roles/retro.md` | Retro 役割定義 (Promotion Candidate Curator) | Medium |
| `prompts/_shared/processes/learn.md` | Learn 手順 (session_id 解決 → schema 書き出し) | Medium |
| `prompts/_shared/processes/retro.md` | Retro 手順 (glob → parse → dedupe → redact → sort → 出力) | Medium |
| `scripts/redact.sh` | 秘匿情報 mask スクリプト (Spec §3.3) | High |
| `scripts/redact.denylist` | redact.sh が参照するユーザ deny-list (初期は空 + コメント) | High |
| `docs/examples/journal-entry-example.md` | journal 1 件分のテンプレ例 (US-003 AC-001) | Medium |
| `.gitignore.journal-template` | リポジトリ内に journal を置く運用の保険 (US-003 AC-003) | Low |
| `tests/redact/test_redact.bats` | redact.sh の unit test (Spec §9.1) | High |
| `tests/redact/fixtures/clean.txt` | clean input fixture | High |
| `tests/redact/fixtures/with-secrets.txt` | sk-/ghp_/AKIA/`/Users/` 含む fixture | High |
| `tests/journal/test_learn.bats` | `/my:learn` の冪等性 + path policy テスト | High |
| `tests/journal/test_retro.bats` | `/my:retro` の glob/sort/redaction/toolkit 解決 統合テスト | High |
| `tests/journal/fixtures/journal/2026-06-20-aaaaaaaa.md` | retro 用 fixture (mistake) | Medium |
| `tests/journal/fixtures/journal/2026-06-22-bbbbbbbb.md` | retro 用 fixture (pattern) | Medium |
| `tests/journal/fixtures/journal/2026-06-25-cccccccc.md` | retro 用 fixture (preference) | Medium |
| `tests/journal/fixtures/toolkit_repo/commands/.keep` | fixture toolkit (US-004 AC-004 テスト用ダミー toolkit、`commands/` だけあれば symlink target になる) | Medium |
| `tests/journal/fixtures/toolkit_repo/rules/typescript/ts-error-handling.md` | duplicate detection テスト用 fixture | Medium |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `README.md` | Commands テーブルに `/my:learn`, `/my:retro` 追加。`### Session Knowledge Capture Flow` セクション追加。`.gitignore.journal-template` 運用手順追記 | Low |

### 2.3 Files to Delete

| File Path | Reason |
|-----------|--------|
| (none) | 既存ファイル削除なし。`commands/my/change.md`, `agents/changer.md` は spec US-004 AC-002 により無修正。 |

**禁止事項 (US-003 invariant):**
- `docs/journal/` ディレクトリは **作成してはならない**。
- 実装中に検証のため作る場合は `~/.claude/projects/custom-slash-command/memory/journal/` を使い、テストは `tests/journal/fixtures/journal/` を使う。

---

## 3. Implementation Steps

### Phase 1: Foundation

#### Step 1.1: スクリプト / テスト / examples ディレクトリの初期化
**File:** `scripts/`, `tests/redact/fixtures/`, `tests/journal/fixtures/journal/`, `docs/examples/`
**Action:** Create

**Details:**
```
- mkdir -p scripts/
- mkdir -p docs/examples/
- mkdir -p tests/redact/fixtures/
- mkdir -p tests/journal/fixtures/journal/
- リポジトリ内 docs/journal/ は作らない (US-003 invariant の自己検査)
```

**Verification:**
- [ ] `ls scripts docs/examples tests/redact/fixtures tests/journal/fixtures/journal` がすべて成功する
- [ ] `test ! -d docs/journal` が真 (作っていない)

---

#### Step 1.2: journal entry の example を作成
**File:** `docs/examples/journal-entry-example.md`
**Action:** Create

**Details:**
- Spec §4.1 schema (frontmatter + 5 body sections + 任意 Suggested Actions) をそのまま満たすサンプル 1 件。
- frontmatter:
  ```yaml
  ---
  session_id: 7a063d83-1234-4abc-89de-f0123456789a
  date: 2026-06-27
  project: custom-slash-command
  categories: [mistake, pattern]
  confidence: medium
  recurrence: 1
  status: raw
  source_commits: []
  tags: [typescript, error-handling]
  ---
  ```
- 5 body sections (`## Request` / `## Investigated` / `## Learned` / `## Completed` / `## Next Steps / Open Threads`) を埋めた上で、6 つ目に `## Suggested Actions (promotion candidates)` を `target / change / rationale` 3 フィールド bullet で 1 件入れる。
- 内容は spec §3.2 サンプル ("TypeScript の error union 型を `unknown` で受けない") を流用。
- ファイルの末尾コメントに「実体は `~/.claude/projects/<repo>/memory/journal/` 配下にのみ書く。リポジトリ内には置かない」と明記。

**Verification:**
- [ ] `yq '.session_id' docs/examples/journal-entry-example.md` で UUID 形式の値が取れる (jq でも可、yq が無ければ手目視)
- [ ] `## Request` / `## Investigated` / `## Learned` / `## Completed` / `## Next Steps` の 5 セクション見出しが順に存在
- [ ] `## Suggested Actions` セクションに `target:` / `change:` / `rationale:` の 3 フィールドが含まれる

---

#### Step 1.3: `.gitignore.journal-template` を作成
**File:** `.gitignore.journal-template`
**Action:** Create

**Details:**
```
# Session knowledge capture journal — never commit to a shared repo.
# Append this template to your project's .gitignore if you keep journals locally.

# Local journal store (default: machine-local under ~/.claude/projects/<repo>/memory/journal/)
docs/journal/
**/journal/*.md
*.journal.md

# Backups created on frontmatter parse failure
**/journal/*.bak
```

**Verification:**
- [ ] `cat .gitignore.journal-template` で 3 つのパターンブロックがそろう
- [ ] README に追記する `cat .gitignore.journal-template >> .gitignore` の手順が動くことを手元で 1 度確認

---

#### Step 1.4: `scripts/redact.denylist` を作成 (雛形のみ)
**File:** `scripts/redact.denylist`
**Action:** Create

**Details:**
- 初期内容は空ファイルではなく、書式コメントのみ:
  ```
  # One pattern per line. Lines starting with '#' are comments.
  # Matched against any 8+ char alphanumeric token in input.
  # Example:
  #   internal-project-codename-2026
  ```
- 初期 entry は **空** (Spec §10「`scripts/redact.denylist` の初期内容は repo 所有者と相談」を尊重)。

**Verification:**
- [ ] ファイル存在
- [ ] ヘッダコメントが 4 行あり、データ行は 0 行

---

### Phase 2: Core Logic

#### Step 2.1: `scripts/redact.sh` を実装
**File:** `scripts/redact.sh`
**Action:** Create

**Details:**
- shebang: `#!/usr/bin/env bash`
- `set -euo pipefail`
- 入力: 第 1 引数のファイルパス、または `-` / 引数なしで stdin。
- 出力: masked text を stdout に書く。
- 検出パターン (Spec §3.3):
  1. `sk-[A-Za-z0-9]{20,}` → `[REDACTED:sk-key]`
  2. `ghp_[A-Za-z0-9]{30,}` → `[REDACTED:ghp-token]`
  3. `AKIA[A-Z0-9]{16}` → `[REDACTED:aws-key]`
  4. `/Users/[^/[:space:]]+/` → `$HOME/` (一致した user 名以下のパスは `$HOME/...` に置換)
  5. `.env` 様式: `^([A-Z0-9_]+_(TOKEN|SECRET|KEY))=.*$` → `\1=[REDACTED]`
  6. deny-list ヒット: `scripts/redact.denylist` (同階層、シンボリックリンク追従) の非コメント行を 1 つずつ `grep -F` で評価し、ヒットすれば `[REDACTED:deny]` に置換。
- 内部実装は `sed -E` を multi-pass で実行 (Python/Node 使用禁止 — NFR-006)。
- exit code:
  - 0: 何もマッチしなかった (clean)
  - 2: 1 つでもマスクを行った (matches found and masked)
  - 1: 引数/ファイル読み込みエラー
- 標準エラー出力: detect count を 1 行 (`redact.sh: matched=<N> patterns=<sk:0,ghp:0,aws:0,home:1,env:0,deny:0>`) で出す (テスト assertion 用)。per-pattern の数値は「マスクされたトークン数」を意味し、「パターンがヒットしたか否か」のフラグではない。

**Skeleton (実装ガイド):**

注意:
- `apply` はトップレベル関数として定義し、`mask` から呼ぶ (Bash の関数定義は lexical scope を持たないため、ネスト定義は避ける)。
- 入力テキストの末尾改行を保持するため、`tmpfile` 経由で `sed -E -i.bak` / もしくは入力ファイル全体を `sed` に流す形式に統一する (`$(...)` は trailing newline を欠落させるため使わない)。
- per-pattern のマスク件数は `sed` 適用前に `grep -cE` で数える。

```bash
#!/usr/bin/env bash
set -euo pipefail

DENYLIST="${REDACT_DENYLIST:-$(dirname "$0")/redact.denylist}"

# Per-pattern match counts (token-level, not "did the pattern fire" flags)
declare -i N_SK=0 N_GHP=0 N_AWS=0 N_HOME=0 N_ENV=0 N_DENY=0

read_input_to_file() {
  # Write input to a temp file so that trailing newlines survive.
  local tmp
  tmp="$(mktemp -t redact.XXXXXX)"
  if [[ $# -ge 1 && "$1" != "-" ]]; then
    [[ -f "$1" ]] || { echo "redact.sh: cannot read $1" >&2; rm -f "$tmp"; return 1; }
    cat -- "$1" > "$tmp"
  else
    cat > "$tmp"
  fi
  printf '%s' "$tmp"
}

# apply <varname-of-counter> <sed-expression> <file>
# - Counts tokens matched (grep -cE on the source pattern part of the sed expr is
#   handled by the caller; here we just rewrite in-place via a temp file).
apply() {
  local _outvar="$1" _expr="$2" _file="$3"
  local _tmp
  _tmp="$(mktemp -t redact.XXXXXX)"
  sed -E "$_expr" "$_file" > "$_tmp"
  mv -- "$_tmp" "$_file"
}

# count_matches <ERE-pattern> <file> → echo integer
count_matches() {
  # -o + wc -l counts tokens (multiple per line); fall back to 0 on no match.
  grep -oE "$1" "$2" 2>/dev/null | wc -l | tr -d ' '
}

mask_file() {
  local f="$1"
  N_SK=$(count_matches 'sk-[A-Za-z0-9]{20,}' "$f")
  apply N_SK 's/sk-[A-Za-z0-9]{20,}/[REDACTED:sk-key]/g' "$f"

  N_GHP=$(count_matches 'ghp_[A-Za-z0-9]{30,}' "$f")
  apply N_GHP 's/ghp_[A-Za-z0-9]{30,}/[REDACTED:ghp-token]/g' "$f"

  N_AWS=$(count_matches 'AKIA[A-Z0-9]{16}' "$f")
  apply N_AWS 's/AKIA[A-Z0-9]{16}/[REDACTED:aws-key]/g' "$f"

  N_HOME=$(count_matches '/Users/[^/[:space:]]+/' "$f")
  apply N_HOME 's|/Users/[^/[:space:]]+/|$HOME/|g' "$f"

  N_ENV=$(count_matches '^[A-Z0-9_]+_(TOKEN|SECRET|KEY)=.*$' "$f")
  apply N_ENV 's/^([A-Z0-9_]+_(TOKEN|SECRET|KEY))=.*$/\1=[REDACTED]/g' "$f"

  if [[ -f "$DENYLIST" ]]; then
    while IFS= read -r pat; do
      [[ -z "$pat" || "$pat" =~ ^# ]] && continue
      local hits
      hits="$(grep -cF -- "$pat" "$f" || true)"
      if (( hits > 0 )); then
        N_DENY=$(( N_DENY + hits ))
        # Use sed for in-place replacement; escape `/` in pat to be safe.
        local esc
        esc="$(printf '%s' "$pat" | sed -e 's/[\/&]/\\&/g')"
        apply N_DENY "s/${esc}/[REDACTED:deny]/g" "$f"
      fi
    done < "$DENYLIST"
  fi
}

main() {
  local tmpfile
  tmpfile="$(read_input_to_file "$@")" || exit 1
  mask_file "$tmpfile"
  cat -- "$tmpfile"           # preserves trailing newline
  local total=$(( N_SK + N_GHP + N_AWS + N_HOME + N_ENV + N_DENY ))
  echo "redact.sh: matched=$total patterns=<sk:$N_SK,ghp:$N_GHP,aws:$N_AWS,home:$N_HOME,env:$N_ENV,deny:$N_DENY>" >&2
  rm -f -- "$tmpfile"
  (( total > 0 )) && exit 2
  exit 0
}

main "$@"
```

**Executable bit (git で追跡):**
- 作成後に `chmod +x scripts/redact.sh` を実行する。
- そのうえで `git add --chmod=+x scripts/redact.sh` を実行し、executable bit を git index にステージする (これを忘れると clone / CI checkout 時に bit が落ち、`/my:retro` が permission denied で失敗する)。
- `git ls-files --stage scripts/redact.sh` の mode が `100755` であることを確認する。

**Verification:**
- [ ] `chmod +x scripts/redact.sh && scripts/redact.sh tests/redact/fixtures/clean.txt; echo exit=$?` → `exit=0` 出力テキストが入力と同一
- [ ] `scripts/redact.sh tests/redact/fixtures/with-secrets.txt; echo exit=$?` → `exit=2` 出力に `[REDACTED:` が含まれる
- [ ] `echo "sk-abcdefghijklmnopqrstuvwxyz" | scripts/redact.sh -; echo exit=$?` → masked 出力 + `exit=2`
- [ ] stderr の `matched=N` が 0 / 非 0 で適切に切り替わる
- [ ] `git ls-files --stage scripts/redact.sh` が `100755 ...` を返す (executable bit が git に記録されている)

---

#### Step 2.2: 共有 role / process 文書を作成
**File:** `prompts/_shared/roles/learn.md`, `prompts/_shared/roles/retro.md`, `prompts/_shared/processes/learn.md`, `prompts/_shared/processes/retro.md`
**Action:** Create

**Details:**

`prompts/_shared/roles/learn.md`:
```
# Role: Session Knowledge Capturer

Captures session-level learnings into a machine-local journal entry conforming to the canonical schema.

## Core Competencies
- Resolving session_id from $CLAUDE_SESSION_ID / timestamp fallback (transcript_path is deferred to a post-MVP phase; see processes/learn.md Step 1)
- Authoring frontmatter + 5 mandatory body sections in YAML+Markdown
- Idempotent append for repeat invocations within the same session
- Strict machine-local path policy enforcement (US-003)

## Responsibilities
- Append knowledge to ~/.claude/projects/<repo>/memory/journal/YYYY-MM-DD-{session_id}.md
- Never write under the repository tree
- Coexist with Auto Memory (MEMORY.md is read-only)
```

`prompts/_shared/roles/retro.md`:
```
# Role: Promotion Candidate Curator

Scans accumulated journals and proposes promotion candidates without mutating anything.

## Core Competencies
- Glob + frontmatter parsing of ~/.claude/projects/<repo>/memory/journal/
- Toolkit repository resolution via ~/.claude/commands symlink or $CLAUDE_TOOLKIT_REPO
  (NEVER guess from cwd — spec §3.5 / US-004 AC-004)
- Duplicate detection against <toolkit_repo>/{rules,prompts,commands,agents}
- Redaction enforcement (scripts/redact.sh exit-code aware)
- Category-grouped, mistake-first rendering with `cd <toolkit_repo> && /my:change "..."` handoff strings

## Responsibilities
- Read-only operation on the journal store
- Emit safe copy-paste commands that include a `cd` to the toolkit repo before /my:change,
  so that promotion artifacts (docs/analysis/changes/, docs/plans/changes/) land in the
  toolkit repo — never in the user's current project
- Surface guidance for the manual status: raw → promoted edit
- On toolkit resolution failure: emit `<TOOLKIT_REPO>` placeholder and a replacement guide;
  never substitute cwd
```

`prompts/_shared/processes/learn.md`:
```
# Process: Learn (Session Knowledge Capture)

## Step 1: Resolve session_id (MVP)
- Prefer $CLAUDE_SESSION_ID if set
- Otherwise fallback to `mv-$(date +%Y%m%d-%H%M%S)` and emit a warning
- (Future) transcript_path-derived session_id is deferred until Claude Code exposes
  the value to the shell via a documented hook payload or env var. Do not rely on
  an undocumented `transcript_path` variable in MVP.

## Step 2: Build target path
- repo := basename "$PWD"
- target := $HOME/.claude/projects/<repo>/memory/journal/$(date +%Y-%m-%d)-<session_id>.md
- Assert target is NOT under "$PWD/" (else abort, exit 1)
- mkdir -p "$(dirname "$target")"

## Step 3: Upsert frontmatter
- If file absent: write full frontmatter (recurrence: 1, status: raw)
- If file present: parse frontmatter, bump `recurrence` += 1, append "Learned" bullet, leave other fields intact
- On parse failure: rename existing file to <name>.bak and start fresh with a warning

## Step 4: Render body sections
- Order is fixed and all 5 are required: Request / Investigated / Learned / Completed / Next Steps
- 6th "Suggested Actions" is optional
- Categories: infer from conversation OR honor --category flag (must be in the enum)

## Step 5: Report
- Print: "Journal entry appended.", path, categories, status
- Print next-step hint: "run /my:retro to see promotion candidates"
```

`prompts/_shared/processes/retro.md`:
```
# Process: Retro (Promotion Candidate Curation)

## Step 1: Enumerate
- glob "$HOME/.claude/projects/$(basename "$PWD")/memory/journal/*.md"
- If empty: emit "No journal entries found at <path>. Run /my:learn first." and exit 0

## Step 2: Filter
- Parse frontmatter via awk/sed/jq pipeline (NFR-006 compliant)
- Apply --since (default 14d), --category, --min-recurrence (default 1) filters
- Skip entries with status: promoted or status: archived

## Step 3: Resolve toolkit repo (spec §3.5)
- Priority 1: if `~/.claude/commands` is a symlink AND its target ends with `/commands`
              AND that target dir exists, set toolkit_repo := dirname(readlink(~/.claude/commands))
- Priority 2: if $CLAUDE_TOOLKIT_REPO is set AND is a directory, set toolkit_repo := $CLAUDE_TOOLKIT_REPO
- Else: toolkit_repo := "" (empty string)
- FORBIDDEN: do NOT fall back to $PWD or any cwd-derived path. cwd is an arbitrary project,
  not the toolkit repo (US-004 AC-004 / §7.4 threat model).

## Step 4: Build candidates
- For each entry, collect Suggested Actions; if empty, synthesize candidates from Learned bullets
- Each candidate: title / target_asset_path / change_summary / rationale / source_entries / recurrence

## Step 5: Duplicate detection
- If toolkit_repo is non-empty:
    grep nearby files under <toolkit_repo>/{rules,prompts,commands,agents}
    Annotate `duplicate_of` when a near-match is found; do not exclude.
- If toolkit_repo is empty:
    SKIP this step. Annotate each candidate with
    "(duplicate check skipped: toolkit repo not resolved)".

## Step 6: Redact
- Pipe each candidate's renderable text through scripts/redact.sh
- exit 0 → redaction_status: clean
- exit 2 → redaction_status: excluded (drop from output, log on stderr)
- script missing → warning on stderr, continue without redaction
- masked is reserved for Phase 2; do not emit in MVP

## Step 7: Group & sort
- Group by category, sort mistake first (then pattern, preference, domain-knowledge, open-question)
- Within a group, sort by recurrence desc, then by date desc

## Step 8: Render
- Output header: "Toolkit repo: <toolkit_repo>" (or "<TOOLKIT_REPO>  (⚠️ 自動解決に失敗)" on failure)
- markdown table per category H3 section
- After each candidate, print the safe copy-paste command (multi-line for readability):
      cd <toolkit_repo> \
        && /my:change "<title>"
  When toolkit_repo is empty, substitute the literal placeholder `<TOOLKIT_REPO>`
  (DO NOT substitute cwd).
- Footer Tip 1: warn that the command MUST be run with the leading `cd`, otherwise
  promotion artifacts will land in the wrong project (US-004 AC-001 / §7.4).
- Footer Tip 2: guidance to manually flip frontmatter status raw → promoted after a successful promotion.
- On resolution failure: additional footer with replacement guide
  ("symlink ~/.claude/commands or hand-edit <TOOLKIT_REPO>"; see spec §3.2 Output failure example).
```

**Verification:**
- [ ] 4 ファイルが `prompts/_shared/roles/` / `prompts/_shared/processes/` 配下に存在
- [ ] 各ファイルが既存の `prompts/_shared/roles/research.md` と同様の H1 + Core Competencies + Responsibilities 構造を持つ

---

#### Step 2.3: `prompts/11_learn.md` を作成
**File:** `prompts/11_learn.md`
**Action:** Create

**Details:**
- `prompts/1_research.md` と同じ XML 構造 (`<role>` / `<process>` / `<rules>` / `<output>`) を踏襲。
- `<role>`: `prompts/_shared/roles/learn.md` を参照。
- `<process>`: `prompts/_shared/processes/learn.md` を参照しつつ、追加で以下 bash スニペットを inline で示す:
  ```bash
  # session_id 解決 (MVP)
  # - 第一候補: $CLAUDE_SESSION_ID (Claude Code が環境変数で提供する場合)
  # - 第二候補: timestamp fallback (`mv-YYYYMMDD-HHMMSS`)
  #
  # NOTE: Spec §3.1 が示す transcript_path 経由の解決は、MVP 時点では
  # Claude Code から shell 環境への提供方式が確立していないため採用しない。
  # 将来 hook 経由で transcript_path が露出した時点で第 2 段に挿入する。
  resolve_sid() {
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then echo "$CLAUDE_SESSION_ID"; return; fi
    echo "mv-$(date +%Y%m%d-%H%M%S)"
  }
  # repo / path
  repo="$(basename "$PWD")"
  sid="$(resolve_sid)"
  target="$HOME/.claude/projects/$repo/memory/journal/$(date +%Y-%m-%d)-$sid.md"
  case "$target" in
    "$PWD"/*) echo "journal path must be machine-local: $target" >&2; exit 1 ;;
  esac
  mkdir -p "$(dirname "$target")"
  ```
- `<rules>`:
  - `<critical>` で「リポジトリ配下に書かない」「`MEMORY.md` には触れない」を明示。
  - `@import _shared/file-naming-rules.md` は不要 (journal は date+sid 命名で独自)。
  - `@import _shared/output-constraints.md` は適用 (出力は file + stdout 確認のみ)。
- `<output>`:
  - stdout confirmation 例 (Spec §3.1):
    ```
    ✅ Journal entry appended.
    Path: ~/.claude/projects/custom-slash-command/memory/journal/2026-06-27-7a063d83.md
    Categories: [mistake]
    Status: raw
    Next: run `/my:retro` to see promotion candidates.
    ```
- `<arguments>` セクション (Spec §3.1 表):
  - `--category <enum>` (省略時会話文脈推定)
  - `--confidence high|medium|low` (省略時 `medium`)
  - free-text memo (`Learned` seed)
- `<edge-cases>` (Spec §6 のうち learn 関連: #1, #2, #3, #4, #10, #11, #13, #15) を箇条書き。

**Verification:**
- [ ] `grep -E '<(role|process|rules|output|arguments)>' prompts/11_learn.md` で 5 種すべて HIT
- [ ] `<critical>` 内に "machine-local" と "MEMORY.md" 両方の文言が含まれる
- [ ] enum (`mistake|pattern|preference|domain-knowledge|open-question`) の 5 種が列挙されている

---

#### Step 2.4: `prompts/12_retro.md` を作成
**File:** `prompts/12_retro.md`
**Action:** Create

**Details:**
- 構造は 11_learn.md と同等 (XML 5 セクション)。
- `<process>` 内の主要 bash + jq スニペット:
  ```bash
  # journal directory
  repo="$(basename "$PWD")"
  jdir="$HOME/.claude/projects/$repo/memory/journal"
  [[ -d "$jdir" ]] || { echo "No journal entries found at $jdir. Run /my:learn first."; exit 0; }

  # since filter
  parse_since() {
    case "$1" in
      *d) date -v -"${1%d}"d +%Y-%m-%d 2>/dev/null || date -d "${1%d} days ago" +%Y-%m-%d ;;
      ????-??-??) echo "$1" ;;
      *) echo "ERR" ;;
    esac
  }
  since="${SINCE:-14d}"
  since_date="$(parse_since "$since")"
  [[ "$since_date" == "ERR" ]] && { echo "usage: --since <Nd|YYYY-MM-DD>" >&2; exit 1; }

  # extract frontmatter as YAML using awk and convert to JSON via yq if available,
  # otherwise grep/sed (NFR-006: only bash + jq guaranteed; yq optional)
  extract_fm() {
    awk 'BEGIN{p=0} /^---$/{p++; next} p==1{print}' "$1"
  }
  ```
- frontmatter parse は NFR-006 で `jq` 前提なので、最終的に YAML → JSON 変換は inline awk で「`key: value` 形式の simple YAML」だけ扱う想定にする (テスト fixture はこの制約を満たす形で書く)。複雑なネスト構造は schema 上発生しない。
- **Toolkit repo 解決 snippet (Spec §3.5)**:
  ```bash
  # Resolve <toolkit_repo>; NEVER fall back to $PWD (spec §3.5 forbidden).
  resolve_toolkit_repo() {
    # Priority 1: ~/.claude/commands symlink
    local link target parent
    link="$HOME/.claude/commands"
    if [ -L "$link" ]; then
      target="$(readlink "$link")"
      # Resolve relative symlinks
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
    # Resolution failure — caller emits placeholder + guidance (US-004 AC-004)
    printf ''
    return 1
  }
  toolkit_repo="$(resolve_toolkit_repo)" || true   # empty on failure; do NOT use $PWD
  ```
- `<rules>`:
  - `<critical>` で「mutation 禁止 (US-004 AC-002, US-002 AC-004)」「`scripts/redact.sh` の exit 2 は出力から除外」を明示。
  - **`<critical>` に追加: 「toolkit_repo を cwd で推測しない (Spec §3.5 / US-004 AC-004)。解決失敗時は `<TOOLKIT_REPO>` placeholder を使い、ユーザに置換させる」**。
  - **`<critical>` に追加: 「`/my:change` ハンドオフ文字列は必ず `cd <toolkit_repo> && /my:change "..."` 形式。bare `/my:change "..."` だけを出してはならない (cwd 漏洩防止)」**。
  - `redact.sh` 見つからない時の挙動 (warning + 続行) を明記。
- `<output>`:
  - 出力 example は Spec §3.2 abridged の **両方** (resolved / failed) を流用。
  - 末尾 Tip 1: `cd` 込み実行の重要性 (cwd 事故防止) を明文化。
  - 末尾 Tip 2: `status: raw → promoted` 手動編集の案内。
  - 解決失敗時のみ、追加 footer で `~/.claude/commands` symlink 手順 + `<TOOLKIT_REPO>` 手動置換ガイドを出す。
- `<arguments>`:
  - `--since` (default 14d)
  - `--category <enum>` (default all)
  - `--min-recurrence <int>` (default 1)
- `<edge-cases>`: Spec §6 のうち retro 関連: #5, #6, #7, #8, #9, #10, #12, #13。**追加で「toolkit symlink 不在」と「`$CLAUDE_TOOLKIT_REPO` 設定済みだが存在しないディレクトリを指している」の 2 ケース**。

**Verification:**
- [ ] `grep '_shared/processes/retro.md' prompts/12_retro.md` または同等の参照あり
- [ ] `<critical>` セクションに "mutation" / "read-only" を含む文言
- [ ] `<critical>` セクションに "cd <toolkit_repo>" / "do not guess from cwd" 旨の文言
- [ ] redact.sh exit 2 ハンドリングが明文化されている (`redaction_status: excluded`)
- [ ] `resolve_toolkit_repo` ヘルパが `<process>` 内に存在し、`$PWD` への fallback がないこと
- [ ] 出力 example が「resolved」「failed」両ケースを示している

---

#### Step 2.5: `scripts/redact.sh` の deny-list 連携を smoke check
**File:** `scripts/redact.sh`, `scripts/redact.denylist`
**Action:** Modify (no code change; just verification step)

**Details:**
- 手元で `echo "internal-project-codename-2026" >> scripts/redact.denylist` し、`echo "leak: internal-project-codename-2026" | scripts/redact.sh -` で `[REDACTED:deny]` に置換されることを確認。
- 確認後 deny-list を空に戻す (リポジトリには空ファイルのままコミット)。

**Verification:**
- [ ] 上記 smoke で `[REDACTED:deny]` が出る
- [ ] 戻した後 `scripts/redact.denylist` にコメント以外の行がないこと

---

### Phase 3: Integration

#### Step 3.1: `commands/my/learn.md` を作成
**File:** `commands/my/learn.md`
**Action:** Create

**Details:**
- 既存 `commands/my/research.md` / `commands/my/change.md` と同様の構造:
  - 先頭 frontmatter: `description: "Capture session knowledge into a machine-local journal"`
  - 本文: `Read and follow the prompt logic at: ~/.prompts/11_learn.md`
  - Input: `$ARGUMENTS`
  - Process 簡略説明 (5 steps)
  - File Naming セクション (journal は date+sid 命名なので一般 normalizer は使わない旨を明記)
  - Critical Constraints (US-003 / NFR-006 を箇条書き)
  - After Completion: 次に `/my:retro` を提案
- Examples (3 件):
  - `/my:learn`
  - `/my:learn --category mistake "TS catch は unknown 必須"`
  - `/my:learn --confidence high "Pattern: prefer Result type over throws"`

**Verification:**
- [ ] `commands/my/learn.md` 先頭に YAML frontmatter (description) がある
- [ ] `~/.prompts/11_learn.md` 参照がある
- [ ] enum 5 種が Examples or Arguments の説明内で言及される

---

#### Step 3.2: `commands/my/retro.md` を作成
**File:** `commands/my/retro.md`
**Action:** Create

**Details:**
- 同様に `description: "Surface promotion candidates from accumulated journals"`
- `Read and follow the prompt logic at: ~/.prompts/12_retro.md`
- Input: `$ARGUMENTS`
- Process 概要:
  1. Enumerate `~/.claude/projects/<repo>/memory/journal/`
  2. Filter by `--since` / `--category` / `--min-recurrence`
  3. Build candidates, detect duplicates against `rules/ prompts/ commands/ agents/`
  4. Run `scripts/redact.sh`; drop excluded
  5. Group by category, mistake first
  6. Render with `/my:change "<title>"` handoff strings
- Critical Constraints: read-only, redact 必須, journal 0 件時は親切なメッセージ
- Examples:
  - `/my:retro`
  - `/my:retro --since 30d`
  - `/my:retro --category mistake --min-recurrence 2`
- After Completion: 次に `/my:change "<title>"` を実行する旨と `status: raw → promoted` の手動編集案内を明記

**Verification:**
- [ ] `commands/my/retro.md` 先頭に YAML frontmatter
- [ ] examples が 3 件以上
- [ ] `/my:change` ハンドオフ言及

---

#### Step 3.3: README.md にコマンド一覧と運用ガイドを追記
**File:** `README.md`
**Action:** Modify

**Details:**
- §"Available Commands" テーブルに 2 行追加:
  ```
  | `/my:learn` | Capture session knowledge to machine-local journal | `~/.claude/projects/<repo>/memory/journal/` |
  | `/my:retro` | Surface promotion candidates from journals | stdout (read-only) |
  ```
- §"Usage" の末尾に新セクション `### Session Knowledge Capture Flow`:
  ```bash
  # 1. 会話中に気付きを記録 (任意のプロジェクトで OK)
  /my:learn --category mistake "TS catch は unknown 必須"

  # 2. 蓄積から昇格候補を一覧 (任意のプロジェクトで OK; toolkit repo を自動解決)
  /my:retro --since 14d

  # 3. 提示された cd 込みコマンドをそのままコピペして実行
  #    ⚠️ 必ず `cd` を含めること — 抜くと cwd のプロジェクトに変更が散逸する
  cd ~/src/github.com/naoking158/custom-slash-command \
    && /my:change "ts-error-handling: enforce unknown in catch"

  # 4. /my:do で実装に反映 (cd 済みなので toolkit repo 内で実行される)
  /my:do 20260627-ts-error-handling

  # 5. 元プロジェクトに戻って journal frontmatter の status を手動で promoted に書き換え
  ```
- §"Directory Structure" のローカルストア説明に `~/.claude/projects/<repo>/memory/journal/` を追加。
- 新規セクション `### Journal Privacy` を作り、`.gitignore.journal-template` の使い方を 3 行で:
  ```
  # journal は machine-local。万一リポジトリ内で運用する場合は:
  cat .gitignore.journal-template >> .gitignore
  ```
- §"Available Commands" テーブル直前または README 末尾の Directory Structure ブロック内で `scripts/` ディレクトリ言及を追加。

**Verification:**
- [ ] `grep "/my:learn" README.md` で 3 箇所以上ヒット
- [ ] `grep "/my:retro" README.md` で 3 箇所以上ヒット
- [ ] `Session Knowledge Capture Flow` セクション見出しが存在
- [ ] `.gitignore.journal-template` の言及が存在

---

#### Step 3.4: `/my:change` ハンドオフ文字列の整合性を確認
**File:** `prompts/12_retro.md`, `commands/my/change.md` (read-only)
**Action:** Verify (no code change required)

**Details:**
- `/my:retro` が出力する **`cd <toolkit_repo> && /my:change "<title>"`** の `<title>` フォーマットが、既存 `commands/my/change.md` の `$ARGUMENTS` 解析に渡せる文字列であることを確認 (US-004 AC-001)。
- 既存 `commands/my/change.md` は変更しない (Spec US-004 AC-002)。
- title は ASCII 推奨、ダブルクオート escape は不要のフォーマットに統一 (例: `ts-error-handling: enforce unknown in catch`)。
- `cd <toolkit_repo>` を必ず先頭に出すこと (Spec §3.5 / US-004 AC-001 / §7.4 threat)。bare `/my:change "..."` 単体行を出してはならない (cwd 漏洩防止)。
- toolkit 未解決時は `cd <TOOLKIT_REPO> && /my:change "..."` でプレースホルダのまま (US-004 AC-004)。

**Verification:**
- [ ] `prompts/12_retro.md` の rendering example で `/my:change "<title>"` 文字列が title 内のダブルクオートを含まないことが文書化されている
- [ ] `prompts/12_retro.md` の rendering example が **必ず `cd ` 前置詞付きで** 表示されている
- [ ] `prompts/12_retro.md` 中に bare `/my:change` 行 (cd なし) が存在しないこと (grep で確認)
- [ ] `commands/my/change.md` の git diff が無修正

---

### Phase 4: Testing

#### Step 4.1: Unit tests — `scripts/redact.sh`
**File:** `tests/redact/test_redact.bats`

**Test Cases (Spec §9.1):**
- [ ] clean input → exit 0、出力が入力と同一
- [ ] `sk-aaaaaaaaaaaaaaaaaaaaaaaaa` → `[REDACTED:sk-key]`、exit 2
- [ ] `ghp_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB` → `[REDACTED:ghp-token]`、exit 2
- [ ] `AKIAABCDEFGHIJKLMNOP` (4+16) → `[REDACTED:aws-key]`、exit 2
- [ ] `/Users/foo/bar/baz` → `$HOME/bar/baz`、exit 2
- [ ] `API_TOKEN=abcdef` → `API_TOKEN=[REDACTED]`、exit 2
- [ ] deny-list ヒット (テスト中だけ `REDACT_DENYLIST` 環境変数で fixture を渡す) → `[REDACTED:deny]`、exit 2
- [ ] 引数なしで stdin から読める
- [ ] 存在しないファイルパス → exit 1, stderr に error 表示

**Fixtures:**
- `tests/redact/fixtures/clean.txt`: 普通の散文 3 行 (検出パターン無し)
- `tests/redact/fixtures/with-secrets.txt`: 上記検出パターンを 1 行ずつ含む
- `tests/redact/fixtures/denylist.txt`: 1 行だけ `secret-codename-aaaa1111`

**Verification:**
- [ ] `bats tests/redact/test_redact.bats` 全件 PASS
- [ ] テストランナー無くとも `bash tests/redact/test_redact.bats` 風の shell driver で代替可能 (CI を当面追加しないため)

---

#### Step 4.2: Unit tests — frontmatter parse (jq pipeline)
**File:** `tests/journal/test_learn.bats` (parse 用ヘルパも同居)

**Test Cases:**
- [ ] 正常な frontmatter (Spec §4.1 全フィールド) → 全フィールドが取り出せる
- [ ] `categories` 配列の parse (`[mistake, pattern]`)
- [ ] `source_commits` 省略時に空配列扱い
- [ ] frontmatter 破損 (`---` が 1 つしか無い等) → backup (`*.bak`) 生成、新規ファイルで再構成、warning
- [ ] 5 body sections のうち 1 つ欠けている fixture → 欠落セクション空で続行、warning

**Fixtures:**
- `tests/journal/fixtures/journal/2026-06-20-aaaaaaaa.md` (mistake, valid)
- `tests/journal/fixtures/journal/2026-06-22-bbbbbbbb.md` (pattern, valid)
- `tests/journal/fixtures/journal/2026-06-25-cccccccc.md` (preference, valid)
- 破損 fixture は test 内で `mktemp` で生成 (リポジトリにはコミットしない)

**Verification:**
- [ ] `bats tests/journal/test_learn.bats` 全件 PASS
- [ ] テスト中、テスト対象が `$HOME/.claude/...` でなく `$BATS_TMPDIR` 配下に書くよう環境変数 (`HOME=$BATS_TMPDIR`) でリダイレクトされている

---

#### Step 4.3: Integration tests — `/my:learn`
**File:** `tests/journal/test_learn.bats` (同ファイル内に integration セクション)

**Test Cases (Spec §9.2):**
- [ ] 空状態で起動 → ファイル新規作成、`recurrence: 1`, `status: raw`
- [ ] 同 session で 2 度目の呼び出し → 同ファイルに追記、`recurrence: 2`
- [ ] repo 配下を resolve した状況 (HOME を `$PWD` に設定) → exit 1, stderr に "machine-local" 文言
- [ ] `--category mistake` → frontmatter `categories: [mistake]`
- [ ] 不正な category → warning + `domain-knowledge` fallback (Edge case #10)
- [ ] session_id 取得不能 → `mv-YYYYMMDD-HHMMSS` 命名にフォールバック (Edge case #2)

**Verification:**
- [ ] `bats tests/journal/test_learn.bats` 全件 PASS

---

#### Step 4.4: Integration tests — `/my:retro`
**File:** `tests/journal/test_retro.bats`

**Test Cases (Spec §9.2):**
- [ ] 0 件 (`HOME` を空 tmp に設定) → "No journal entries found ..." を出して exit 0
- [ ] fixtures 3 件 (mistake/pattern/preference) → 出力で `## mistake` セクションが先頭、各候補に **`cd <toolkit_repo> && /my:change "<title>"`** が併記される (US-004 AC-001)
- [ ] `--since 1d` → 全 fixtures より新しい日付なので 0 件、案内文
- [ ] `--category mistake` → mistake fixture のみ出力
- [ ] `--min-recurrence 2` → fixture の `recurrence: 1` は除外
- [ ] `--since invalid` → exit 1, usage 表示 (Edge case #6)
- [ ] `--min-recurrence -1` → exit 1, usage (Edge case #9)
- [ ] fixtures のうち 1 件に sk- を埋め込むと、その候補は `excluded` として出力から消える (Edge case #8)
- [ ] `scripts/redact.sh` を `$PATH` から外す → warning + redaction skip で続行 (Edge case #7)
- [ ] 既存 `rules/typescript/ts-error-handling.md` (toolkit repo 配下) がある状態で title=ts-error-handling 候補 → `(possible duplicate of rules/typescript/ts-error-handling.md)` 注記
- [ ] 出力中に `/Users/<name>/` が残っていないこと (redaction L2 動作確認)

**Toolkit resolution test cases (Spec §3.5 / US-004 AC-004):**
- [ ] **`~/.claude/commands` symlink を fixture toolkit に向けて作成** → 出力に `Toolkit repo: <そのパス>` が表示され、各候補に `cd <そのパス> && /my:change "..."` が出る
- [ ] `~/.claude/commands` が不在 / 通常ディレクトリ → 出力に `Toolkit repo: <TOOLKIT_REPO>  (⚠️ 自動解決に失敗)` と置換ガイドが出る。**プレースホルダが cwd に置換されていないこと** (grep で `<TOOLKIT_REPO>` がそのまま残っていることを確認)
- [ ] symlink 不在 + `$CLAUDE_TOOLKIT_REPO=<fixture toolkit>` → env var が採用される
- [ ] `$CLAUDE_TOOLKIT_REPO` が存在しないパスを指している → resolution failure 扱い (placeholder 出力)
- [ ] symlink 不在時の duplicate detection 注記 `(duplicate check skipped: toolkit repo not resolved)` が各候補に付くこと
- [ ] 出力末尾の Tip 1 に「**cd 込みで実行**」の文言が含まれること (cwd 漏洩警告 / §7.4 threat)

**Verification:**
- [ ] `bats tests/journal/test_retro.bats` 全件 PASS

---

#### Step 4.5: E2E manual smoke
**File:** N/A (手動チェックリスト, README に転記しない、本 plan 末尾でのみ管理)

**Test Cases (Spec §9.3):**
- [ ] 実セッションで `/my:learn "test entry"` → `~/.claude/projects/custom-slash-command/memory/journal/` にファイル作成
- [ ] 5 件溜めた後 `/my:retro --since 7d` → 候補リスト表示
- [ ] 候補 1 件を `/my:change` に渡す → `docs/analysis/changes/` と `docs/plans/changes/` に痕跡
- [ ] `/my:do` 完了後、journal `status: raw` を手動で `promoted` に書き換え → 再 `/my:retro` で候補から消える
- [ ] `/my:retro` 出力に絶対 home パスが残っていない

**Verification:**
- [ ] チェックリスト 5 項目すべて手動で通過したことを Plan 末尾 §5.3 に記録

---

#### Step 4.6: Acceptance criteria mapping
**File:** N/A (本 plan §5.3 で trace)

**Details:**
- Spec の US-001..US-005 の各 AC を §5.3 に列挙し、検証手段 (test name / 手動確認) を 1 行で紐付ける。
- US-004 AC-004 (toolkit resolution 失敗時の cwd 推測禁止) を必ず含めること。

**Verification:**
- [ ] §5.3 に全 21 個の AC (US-001: 5, US-002: 6, US-003: 3, US-004: **4**, US-005: 3) が列挙される (US-004 に AC-004 が追加されたため +1)

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `bash` | 4+ (macOS の bash3 でも極力動くよう書く) | スクリプト実装 |
| `jq` | 1.6+ | frontmatter の JSON 表現生成 (内部) |
| `bats-core` | 1.10+ | テストランナー (任意、無ければ shell driver fallback) |
| `coreutils` (`date`, `sed`, `awk`, `grep`) | system 既定 | パイプライン |

NFR-006: Python / Node 追加依存は無し。`yq` は推奨だが必須ではない (無ければ awk + jq で代替)。

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `commands/my/change.md` | Existing, **未修正** | US-004 AC-002 |
| `agents/changer.md` | Existing, **未修正** | 同上 |
| `prompts/6_change.md` | Existing, 未修正 | 同上 |
| `prompts/_shared/{output-constraints,quality-standards}.md` | Existing | 11_learn / 12_retro から `@import` 参照 |
| `rules/`, `prompts/`, `commands/`, `agents/` | Existing | `/my:retro` の duplicate 検出ターゲット |
| Auto Memory (`~/.claude/projects/<repo>/memory/MEMORY.md`) | External | 触れない (read-only) |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document `docs/specs/20260627-session-knowledge-capture.md` を最終版で確認 (review 指摘 E001/E002 が反映済みである旨)
- [ ] `bash --version` / `jq --version` が利用可能
- [ ] `bats --version` を確認 (無ければ shell driver で代替する旨を README または開発者メモに記録)
- [ ] `docs/journal/` が repo 内に存在しないこと (US-003 invariant)

### 5.2 Post-Implementation
- [ ] `scripts/redact.sh` が executable (`test -x scripts/redact.sh`)
- [ ] `git ls-files --stage scripts/redact.sh` が `100755` (executable bit が git index に記録されている)
- [ ] `bats tests/redact/ tests/journal/` 全 PASS
- [ ] `grep -r "docs/journal" .` が 0 ヒット (リポジトリ内に痕跡無し)
- [ ] `commands/my/change.md` の git diff が空
- [ ] `agents/changer.md` の git diff が空
- [ ] README に `/my:learn` / `/my:retro` の説明と Session Knowledge Capture Flow が追加されている
- [ ] markdown lint / 型エラー無し (このリポジトリには CI 無いので手目視)

### 5.3 Acceptance Criteria Verification (Spec §2)

**US-001 (`/my:learn` 手動キャプチャ)**
- [ ] AC-001: 引数なしで canonical schema 通り journal が作成される — `tests/journal/test_learn.bats: "creates new journal with full schema"`
- [ ] AC-002: 引数を渡すと `Learned` に反映 — `tests/journal/test_learn.bats: "memo arg lands in Learned"`
- [ ] AC-003: 同一 session_id では append + recurrence++ — `tests/journal/test_learn.bats: "idempotent append bumps recurrence"`
- [ ] AC-004: repo 配下解決時 abort — `tests/journal/test_learn.bats: "aborts when path resolves under repo"`
- [ ] AC-005: frontmatter + 5 body sections 必須 — `tests/journal/test_learn.bats: "all 5 body sections present"`

**US-002 (`/my:retro` 提案)**
- [ ] AC-001: journal ディレクトリを glob — `tests/journal/test_retro.bats: "globs the journal dir"`
- [ ] AC-002: `--since` 期間絞り込み — `tests/journal/test_retro.bats: "since filters correctly"`
- [ ] AC-003: markdown table 4 列 — `tests/journal/test_retro.bats: "renders 4-column candidate table"`
- [ ] AC-004: `/my:change "<title>"` ハンドオフ文字列を提示 — `tests/journal/test_retro.bats: "emits /my:change handoff"`
- [ ] AC-005: 既存アセットとの duplicate 注記 — `tests/journal/test_retro.bats: "duplicate-of annotation"`
- [ ] AC-006: redact.sh で除外 — `tests/journal/test_retro.bats: "redaction excludes candidate"`

**US-003 (machine-local invariant)**
- [ ] AC-001: `docs/journal/` を作らない — Step 1.1 verification + 5.2 grep
- [ ] AC-002: write/read パスが `~/.claude/projects/<repo>/memory/journal/` のみ — `prompts/11_learn.md` / `prompts/12_retro.md` の `<rules>` レビュー + integration test
- [ ] AC-003: `.gitignore.journal-template` が repo にある — Step 1.3

**US-004 (SDD パイプライン連携)**
- [ ] AC-001: **`cd <toolkit_repo> && /my:change "<title>"`** 文字列が併記 — `tests/journal/test_retro.bats: "emits cd-prefixed /my:change handoff"`
- [ ] AC-002: `/my:change` 無修正 — 5.2 `git diff` チェック
- [ ] AC-003: 手動で `status: promoted` 書き換える運用ガイドが retro 出力にある — `tests/journal/test_retro.bats: "footer guidance present"`
- [ ] AC-004: toolkit 解決失敗時 `<TOOLKIT_REPO>` プレースホルダ + 置換ガイド出力、cwd 推測しない — `tests/journal/test_retro.bats: "placeholder shown on toolkit resolution failure"` + `"never substitutes cwd as toolkit"`

**US-005 (category taxonomy)**
- [ ] AC-001: enum 5 種限定 — `tests/journal/test_learn.bats: "unknown category falls back to domain-knowledge"`
- [ ] AC-002: 会話文脈推定 + `--category` 明示 — Step 2.3 / 3.1 verification
- [ ] AC-003: retro 出力 category 別 H3 + mistake 先頭 — `tests/journal/test_retro.bats: "mistake group renders first"`

---

## 6. Rollback Plan

1. `git status` で未コミット変更を確認、必要なら stash。
2. `git rm` で本 plan が追加した以下のみを取り除く:
   ```
   commands/my/learn.md
   commands/my/retro.md
   prompts/11_learn.md
   prompts/12_retro.md
   prompts/_shared/roles/learn.md
   prompts/_shared/roles/retro.md
   prompts/_shared/processes/learn.md
   prompts/_shared/processes/retro.md
   scripts/redact.sh
   scripts/redact.denylist
   docs/examples/journal-entry-example.md
   .gitignore.journal-template
   tests/redact/
   tests/journal/
   ```
3. `README.md` の変更は `git checkout README.md` で取り消す。
4. ローカルの `~/.claude/projects/custom-slash-command/memory/journal/` は **削除しない** (個人データのため)。
5. `commands/my/change.md` / `agents/changer.md` は無修正のはずなので何もしない。

ロールバック後、`/my:learn` / `/my:retro` は未登録に戻る。既存のフローには影響しない。

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | 4 ファイル作成、ディレクトリ作成のみ |
| Phase 2: Core Logic | Medium | `redact.sh` のパターンマッチ実装 + 2 prompt 文書作成。bash の細部 (macOS bash3 / `date -v`) で慎重さ必要 |
| Phase 3: Integration | Low | 2 command 定義と README 追記。`/my:change` には触れない |
| Phase 4: Testing | Medium | bats が無い環境で shell driver fallback を書く場合は工数増 |

---

**Created:** 2026-06-27
**Status:** Ready
**Assignee:** implementer subagent (`/my:do 20260627-session-knowledge-capture`)
