#!/usr/bin/env bash
# scripts/ci/coverage.sh
#
# Run flutter test --coverage, generate HTML report, check thresholds.
# Verbose output captured to /tmp, summary printed to stdout.
# Usage:
#   ./scripts/ci/coverage.sh                     # all tests, threshold 90%
#   ./scripts/ci/coverage.sh test/src/services/  # specific path, threshold 100%
#   ./scripts/ci/coverage.sh "" 95               # all tests, custom threshold
#
# Requires: lcov (brew install lcov / apt install lcov)
#
# Output files written:
#   /tmp/ed_coverage_full.txt    — flutter test --coverage output
#   /tmp/ed_coverage_summary.txt — per-file and total coverage %
#   coverage/lcov.info           — standard lcov file (in project root)
#   coverage/html/               — HTML report (in project root)

set -uo pipefail

LOGFILE="/tmp/ed_coverage_full.txt"
SUMMARYFILE="/tmp/ed_coverage_summary.txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

TEST_PATH="${1:-}"
THRESHOLD="${2:-90}"

# Services path always requires 100%
if echo "$TEST_PATH" | grep -q "services"; then
  THRESHOLD=100
fi

echo "[$TIMESTAMP] coverage path='${TEST_PATH:-all}' threshold=${THRESHOLD}%" >"$LOGFILE"

# Run tests with coverage
if [ -n "$TEST_PATH" ]; then
  flutter test --coverage "$TEST_PATH" >>"$LOGFILE" 2>&1
  TEST_EXIT=$?
else
  flutter test --coverage >>"$LOGFILE" 2>&1
  TEST_EXIT=$?
fi

# Generate HTML if lcov is available
if command -v genhtml >/dev/null 2>&1; then
  genhtml coverage/lcov.info \
    --output-directory coverage/html \
    --quiet >>"$LOGFILE" 2>&1 || true
fi

# Parse total coverage from lcov.info
TOTAL_LINES=$(grep -c "^DA:" coverage/lcov.info 2>/dev/null || true)
TOTAL_LINES=${TOTAL_LINES:-0}
HIT_LINES=$(grep -cE "^DA:[0-9]+,[^0]" coverage/lcov.info 2>/dev/null || true)
HIT_LINES=${HIT_LINES:-0}

if [ "$TOTAL_LINES" -gt 0 ]; then
  COVERAGE=$(awk "BEGIN {printf \"%.1f\", ($HIT_LINES / $TOTAL_LINES) * 100}")
else
  COVERAGE="0.0"
fi

# Check threshold
THRESHOLD_MET=0
if awk "BEGIN {exit !($COVERAGE >= $THRESHOLD)}"; then
  THRESHOLD_MET=1
fi

{
  echo "=== coverage summary ==="
  echo "Timestamp : $TIMESTAMP"
  echo "Path      : ${TEST_PATH:-all}"
  echo "Threshold : ${THRESHOLD}%"
  echo ""
  echo "Lines hit  : $HIT_LINES / $TOTAL_LINES"
  echo "Coverage   : ${COVERAGE}%"
  echo "Threshold  : $( [ "$THRESHOLD_MET" -eq 1 ] && echo "MET" || echo "NOT MET")"
  echo "Test exit  : $TEST_EXIT"
  echo ""
  # Per-file breakdown from lcov
  if command -v lcov >/dev/null 2>&1; then
    echo "--- Per-file coverage ---"
    lcov --summary coverage/lcov.info 2>&1 | grep -E "lines|functions|branches" || true
  fi
} | tee "$SUMMARYFILE"

# Fail if tests failed OR coverage below threshold
if [ "$TEST_EXIT" -ne 0 ]; then
  exit "$TEST_EXIT"
fi
if [ "$THRESHOLD_MET" -eq 0 ]; then
  echo "ERROR: Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
  exit 1
fi

exit 0
