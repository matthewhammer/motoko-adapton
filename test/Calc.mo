import C "../src/eval/Calc";
import Render "mo:redraw/Render";
import Debug "mo:base/Debug";

actor {

  public func test() : async Render.Result {
    let r = redraw({width=384; height=384;});
    Debug.print "almost done";
    r
  };

  // for client side, see https://github.com/matthewhammer/ic-game-terminal
  func redraw(_dim:Render.Dim) : Render.Result {
    // to do -- use dim

    Debug.print "Redraw begin";

    // test the Calc definition imported above:
    let calc = C.Calc();

    Debug.print "Calc() done.";

    let exp =
      #named("f",
             #add(
               #named("g", #div(#num(4), #mul(#num(6), #num(2)))),
               #named("a",
                      #div(#named("b", #mul(#num(3), #named("c", #add(#num(1), #num(2))))),
                           #named("d", #sub(#num(5), #named("e", #div(#num(4), #num(2)))))
                      ))));

    Debug.print "(trivial: exp done.)";

    calc.engine.draw().logEventLast();

    Debug.print "calc.engine.draw().logEventLast() done";

    // to do -- change the expression somehow

    let res = calc.eval(exp);

    Debug.print "calc.eval(exp) done";

    calc.engine.draw().logEventLast();

    Debug.print "calc.engine.draw().logEventLast() done";

    let r = calc.engine.draw().getResult();

    Debug.print "calc.engine.draw().getResult() done";

    r
  };
}
