#!/usr/bin/env bash
# Regression runner for the changelog-derived suite (tests/sample.txt).
#
#   ./tests/run_tests4.sh           comp4 golden diff + perf4 baseline check
#   ./tests/run_tests4.sh --record  regenerate tests/comp4.golden and
#                                   tests/perf4.baseline
#
# comp4.q/perf4.q run inside tests/.c4run so the changelog's file-writing
# cases keep their artifacts in scratch space (removed after the run).
#
# Exit 0 on pass, 1 on any failure, 2 if the q binary is missing.
set -u
cd "$(dirname "$0")/.."
Q="$(pwd)/q"
SCRATCH=tests/.c4run
fail=0

if [ ! -x "$Q" ]; then echo "run_tests4: build q first (make -j8)" >&2; exit 2; fi

if [ "${1:-}" = "--record" ]; then
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
  (cd "$SCRATCH" && "$Q" ../comp4.q </dev/null) > tests/comp4.golden 2>&1
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
  (cd "$SCRATCH" && "$Q" ../perf4.q </dev/null) | tee tests/perf4.baseline
  rm -rf "$SCRATCH"
  echo "recorded tests/comp4.golden + tests/perf4.baseline"
  exit 0
fi

# --- compatibility: deterministic replay vs checked-in golden ---
if [ ! -f tests/comp4.golden ]; then
  echo "run_tests4: tests/comp4.golden missing — run ./tests/run_tests4.sh --record" >&2
  fail=1
else
  rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
  (cd "$SCRATCH" && "$Q" ../comp4.q </dev/null) > tests/.comp4.out 2>&1
  if diff -u tests/comp4.golden tests/.comp4.out > tests/.comp4.diff; then
    echo "compatibility: PASS"
  else
    echo "compatibility: FAIL (first diff lines:)"
    head -40 tests/.comp4.diff
    fail=1
  fi
  rm -f tests/.comp4.out tests/.comp4.diff
fi

# --- performance: per-case ms vs baseline x 3 (silent unless a case fails) ---
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
(cd "$SCRATCH" && "$Q" ../perf4.q </dev/null) > tests/.perf4.out 2>&1
if [ -f tests/perf4.baseline ]; then
  nfail=$(awk 'NR==FNR { if ($2 ~ /^[0-9]+$/) base[$1]=$2; next }
       $2 ~ /^[0-9]+$/ && ($1 in base) {
         lim = base[$1]*3; n++
         if ($2 > lim) {
           printf "%-15s %8d ms  baseline %d limit %d  FAIL\n", $1, $2, base[$1], lim > "/dev/stderr"
           bad++
         }
       }
       END { printf "%d %d\n", n, bad+0 }' tests/perf4.baseline tests/.perf4.out)
  set -- $nfail
  if [ "${2:-0}" -gt 0 ]; then fail=1; else echo "performance: PASS (${1:-0} cases)"; fi
else
  echo "note: no tests/perf4.baseline (./tests/run_tests4.sh --record to create)"
fi

# --- reference table: current run vs frozen baselines (ms per case) ----
# tests/perf4.baseline.orig : upstream peachq.org numbers (never rewritten)
# tests/perf4.baseline.k/.l : kdb / l-labs numbers if ever captured.
# Reference only — none of these gate the run.
o=tests/perf4.baseline.orig; [ -f "$o" ] || o=/dev/null
k=tests/perf4.baseline.k;    [ -f "$k" ] || k=/dev/null
l=tests/perf4.baseline.l;    [ -f "$l" ] || l=/dev/null
if [ "$o$k$l" != "/dev/null/dev/null/dev/null" ]; then
  printf '%-15s %8s %16s %16s %16s\n' "case" "ours" "orig" "kx" "l5"
  awk -v OF="$o" -v KF="$k" -v LF="$l" '
       FILENAME==OF { if ($2 ~ /^[0-9]+$/) a[$1]=$2; next }
       FILENAME==KF { if ($2 ~ /^[0-9]+$/) b[$1]=$2; next }
       FILENAME==LF { if ($2 ~ /^[0-9]+$/) c[$1]=$2; next }
       $2 ~ /^[0-9]+$/ {
         line = sprintf("%-15s %8d", $1, $2)
         if ($1 in a) {
           if ($2 == 0) line = line sprintf(" %8d (n/a)", a[$1])
           else line = line sprintf(" %8d (%4.1fx)", a[$1], a[$1]/$2)
         }
         else line = line sprintf(" %16s", "-")
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
       }' "$o" "$k" "$l" tests/.perf4.out
fi
rm -f tests/.perf4.out
rm -rf "$SCRATCH"

exit $fail
