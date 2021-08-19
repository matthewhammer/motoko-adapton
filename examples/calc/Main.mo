import Calc "Calc";
import Debug "mo:base/Debug";

actor {
  public query func test() : async () {
    let calc = Calc.Calc();
    let exp =
      #alloc("f",
             #add(
               #alloc("g", #div(#num(4), #mul(#num(6), #alloc("h", #num(2))))),
               #alloc("a",
                      #div(#alloc("b", #mul(#num(3), #alloc("c", #add(#num(1), #num(2))))),
                           #alloc("d", #sub(#num(5), #alloc("e", #div(#num(4), #num(2)))))
                      ))));

    let testPrefix = "Calc test: ";
    let testStep = " - test step: ";
    debug { Debug.print(testPrefix # "Start") };
    do /* initial run */ {
      let res1 = calc.eval(exp);
      debug { Debug.print(testStep # "Assert first evaluation.") };
      assert calc.takeLog() == [
        #putThunk("h", #num(+2), []),
        #putThunk("g", #div(#num(+4), #mul(#num(+6), #thunk("h"))), []),
        #putThunk("c", #add(#num(+1), #num(+2)), []),
        #putThunk("b", #mul(#num(+3), #thunk("c")), []),
        #putThunk("e", #div(#num(+4), #num(+2)), []),
        #putThunk("d", #sub(#num(+5), #thunk("e")), []),
        #putThunk("a", #div(#thunk("b"), #thunk("d")), []),
        #putThunk("f", #add(#thunk("g"), #thunk("a")), []),
        #get("f", #ok(+3), [
          #evalThunk("f", #ok(+3),
          [#get("g", #ok(0),
          [#evalThunk("g", #ok(0),
          [#get("h", #ok(+2),
          [#evalThunk("h", #ok(+2), [])])])]),
           #get("a", #ok(+3),
          [#evalThunk("a", #ok(+3),
          [#get("b", #ok(+9),
          [#evalThunk("b", #ok(+9),
          [#get("c", #ok(+3),
          [#evalThunk("c", #ok(+3), [])])])]),
           #get("d", #ok(+3),
          [#evalThunk("d", #ok(+3),
          [#get("e", #ok(+2),
          [#evalThunk("e", #ok(+2), [])])])])])])])])
        ];

      debug { Debug.print(testStep # "Assert re-get.") };
      ignore calc.engine.get("f");
      assert calc.takeLog() ==
        [#get("f", #ok(+3),
        [#cleanThunk("f", true,
        [#cleanEdgeTo("g", true, []),
         #cleanEdgeTo("a", true, [])])])];

      debug { Debug.print(testStep # "Assert share.") };
      ignore calc.eval(#alloc("k", #add(#thunk("g"), #num(3))));
      assert calc.takeLog() ==
        [#putThunk("k", #add(#thunk("g"), #num(+3)), []),
         #get("k", #ok(+3),
        [#evalThunk("k", #ok(+3),
        [#get("g", #ok(0),
        [#cleanThunk("g", true,
        [#cleanEdgeTo("h", true, [])])])])])]
    };

    do /* input change (overwrite "g"), and re-demand output value (of "f") */ {
      ignore calc.engine.putThunk("g", #add(#num(1), #num(2)));
      debug { Debug.print(testStep # "Assert input change: Overwrite thunk with putThunk.") };
      assert calc.takeLog() ==
        [#putThunk("g", #add(#num(+1), #num(+2)),
                   [#dirtyIncomingTo("g",
                   [#dirtyEdgeFrom("f",
                   [#dirtyIncomingTo("f", [])]),
                    #dirtyEdgeFrom("k",
                   [#dirtyIncomingTo("k", [])])])])];

      let res3 = calc.engine.get("f");
      debug { Debug.print(testStep # "Assert change propagation: Reuse clean graph") };
      assert calc.takeLog() ==
        [#get("f", #ok(+6),
        [#cleanThunk("f", false,
        [#cleanEdgeTo("g", false,
        [#cleanThunk("g", false,
        [#evalThunk("g", #ok(+3), [])])]),
         #evalThunk("f", #ok(+6),
        [#get("g", #ok(+3),
        [#cleanThunk("g", true, [])]),
         #get("a", #ok(+3),
        [#cleanThunk("a", true,
        [#cleanEdgeTo("b", true, []),
         #cleanEdgeTo("d", true, [])])])])])])]
    };

    do /* input change with same valuation ("g"'s new  expression has same value) */ {
      ignore calc.engine.putThunk("g", #add(#num(3), #num(0)));
      debug { Debug.print(testStep # "Assert input change: Overwrite thunk with putThunk, again.") };
      assert calc.takeLog() ==
      [#putThunk("g", #add(#num(+3), #num(0)),
        [#dirtyIncomingTo("g",
        [#dirtyEdgeFrom("f",
        [#dirtyIncomingTo("f", [])])])])];

      let res3 = calc.engine.get("f");
      debug { Debug.print(testStep # "Assert change propagation: Clean and reuse (most of) graph") };
      assert calc.takeLog() ==
        [#get("f", #ok(+6),
        [#cleanThunk("f", true,
        [#cleanEdgeTo("g", true,
        [#cleanThunk("g", false,
        [#evalThunk("g", #ok(+3), [])])]),
         #cleanEdgeTo("a", true, [])])])]
    };

    do /* re-demand "k", and re-use cleaning from above (of "g"), though the value changed. */ {
      let res3 = calc.engine.get("k");
      debug { Debug.print(testStep # "Assert change propagation: Reuse clean graph") };
      assert calc.takeLog() ==
        [#get("k", #ok(+6),
        [#cleanThunk("k", false,
        [#cleanEdgeTo("g", false,
        [#cleanThunk("g", true, [])]),
         #evalThunk("k", #ok(+6),
        [#get("g", #ok(+3),
        [#cleanThunk("g", true, [])])])])])]
    };

    debug { Debug.print(testPrefix # "Success") };
  };
}
