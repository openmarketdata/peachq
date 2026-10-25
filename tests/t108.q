a:til 10
a (::)
(::) a
b:a (::)
c:(::) a
a[0]:5
b[0]:6
c[0]:7
a
b
c
a[(::)]
b:a[(::)]
a[0]:100
b[0]:101
a
b
a:til 10
a@(::)
(::)@a
@[.;"1@nul";::]   / an atom ranks on any index, even nul
(::)@1            / nul is the identity vector: nul@1 is 1
\\
