#!/bin/bash

MIN_COVERAGE=${1:?"Usage: $0 <minimum_coverage_percent>"}
LCOV_FILE="coverage/lcov.info"

# ── Run tests ────────────────────────────────────────────────────────
flutter test --coverage

if [ ! -f "$LCOV_FILE" ]; then
  echo "ERROR: $LCOV_FILE not found"
  exit 2
fi

# ── 1. Overall summary ──────────────────────────────────────────────
SUMMARY=$(lcov --summary "$LCOV_FILE" 2>&1)
LINE_COV=$(echo "$SUMMARY" | grep 'lines' | awk '{print $2}' | sed 's/%//')
FUNC_COV=$(echo "$SUMMARY" | grep 'functions' | awk '{print $2}' | sed 's/[^0-9.]//g')
BRANCH_COV=$(echo "$SUMMARY" | grep 'branches' | awk '{print $2}' | sed 's/[^0-9.]//g')

echo "============================================"
echo " COVERAGE SUMMARY"
echo "============================================"
echo "Lines:     ${LINE_COV}%"
echo "Functions: ${FUNC_COV:-N/A}%"
echo "Branches:  ${BRANCH_COV:-N/A}%"
echo "Minimum:   ${MIN_COVERAGE}%"
echo "============================================"
echo ""

# ── 2. Per-file breakdown (sorted worst-first) ──────────────────────
echo "============================================"
echo " PER-FILE COVERAGE (worst first)"
echo "============================================"
awk '
  /^SF:/  { file=$0; sub(/^SF:/, "", file) }
  /^LH:/  { hit=$0;  sub(/^LH:/, "", hit); hit=hit+0 }
  /^LF:/  { found=$0; sub(/^LF:/, "", found); found=found+0 }
  /^end_of_record/ {
    pct = (found > 0) ? (hit/found)*100 : 100;
    printf "%6.1f%%  %4d/%4d  %s\n", pct, hit, found, file
  }
' "$LCOV_FILE" | sort -n
echo ""

# ── 3. Uncovered lines per file (most useful for AI) ────────────────
echo "============================================"
echo " UNCOVERED LINES BY FILE"
echo "============================================"
awk '
  /^SF:/ {
    if (file != "" && count > 0) {
      printf "%s\n", file
      for (i = 0; i < count; i++) printf "  %d\n", lines[i]
      printf "\n"
    }
    file = $0; sub(/^SF:/, "", file)
    count = 0; delete lines
  }
  /^DA:/ {
    split($0, a, ","); sub(/^DA:/, "", a[1])
    if (a[2]+0 == 0) { lines[count] = a[1]+0; count++ }
  }
  END {
    if (file != "" && count > 0) {
      printf "%s\n", file
      for (i = 0; i < count; i++) printf "  %d\n", lines[i]
      printf "\n"
    }
  }
' "$LCOV_FILE" | awk '
  # Collapse consecutive line numbers into ranges
  /^[[:space:]]/ {
    line = $1 + 0
    if (in_file == 0) { in_file = 1; start = line; end = line; next }
    if (line == end + 1) { end = line }
    else {
      if (start == end) printf "  L%d\n", start
      else printf "  L%d-L%d\n", start, end
      start = line; end = line
    }
    next
  }
  {
    if (in_file) {
      if (start == end) printf "  L%d\n", start
      else printf "  L%d-L%d\n", start, end
      printf "\n"
    }
    in_file = 0
    print
  }
  END {
    if (in_file) {
      if (start == end) printf "  L%d\n", start
      else printf "  L%d-L%d\n", start, end
      printf "\n"
    }
  }
'

# ── 4. JSON output (for structured AI consumption) ───────────────────
JSON_OUT="coverage/coverage_report.json"
echo "============================================"
echo " GENERATING JSON: $JSON_OUT"
echo "============================================"

awk -v min="$MIN_COVERAGE" '
  function print_entry() {
    pct = (lf > 0) ? (lh/lf)*100 : 100
    if (entry_count > 0) printf ",\n"
    entry_count++
    printf "    {\n"
    printf "      \"file\": \"%s\",\n", file
    printf "      \"lines_found\": %d,\n", lf
    printf "      \"lines_hit\": %d,\n", lh
    printf "      \"coverage_pct\": %.1f,\n", pct
    printf "      \"uncovered_lines\": ["
    for (i = 0; i < ucount; i++) {
      if (i > 0) printf ","
      printf "%d", uncov[i]
    }
    printf "]\n"
    printf "    }"
  }

  BEGIN { entry_count = 0; printf "{\n  \"files\": [\n" }

  /^SF:/ {
    if (file != "") print_entry()
    file = $0; sub(/^SF:/, "", file)
    lf = 0; lh = 0; ucount = 0; delete uncov
  }
  /^DA:/ {
    split($0, a, ","); sub(/^DA:/, "", a[1])
    if (a[2]+0 == 0) { uncov[ucount] = a[1]+0; ucount++ }
  }
  /^LF:/ { lf = $0; sub(/^LF:/, "", lf); lf = lf+0 }
  /^LH:/ { lh = $0; sub(/^LH:/, "", lh); lh = lh+0 }

  END {
    if (file != "") print_entry()
    printf "\n  ],\n"
    printf "  \"summary\": {\n    \"minimum\": %s\n  }\n}\n", min
  }
' "$LCOV_FILE" > "$JSON_OUT"

echo "Written to $JSON_OUT"
echo ""

# ── 5. Markdown summary (paste-friendly for AI chat) ────────────────
MD_OUT="coverage/coverage_report.md"
{
  echo "# Coverage Report"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Lines | ${LINE_COV}% |"
  echo "| Functions | ${FUNC_COV:-N/A}% |"
  echo "| Branches | ${BRANCH_COV:-N/A}% |"
  echo "| Minimum | ${MIN_COVERAGE}% |"
  echo ""
  echo "## Files Below 100%"
  echo ""
  echo "| File | Coverage | Uncovered Lines |"
  echo "|------|----------|-----------------|"

  awk '
    function print_row() {
      pct = (lf > 0) ? (lh/lf)*100 : 100
      ranges = ""
      rs = uncov[0]; re = uncov[0]
      for (i = 1; i < ucount; i++) {
        if (uncov[i] == re + 1) { re = uncov[i] }
        else {
          if (ranges != "") ranges = ranges ", "
          ranges = ranges (rs == re ? rs : rs "-" re)
          rs = uncov[i]; re = uncov[i]
        }
      }
      if (ranges != "") ranges = ranges ", "
      ranges = ranges (rs == re ? rs : rs "-" re)
      printf "| `%s` | %.1f%% | %s |\n", file, pct, ranges
    }

    /^SF:/ {
      if (file != "" && ucount > 0) print_row()
      file = $0; sub(/^SF:/, "", file)
      lf = 0; lh = 0; ucount = 0; delete uncov
    }
    /^DA:/ {
      split($0, a, ","); sub(/^DA:/, "", a[1])
      if (a[2]+0 == 0) { uncov[ucount] = a[1]+0; ucount++ }
    }
    /^LF:/ { lf = $0; sub(/^LF:/, "", lf); lf = lf+0 }
    /^LH:/ { lh = $0; sub(/^LH:/, "", lh); lh = lh+0 }

    END { if (file != "" && ucount > 0) print_row() }
  ' "$LCOV_FILE"
} > "$MD_OUT"

echo "Markdown written to $MD_OUT"
echo ""

# ── Pass/Fail ────────────────────────────────────────────────────────
if (( $(echo "$LINE_COV < $MIN_COVERAGE" | bc -l) )); then
  echo "❌ FAIL: Coverage ${LINE_COV}% is below minimum ${MIN_COVERAGE}%"
  exit 1
fi

echo "✅ PASS: Coverage ${LINE_COV}% meets minimum ${MIN_COVERAGE}%"
exit 0