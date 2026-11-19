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

# --- performance: per-case ms vs baseline x 3 (silent unless a case fails) ---
"$Q" tests/perf.q </dev/null > tests/.perf.out 2>&1
if [ -f tests/perf.baseline ]; then
  nfail=$(awk 'NR==FNR { if ($2 ~ /^[0-9]+$/) base[$1]=$2; next }
       $2 ~ /^[0-9]+$/ && ($1 in base) {
         lim = base[$1]*3; n++
         if ($2 > lim) {
           printf "%-15s %8d ms  baseline %d limit %d  FAIL\n", $1, $2, base[$1], lim > "/dev/stderr"
           bad++
         }
       }
       END { printf "%d %d\n", n, bad+0 }' tests/perf.baseline tests/.perf.out)
  set -- $nfail
  if [ "${2:-0}" -gt 0 ]; then fail=1; else echo "performance: PASS (${1:-0} cases)"; fi
else
  echo "note: no tests/perf.baseline (./tests/run_tests.sh --record to create)"
fi

# --- reference table: current run vs frozen baselines (ms per case) ----
# tests/perf.baseline.orig : upstream peachq.org numbers (never rewritten)
# tests/perf.baseline.k    : kdb,     refreshed manually (../mbo/bin/l64/q tests/perf.q)
# tests/perf.baseline.l    : l-labs,  refreshed manually (../l/l5 tests/perf.q)
# Reference only — none of these gate the run.
o=tests/perf.baseline.orig; [ -f "$o" ] || o=/dev/null
k=tests/perf.baseline.k;    [ -f "$k" ] || k=/dev/null
l=tests/perf.baseline.l;    [ -f "$l" ] || l=/dev/null
if [ "$o$k$l" != "/dev/null/dev/null/dev/null" ]; then
  printf '%-15s %8s %16s %16s %16s\n' "case" "ours" "orig" "kx" "l5"
  awk 'FNR==1 { f++ }
       f==1 { if ($2 ~ /^[0-9]+$/) a[$1]=$2; next }
       f==2 { if ($2 ~ /^[0-9]+$/) b[$1]=$2; next }
       f==3 { if ($2 ~ /^[0-9]+$/) c[$1]=$2; next }
       $2 ~ /^[0-9]+$/ {
         line = sprintf("%-15s %8d", $1, $2)
         if ($1 in a)
           line = line sprintf(" %8d (%4.1fx)", a[$1], ($2 > 0 ? a[$1]/$2 : 0))
         if ($1 in b) {
           if (b[$1] == 0) line = line sprintf(" %8d (<1ms)", b[$1])
           else { r = $2/b[$1]; line = line sprintf(" %8d (%.1fx %s)",
                          b[$1], (r <= 1 ? 1/r : r), (r <= 1 ? "faster" : "slower")) }
         } else line = line sprintf(" %16s", "-")
         if ($1 in c) {
           if (c[$1] == 0) line = line sprintf(" %8d (<1ms)", c[$1])
           else { r = $2/c[$1]; line = line sprintf(" %8d (%.1fx %s)",
                          c[$1], (r <= 1 ? 1/r : r), (r <= 1 ? "faster" : "slower")) }
         } else line = line sprintf(" %16s", "-")
         print line
       }' "$o" "$k" "$l" tests/.perf.out
fi
rm -f tests/.perf.out

exit $fail
