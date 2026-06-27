#!/usr/bin/env bats
# Unit tests for scripts/redact.sh — Spec §9.1.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REDACT="$REPO_ROOT/scripts/redact.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  TMP="$(mktemp -d -t redact-test.XXXXXX)"
}

teardown() {
  [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -rf "$TMP"
}

@test "clean input exits 0 and output is identical to input" {
  run "$REDACT" "$FIXTURES/clean.txt"
  [ "$status" -eq 0 ]
  # Use diff to ensure exact match including trailing newline.
  echo "$output" > "$TMP/out.txt"
  # bats run drops the final newline from $output; recreate by comparing payloads
  # via diff on a piped stdin so we are robust to that.
  diff <("$REDACT" "$FIXTURES/clean.txt" 2>/dev/null) "$FIXTURES/clean.txt"
}

@test "sk- API key is masked and exit code is 2" {
  echo "key sk-abcdefghijklmnopqrstuvwxyz0123 in line" > "$TMP/in.txt"
  run "$REDACT" "$TMP/in.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:sk-key]"* ]]
  [[ "$output" != *"sk-abcdefghijklmnopqrstuvwxyz0123"* ]]
}

@test "ghp_ token is masked and exit code is 2" {
  echo "token ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" > "$TMP/in.txt"
  run "$REDACT" "$TMP/in.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:ghp-token]"* ]]
}

@test "AKIA AWS key is masked and exit code is 2" {
  echo "aws AKIAABCDEFGHIJKLMNOP issued" > "$TMP/in.txt"
  run "$REDACT" "$TMP/in.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:aws-key]"* ]]
}

@test "/Users/<name>/ path is rewritten to \$HOME/ and exit code is 2" {
  echo "path /Users/foo/bar/baz" > "$TMP/in.txt"
  run "$REDACT" "$TMP/in.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"\$HOME/bar/baz"* ]]
  [[ "$output" != *"/Users/foo/"* ]]
}

@test ".env style API_TOKEN= line is masked and exit code is 2" {
  echo "API_TOKEN=supersecretvalueshouldnotleak" > "$TMP/in.txt"
  run "$REDACT" "$TMP/in.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"API_TOKEN=[REDACTED]"* ]]
  [[ "$output" != *"supersecretvalueshouldnotleak"* ]]
}

@test "all patterns together produce exit 2 and at least one [REDACTED: token" {
  run "$REDACT" "$FIXTURES/with-secrets.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:"* ]]
  # Cross-pattern checks
  [[ "$output" == *"[REDACTED:sk-key]"* ]]
  [[ "$output" == *"[REDACTED:ghp-token]"* ]]
  [[ "$output" == *"[REDACTED:aws-key]"* ]]
  [[ "$output" == *"\$HOME/"* ]]
  [[ "$output" == *"API_TOKEN=[REDACTED]"* ]]
}

@test "deny-list hit via REDACT_DENYLIST env produces [REDACTED:deny] and exit 2" {
  echo "leak: secret-codename-aaaa1111 found" > "$TMP/in.txt"
  REDACT_DENYLIST="$FIXTURES/denylist.txt" run "$REDACT" "$TMP/in.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:deny]"* ]]
  [[ "$output" != *"secret-codename-aaaa1111"* ]]
}

@test "stdin input (no args) is supported" {
  run bash -c 'echo "sk-abcdefghijklmnopqrstuvwxyz0123" | "$0"' "$REDACT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:sk-key]"* ]]
}

@test "stdin input via explicit '-' is supported" {
  run bash -c 'echo "sk-abcdefghijklmnopqrstuvwxyz0123" | "$0" -' "$REDACT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"[REDACTED:sk-key]"* ]]
}

@test "nonexistent file path returns exit 1 with stderr error" {
  run "$REDACT" "$TMP/does-not-exist.txt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot read"* ]] || [[ "$stderr" == *"cannot read"* ]]
}

@test "stderr summary line uses contract format" {
  run "$REDACT" "$FIXTURES/clean.txt"
  [ "$status" -eq 0 ]
  # bats merges stderr into $output by default; check the line exists.
  run bash -c '"$0" "$1" 2>&1 1>/dev/null' "$REDACT" "$FIXTURES/clean.txt"
  [[ "$output" == *"redact.sh: matched=0 patterns=<sk:0,ghp:0,aws:0,home:0,env:0,deny:0>"* ]]
}

@test "stderr summary reports non-zero counts for masked input" {
  run bash -c '"$0" "$1" 2>&1 1>/dev/null' "$REDACT" "$FIXTURES/with-secrets.txt"
  [[ "$output" == *"redact.sh: matched="* ]]
  [[ "$output" != *"matched=0"* ]]
}
