5 in mod 10
5 11 in til 10
1 2 3 4 5 except 2 4
1 2 3 except 2

5.0 in 0.0+til 10
5 11.0 in 0.0+til 10
1 2 3 4 5.0 except 2 4.0
1 2 3.0 except 2.0

"a" in "asdf"
"ab" in "asdf"
"asdf" except "sd"
"asdf" except "s"

`a in `a `s `d `f
`a `b in `a `s `d `f
`a `s `d `f except `s `d
`a `s `d `f except `s

(. enlist `a,1) in (. enlist `a,1;. enlist `b,2)
(. enlist `a,1;. enlist `b,2) in (. enlist `a,1;. enlist `b,2;. enlist `c,3)
(. enlist `a,1;. enlist `b,2;. enlist `c,3;. enlist `d,4) except (. enlist `b,2;. enlist `c,3)
(. enlist `a,1;. enlist `b,2;. enlist `c,3;. enlist `d,4) except . enlist `b,2

(::) in (;;;)
(;;) in (;;;)
(;;) except (;;;)
(::) except (;;;)

{} in ({};{x})
({};{x};{z}) in ({};{x};{y})
({};{x};{y};{z}) except ({x};{y})
({};{x};{y};{z}) except {x}

in[5;til 10]
in[5 11;til 10]
except[1 2 3 4 5;2 4]
except[1 2 3;2]

in[5.0;0.0+til 10]
in[5 11.0;0.0+til 10]
except[1 2 3 4 5.0;2 4.0]
except[1 2 3.0;2.0]

in["a";"asdf"]
in["ab";"asdf"]
except["asdf";"sd"]
except["asdf";"s"]

in[`a;`a `s `d `f]
in[`a `b;`a `s `d `f]
except[`a `s `d `f;`s `d]
except[`a `s `d `f;`s]

in[(. enlist `a,1);(. enlist `a,1;. enlist `b,2)]
in[(. enlist `a,1;. enlist `b,2);(. enlist `a,1;. enlist `b,2;. enlist `c,3)]
except[(. enlist `a,1;. enlist `b,2;. enlist `c,3;. enlist `d,4);(. enlist `b,2;. enlist `c,3)]
except[(. enlist `a,1;. enlist `b,2;. enlist `c,3;. enlist `d,4);. enlist `b,2]

in[(::);(;;;)]
in[(;;);(;;;)]
except[(;;);(;;;)]
except[(::);(;;;)]

in[{};({};{x})]
in[({};{x};{z});({};{x};{y})]
except[({};{x};{y};{z});({x};{y})]
except[({};{x};{y};{z});{x}]

\\
