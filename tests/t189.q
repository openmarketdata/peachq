/ amend entire
a:()
f:{
 r:()
 r,:enlist .[x;0#0;,;"z"]
 r,:enlist .[x;0#0.0;,;"z"]
 r,:enlist .[x;"";,;"z"]
 r,:enlist .[x;0#`;,;"z"]
 r,:enlist .[x;();,;"z"]
 r}
f 1
f 1.0
f "a"
f `a
f@. ()
f {}
a
f 1 2
f 1 2.0
f "ab"
f `a `b
f (. ();{})

.[til 3;1;,;9]
.[til 3;enlist 1;,;9]
.[til 3;(::);,;9]
.[til 3;enlist(::);,;9]
.[til 3;,enlist(::);,;9]
.[til 3;(::);,;7 8 9]
.[til 3;enlist(::);,;7 8 9]
.[til 3;,enlist(::);,;enlist 7 8 9]
.[til 3;enlist each enlist 1;,;9]
.[0.0+til 3;1;,;9.0]
.[0.0+til 3;enlist 1;,;9.0]
.[0.0+til 3;(::);,;9.0]
.[0.0+til 3;enlist(::);,;9.0]
.[0.0+til 3;,enlist(::);,;9.0]
.[0.0+til 3;(::);,;7 8 9.0]
.[0.0+til 3;enlist each enlist 1;,;9.0]
.["abc";1;,;"z"]
.["abc";enlist 1;,;"z"]
.["abc";(::);,;"z"]
.["abc";enlist(::);,;"z"]
.["abc";,enlist(::);,;"z"]
.["abc";(::);,;"xyz"]
.["abc";enlist(::);,;"xyz"]
.["abc";,enlist(::);,;enlist "xyz"]
.["abc";enlist each enlist 1;,;"z"]
.[`a `b `c;1;,;`z]
.[`a `b `c;enlist 1;,;`z]
.[`a `b `c;(::);,;`z]
.[`a `b `c;enlist(::);,;`z]
.[`a `b `c;,enlist(::);,;`z]
.[`a `b `c;(::);,;`x `y `z]
.[`a `b `c;enlist(::);,;`x `y `z]
.[`a `b `c;,enlist(::);,;enlist `x `y `z]
.[`a `b `c;enlist each enlist 1;,;`z]
.[(0;1;2.0);1;,;9]
.[(0;1;2.0);enlist 1;,;9]
.[(0;1;2.0);(::);,;9]
.[(0;1;2.0);enlist(::);,;9]
.[(0;1;2.0);,enlist(::);,;9]
.[(0;1;2.0);(::);,;7 8 9]
.[(0;1;2.0);enlist(::);,;7 8 9]
.[(0;1;2.0);,enlist(::);,;enlist 7 8 9]
.[(0;1;2.0);,,enlist(::);,;,enlist 7 8 9]
.[(0;1;2.0);,,,enlist(::);,;,,enlist 7 8 9]
.[(0;1;2.0);enlist each enlist 1;,;9]

d:3#enlist til 3
.[d;((::);0 1);-;10 10 10]
.[d;(enlist(::);0 1);-;enlist 10 10 10]
.[d;(,enlist(::);0 1);-;,enlist 10 10 10]
.[d;(,,enlist(::);0 1);-;,,enlist 10 10 10]
d:3#enlist 3#enlist til 3
.[d;((::);(::);0 1);-;10 10 10]
.[d;(enlist(::);(::);0 1);-;enlist 10 10 10]
.[d;(,enlist(::);(::);0 1);-;,enlist 10 10 10]
.[d;(,,enlist(::);(::);0 1);-;,,enlist 10 10 10]

d:(!) . (`a `b `c;(1 1;2 2;3 3))
.[d;`b;,;"z"]
.[d;(::);,;"z"]
.[d;enlist(::);,;"z"]
.[d;,enlist(::);,;enlist "z"]
.[d;,,enlist(::);,;,enlist "z"]
.[d;(::);,;"xyz"]
.[d;enlist(::);,;"xyz"]
.[d;,enlist(::);,;enlist "xyz"]
.[d;,,enlist(::);,;,enlist "xyz"]

d:(!) . (`a `b `c;(1 1;2 2;3 3))
e.f:d
.[e;`f `b;,;9.0]
.[e;(`f;`a `b `c);,;9.0]
.[e;(`f;`a `b `c);,;7 8 9.0]

.[e;((::);`a `b `c);,;9.0]
.[e;((::);`a `b `c);,;enlist 7 8 9.0]
.[e;(`f;(::));,;9.0]
.[e;(`f;(::));,;7 8 9.0]
.[e;(enlist(::);`a `b `c);,;9.0]
.[e;(enlist(::);`a `b `c);,;,enlist 7 8 9.0]
.[e;(,enlist(::);`a `b `c);,;,,enlist 7 8 9.0]
.[e;(,,enlist(::);`a `b `c);,;,,,enlist 7 8 9.0]

\\
