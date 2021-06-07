import C "../src/eval/Calc";
import Render "mo:redraw/Render";
import Debug "mo:base/Debug";

actor {
  var scriptTime : Int = 0;

  func timeNow_() : Int {
    scriptTime
  };

  public shared(msg) func scriptTimeTick() : async ?() {
    scriptTime := scriptTime + 1;
    ?()
  };

  public shared(msg) func reset() : async ?() {
    scriptTime := 0;
    ?()
  };


  public func test() : async ?Render.Result {
    ?redraw({width=384; height=384;})
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

    calc.engine.draw().logEventLast();

    // to do -- change the expression somehow

    let res = calc.eval(exp);
    calc.engine.draw().logEventLast();
    calc.engine.draw().getResult()
  };
}
