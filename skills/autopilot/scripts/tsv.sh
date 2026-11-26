# tsv.sh — Append-only TSV rows for the autopilot logs. Sourced by log-*.sh.
#
# Adapted from pstack `show-me-your-work/scripts/log.sh` (github.com/cursor/plugins, MIT).

# tsv_cell <value> — prints the value as one safe cell: tabs, newlines and
# carriage returns become spaces, and a leading = + - @ gets a ' so that a
# spreadsheet does not run it as a formula.
tsv_cell() {
  local v="$1"
  v="${v//$'\t'/ }"
  v="${v//$'\n'/ }"
  v="${v//$'\r'/ }"
  case "$v" in
    [=+@-]*) v="'$v" ;;
  esac
  printf '%s' "$v"
}

# tsv_append <logfile> <header> <cell>... — appends one row of cells, writing
# the tab-separated <header> line first when the file is missing or empty.
tsv_append() {
  local logfile="$1" header="$2" sep="" cell
  shift 2
  mkdir -p "$(dirname "$logfile")"
  [ -s "$logfile" ] || printf '%s\n' "$header" >>"$logfile"
  {
    for cell in "$@"; do
      printf '%s' "$sep"
      tsv_cell "$cell"
      sep=$'\t'
    done
    printf '\n'
  } >>"$logfile"
}
