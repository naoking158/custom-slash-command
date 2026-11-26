#!/usr/bin/env bash
# log-decision.sh — Append one decision of an autopilot run to its decisions.tsv.
#
#   log-decision.sh <logfile> <phase> <decision> <why> <evidence> <result>
#
# Columns: ts (UTC ISO 8601), phase, decision, why, evidence, result. The header
# is written when the file is missing or empty; rows are only ever appended.
# Cells are flattened to one line and guarded against spreadsheet formulas
# (see tsv.sh).
#
# Exit status: 0 appended, 2 usage error.
# Adapted from pstack `show-me-your-work/scripts/log.sh` (github.com/cursor/plugins, MIT).
set -euo pipefail

if [ $# -ne 6 ]; then
  echo "usage: log-decision.sh <logfile> <phase> <decision> <why> <evidence> <result>" >&2
  exit 2
fi

. "$(cd "$(dirname "$0")" && pwd)/tsv.sh"

tsv_append "$1" $'ts\tphase\tdecision\twhy\tevidence\tresult' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" "$3" "$4" "$5" "$6"
