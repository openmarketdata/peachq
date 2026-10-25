+0
+0.0
+"a"
+`a
+. ()
+(::)
+{}

+0 1
+0 1.0
+"ab"
+`a `b
+(. ();. ())
+(;;)
+({};{})

+2#enlist 0 1
+2#enlist 0 1.0
+2#enlist "ab"
+2#enlist `a `b
+2#enlist (. ();. ())
+2#enlist (;;)
+2#enlist ({};{})

a:+("asdf";"asdf")
b:+a
c:+b
a
b
c
a~c

a:("asdf";"asdf";`a;1;2.0;. ();"z")
b:+a
c:+b
a
b
c
not a~c

\\

a:("asdf";"asdf";`a;1;2.0;. ();"z")
a:("asdf";"asdf";`a;1;2.0;. ();"z")
a:("asdf";"asdf";`a;1;2.0;. ();"z")
\\
