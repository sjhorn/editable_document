#!/usr/bin/env bash
# scripts/ci/ci_gate.sh
#
# Run the full commit gate: analyze → format check → test.
# Each sub-script captures its own verbose output to /tmp log files
# and prints only a summary to stdout.
#
# Usage:
#   ./scripts/ci/ci_gate.sh                  # full gate on everything
#   ./scripts/ci/ci_gate.sh test/src/model/  # gate scoped to one layer
#
# Output files written:
#   /tmp/ed_gate_summary.txt — pass/fail per step + overall result
#   (plus each sub-script's own /tmp/ed_*.txt files)

set -uo pipefail

SUMMARYFILE="/tmp/ed_gate_summary.txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SCOPE="${1:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RESULT_ANALYZE="SKIP"
RESULT_FORMAT="SKIP"
RESULT_TEST="SKIP"

# Step 1: analyze
echo ">>> flutter analyze"
if bash "$SCRIPT_DIR/flutter_analyze.sh" ${SCOPE:+"$SCOPE"}; then
  RESULT_ANALYZE="PASS"
else
  RESULT_ANALYZE="FAIL"
fi
echo ""

# Step 2: format check
echo ">>> dart format check"
if bash "$SCRIPT_DIR/dart_format.sh" check ${SCOPE:+"$SCOPE"}; then
  RESULT_FORMAT="PASS"
else
  RESULT_FORMAT="FAIL"
fi
echo ""

# Step 3: tests
echo ">>> flutter test"
if bash "$SCRIPT_DIR/flutter_test.sh" ${SCOPE:+"$SCOPE"}; then
  RESULT_TEST="PASS"
else
  RESULT_TEST="FAIL"
fi
echo ""

# Determine overall result
OVERALL="PASS"
if [ "$RESULT_ANALYZE" = "FAIL" ] || [ "$RESULT_FORMAT" = "FAIL" ] || [ "$RESULT_TEST" = "FAIL" ]; then
  OVERALL="FAIL"
fi

{
  echo "=== CI gate summary ==="
  echo "Timestamp : $TIMESTAMP"
  echo "Scope     : ${SCOPE:-all}"
  echo ""
  echo "  flutter analyze   : $RESULT_ANALYZE"
  echo "  dart format check : $RESULT_FORMAT"
  echo "  flutter test      : $RESULT_TEST"
  echo ""
  echo "Overall   : $OVERALL"
} | tee "$SUMMARYFILE"

[ "$OVERALL" = "PASS" ] && exit 0 || exit 1
