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

    debug { Debug.print("Calc test: Start") };
    do /* initial run */ {
      let res1 = calc.eval(exp);
      let res2 = calc.engine.get("f");

      assert calc.engine.takeLog() ==
        [#putThunk("h", #num(+2), []),
         #putThunk("g", #div(#num(+4), #mul(#num(+6), #thunk("h"))), []),
         #putThunk("c", #add(#num(+1), #num(+2)), []),
         #putThunk("b", #mul(#num(+3), #thunk("c")), []),
         #putThunk("e", #div(#num(+4), #num(+2)), []),
         #putThunk("d", #sub(#num(+5), #thunk("e")), []),
         #putThunk("a", #div(#thunk("b"), #thunk("d")), []),
         #putThunk("f", #add(#thunk("g"), #thunk("a")), []),
         #get("f", #ok(+3),
              [
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
                [#evalThunk("e", #ok(+2), [])])])])])])])]),
         #get("f", #ok(+3), [])
        ]
    };

    do /* input change, and re-demand output value */ {
      ignore calc.engine.putThunk("g", #add(#num(1), #num(2)));

      assert calc.engine.takeLog() ==
        [#putThunk("g", #add(#num(+1), #num(+2)),
                   [#dirtyIncomingTo("g",
                   [#dirtyEdgeFrom("f",
                   [#dirtyIncomingTo("f", [])])])])];

      let res3 = calc.engine.get("f");

      assert calc.engine.takeLog() ==
        [#get("f", #ok(+6),
          [
            #cleanThunk("f", false,
             [#cleanEdgeTo("g", false, [])]),
            #evalThunk("f", #ok(+6),
                       [
                         #get("g", #ok(+3),
                              [#evalThunk("g", #ok(+3), [])]),
                         #get("a", #ok(+3), [])
                       ]
            )])];

    };

    debug { Debug.print("Calc test: Success") };
  };
}
