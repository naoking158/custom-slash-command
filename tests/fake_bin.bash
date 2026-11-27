# fake_bin.bash — `load ../fake_bin` in a bats file.

# fake_bin PATH — install the script read from stdin as executable PATH.
# The script is written once per bats file and content (tests running in
# parallel may each write a copy of the same content), and PATH is a symlink
# to that copy: on macOS the first exec of every newly written executable
# costs about 130ms (provenance check), a symlink to a checked one does not.
# An existing copy is found by comparing contents in bash, so a call that
# finds one starts no process but ln. Safe when tests of one file run in
# parallel.
fake_bin() {
  local body copy content tmp dir="$BATS_FILE_TMPDIR/fake-bin"
  IFS= read -r -d '' body || true
  while [ "${body%$'\n'}" != "$body" ]; do body="${body%$'\n'}"; done
  for copy in "$dir"/fake.*; do
    [ -f "$copy" ] || continue
    IFS= read -r -d '' content <"$copy" || true
    if [ "$content" = "$body"$'\n' ]; then
      ln -sfn "$copy" "$1"
      return
    fi
  done
  [ -d "$dir" ] || mkdir -p "$dir"
  tmp="$dir/.tmp.$$.$RANDOM$RANDOM"
  printf '%s\n' "$body" >"$tmp"
  chmod +x "$tmp"
  copy="$dir/fake.$$.$RANDOM$RANDOM"
  mv "$tmp" "$copy"
  ln -sfn "$copy" "$1"
}
