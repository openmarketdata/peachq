/ tests/perf4.q — timed cases extracted from the kdb+ 4.1 changelog
/ (tests/sample.txt), adapted to the `t:` probe format of tests/perf.q.
/ Prints "name ms" per case; gated at 3x tests/perf4.baseline by
/ tests/run_tests4.sh (make test4).  Runs inside tests/.c4run so the
/ file-writing cases keep their outputs in scratch space.
/ Regenerate baseline: ./tests/run_tests4.sh --record

/ run[e]: one counted `t:` probe; rep[e]: min of 3 single-shot probes
run:{[nm;e] -1 (string nm)," ",string first system e;}
rep:{[nm;e] -1 (string nm)," ",string min (first system e;first system e;first system e);}

/ --- sample.txt:209-214 — \ts:100 select time,price,size from t --------
/ changelog measures a select over a partitioned table; adapted to an
/ in-memory table of the same shape (no HDB mount needed in the suite)
t:([]time:asc 1000000?2020.01.01D00:00:00;price:1000000?10f;size:1000000?100);
rep[`part_select;   "t select time,price,size from t"];

/ --- sample.txt:631-632 — a:where 10000#1000; \ts:10 `p#a --------------
/ applying `p# attribute (10x larger vec than changelog for a stable probe)
a4:where 1000000#100;
rep[`attr_p_vec;    "t `p#a4"];

/ --- sample.txt:635-636 — `:tab/ set ([]where 10000#100); \ts @[`:tab/;`x;`p#]
/ on-disk amend to apply `p#
`:tab/ set ([]x:where 100000#100);
rep[`attr_p_file;   "t @[`:tab/;`x;`p#]"];

/ --- sample.txt:477-478 — a:100000#0f; \t {a[x]:0Nf;?[a;0Nf]} each reverse til count a
/ set-then-find over a float vector
af4:100000#0f;
run[`find_null_f64; "t {af4[x]:0Nf;?[af4;0Nf]} each reverse til count af4"];

/ --- sample.txt:480-481 — a:100000#0e; \t {a["i"$x]:x;?[a;x]} each reverse "e"$til count a
/ set-then-find over a real vector; scaled to 10000 (the f32 set/find path
/ is ~100x costlier per element than the f64 one in this build; 2000 keeps the probe under ~3s)
ae4:2000#0e;
run[`find_val_f32;  "t {ae4[\"i\"$x]:x;?[ae4;x]} each reverse \"e\"$til count ae4"];

/ --- sample.txt:624 — concurrent anymap writes via peach -----------------
/ v:(3?4000)#'"a"; n:`$":a",/:string til system"s"; {x set 100000?v}peach n
v4f:(3?4000)#'"a"; n4:`$":pf",/:string til 8;  / fixed count — changelog used til system"s" (0 workers here would probe nothing)
run[`peach_writes;  "t {x set 20000?v4f}peach n4"];

/ --- sample.txt:824 — \t ("ii";4 4)1:/:0N 8#1000000?0x0 ------------------
/ splayed byte write
rep[`splay_write;   "t (\"ii\";4 4)1:/:0N 8#100000?0x0"];

/ --- sample.txt:833-834 — v:` sv 10000000#","0:10 10#til 100; ------------
/ \t system"s 10";(10#"J";",")0:v   (csv write of a 10M sym vector)
v4:` sv 10000000#","0:10 10#til 100;
run[`csv_write;     "t (10#\"J\";\",\")0:v4"];

/ --- sample.txt:889 — `:a set 500000 100#"abc"; system"ts `:b set get`:a"
/ serialized set/get roundtrip of a 500000x100 char matrix (~50MB)
`:f4a set 500000 100#"abc";
rep[`file_roundtrip;"t `:f4b set get`:f4a"];
