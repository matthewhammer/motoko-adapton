import A "mo:adapton/adapton";
import D "mo:adapton/draw";
import E "mo:adapton/evalType";
import H "mo:base/hash";
import L "mo:base/list";
import R "mo:base/result";

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
class Calc() {

  /* -- cache implementation, via adapton package -- */
  var namedCache : A.Engine<Name, Val, Error, Exp> = {
    let _errorEq = errorEq;
    A.Engine<Name, Val, Error, Exp>({
      nameEq=func (x:Text, y:Text) : Bool { x == y };
      valEq=func (x:Int, y:Int) : Bool { x == y };
      errorEq=_errorEq;
      closureEq=expEq;
      nameHash=H.hashOfText;
      closureEval=eval;
      cyclicDependency=func (stack:L.List<Name>, name:Name) : Error {
        assert false; loop { }
        }
    },
    true)
  };

  /* -- custom DSL evaluator definition: -- */
  public func eval(e:Exp) : R.Result<Val, Error> {
    switch e {
    case (#num(n)) { #ok(n) };
    case (#add(e1, e2)) {
           switch (eval(e1)) {
           case (#err(e)) #err(e);
           case (#ok(n1)) {
                  switch (eval(e2)) {
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

  /* -- extra stuff we need -- */

  func expEq(x:Exp, y:Exp) : Bool {
    switch (x, y) {
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

 }
}
