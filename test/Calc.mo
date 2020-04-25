import C "mo:adapton/eval/Calc";
import Debug "mo:base/debug";

actor {
  public func run() {
    // test the Calc definition imported above:
    let calc = C.Calc();
    let exp =
      /* exp = (3 * (1 + 2)) / (5 - (4 / 2))
       *      ||    |     ||   |    |     ||
       *      ||    c-----+|   |    e-----+|
       *      ||          ^|   |          ^|
       *      ||          ||   |          ||
       *      |b----------++   d----------++
       *      |            ^               ^
       *      |            |               |
       *      a------------+---------------+
       *                                   ^
       *                                   |
       */
      #named("a",
             #div(#named("b", #mul(#num(3), #named("c", #add(#num(1), #num(2))))),
                  #named("d", #sub(#num(5), #named("e", #div(#num(4), #num(2)))))));

    Debug.print (debug_show exp);
    let res1 = calc.eval(exp);
    Debug.print (debug_show res1);
    //Debug.print (debug_show calc.engine.getLogEventLast());
    let res2 = calc.eval(exp);
    Debug.print (debug_show res2);
    //Debug.print (debug_show calc.engine.getLogEventLast());
  };

}
