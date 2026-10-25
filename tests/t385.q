f:{x}
p:{x+y}
j:{x,y}

f each til 10
p'[til 10;til 10]
2 p\[3;4 5]
2 3 p/ 4 5
2 3 p\/ 4 5 6
2 3 p/\ 4 5 6
(p/) til 10
(p\) til 10

f each 0.0+til 10
p'[0.0+til 10;0.0+til 10]
2 p\[3.0;4 5.0]
2 3.0 p/ 4 5.0
2 3.0 p\/ 4 5 6.0
2 3.0 p/\ 4 5 6.0
(p/) 0.0+til 10
(p\) 0.0+til 10

f each "asdf"
j'["asdf";"wxyz"]
j\:["asdf";"wxyz"]
"asdf" j/ "wxyz"
"as" j\/ "wxyz"
"as" j/\ "wxyz"
(j/) "asdfwxyz"
(j\) "asdfwxyz"

f each `a `s `d `f
j'[`a `s `d `f;`w `x `y `z]
`a `s `d j\:[`f;`w `x `y `z]
`a `s `d `f j/ `w `x `y `z
`a `s j\/ `w `x `y `z
`a `s j/\ `w `x `y `z
(j/) `a `s `d `f `w `x `y `z
(j\) `a `s `d `f `w `x `y `z

f each (1;2.0;"a";`b)
j'[(1;2.0;"a";`b);(3;4.0;"c";`d)]
j\:[(1;2.0;"a";`b);(3;4.0;"c";`d)]
(1;2.0;"a";`b) j/ (3;4.0;"c";`d)
(1;2.0) j\/ (3;4.0;"c";`d)
(1;2.0) j/\ (3;4.0;"c";`d)
(j/) (1;2.0;"a";`b;3;4.0;"c";`d)
(j\) (1;2.0;"a";`b;3;4.0;"c";`d)

\\
