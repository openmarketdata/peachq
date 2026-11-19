/ tests/comp4.q — kdb+ 4.1 changelog (tests/sample.txt) compatibility replay.
/ Every `q)` line is evaluated in order via chk (errors captured, big
/ results summarized), and the (expr;result) pairs are golden-diffed
/ against tests/comp4.golden by tests/run_tests4.sh (make test4).
/ File-writing cases run inside tests/.c4run.  Regenerate golden after
/ an INTENTIONAL semantics change with: ./tests/run_tests4.sh --record

chk:{[s] r:@[value;s;{(`err;x)}];
  n:@[{count x};r;{0}];
  0N!(s;$[n>100;("len";n;"type";type r);r])};
chkS:{[s] r:@[{system x};s;{(`err;x)}]; 0N!(s;r)};

chk "\"U\"$\"71582789:00\"               / was 00:44 , now 0Nu";  / sample.txt:6
chk "\"V\"$\"596524:00:00\"              / was -**:28:16 , now 0Nv";  / sample.txt:7
chk "\"T\"$\"1111111111:00:00.000\"      / was -**:36:52.608 , now 0Nt";  / sample.txt:8
chk "\"P\"$\"2020.12.01D11111111111111\" / was 2064.10.26D06:34:55.000000000 , now 0Np";  / sample.txt:9
chk "\"N\"$\"106751D23:47:16.9\"         / was -106751D23:47:16.809551616 , now 0Nn";  / sample.txt:10
chk "k:([k:1 2]v:3 4); do[10;@[{k+x};`a`b!1 2;::]]; -16!k";  / sample.txt:19
chk "-1152921504606846977?0Ng   / ended the process";  / sample.txt:21
chk "k:([k:1 2]v:3 4); w:1 2 3; do[10;@[{x upsert y}k;w;::]]; -16!w   / refcount grows by 10";  / sample.txt:23
chk "string raze (1;flip `a`b!`tab;2)   / was a crash, now 'splay";  / sample.txt:25
chk "0W 1#til 3";  / sample.txt:27
chk "0W 0#til 3     / segfault; now 'limit";  / sample.txt:29
chk "1 0W 0#til 3   / segfault; now 'limit";  / sample.txt:30
chk "-9!@[-18!2000#0x11;8 9 10 11;:;0xa0860100] / 'badmsg";  / sample.txt:32
chk "t:([]time:`s#`time$2147460000 2147460000;v:1 2);";  / sample.txt:34
chk "(select sum v by time.minute from t)~select sum v by minute:`minute$time from t   / was 0b, now 1b";  / sample.txt:35
chk "get[`:v set (\"abc\";\"def\")]like enlist\"*\"";  / sample.txt:52
chk "\"\\n\"$(\"123\";\"456\")";  / sample.txt:55
chk "`:HDB/2026.02.10/test/ set([]time:0 2 4);system\"l HDB\";?[test;();0b;`time`bucket!(`time;(`s#1 3!`closed`open;`time))]";  / sample.txt:58
chk "(a;b):get`:foo set (1;0x0000)";  / sample.txt:66
chk "(`:T/2000.01.01/t/;`:T/2000.01.02/t/) set\\: ([]1000000#1b)";  / sample.txt:71 / adapted: (side []1000000#1b), scaled from 1073741824# (2^31 overflow case)
chkS "l T/";  / sample.txt:72
chk "select avg x from t";  / sample.txt:73
chk "0x01*/0x01020304";  / sample.txt:76
chk "1h*/1 2 3 4h";  / sample.txt:77
chk "0&/`s#1 2 3";  / sample.txt:79
chk "{ if[a;1 2]:3 4 }";  / sample.txt:109
chk "do:1";  / sample.txt:111
chk "10h$.Q.atob \"aGVsbG8=\"";  / sample.txt:122
chk ".h.hn[\"200 OK\";`jpg;read1`$\":test.jpg\"]";  / sample.txt:127
chk "{`a`b : x}`c`d";  / sample.txt:137
chk "{v:(([]a:1 2);enlist(in;`a;(?;(`v;0);(`v;1);0b;(`v;2)));enlist[`a]!enlist `a);?[v 0;v 1;0b;v 2]}peach(::;::)";  / sample.txt:140
chk "{v:(([]a:1 2);enlist(in;`a;(?;(`v;0);(`v;1);0b;(`v;2)));enlist[`a]!enlist `a);?[v 0;v 1;0b;v 2]}peach(::;::)";  / sample.txt:143
chk "`:ragged/.d set`x`a;";  / sample.txt:146
chk "`:ragged/x set 1 2;";  / sample.txt:147
chk "`:ragged/a set 1993#(1 2;3 4);";  / sample.txt:148
chk "select from `:ragged/;.Q.w[]`mmap";  / sample.txt:149
chk "@[flip[`a`b!`:foobar]_;0;::]";  / sample.txt:168
chk "{count .Q.w[]}peach til system\"s\"";  / sample.txt:172 / adapted: count each .Q.w[] via peach (raw .Q.w[] values are memory-dependent)
chk "lines:(\"aaa \";\"bbb\");.Q.ld lines;lines";  / sample.txt:174
chk "select i from t where i=0,{x=0}[i]";  / sample.txt:181
chk ".Q.enxs[$;::;t;`sym]";  / sample.txt:187
chk ".Q.en[::;t] / user should ensure on-disk file kept in sync with in-memory enum domain";  / sample.txt:188
chkS "p 5000";  / sample.txt:194
chk ".z.ac:{[x]hclose .z.w;(2;\"HTTP/1.1 401 Unauthorized\\r\\nConnection: close\\r\\n\\r\\n\")}";  / sample.txt:195
chk "`:http://localhost:5000 \"GET / HTTP/1.1\\r\\n\\r\\n\"";  / sample.txt:197
chk "a:`g#1#(::);a,:100#`s";  / sample.txt:202
chk "a:`g#1 1#(::);a,:100#([]`a`b`c)";  / sample.txt:203
chk "`:a0 set a:\"G\"$(\"8462c71d-bb02-9094-7f17-dcff70120905\";\"746906b1-50b1-4dfe-f665-700193516426\")";  / sample.txt:205
chk ".[`:a0;();`p#]; `:a1 set `p#a; (read1`:a0)~read1`:a1";  / sample.txt:206
chk "1=count select from ([]get`:a0) where x=first a";  / sample.txt:207
/ sample.txt:209: (perf4) `:./db/2001.01.01/t/ set 10000000#([]time:10?.z.P;price:10?10f;size:10?100)
chkS "l ./db";  / sample.txt:210
/ sample.txt:211: (perf4) \ts:100 select time,price,size from t
chk ".Q.MAP[]";  / sample.txt:213
/ sample.txt:214: (perf4) \ts:100 select time,price,size from t
chk "set\\:[;([]a:1 2)]sv'[`],'[;`].Q.par[`:hdb;;`t]@'`long$1e11*1+til 3";  / sample.txt:220
chkS "l hdb";  / sample.txt:221
chk "select from t";  / sample.txt:222
chk "select int,a from t";  / sample.txt:231
chk ".Q.id[`b`b1``in!2 3 4 5]~([b:2;b1:3;a:4;in1:5])";  / sample.txt:251
chk "`:./db/2001.01.01/t/ set tt:.Q.en[`:./db]([]sym:10?`A`B`C;time:10?.z.T;price:10?10f)";  / sample.txt:255
chkS "l ./db";  / sample.txt:256
chk "`:2001.01.02/t/`:2001.01.03/t/ set\\:tt";  / sample.txt:257
chk "date";  / sample.txt:258
chk ".Q.li[2001.01.02];date";  / sample.txt:260
chk ".Q.li[2001.01.02 2001.01.03];select count i by date from t";  / sample.txt:262
chk "select date,sym from trade";  / sample.txt:270
chk "select by sym,date from trade";  / sample.txt:272
chk "select from trade where sym=`AAA,date=.z.D";  / sample.txt:274
chk "\"type\"~@[value;\"select from([]1 2)where x within 1\";::]";  / sample.txt:278
chk "delete a, from t";  / sample.txt:285
chk "delete .. a from t";  / sample.txt:286
chk "a:get`:a 1:((1 2;3 4);(5 6;7 8));  (0#0;0#0)~a 0N / was: ()~a 0N";  / sample.txt:296
chk "update c:8,d:9 from ([]a) where i=1               / was 'length";  / sample.txt:297
chk "all 5=count each string last (\"I *S\";2 3 2 5) 0: ` sv 10000#enlist\"12~~~hiMYSYM\"   / q -s 2";  / sample.txt:299
chk "update a by b from([a:1;b:2]) / 'type";  / sample.txt:304
chk "read0 each 0 0";  / sample.txt:315
chk "{[1;2]}";  / sample.txt:320
chk "{d:([1;2;3]);(a:d):x} / 'type";  / sample.txt:322
chk "((,:)a):enlist 1; a~1";  / sample.txt:324
chk ".z.ac:{(0;\"\")}";  / sample.txt:326
chk ".Q.trpd[{x+y};(1;2);{(`err;x)}]";  / sample.txt:337 / adapted: .Q.sbt backtrace embeds source paths — stable handler
chk ".Q.trpd[{x+y};(1;`2);{(`err;x)}]";  / sample.txt:339 / adapted: .Q.sbt backtrace embeds source paths — stable handler
chk "h({neg[.z.w]\"hclose .z.w\"};::)";  / sample.txt:351
chk "{[a:`i;b:`j]$1}";  / sample.txt:353
chk "{[a:`i;$1]   1}";  / sample.txt:354
chk "((:1+):{x}):1";  / sample.txt:356
chk "():1       / 'match";  / sample.txt:358
chk "exit:1     / 'assign";  / sample.txt:360
chk "f:{[x+y]x} / 'nyi";  / sample.txt:362
chk "select %[;2]sum a from t";  / sample.txt:364
/ sample.txt:368: skipped — nondeterministic (.z.W memory stats): 0N!.z.W
chk "h:hopen`:tcps://localhost:5001";  / sample.txt:385
chk "h\".z.e`CERT\"";  / sample.txt:386
chk "\"type\"~@[{(a:`a`B):x};1;::]";  / sample.txt:396
chk "d:([k1:v1;k2:v2;..]);    k1:1;d:([k1;k2:2]);   d:([1;2]);d~([x:1;x1:2])";  / sample.txt:403
chk "([k1:;k2:])[1;\"a\"] / ~ ([k1:1;k2:\"a\"]); compare: (;)[1;\"a\"] ~ (1;\"a\")";  / sample.txt:405
chk "f:{[p:`f;s:`j]p*s};         msg:{(sym:`s;ex:`c;price:`f):x}";  / sample.txt:415
chk "addprice:{[(s;e;p):msg;x:`f](s;e;p+x)};";  / sample.txt:416
chk "addprice[(`A;\"b\";10.5);2.5] / w/o checks can do: addprice:{(;;:y+):x}";  / sample.txt:417
chk "a:get`:a set `sym?5120#`a; b:get`:a;c:get`:a;b:(); `p#c";  / sample.txt:434
chk "a:0;{a:1;exec value\"2*a\"from([]``)}[]";  / sample.txt:439
chk "{select from t where {1b}[x]}peach 1 2";  / sample.txt:444
chk "var(1;2i)";  / sample.txt:453
chk "var(1 2;3 4i)";  / sample.txt:454
chk "n:10000;{(\"js\";1#\",\")0:x}peach 2#`:test.csv 0:\",\"0:([]a:n#1;b:n?`2)";  / sample.txt:463
/ sample.txt:477: (perf4) a:100000#0f
/ sample.txt:478: (perf4) \t {a[x]:0Nf;?[a;0Nf]} each reverse til count a
/ sample.txt:480: (perf4) a:100000#0e;
/ sample.txt:481: (perf4) \t {a["i"$x]:x;?[a;x]} each reverse "e"$til count a
chk "get `:lsym set a:`$2097153#\"a\"";  / sample.txt:486
chk "([k:1 2 3]s:110b;t:1 2 3)^([k:1 2 3]t:3 4 5)";  / sample.txt:488
chk "([k:1 2 3]s:110b;t:1 2 3)^reverse ([k:1 2 3]t:3 4 5)";  / sample.txt:494
chk "0N!\" \"vs\"x\"$\"a b\";";  / sample.txt:501
chk "0N!0x20 vs\"x\"$\"a b\";";  / sample.txt:503
chk "(::)peach([]1 2;3 4)";  / sample.txt:513
chk "csv 0:([](\"foo\\nbar\";\"baz\"))";  / sample.txt:558
chk "`t1 lj t2";  / sample.txt:566
chk "`t1 ljf t2";  / sample.txt:567
chk "`t1 pj t2";  / sample.txt:568
chk "aj[`sym`time;`t1;t2]";  / sample.txt:569
chk "ajf[`sym`time;`t1;t2]";  / sample.txt:570
chk "aj0[`sym`time;`t1;t2]";  / sample.txt:571
chk "ajf0[`sym`time;`t1;t2]";  / sample.txt:572
chk "wj[w;`sym`time;`t1;(t2;(max;`bid);(min;`ask))]";  / sample.txt:573
chk "wj1[w;`sym`time;`t1;(t2;(max;`bid);(min;`ask))]";  / sample.txt:574
chk "select link.x by sym from trade";  / sample.txt:577
chk "(`:a;12;1;0) set 1 2; p:-21!`:a;.[`:a;();`p#];(2_p)~2_-21!`:a";  / sample.txt:582
chk "(`:file;17;2;9)1:100#0x0";  / sample.txt:593
chk "all{x~get`:parse.bin set x}each(1+;'[sum;avg])";  / sample.txt:602
/ sample.txt:607: skipped — prints cwd: \cd
chk "key`:db/2023.02.01";  / sample.txt:609
chk ".Q.lo[`db;0;0]";  / sample.txt:611
chk "trade";  / sample.txt:612
/ sample.txt:620: skipped — prints cwd: \cd
chk "v:(3?4000)#'\"a\";n:`$\":a\",/:string til system\"s\";{x set 100000?v}peach n;all{all (distinct get x)in v} peach n";  / sample.txt:624
/ sample.txt:631: (perf4) a:where 10000#1000
/ sample.txt:632: (perf4) \ts:10 `p#a
/ sample.txt:635: (perf4) `:tab/ set ([]where 10000#100);
/ sample.txt:636: (perf4) \ts @[`:tab/;`x;`p#]
chk "select sum x by y from ([](1 2;3 4);y:-1 1h)";  / sample.txt:641
chk ".Q.id`$\"_\"";  / sample.txt:648
chk "cols .Q.id(`$(\"3aa\";\"_aa\";\"_aa\"))xcol([]1 2;3 4;5 6)";  / sample.txt:650
chkS "p 80/85";  / sample.txt:654
chkS "p";  / sample.txt:655
chkS "p myhost:2000/2010";  / sample.txt:660
chkS "p -2000/2010";  / sample.txt:662
chk ".Q.ld read0`:funcs.q";  / sample.txt:665
chk ".Q.gc 0 / least aggressive";  / sample.txt:687
chk ".Q.gc[] / most aggressive (continue to use this in the general case; currently matches level 2)";  / sample.txt:688
chk ".z.zd:17 5 1;x~get `:ziptest set x:asc 10000000?1000";  / sample.txt:692
.z.zd:();;
chk "`:oldenum set `:sym?`a`b`c / in v3.5 or earlier";  / sample.txt:699
chk "1 0 3 1~([]1 2 3;get`:oldenum)?([]2 1 0 2;`:sym?`b`a`c`b)";  / sample.txt:700
chk "M:get`:m77 set m:(2 3;4 0N;1 7)";  / sample.txt:706
chk "T:get`:tab/ set t:flip`a`b!flip m";  / sample.txt:707
chk "var each(m;M;t;T)";  / sample.txt:708
chk "dev each(m;M;t;T)";  / sample.txt:713
chk "svar each(m;M;t;T)";  / sample.txt:718
chk "sdev each(m;M;t;T)";  / sample.txt:723
chk "parse \"a:3\",1000000#\"0\"";  / sample.txt:730 / adapted: 0wi# (2GB string) scaled to 1e6
chk ".Q.dd[`:./db1;`2022.01.01`ecfmapping`] set .Q.en[`:./db1] ([]firmName:enlist \"DUMMY\")";  / sample.txt:735
chkS "l ./db1";  / sample.txt:736
chk "select ecfmap.firmName from ([id:1 2];ecfmap:`ecfmapping!1 1)";  / sample.txt:737
chk ".Q.id`$\"+\"";  / sample.txt:744
chk "cols .Q.id(`$(\"count+\";\"count*\";\"count1\"))xcol([]1 2;3 4;5 6)";  / sample.txt:749
chk "cols .Q.id(`$(\"aa\";\"=\";\"+\"))xcol([]1 2;3 4;5 6)";  / sample.txt:751
chk ".[`:./db/t/;(0 1;`v)]";  / sample.txt:760
chk ".z.zd:17 2 6;`:file set();system\"x .z.zd\";`:file upsert 1000#0;-21!`:file";  / sample.txt:772
.z.zd:();;
chk "(`:empty set())upsert 0 1";  / sample.txt:774
chk "{x}[;1]";  / sample.txt:779
chk "select sum a*(`aaf=`aaf)|(`aaf=`aaf)|(`aaf=`aaf) by b from ([]a:1 2;b:3 4)";  / sample.txt:783
chk "h:hopen`:localhost:5000";  / sample.txt:787
chk "@[h;`:./a 2:`a,1;::] / attempting to send a dynamically loaded function";  / sample.txt:788
chk "h\"1+2\"";  / sample.txt:790
chk "where 0W 0W 1 1";  / sample.txt:804
chk ".z.zd:();`:./aaa set til 10";  / sample.txt:806
chk "-25!(1#0N;\"aaa\")";  / sample.txt:809
chk "hopen[4000]\"reval(hdel;enlist`:somefile)\"";  / sample.txt:812 / adapted: hopen[4000] timeout shortened from [4000]
chk "h:@[{hopen 4000};::;{x}]";  / sample.txt:815 / adapted: h:@[hopen;...] wrapped to keep err symbol deterministic
chk "h\"reval(hopen;enlist`:somefile)\"";  / sample.txt:816
chk "h\"hopen`:../somefile\"";  / sample.txt:818
chk "hopen[4000]\"hopen`:fifo://../somefifo\"";  / sample.txt:821 / adapted: hopen[4000] timeout shortened from [4000]
/ sample.txt:824: (perf4) \t ("ii";4 4)1:/:0N 8#1000000?0x0
chk "r~.Q.gz .Q.gz(6;r:1000000?0x00)";  / sample.txt:826 / adapted: gzip roundtrip scaled from 4294967295?0x00 (4GB)
chk "0Nh~\"H\"$\" \"";  / sample.txt:828
/ sample.txt:833: (perf4) v:` sv 10000000#","0:10 10#til 100
/ sample.txt:834: (perf4) \t system"s 10";(10#"J";",")0:v
chk "0x0203 sv 0x0203 vs \"x\"$til 6";  / sample.txt:844
chk "0x02 vs \"x\"$til 5";  / sample.txt:846
chk "{x~0b sv 0b vs x}rand 0Ng";  / sample.txt:850
chk "0Nh~\"H\"$\"32768\"";  / sample.txt:852
chk "{x~\"c\"$.Q.gz .Q.gz(6;\"x\"$x)}10000#\"helloworld\"";  / sample.txt:856
chk "0 wavg 0 1";  / sample.txt:861
chk "\"0Wh\"~-3!0Wh";  / sample.txt:864
chk "select last x by n:i from ([]([]a:enlist\"AB\")) where i=0";  / sample.txt:866
chk "-120!'.mm.a:1";  / sample.txt:876
chk "`:x set get `:x set (`s;{([]s:1)};`a`b;`g#`c`a`b;`a`b)";  / sample.txt:882
chk "a:(\"hi\";\"there\";\"world\");`:a0 set a;`:a1 set a@where 1000 2000 3000;(hcount`$\":a0#\")=hcount`$\":a1#\"";  / sample.txt:887
/ sample.txt:889: (perf4) `:a set 500000 100#"abc";system"ts `:b set get`:a" / was 76584400 bytes, now 8390208.
chk "`:db/2000.01.01 `t";  / sample.txt:891
chk "update x:0 from get`:mysplay/";  / sample.txt:892
chk ".1 .2 .3 .4 .5 .6~.1 xbar .1 .2 .3 .4 .5 .6";  / sample.txt:897
chk "4.4~1.1 xbar 5";  / sample.txt:898
chk "1b~.z.r / in reval, -b cmd line (read-only), or a thread other than the main event thread.";  / sample.txt:915
chk "t:([]`g#`a`b`c);.Q.dpt[`:db;2000.01.01;`t];`g~attr `:db/2000.01.01/t `x";  / sample.txt:921
chk "H:hopen each 4#4000;{x\"\"}peach H";  / sample.txt:927
chk "string[x]~raze string vs[10;x:\"j\"$2 xexp 55]";  / sample.txt:938
exit 0
