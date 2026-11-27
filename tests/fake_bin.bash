# fake_bin.bash — `load ../fake_bin` in a bats file.

# fake_bin PATH — install the script read from stdin as executable PATH.
# PATH is a symlink to a copy of the script in a cache shared by every test
# and every run ($TMPDIR/my-toolkit-test-fakes.<uid>, created with mode 700): on macOS the
# first exec of every newly written executable costs about 350ms and these
# checks run one at a time across the machine, while an exec through a
# symlink to a file already checked does not pay it. A copy is found by
# comparing contents in bash, so a call that finds one starts no process but
# ln. When the cache directory is not ours, the copies go under
# $BATS_FILE_TMPDIR instead. Safe when tests run in parallel; tests must not
# write through PATH, which would change the shared copy.
fake_bin() {
  local body copy content tmp dir
  dir="${TMPDIR:-/tmp}"
  dir="${dir%/}/my-toolkit-test-fakes.${UID:-0}"
  [ -d "$dir" ] || mkdir -m 700 "$dir" 2>/dev/null || true
  if [ ! -d "$dir" ] || [ ! -O "$dir" ] || [ -L "$dir" ]; then
    dir="$BATS_FILE_TMPDIR/fake-bin"
    [ -d "$dir" ] || mkdir -p "$dir"
  fi
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
  copy="$(mktemp "$dir/fake.XXXXXX")"
  tmp="$dir/.tmp.${copy##*/}"
  printf '%s\n' "$body" >"$tmp"
  chmod +x "$tmp"
  mv -f "$tmp" "$copy"
  ln -sfn "$copy" "$1"
}
