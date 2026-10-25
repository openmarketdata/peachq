/ ktree amend protection

\e 0

.[`;`k;{0}]
.[`;`z;{. enlist `q0,0}]
.[`;`k;{. enlist `q0,0}]
.k

.[`;enlist `k;{1}]
.[`;enlist `z;{. enlist `q1,1}]
.[`;enlist `k;{. enlist `q1,1}]
.k

.[`;(::);{2}]
.[`;(::);{. enlist `q2,2}]  / k gets set, error on z
.k

.[`;enlist each enlist `k;{3}]
.[`;enlist each enlist `z;{. enlist `q3,3}]
.[`;enlist each enlist `k;{. enlist `q3,3}]
.k

"kamend4"
.[`;`k;::;4]
.[`;`z;::;. enlist `q4,4]
.[`;`k;::;. enlist `q4,4]
.k

.[`;(::);::;5]
.[`;(::);::;. enlist `q5,5]  / k gets set, error on z
.k

"kamendi3"
@[`;`k;{6}]
@[`;`aa `k;{6}] / aa gets set, error on k
.aa
@[`;`k;{. enlist `q7,7}]
.k

"kamendi4"
@[`;`k;::;6]
@[`;`aa `k;::;6] / aa gets set, error on k
.aa
@[`;`k;::;. enlist `q7,7]
.k

"trap . ."
.[.;(`;(::);{1});::]
.[.;(`;enlist `k;{1});::]
.[.;(`;(::);::;2);::]
.[.;(`;enlist `k;::;2);::]
.[.;(`;`k;::;. enlist `q8,8);::]
.k

"trap @ @"
.[@;(`;(::);{1});::]
.[@;(`;enlist `k;{1});::]
.[@;(`;(::);::;2);::]
.[@;(`;enlist `k;::;2);::]
.[@;(`;`k;::;. enlist `q9,9);::]
.k

\\
