#!/usr/bin/env bash
# Usage: v.sh [stdin]
#   (no arg)  run each test as a file argument   (file mode)
#   stdin     feed each test on stdin            (REPL mode)

mode=$1

os=`uname -s`
if [ "$os" = "Darwin" ]; then echo "valgrind tests are linux only"; exit 0; fi
which valgrind &>/dev/null
if [ $? -ne 0 ]; then echo "valgrind not found" && exit 1; fi
file ../q | grep -q debug_info
if [ $? -ne 0 ]; then echo "valgrind tests only work with a debug build of ../q"; exit 1; fi
ec=0
vo="--leak-check=full --show-leak-kinds=all --error-exitcode=1 --errors-for-leak-kinds=all"
for t in `cat tests`; do
  echo -n "t$t: "
  if [ "$mode" = stdin ]; then
    valgrind $vo ../q < t$t.q >/dev/null 2> v$t
  else
    valgrind $vo ../q t$t.q </dev/null >/dev/null 2> v$t
  fi
  grep -q "ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)" v$t
  if [ $? -ne 0 ]; then
    ec=$((ec+1))
    echo -e "fail *****"
  else
    echo -e "pass"
    rm -f $t v$t
  fi
done
echo failed: $ec
exit $ec
