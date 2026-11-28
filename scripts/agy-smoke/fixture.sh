#!/usr/bin/env bash
# fixture.sh — Create the repository a smoke case runs in.
#
# Usage: scripts/agy-smoke/fixture.sh <dir>
#
# <dir>/origin.git is a bare repository standing in for GitHub, and <dir>/repo
# a clone of it on branch feature/mul, one commit ahead of origin/main, with
# origin/HEAD set. Nothing points at a network remote.
# Dependencies: bash, git.
set -eu

dir="$1"
mkdir -p "$dir"
git init -q --bare -b main "$dir/origin.git"
git init -q -b main "$dir/repo"
cd "$dir/repo"
git config user.name smoke
git config user.email smoke@example.invalid
cat >calc.sh <<'EOF'
#!/usr/bin/env bash
# calc.sh — integer calculator: calc.sh <add> <a> <b>
set -eu
add() { echo $(($1 + $2)); }
case "${1:-}" in
  add) add "$2" "$3" ;;
  *) echo "usage: calc.sh add <a> <b>" >&2; exit 2 ;;
esac
EOF
cat >test_calc.sh <<'EOF'
#!/usr/bin/env bash
set -eu
[ "$(./calc.sh add 2 3)" = 5 ] || { echo "add failed"; exit 1; }
echo ok
EOF
chmod +x calc.sh test_calc.sh
mkdir -p docs/prd
cat >docs/prd/20261128-calc-history.md <<'EOF'
# PRD: 計算履歴

## 背景
calc.sh の利用者は直前の計算結果を再利用したい。

## 要件
- 計算ごとに式と結果を ~/.calc_history に 1 行で追記する
- `calc.sh history` で直近 10 件を表示する
EOF
git add -A
git commit -qm "calc.sh: add"
git remote add origin "$dir/origin.git"
git push -q origin main
git remote set-head origin main
git switch -qc feature/mul
cat >calc.sh <<'EOF'
#!/usr/bin/env bash
# calc.sh — integer calculator: calc.sh <add|mul> <a> <b>
set -eu
add() { echo $(($1 + $2)); }
mul() { echo $(($1 * $2)); }
case "${1:-}" in
  add) add "$2" "$3" ;;
  mul) mul "$2" "$3" ;;
  *) echo "usage: calc.sh add|mul <a> <b>" >&2; exit 2 ;;
esac
EOF
git commit -qam "calc.sh: add mul"
