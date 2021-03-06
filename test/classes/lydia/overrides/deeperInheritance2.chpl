// Checks that you can access the overridden parent method.
class A {
  proc foo() {
    writeln("in A.foo()");
  }
}

class B: A {
  proc foo() {
    super.foo();
    writeln("in B.foo()");
  }
}

class C: B {
  proc foo() {
    super.foo();
    writeln("in C.foo()");
  }
}

var a = new A();
var b = new B();
var c = new C();
var c2: A = new C();
var c3: B = new C();
a.foo();
b.foo();
c.foo();
c2.foo();
c3.foo();
