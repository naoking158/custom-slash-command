# fake_bin.bash — `load ../fake_bin` in a bats file.

# fake_bin PATH — install the script read from stdin as executable PATH.
# The script is written once per bats file and content, and PATH is a symlink
# to that copy: on macOS the first exec of every newly written executable
# costs about 130ms (provenance check), a symlink to a checked one does not.
# Safe when tests of one file run in parallel.
fake_bin() {
  local body sum tmp dir="$BATS_FILE_TMPDIR/fake-bin"
  body="$(cat)"
  sum="$(printf '%s' "$body" | cksum | tr ' ' _)"
  if [ ! -e "$dir/$sum" ]; then
    mkdir -p "$dir"
    tmp="$(mktemp "$dir/.tmp.XXXXXX")"
    printf '%s\n' "$body" >"$tmp"
    chmod +x "$tmp"
    ln "$tmp" "$dir/$sum" 2>/dev/null || true
    rm -f "$tmp"
  fi
  rm -f "$1"
  ln -s "$dir/$sum" "$1"
}
