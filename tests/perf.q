/ tests/perf.q — performance probes for the `$` conversion paths.
/ Prints "name ms" per case.  tests/run_tests.sh fails the run when a case
/ is >3x its entry in tests/perf.baseline; regenerate the baseline with
/ ./tests/run_tests.sh --record (also rewrite it after intended fast/slow
/ changes so the floor tracks the machine).

ts:2019.11.19D12:00:00+0D00:00:01*til 10000000;   / 10M timestamps
dt:`datetime$ts;                                / 10M datetimes
f:10000000?100.0;                               / 10M floats
L:raze {(1;2.5;3h)}each til 300000;             / 900K mixed boxed atoms
bv:1000000?0xff;                                / 1M bytes
LB:raze 100000#enlist(65;0x42;67h);             / 300K boxed char atoms

/ run[e]: one counted `t:` probe; rep[e]: min of 3 single-shot probes
run:{[nm;e] -1 (string nm)," ",string first system e;}
rep:{[nm;e] -1 (string nm)," ",string min (first system e;first system e;first system e);}

rep[`minute_vec;    "t `minute$ts"];            / per-element temporal arm
rep[`second_vec;    "t `second$ts"];
rep[`month_vec;     "t `month$dt"];
rep[`date_vec;      "t `date$ts"];              / fast range-worker leaf
rep[`int_float;     "t `int$f"];                / float->int vec loop
rep[`long_boxed;    "t `long$L"];               / boxed-list distribution
run[`char_atom;     "t:1000000 `char$0x0a0b0c"];  / per-call designator+charv
run[`sym_char_atom; "t:1000000 `$`char$0x0a0b0c"];
run[`char_bytevec;  "t:100 `char$bv"];          / bulk byte->char copy
run[`char_boxed;    "t:10 \"c\"$LB"];           / boxed-atom char pack

/ --- name/dict lookups: every path below is a linear scan today ---
/ (env.c env_lookup_flat, dict.c ray_dict_find_sym, q_search_find_item,
/  find_rows_probe col-0 row_scan).  Probes target the LAST key so the
/ scan is worst-case; sizes chosen so each run lands in measurable ms.
gv:42;                                            / global binding for env reads
K:`$string each til 256;                          / 256 sym keys
sd:K!til 256;                                     / sym-key dict
pk:K[255];                                        / probe: last key (worst scan)
id:(til 256)!til 256;                             / i64-key dict
TK:{(x;`$string x)}each til 256;                  / 256 tuple keys (LIST keys)
td:TK!til 256;                                    / tuple-key dict
pk3:TK[255];                                      / tuple probe -> q_match_exact x255
kt:([a:til 256;b:K]v:til 256);                    / keyed table, 2-col key
pk4:(255;K[255]);                                 / row probe -> row_scan

run[`env_lookup;    "t:1000000 gv"];              / global name resolution
run[`dict_sym;      "t:100000 sd[pk]"];           / sym-key dict probe
run[`dict_i64;      "t:100000 id[255]"];          / i64-key dict probe
run[`dict_tuple;    "t:100000 td[pk3]"];          / boxed-tuple key probe
run[`kt_row;        "t:100000 kt[pk4]"];          / keyed-table row probe
run[`dict_findvec;  "t:1000 sd[K]"];              / vector probe: O(keys^2) today
run[`find_tuple;    "t:10000 TK?pk3"];            / list?tuple find, deep compares
