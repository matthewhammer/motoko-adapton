import Engine "../../src/Engine";

import H "mo:base/Hash";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Text "mo:base/Text";


/* # Example of using Adapton engine. */

/* Adapton engine use -- step 1a:
      Define four types (see *'s below), and operations: */
module {
public type Name = Text; // *
public type Val = Int; // *

public type Error = { // *
  #divByZero;
  #unimplemented;
  #putError : Name;
};

public type Exp = { // *
  #num: Int;
  #add: (Exp, Exp);
  #sub: (Exp, Exp);
  #mul: (Exp, Exp);
  #div: (Exp, Exp);
  #named: (Name, Exp); // record a cached result at Name
};

// simple integer-based calculator, with incremental caching
public class Calc() {

  /* -- utils -- extra stuff we need -- */

  public func binOpOfExp(e:Exp)
    : ?{#add;#sub;#mul;#div} {
    switch e {
    case (#add _) ?#add;
    case (#sub _) ?#sub;
    case (#mul _) ?#mul;
    case (#div _) ?#div;
    case _ null;
    }
  };

  func expEq(x:Exp, y:Exp) : Bool {
    x == y
  };

  func errorEq(x:Error, y:Error) : Bool {
    x == y
  };

  /* -- custom DSL evaluator definition: -- */

  var init : Bool = false;

  public func eval(e:Exp) : R.Result<Val, Error> {
    if (not init) {
      // Adapton functor step 3:
      //   initialize engine with evaluation function.
      engine.setEvalClosure({eval=evalRec});
      // Now the the calculator is ready for (incremental) evaluation!
      init := true;
    };
   evalRec(e)
  };

  // Adapton functor step 2:
  //    Using engine as a cache, define a custom evaluation function for DSL:
  func evalRec(e:Exp) : R.Result<Val, Error> {
    switch e {
    case (#num(n)) { #ok(n) };
    case ( #add(_, _) // feedback to compiler design: This would be easier if I could bind vars here.
        or #sub(_, _)
        or #mul(_, _)
        or #div(_, _) ) {
           switch (evalEagerPair(e)) {
             case (#err(e)) #err(e);
             case (#ok((n1, n2))) {
                    switch (binOpOfExp(e)) {
                    case null { P.unreachable() };
                    case (?#add) #ok(n1 + n2) ;
                    case (?#mul) #ok(n1 * n2);
                    case (?#sub) #ok(n1 - n2);
                    case (?#div) if (n2 == 0) { #err(#divByZero) } else #ok(n1 / n2);
                  }
                  }
           }
         };
    case (#named(n, e)) {
           // Engine helps via cache steps (a) and (b):
           //   (a) put Thunk within the cache at given name
           switch (engine.putThunk(n, e)) {
           case (#err(_)) { #err(#putError(n)) }; // e.g., non-unique name in AST
           case (#ok(n)) {
                  // (b) get demands the evaluation result of put Thunk
                  switch (engine.get(n)) {
                  case (#ok(res)) { res }; // temp
                  case (#err(_)) { P.unreachable() };
                  }
                };
           }
         };
    }
  };

  func evalEagerPair(e:Exp) : R.Result<(Val, Val), Error> {
    func doit(e1:Exp, e2:Exp) : R.Result<(Val, Val), Error> {
      switch (evalRec(e1)) {
      case (#err(e)) #err(e);
      case (#ok(v1)) {
             switch (evalRec(e2)) {
             case (#err(e)) #err(e);
             case (#ok(v2)) {
                    #ok((v1, v2))
                  }
             }
           }
      }
    };
    switch e {
      // redoing the pattern-match because I cannot bind vars in `or` patterns
      case (#add(e1, e2)) { doit(e1, e2) };
      case (#sub(e1, e2)) { doit(e1, e2) };
      case (#div(e1, e2)) { doit(e1, e2) };
      case (#mul(e1, e2)) { doit(e1, e2) };
      case _ { P.unreachable() };
    }
  };

  /* -- cache implementation, via adapton package -- */

  public var engine : Engine.Engine<Name, Val, Error, Exp> = do {
    let _errorEq = errorEq;
    // Adapton functor step 1b:
    //   Apply the functor to the definitions of types and operations,
    //   excluding the definition of evaluation itself (step 2).
    let engine = Engine.Engine<Name, Val, Error, Exp>
    ({
       nameEq=func (x:Text, y:Text) : Bool { x == y };
       valEq=func (x:Int, y:Int) : Bool { x == y };
       errorEq=_errorEq;
       closureEq=expEq;
       nameHash=Text.hash;
       cyclicDependency=func (stack:L.List<Name>, name:Name) : Error {
         assert false; loop { }
       }
     },
     true);
    engine
  };

};

}
