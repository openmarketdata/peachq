1 atan2 2
1 atan2 2 3
1 2 atan2 3
1 2 atan2 3 4

1.0 atan2 2
1.0 atan2 2 3
1 2.0 atan2 3
1 2.0 atan2 3 4

1 atan2 2.0
1 atan2 2 3.0
1 2 atan2 3.0
1 2 atan2 3 4.0

1.0 atan2 2.0
1.0 atan2 2 3.0
1 2.0 atan2 3.0
1 2.0 atan2 3 4.0

/1 atan2 (2;3.0)  / e doesn't normalize the result here. ex: (0.4636476;0.3217506)
/(1;2.0) atan2 3
/1.0 atan2 (2;3.0)
/(1;2.0) atan2 3.0
/(1;2.0) atan2 (3;4.0)

10 div 2
"asdf"
0Wi div 2
10 div 0Wi
0Ni div 2
/10 div 0N        / e gives -1 vs 0
/-0I div 2        / e gives -1073741824 vs -1073741823
/10 div -0I       / e gives -1 vs 0
0Ni div 0Ni
/0N div 0I        / e gives -2 vs -1
0Ni div -0Wi
/0I div 0N        / e gives -1 vs 0
0Wi div 0Wi
0Wi div -0Wi
-0Wi div 0Ni
-0Wi div 0Wi
-0Wi div -0Wi
/10 div 2 3        / e throws a type error if any operands to div are integer vectors
/10 20 div 3
/10 20 div 3 4

1 and 2
1 and 2 4
1 2 and 4
1 2 and 4 8
0Wi and 2
0Ni and 2
-0Wi and 2
0Wi and 2 4
0Ni and 2 4
-0Wi and 2 4
0Wi and 0Wi
0Wi and 0Ni
0Wi and -0Wi
0Ni and 0Wi
0Ni and 0Ni
0Ni and -0Wi
-0Wi and 0Wi
-0Wi and 0Ni
-0Wi and -0Wi

1 or 2
1 or 2 4
1 2 or 4
1 2 or 4 8
0Wi or 2
0Ni or 2
-0Wi or 2
0Wi or 2 4
0Ni or 2 4
-0Wi or 2 4
0Wi or 0Wi
0Wi or 0Ni
0Wi or -0Wi
0Ni or 0Wi
0Ni or 0Ni
0Ni or -0Wi
-0Wi or 0Wi
-0Wi or 0Ni
-0Wi or -0Wi

1 xor 3
1 xor 3 4
1 2 xor 3
1 2 xor 3 8
0Wi xor 2
0Ni xor 2
-0Wi xor 2
0Wi xor 2 4
0Ni xor 2 4
-0Wi xor 2 4
0Wi xor 0Wi
0Wi xor 0Ni
0Wi xor -0Wi
0Ni xor 0Wi
0Ni xor 0Ni
0Ni xor -0Wi
-0Wi xor 0Wi
-0Wi xor 0Ni
-0Wi xor -0Wi

not 1
not 1 2
not 0Wi
not 0Ni
not -0Wi

1 rot 3
8 rot -3
1 rot 1 2 3
2 4 8 rot -1 -2 -3
1 rot 0Wi
1 rot 0Ni
1 rot -0Wi
0Wi rot 1
/0N rot 1             / e gives 1 vs -1
/-0I rot 1            / e gives 3 vs -1

1 shift 3
8 shift -3
1 shift 1 2 3
2 4 8 shift -1 -2 -3
1 shift 0Wi
1 shift 0Ni
1 shift -0Wi
0Wi shift 1
0Ni shift 1
-0Wi shift 1

atan2[1;2]
atan2[1;2 3]
atan2[1 2;3]
atan2[1 2;3 4]

atan2[1.0;2]
atan2[1.0;2 3]
atan2[1 2.0;3]
atan2[1 2.0;3 4]

atan2[1;2.0]
atan2[1;2 3.0]
atan2[1 2;3.0]
atan2[1 2;3 4.0]

atan2[1.0;2.0]
atan2[1.0;2 3.0]
atan2[1 2.0;3.0]
atan2[1 2.0;3 4.0]

/atan2[1;(2;3.0)]  / e doesn't normalize the result here. ex: (0.4636476;0.3217506)
/atan2[(1;2.0);3]
/atan2[1.0;(2;3.0)]
/atan2[(1;2.0);3.0]
/atan2[(1;2.0);(3;4.0)]

div[10;2]
div[0Wi;2]
div[10;0Wi]
div[0Ni;2]
/div[10;0N]        / e gives -1 vs 0
/div[-0I;2]        / e gives -1073741824 vs -1073741823
/div[10;-0I]       / e gives -1 vs 0
div[0Ni;0Ni]
/div[0N;0I]        / e gives -2 vs -1
div[0Ni;-0Wi]
/div[0I;0N]        / e gives -1 vs 0
div[0Wi;0Wi]
div[0Wi;-0Wi]
div[-0Wi;0Ni]
div[-0Wi;0Wi]
div[-0Wi;-0Wi]
/div[10;2 3]        / e throws a type error if any operands to div are integer vectors
/div[10 20;3]
/div[10 20;3 4]

and[1;2]
and[1;2 4]
and[1 2;4]
and[1 2;4 8]
and[0Wi;2]
and[0Ni;2]
and[-0Wi;2]
and[0Wi;2 4]
and[0Ni;2 4]
and[-0Wi;2 4]
and[0Wi;0Wi]
and[0Wi;0Ni]
and[0Wi;-0Wi]
and[0Ni;0Wi]
and[0Ni;0Ni]
and[0Ni;-0Wi]
and[-0Wi;0Wi]
and[-0Wi;0Ni]
and[-0Wi;-0Wi]

or[1;2]
or[1;2 4]
or[1 2;4]
or[1 2;4 8]
or[0Wi;2]
or[0Ni;2]
or[-0Wi;2]
or[0Wi;2 4]
or[0Ni;2 4]
or[-0Wi;2 4]
or[0Wi;0Wi]
or[0Wi;0Ni]
or[0Wi;-0Wi]
or[0Ni;0Wi]
or[0Ni;0Ni]
or[0Ni;-0Wi]
or[-0Wi;0Wi]
or[-0Wi;0Ni]
or[-0Wi;-0Wi]

xor[1;3]
xor[1;3 4]
xor[1 2;3]
xor[1 2;3 8]
xor[0Wi;2]
xor[0Ni;2]
xor[-0Wi;2]
xor[0Wi;2 4]
xor[0Ni;2 4]
xor[-0Wi;2 4]
xor[0Wi;0Wi]
xor[0Wi;0Ni]
xor[0Wi;-0Wi]
xor[0Ni;0Wi]
xor[0Ni;0Ni]
xor[0Ni;-0Wi]
xor[-0Wi;0Wi]
xor[-0Wi;0Ni]
xor[-0Wi;-0Wi]

not[1]
not[1 2]
not[0Wi]
not[0Ni]
not[-0Wi]

rot[1;3]
rot[8;-3]
rot[1;1 2 3]
rot[2 4 8;-1 -2 -3]
rot[1;0Wi]
rot[1;0Ni]
rot[1;-0Wi]
rot[0Wi;1]
/rot[0N;1]             / e gives 1 vs -1
/rot[-0I;1]            / e gives 3 vs -1

shift[1;3]
shift[8;-3]
shift[1;1 2 3]
shift[2 4 8;-1 -2 -3]
shift[1;0Wi]
shift[1;0Ni]
shift[1;-0Wi]
shift[0Wi;1]
shift[0Ni;1]
shift[-0Wi;1]

\\
