def doInd(D, i) {
  writeln("D.order/position(",i,") = ", D.order(i), "/", D.position(i));
}

def doDom(D) {
  doInd(D, D.low-D.high);
  for i in D {
    doInd(D, i);
  }
  doInd(D, D.high+D.low);
  writeln();
}

doDom([3..5]);
doDom([3..7 by 2]);

doDom([3..5, 3..5]);
doDom([3..7 by 2, 3..7 by 2]);


