import A "../Adapton";
import E "../EvalType";

import H "mo:base/hash";
import L "mo:base/list";
import R "mo:base/result";
import P "mo:base/prelude";

import Debug "mo:base/debug";

// example evaluator
module {
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
public class Calc() {

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

  /* -- extra stuff we need -- */

  func expEq(x:Exp, y:Exp) : Bool {
    switch (x, y) {
    case (#num(n1), #num(n2)) { n1 == n2 };
    case (#named(n1, e1), #named(n2, e2)) { n1 == n2 and expEq(e1, e2) };
    case (#add(e1, e2), #add(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case (#mul(e1, e2), #mul(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case (#div(e1, e2), #div(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case (#sub(e1, e2), #sub(e3, e4)) { expEq(e1, e3) and expEq(e2, e4) };
    case _ { false };
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
    case ( #add(_, _) // feedback to compiler design: This would be easier if I could bind vars here.
        or #sub(_, _)
        or #mul(_, _)
        or #div(_, _) ) {
           switch (evalEagerPair(e)) {
             case (#err(e)) #err(e);
             case (#ok((n1, n2))) {
                    switch (binOpOfExp(e)) {
                    case null { P.unreachable() };
                    case (?#add) { #ok(n1 + n2) };
                    case (?#mul) { #ok(n1 * n2) };
                    case (?#sub) { #ok(n1 - n2) };
                    case (?#div) { if (n2 == 0) { #err(#divByZero) } else #ok(n1 / n2) };
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
/*
    case _ {
           #err(#unimplemented)
         }
*/
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

}
