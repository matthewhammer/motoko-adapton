import A "mo:adapton/adapton";
import E "mo:adapton/evalType";
import H "mo:base/hash";
import L "mo:base/list";
import R "mo:base/result";

import Debug "mo:base/debug";

// see run() function
actor {
public type Name = Text;

public type Val = Int;

public type Error = {
  #divByZero;
  #unimplemented;
  #putError : Name;
};

public type Exp = {
  #num: Int;
  #add: (Exp, Exp);
  #sub: (Exp, Exp);
  #mul: (Exp, Exp);
  #div: (Exp, Exp);
  #named: (Name, Exp); // record a cached result at Name
};

// simple integer-based calculator, with incremental caching
class Calc() {

  /* -- extra stuff we need -- */

  func expEq(x:Exp, y:Exp) : Bool {
    switch (x, y) {
    case (#num(n1), #num(n2)) { n1 == n2 };
    case (#add(e1, e2), #add(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case _ { false }; // to do
    }
  };

  func errorEq(x:Error, y:Error) : Bool {
    switch (x, y) {
    case (#divByZero, #divByZero) { true };
    case (#unimplemented, #unimplemented) { true };
    case (#putError(n1), #putError(n2)) { n1 == n2 };
    case _ { false };
    }
  };

  var init : Bool = false;

  public func eval(e:Exp) : R.Result<Val, Error> {
    if (not init) {
      namedCache.setEvalClosure({eval=evalRec});
      init := true;
    };
    evalRec(e)
  };

  /* -- custom DSL evaluator definition: -- */

  func evalRec(e:Exp) : R.Result<Val, Error> {
    switch e {
    case (#num(n)) { #ok(n) };
    case (#add(e1, e2)) {
           switch (evalRec(e1)) {
           case (#err(e)) #err(e);
           case (#ok(n1)) {
                  switch (evalRec(e2)) {
                  case (#err(e)) #err(e);
                  case (#ok(n2)) {
                         #ok(n1 + n2)
                       }
                  }
                }
           }
         };
    case (#named(n, e)) {
           // use the name to create a Thunk within the cache
           switch (namedCache.putThunk(n, e)) {
           case (#err(_)) { #err(#putError(n)) };
           case (#ok(n)) {
                  switch (namedCache.get(n)) {
                  case (#err(_)) { assert false; loop { } };
                  case (#ok(res)) { res };
                  }
                };
           }
         };
    case _ {
           #err(#unimplemented)
         }
    }
  };

  /* -- cache implementation, via adapton package -- */

  var namedCache : A.Engine<Name, Val, Error, Exp> = {
    let _errorEq = errorEq;
    let engine = A.Engine<Name, Val, Error, Exp>
    ({
       nameEq=func (x:Text, y:Text) : Bool { x == y };
       valEq=func (x:Int, y:Int) : Bool { x == y };
       errorEq=_errorEq;
       closureEq=expEq;
       nameHash=H.hashOfText;
       cyclicDependency=func (stack:L.List<Name>, name:Name) : Error {
         assert false; loop { }
       }
     },
     true);
    // not yet fully initialized (still need to do setClosureEval)
    engine
  };

};

public func run() {
  // test the Calc definition above:
  let calc = Calc();
  let exp = #add(#num(1), #add(#num(1), #num(2)));
  Debug.print (debug_show exp);
  let res = calc.eval(exp);
  Debug.print (debug_show res);
};

}
