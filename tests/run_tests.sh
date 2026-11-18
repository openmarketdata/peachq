#!/usr/bin/env bash
# Regression runner for the `$` conversion suite.
#
#   ./tests/run_tests.sh           compatibility golden diff + perf baseline check
#   ./tests/run_tests.sh --record  regenerate tests/comp.golden and tests/perf.baseline
#                                  (do this after an INTENTIONAL semantics change, or on
#                                  a new machine so the perf floor is calibrated)
#
# Exit 0 on pass, 1 on any failure, 2 if the q binary is missing.
set -u
cd "$(dirname "$0")/.."
Q=./q
fail=0

if [ ! -x "$Q" ]; then echo "run_tests: build q first (make -j8)" >&2; exit 2; fi

if [ "${1:-}" = "--record" ]; then
  "$Q" tests/comp.q </dev/null > tests/comp.golden 2>&1
  "$Q" tests/perf.q </dev/null 2>&1 | tee tests/perf.baseline
  echo "recorded tests/comp.golden + tests/perf.baseline"
  exit 0
fi

# --- compatibility: deterministic dump vs checked-in golden ---
if [ ! -f tests/comp.golden ]; then
  echo "run_tests: tests/comp.golden missing — run ./tests/run_tests.sh --record" >&2
  fail=1
else
  "$Q" tests/comp.q </dev/null > tests/.comp.out 2>&1
  if diff -u tests/comp.golden tests/.comp.out > tests/.comp.diff; then
    echo "compatibility: PASS"
  else
    echo "compatibility: FAIL (first diff lines:)"
    head -40 tests/.comp.diff
    fail=1
  fi
  rm -f tests/.comp.out tests/.comp.diff
fi

# --- performance: per-case ms vs baseline x 3 ---
"$Q" tests/perf.q </dev/null > tests/.perf.out 2>&1
cat tests/.perf.out
if [ -f tests/perf.baseline ]; then
  awk 'NR==FNR { if ($2 ~ /^[0-9]+$/) base[$1]=$2; next }
       $2 ~ /^[0-9]+$/ && ($1 in base) {
         lim = base[$1]*3
         st = ($2 <= lim) ? "ok" : "FAIL"
         printf "%-15s %8d ms  baseline %d limit %d  %s\n", $1, $2, base[$1], lim, st
         if (st == "FAIL") bad = 1
       }
       END { exit bad }' tests/perf.baseline tests/.perf.out || fail=1
else
  echo "note: no tests/perf.baseline (./tests/run_tests.sh --record to create)"
fi

# --- reference: current run vs the original pre-optimization numbers ---
# tests/perf.baseline.orig is a frozen snapshot kept for comparison; it is
# never rewritten by --record and never gates the run.
if [ -f tests/perf.baseline.orig ]; then
  echo "vs original:"
  awk 'NR==FNR { if ($2 ~ /^[0-9]+$/) orig[$1]=$2; next }
       $2 ~ /^[0-9]+$/ && ($1 in orig) {
         r = 0; if ($2 > 0) r = orig[$1] / $2
         printf "%-15s %8d -> %6d ms  (%.1fx)\n", $1, orig[$1], $2, r
       }' tests/perf.baseline.orig tests/.perf.out
fi
rm -f tests/.perf.out

exit $fail
