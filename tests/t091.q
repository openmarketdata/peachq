f:{til x}
f each 5 5 5
g:{enlist x}
g each "asdf"
g (each each 2)#enlist "asdf"
g (each each '3)#enlist "asdf"
r:,//g (each each '3)#enlist "asdf"
g each r
(,/) g each r
\\
