#!/usr/bin/env bash
# Usage: t.sh [stdin]
#   (no arg)  run each test as a file argument   (file mode)
#   stdin     feed each test on stdin            (REPL mode)
# REPL-mode bugs (e.g. top-level :return, RETURN leaking from a called
# function) don't show in file mode, so the suite can be run both ways.
# In REPL mode q writes the "q)" prompt and the input echo on stdout;
# those lines are filtered out before stdout is compared to r$t.

mode=$1
ec=0
for t in `cat tests`; do
  echo -n "t$t: "
  if [ "$mode" = stdin ]; then
    ../q < t$t.q 2>e$t | sed '/^q)/d' > $t
    rc=${PIPESTATUS[0]}
  else
    ../q t$t.q -q -c 2000 2000 < /dev/null > $t 2>e$t
    rc=$?
  fi
  ./ndiff r$t $t &> d$t
  if [ $rc -ne 0 -o $? -ne 0 ]; then
    ec=$((ec+1))
    echo -e "fail *****"
    ../k t$t.q -q -c 2000 2000 < /dev/null > r$t
    exit 1
  else
    echo -e "pass"
    rm -f $t d$t e$t
  fi
done
echo failed: $ec
exit $ec
