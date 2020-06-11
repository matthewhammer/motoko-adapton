import C "../src/eval/Calc";
import Render "mo:redraw/Render";
import Debug "mo:base/Debug";

actor {
  // for client side, see https://github.com/matthewhammer/ic-game-terminal
  public func windowSizeChange(_dim:Render.Dim) : async Render.Result {
    // to do -- use dim

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
    calc.engine.draw().logEventLast();

    // to do -- change the expression somehow

    let res2 = calc.eval(exp);
    calc.engine.draw().logEventLast();
    calc.engine.draw().getResult()
  };
}
