import Calc "Calc";
import Debug "mo:base/Debug";
// import matchers

actor {
  func test() {
    let calc = Calc.Calc();
    Debug.print "Calc() done.";
    let exp =
      #named("f",
             #add(
               #named("g", #div(#num(4), #mul(#num(6), #num(2)))),
               #named("a",
                      #div(#named("b", #mul(#num(3), #named("c", #add(#num(1), #num(2))))),
                           #named("d", #sub(#num(5), #named("e", #div(#num(4), #num(2)))))
                      ))));
    let res = calc.eval(exp);
    // check result
    // change expression using put
    let res = calc.eval(exp);
    // check result
    // check trace
  };
}
