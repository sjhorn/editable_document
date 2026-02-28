#!/usr/bin/env bash
# scripts/ci/dart_format.sh
#
# Check or apply dart format with line-length 100.
# Verbose output captured to /tmp, summary printed to stdout.
# Usage:
#   ./scripts/ci/dart_format.sh check          # check only (default, exits non-zero if unformatted)
#   ./scripts/ci/dart_format.sh fix            # apply formatting
#   ./scripts/ci/dart_format.sh check lib/     # check specific directory
#
# Output files written:
#   /tmp/ed_format_full.txt    — complete dart format output
#   /tmp/ed_format_diff.txt    — files that need formatting
#   /tmp/ed_format_summary.txt — summary

set -uo pipefail

LOGFILE="/tmp/ed_format_full.txt"
DIFFFILE="/tmp/ed_format_diff.txt"
SUMMARYFILE="/tmp/ed_format_summary.txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

MODE="${1:-check}"
TARGET="${2:-.}"

echo "[$TIMESTAMP] dart format mode=$MODE target=$TARGET" >"$LOGFILE"

if [ "$MODE" = "fix" ]; then
  dart format --line-length 100 "$TARGET" >>"$LOGFILE" 2>&1
  FORMAT_EXIT=$?
else
  dart format --line-length 100 --set-exit-if-changed --output=none \
    "$TARGET" >>"$LOGFILE" 2>&1
  FORMAT_EXIT=$?
fi

# Only match lines listing actual changed/would-change files (not the summary line)
grep -E "^(Changed|Would change) " "$LOGFILE" \
  >"$DIFFFILE" 2>/dev/null || true

CHANGED_COUNT=$(wc -l <"$DIFFFILE" | tr -d ' ')

{
  echo "=== dart format summary ==="
  echo "Timestamp : $TIMESTAMP"
  echo "Mode      : $MODE"
  echo "Target    : $TARGET"
  echo "Line len  : 100"
  echo ""
  echo "Changed   : $CHANGED_COUNT file(s)"
  echo "Exit      : $FORMAT_EXIT"
  echo ""
  if [ -s "$DIFFFILE" ]; then
    echo "--- Files needing format ---"
    cat "$DIFFFILE"
  else
    if [ "$MODE" = "check" ]; then
      echo "All files correctly formatted."
    else
      echo "Formatting applied."
    fi
  fi
} | tee "$SUMMARYFILE"

exit "$FORMAT_EXIT"
