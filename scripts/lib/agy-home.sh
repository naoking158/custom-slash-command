#!/usr/bin/env bash
# agy-home.sh — Make a throwaway HOME in which Antigravity (agy) loads a given
# toolkit checkout as the `my` plugin.
#
# Usage: scripts/lib/agy-home.sh <new home> <toolkit checkout>
#
# agy has no setting for where plugins live, and a workspace's .agents/plugins
# loses to an installed plugin of the same name, so the checkout goes into the
# new home's .gemini/config/plugins/my (and its antigravity-agents/ into
# my-agents when present). Everything else in .gemini and .gemini/config is a
# symlink to the real one, so sign-in and conversations keep working; so are
# ~/Library (agy's sign-in lives in the keychain), ~/.gitconfig, ~/.config and
# ~/.local/{bin,share,lib}. ~/.claude and ~/.local/state are not linked: they
# stay empty in the new home. Run agy with HOME=<new home>.
#
# Exit codes: 0 made, 1 usage error or <new home> already exists.
# Dependencies: bash, ln, mkdir.
set -u

[ $# -eq 2 ] || { echo "usage: agy-home.sh <new home> <toolkit checkout>" >&2; exit 1; }
h="$1"
plugin="$(cd "$2" 2>/dev/null && pwd -P)" || { echo "agy-home.sh: no such directory: $2" >&2; exit 1; }
[ ! -e "$h" ] || { echo "agy-home.sh: $h already exists" >&2; exit 1; }
mkdir -p "$h/.gemini/config/plugins" || exit 1
for f in "$HOME"/.gemini/* "$HOME"/.gemini/.[!.]*; do
  [ -e "$f" ] || continue
  b="${f##*/}"
  [ "$b" = config ] || ln -s "$f" "$h/.gemini/$b"
done
for f in "$HOME"/.gemini/config/*; do
  [ -e "$f" ] || continue
  b="${f##*/}"
  [ "$b" = plugins ] || ln -s "$f" "$h/.gemini/config/$b"
done
ln -s "$plugin" "$h/.gemini/config/plugins/my"
if [ -d "$plugin/antigravity-agents" ]; then
  ln -s "$plugin/antigravity-agents" "$h/.gemini/config/plugins/my-agents"
fi
for b in Library .gitconfig .config .local/bin .local/share .local/lib; do
  [ -e "$HOME/$b" ] || continue
  mkdir -p "$(dirname "$h/$b")"
  ln -s "$HOME/$b" "$h/$b"
done
exit 0
