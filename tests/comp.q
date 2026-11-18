/ tests/comp.q — compatibility dump for the `$` cast/tok conversion matrix.
/ Deterministic output, golden-diffed against tests/comp.golden by
/ tests/run_tests.sh (make test).  Regenerate after an INTENTIONAL
/ semantics change with:  ./tests/run_tests.sh --record

/ --- the differential cast matrix: every designator x a spread of ---
/ --- source shapes (atoms, nulls, infinities, vectors, boxed lists) ---
srcs:(42;42i;42h;1b;0x2a;42f;42e;2.5;3.7;-2.5;0N;0n;0Ni;0W;-0W;
      2019.11.19;12:34:56.789;03:45;03:45:12;2019.11m;
      2019.11.19D12:34:56.123456789;0D01:02:03.456789000;
      2019.11.19T12:34:56.789;`abc;"abc";"65";enlist "9";
      1 2 3;1.5 2.5 3.5;1 2 3h;0 1 2i;
      2019.11.19 2019.12.25;12:00 13:30;(1;2.5;3h);
      (2019.11.19;2019.12.25D00:00:00);"abc";("abc";"de");101b;0x010203);
f:{[t;v] @[{x$y}[t];v;{(`err;x)}]};

/ char-letter designators: lowercase = cast, UPPERCASE = Tok (string parse)
tagsL:"bxhijefcspmdznuvt";
tagsU:"BXHIJEFCSPMDZNUVT";
/ kdb type-name designators (sym lhs)
tagsN:`boolean`byte`short`int`long`real`float`char`symbol`timestamp`month`date`datetime`timespan`minute`second`time;
/ kdb type-number designators: positive short atom = cast, negative = Tok,
/ 0h = Identity
tagsP:1 2 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19h;
tagsK:neg tagsP;
tagsI:enlist 0h;

{[t] 0N!(t; f[t] each srcs)} each tagsL;
{[t] 0N!(t; f[t] each srcs)} each tagsU;
{[t] 0N!(t; f[t] each srcs)} each tagsN;
{[t] 0N!(t; f[t] each srcs)} each tagsP;
{[t] 0N!(t; f[t] each srcs)} each tagsK;
{[t] 0N!(t; f[t] each srcs)} each tagsI;

/ --- "c"$/`char$ shape law: atom vs enlist vs vector vs boxed-list pack ---
0N!`char$0x0a0b0c;
0N!"c"$0x41;
0N!`char$65;
0N!"c"$65 66 67;
0N!"c"$65 66 67i;
0N!"c"$65 66 67h;
0N!`char$enlist 0x41;
0N!`char$`byte$();
0N!"c"$101b;
0N!"c"$1b;
0N!"c"$65.4 66.6;
0N!"c"$65e;
0N!"c"$(65;0x42;67h;1b;"D");
0N!"c"$"abc";
0N!type `char$0x0a0b0c;
0N!type `char$enlist 0x41;
0N!type `char$0x41;
0N!type "c"$65 66 67;
0N!count `char$`byte$();
0N!`$`char$0x616263;
0N!@[{`char$x};`sym;{x}];

/ --- pinned kdb semantics exercised during the cast rework ---
0N!`long$3.7;                    / rounds half-to-even: 4
0N!"j"$2.5;                      / banker's: 2
0N!`int$6.6;                     / 7i
0N!"e"$42;                       / 42e
0N!"h"$300.7;                    / 301h
0N!`long$0n;                     / 0N
0N!`int$0W;                      / i64 inf narrows -> 0Wi
0N!"u"$0W;                       / through the i32 lane -> 0Wu
0N!`float$0Wh;                   / widening keeps payload -> 32767f
0N!"b"$0 1 2;                    / 011b
0N!`timestamp$2019.11.19;        / date -> midnight ns
0N!`time$0D01:02:03.456789000;   / ns -> ms-of-day floor
0N!`date$2019.11.19D12:00:00;    / floor of the day split
0N!`date$0Np;                    / 0Nd
0N!`long$();                     / `long$()
0N!`$"hello";                    / `hello
0N!`symbol$"abc";                / `abc
0N!string 123;                   / "123"
0N!"x"$"abc";                    / 0x616263
0N!`long$"A";                    / code point 65
0N!"i"$2019.11.19;               / 7262i
0N!`long$(1;2.5;3h);             / boxed mix casts per element
0N!10h$0x414243;                 / "ABC"
0N!(`int`float$5 6);             / sym-vector multi designator
0N!("fiij"$10.7);                / letter-string multi designator
0N!("i"$"42");                   / cast: code points 52 50i
0N!-6h$"42";                     / Tok I: 42i
0N!0h$"keepme";                  / Identity returns y
0N!"*"$`sym;                     / Identity returns y
0N!`week$2026.11.17;             / temporal component: week
0N!`year$2026.11.17D10:00:00;    / temporal component: year
0N!meta ([]a:1 2;b:`x`y);        / `t` column rides qnames
0N!@[{`badtype$x};1;{x}];        / unknown designator -> "badtype" error
