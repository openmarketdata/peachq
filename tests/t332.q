. enlist (`a;)
. enlist (`a;(::))

. enlist (`a;0)
. enlist (`a;enlist 0)
. enlist (`a;0 1)
. enlist (`a;enlist 0 1)

. enlist (`a;0.0)
. enlist (`a;enlist 0.0)
. enlist (`a;0 1.0)
. enlist (`a;enlist 0 1.0)

. enlist (`a;"b")
. enlist (`a;enlist "b")
. enlist (`a;"bc")
. enlist (`a;enlist "bc")

. enlist (`a;`b)
. enlist (`a;enlist `b)
. enlist (`a;`b `c)
. enlist (`a;enlist `b `c)

. (enlist (`a;))
. (enlist (`a;(::)))

. (enlist (`a;0))
. (enlist (`a;enlist 0))
. (enlist (`a;0 1))
. (enlist (`a;enlist 0 1))

. (enlist (`a;0.0))
. (enlist (`a;enlist 0.0))
. (enlist (`a;0 1.0))
. (enlist (`a;enlist 0 1.0))

. (enlist (`a;"b"))
. (enlist (`a;enlist "b"))
. (enlist (`a;"bc"))
. (enlist (`a;enlist "bc"))

. (enlist (`a;`b))
. (enlist (`a;enlist `b))
. (enlist (`a;`b `c))
. (enlist (`a;enlist `b `c))

. ((`a;1);(`b;2))
. ((`a;1.0);(`b;2.0))
. ((`a;"a");(`b;"b"))
. ((`a;"aa");(`b;"bb"))
. ((`a;`aa);(`b;`bb))
. ((`a;`a `a);(`b;`b `b))
. ((`a;`a `b);(`b;`b `b))
. ((`a;`a `b `c);(`b;`b `c `d))

. ((`a;1);(`b;2.0))
. ((`a;1);(`b;2.0);(`c;"a"))
. ((`a;1);(`b;2.0);(`c;"a");(`d;"asdf"))
. ((`a;1);(`b;2.0);(`c;"a");(`d;"asdf");(`e;(1;2.0;. ((`a;1);(`b;2)))))
. ((`a;1);(`b;2.0);(`c;"a");(`d;"asdf");(`e;(1;2.0;. ((`a;1);(`b;2));til 10;"asdf")))

\\
