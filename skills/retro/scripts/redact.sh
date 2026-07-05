#!/usr/bin/env bash
# redact.sh — Mask secrets from journal candidate text before display.
#
# Reads input from a file path or stdin, applies a sequence of redaction
# patterns, prints the masked output on stdout, and reports per-pattern
# token counts on stderr.
#
# Exit codes:
#   0 = clean (nothing matched)
#   1 = error (argument / file read failure)
#   2 = matches found and masked
#
# Stderr contract (used by callers like /my:retro):
#   redact.sh: matched=<N> patterns=<sk:N,ghp:N,aws:N,home:N,env:N,deny:N>
#
# Dependencies: bash, sed, grep, awk, mktemp (NFR-006: no python/node).
set -euo pipefail

# Locate the deny-list. Allow override via REDACT_DENYLIST for tests.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DENYLIST="${REDACT_DENYLIST:-${SCRIPT_DIR}/redact.denylist}"

# Per-pattern match counts (token-level, NOT "did the pattern fire" flags).
declare -i N_SK=0 N_GHP=0 N_AWS=0 N_HOME=0 N_ENV=0 N_DENY=0

# read_input_to_file — Stage input into a temp file so trailing newlines
# survive (command substitution would strip them).
# Args: optional file path; if absent or "-", read from stdin.
# Prints the temp file path to stdout.
read_input_to_file() {
  local tmp
  tmp="$(mktemp -t redact.XXXXXX)"
  if [[ $# -ge 1 && "$1" != "-" ]]; then
    if [[ ! -f "$1" ]]; then
      echo "redact.sh: cannot read $1" >&2
      rm -f -- "$tmp"
      return 1
    fi
    cat -- "$1" > "$tmp"
  else
    cat > "$tmp"
  fi
  printf '%s' "$tmp"
}

# count_matches — Count tokens matching an ERE pattern in a file.
# Uses grep -oE | wc -l so multiple matches per line are counted (not boolean).
# Returns "0" if grep finds nothing (suppresses grep's exit=1 to avoid
# tripping `set -e` / `pipefail` in the caller).
count_matches() {
  local pattern="$1" file="$2"
  local n
  n="$( { grep -oE "$pattern" "$file" 2>/dev/null || true; } | wc -l | tr -d ' ')"
  printf '%s' "${n:-0}"
}

# apply — Rewrite a file in-place using a sed expression, via a temp file
# so we never lose trailing newlines and never collide with sed -i portability
# differences between BSD/GNU.
apply() {
  local expr="$1" file="$2"
  local tmp
  tmp="$(mktemp -t redact.XXXXXX)"
  sed -E "$expr" "$file" > "$tmp"
  mv -- "$tmp" "$file"
}

# mask_file — Apply all redaction patterns to a staged file.
mask_file() {
  local f="$1"

  # 1. Anthropic-style API keys: sk-XXXXXXXXXXXXXXXXXXXX (20+ alnum)
  N_SK=$(count_matches 'sk-[A-Za-z0-9]{20,}' "$f")
  apply 's/sk-[A-Za-z0-9]{20,}/[REDACTED:sk-key]/g' "$f"

  # 2. GitHub personal-access tokens: ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX (30+)
  N_GHP=$(count_matches 'ghp_[A-Za-z0-9]{30,}' "$f")
  apply 's/ghp_[A-Za-z0-9]{30,}/[REDACTED:ghp-token]/g' "$f"

  # 3. AWS access key IDs: AKIA + 16 uppercase alnum
  N_AWS=$(count_matches 'AKIA[A-Z0-9]{16}' "$f")
  apply 's/AKIA[A-Z0-9]{16}/[REDACTED:aws-key]/g' "$f"

  # 4. Absolute home paths: /Users/<name>/  →  $HOME/
  N_HOME=$(count_matches '/Users/[^/[:space:]]+/' "$f")
  apply 's|/Users/[^/[:space:]]+/|$HOME/|g' "$f"

  # 5. .env style RHS: FOO_TOKEN=..., FOO_SECRET=..., FOO_KEY=...
  N_ENV=$(count_matches '^[A-Z0-9_]+_(TOKEN|SECRET|KEY)=.*$' "$f")
  apply 's/^([A-Z0-9_]+_(TOKEN|SECRET|KEY))=.*$/\1=[REDACTED]/g' "$f"

  # 6. Deny-list — user-configured tokens. Each non-comment, non-empty line
  # is matched literally (grep -F) and substituted via sed; metacharacters
  # in the pattern (/, &, special chars) are escaped before sed sees them.
  if [[ -f "$DENYLIST" ]]; then
    local pat hits esc
    while IFS= read -r pat || [[ -n "$pat" ]]; do
      # Skip blanks and comments.
      [[ -z "$pat" ]] && continue
      case "$pat" in
        \#*) continue ;;
      esac
      hits="$(grep -cF -- "$pat" "$f" 2>/dev/null || true)"
      hits="${hits:-0}"
      if (( hits > 0 )); then
        # Token count: multiple occurrences on one line still register as 1
        # per line via grep -cF; that's the best portable token count we can
        # offer without a second pass. We add the line-count here.
        N_DENY=$(( N_DENY + hits ))
        # Escape sed metachars in the literal pattern. Replace any
        # character in the set [\/&.*^$[]] with a backslashed equivalent
        # using a sed expression that operates on the pattern string itself.
        esc="$(printf '%s' "$pat" | sed -e 's/[][\/.^$*&]/\\&/g')"
        apply "s/${esc}/[REDACTED:deny]/g" "$f"
      fi
    done < "$DENYLIST"
  fi
}

main() {
  local tmpfile
  tmpfile="$(read_input_to_file "$@")" || exit 1
  mask_file "$tmpfile"
  # Preserve trailing newline of original input by streaming the temp file.
  cat -- "$tmpfile"
  local total=$(( N_SK + N_GHP + N_AWS + N_HOME + N_ENV + N_DENY ))
  echo "redact.sh: matched=${total} patterns=<sk:${N_SK},ghp:${N_GHP},aws:${N_AWS},home:${N_HOME},env:${N_ENV},deny:${N_DENY}>" >&2
  rm -f -- "$tmpfile"
  if (( total > 0 )); then
    exit 2
  fi
  exit 0
}

main "$@"
