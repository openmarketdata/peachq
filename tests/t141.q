/ afl came up with this one and revealed some memory corruption
\e 0
f:{f . enlist x:{f . enlist x} each}'
f 1 2
\\
