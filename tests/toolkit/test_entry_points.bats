#!/usr/bin/env bats
# Tests for the scripts users and hooks start directly. The other tests start
# them as `bash SCRIPT`, which reads neither the executable bit nor the #!
# line, so this file checks both.
#
# Contract under test:
#   - Every tracked file with a #! line under scripts/, orca/bin/,
#     skills/*/scripts/ and tests/*.sh is executable and starts with
#     #!/usr/bin/env bash.

@test "every script with a #! line is executable and runs bash through env" {
  local REPO_ROOT f first bad=""
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  while IFS= read -r f; do
    IFS= read -r first <"$REPO_ROOT/$f" || true
    case "$first" in '#!'*) ;; *) continue ;; esac
    if [ "$first" != '#!/usr/bin/env bash' ] || [ ! -x "$REPO_ROOT/$f" ]; then
      bad="$bad $f"
    fi
  done < <(git -C "$REPO_ROOT" ls-files -- 'scripts/*' 'orca/bin/*' 'skills/*/scripts/*' 'tests/*.sh')
  [ -z "$bad" ] || { echo "not executable bash scripts:$bad"; false; }
}
