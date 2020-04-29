import C "mo:adapton/eval/Calc";
import Render "mo:redraw/Render";
import Debug "mo:base/Debug";

actor {
  public func render() : async Render.Result {
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

    let res1 = calc.eval(exp);    
    calc.engine.draw.logEvent();
    
    // to do -- change the expression somehow
    
    let res2 = calc.eval(exp);
    calc.engine.draw.logEvent();
    calc.engine.draw.getResult()
  };

  // To do -- try to reproduce and minimize what this code triggers in compiler:
  //Debug.print (debug_show calc.engine.getLogEventLast());

}
