#!/usr/bin/env bash
# scripts/ci/dart_fix.sh
#
# Run dart fix to apply automated lint fixes.
# Verbose output captured to /tmp, summary printed to stdout.
# Usage:
#   ./scripts/ci/dart_fix.sh preview         # show what would change (default)
#   ./scripts/ci/dart_fix.sh apply           # apply fixes
#   ./scripts/ci/dart_fix.sh preview lib/    # preview specific directory
#
# Output files written:
#   /tmp/ed_fix_full.txt    — complete dart fix output
#   /tmp/ed_fix_changes.txt — list of proposed/applied changes
#   /tmp/ed_fix_summary.txt — summary

set -uo pipefail

LOGFILE="/tmp/ed_fix_full.txt"
CHANGEFILE="/tmp/ed_fix_changes.txt"
SUMMARYFILE="/tmp/ed_fix_summary.txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

MODE="${1:-preview}"
TARGET="${2:-.}"

echo "[$TIMESTAMP] dart fix mode=$MODE target=$TARGET" >"$LOGFILE"

if [ "$MODE" = "apply" ]; then
  dart fix --apply "$TARGET" >>"$LOGFILE" 2>&1
  FIX_EXIT=$?
else
  dart fix --dry-run "$TARGET" >>"$LOGFILE" 2>&1
  FIX_EXIT=$?
fi

# Extract change lines
grep -E "^(Would fix|Fixed|Applying|\s+lib/|\s+test/)" "$LOGFILE" \
  >"$CHANGEFILE" 2>/dev/null || true

CHANGE_COUNT=$(wc -l <"$CHANGEFILE" | tr -d ' ')

{
  echo "=== dart fix summary ==="
  echo "Timestamp : $TIMESTAMP"
  echo "Mode      : $MODE"
  echo "Target    : $TARGET"
  echo ""
  echo "Changes   : $CHANGE_COUNT"
  echo "Exit      : $FIX_EXIT"
  echo ""
  if [ -s "$CHANGEFILE" ]; then
    echo "--- Proposed/applied changes ---"
    cat "$CHANGEFILE"
  else
    echo "No fixes available."
  fi
} | tee "$SUMMARYFILE"

exit "$FIX_EXIT"
