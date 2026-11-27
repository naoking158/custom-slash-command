#!/usr/bin/env bash
# diff-hunks.sh — Index a saved unified diff into hunk rows and statistics.
#
# Deliberately does NOT call git: it reads a patch file the caller already
# saved (spec §3.2.2). That keeps the numbering rule testable against fixture
# patches and makes the source of the diff (git diff / git show / gh pr diff)
# irrelevant to everything downstream.
#
# Usage: diff-hunks.sh --diff <patch-file> --out <dir>
#
# Outputs:
#   <dir>/hunks.tsv    hunk_id \t path \t hunk_header \t old_start \t new_start
#   <dir>/stats.json   {"files":N,"hunks":N,"insertions":N,"deletions":N}
#
# Exit codes:
#   0 = success
#   1 = bad arguments / patch file unreadable
#   2 = patch contains no hunks (empty or binary-only diff)
#
# Dependencies: bash, awk, iconv, jq (NFR-001: no python/node).
set -euo pipefail

usage() {
  echo "usage: diff-hunks.sh --diff <patch-file> --out <dir>" >&2
}

PATCH_FILE=""
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      PATCH_FILE="$2"; shift 2 ;;
    --out)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      OUT_DIR="$2"; shift 2 ;;
    *)
      echo "diff-hunks.sh: unknown argument: $1" >&2
      usage; exit 1 ;;
  esac
done

if [[ -z "$PATCH_FILE" || -z "$OUT_DIR" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$PATCH_FILE" || ! -r "$PATCH_FILE" ]]; then
  echo "diff-hunks.sh: cannot read $PATCH_FILE" >&2
  exit 1
fi

# BSD awk fails on bytes that are not UTF-8; GNU awk and mawk parse them. Check
# the encoding here so that every platform rejects such a patch the same way.
if ! iconv -f UTF-8 -t UTF-8 "$PATCH_FILE" >/dev/null 2>&1; then
  echo "diff-hunks.sh: cannot parse $PATCH_FILE (non-UTF-8 patch)" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Single pass over the patch. Rows are buffered so the zero-padding width can
# be derived from the final hunk count (spec §3.2.2) without re-reading the
# file — and so the hunk-header pattern appears exactly once.
#
# `in_hunk` gates the `---` / `+++` file headers: inside a hunk body those
# same prefixes are ordinary deleted/added source lines (e.g. a removed SQL
# `-- comment` arrives as `--- comment`).
set +e
counts="$(awk -v tsv="$OUT_DIR/hunks.tsv" '
  function strip_prefix(p) {
    if (substr(p, 1, 2) == "a/" || substr(p, 1, 2) == "b/") return substr(p, 3)
    return p
  }
  /^diff --git / { files++; in_hunk = 0; path_old = ""; path_new = ""; next }
  !in_hunk && /^--- / {
    p = substr($0, 5)
    path_old = (p == "/dev/null") ? "" : strip_prefix(p)
    next
  }
  !in_hunk && /^\+\+\+ / {
    p = substr($0, 5)
    path_new = (p == "/dev/null") ? "" : strip_prefix(p)
    next
  }
  # HUNK_RE: ^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@
  /^@@ -[0-9]+(,[0-9]+)? \+[0-9]+(,[0-9]+)? @@/ {
    in_hunk = 1
    n++
    os = substr($2, 2); sub(/,.*/, "", os)
    ns = substr($3, 2); sub(/,.*/, "", ns)
    header = $0
    gsub(/\t/, " ", header)
    row_path[n]   = (path_new != "") ? path_new : path_old
    row_header[n] = header
    row_os[n]     = os
    row_ns[n]     = ns
    next
  }
  in_hunk && /^\+/ { insertions++; next }
  in_hunk && /^-/  { deletions++;  next }
  END {
    # 9, not 2: awk itself exits 2 on a multibyte conversion failure, and a
    # non-UTF-8 patch must not be reported as an empty one.
    if (n == 0) exit 9
    width = (length(n) > 3) ? length(n) : 3
    fmt = "h%0" width "d"
    for (i = 1; i <= n; i++)
      printf "%s\t%s\t%s\t%s\t%s\n", sprintf(fmt, i), row_path[i], row_header[i], row_os[i], row_ns[i] > tsv
    close(tsv)
    printf "%d %d %d %d\n", files + 0, n + 0, insertions + 0, deletions + 0
  }
' "$PATCH_FILE")"
rc=$?
set -e

if (( rc == 9 )); then
  echo "diff-hunks.sh: no hunks in $PATCH_FILE" >&2
  exit 2
fi
if (( rc != 0 )); then
  echo "diff-hunks.sh: cannot parse $PATCH_FILE (non-UTF-8 or malformed patch)" >&2
  exit 1
fi

read -r n_files n_hunks n_ins n_del <<< "$counts"

jq -n \
  --argjson files "$n_files" \
  --argjson hunks "$n_hunks" \
  --argjson insertions "$n_ins" \
  --argjson deletions "$n_del" \
  '{files: $files, hunks: $hunks, insertions: $insertions, deletions: $deletions}' \
  > "$OUT_DIR/stats.json"
