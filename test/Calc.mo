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
      #named("f",
             #add(
               #named("g", #div(#num(4), #mul(#num(6), #num(2)))),
               #named("a",
                      #div(#named("b", #mul(#num(3), #named("c", #add(#num(1), #num(2))))),
                           #named("d", #sub(#num(5), #named("e", #div(#num(4), #num(2)))))
                      ))));

    calc.engine.draw().logEventLast();

    // to do -- change the expression somehow

    let res = calc.eval(exp);
    calc.engine.draw().logEventLast();
    calc.engine.draw().getResult()
  };
}
