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
  #getError : Name;
};

public type Exp = { // *
  #alloc: (Name, Exp); // reduces to #thunk case *before* evaluation, to permit fine-grained changes
  #num: Int;
  #add: (Exp, Exp);
  #sub: (Exp, Exp);
  #mul: (Exp, Exp);
  #div: (Exp, Exp);
  #thunk: Name;
};

// simple integer-based calculator, with incremental caching
public class Calc() {

  /* -- cache implementation, via adapton package -- */
  public var engine : Engine.Engine<Name, Val, Error, Exp> =
    Engine.Engine<Name, Val, Error, Exp>(
      {
        nameEq=func (x:Text, y:Text) : Bool { x == y };
        valEq=func (x:Int, y:Int) : Bool { x == y };
        closureEq=func (x:Exp, y:Exp) : Bool { x == y };
        errorEq=func (x:Error, y:Error) : Bool { x == y };
        nameHash=Text.hash;
        cyclicDependency=func (stack:L.List<Name>, name:Name) : Error {
          assert false; loop { }
        }
      },
      true // logging
    );

  public var engineIsInit = false;

  /// Pre-evaluation allocation step.
  ///
  /// To permit fine-grained changes and re-execution,
  /// first allocate the AST nodes into the Engine as thunks,
  /// before evaluating them.
  func alloc(e : Exp) : Exp {
    switch e {
      case (#num(n)) { #num(n) };
      case (#thunk(n)) { #thunk((n)) };
      case (#add(e1, e2)) { #add(alloc e1, alloc e2) };
      case (#sub(e1, e2)) { #sub(alloc e1, alloc e2) };
      case (#mul(e1, e2)) { #mul(alloc e1, alloc e2) };
      case (#div(e1, e2)) { #div(alloc e1, alloc e2) };
      case (#alloc(n, e)) {
        switch (engine.putThunk(n, alloc(e))) {
        case (#err(err)) { loop { assert false } };
        case (#ok(n)) { #thunk(n) };
        }
      }
    }
  };

  func binOpOfExp(e:Exp)
    : ?{#add;#sub;#mul;#div} {
    switch e {
    case (#add _) ?#add;
    case (#sub _) ?#sub;
    case (#mul _) ?#mul;
    case (#div _) ?#div;
    case _ null;
    }
  };

  public func eval(exp : Exp) : R.Result<Val, Error> {
    if (not engineIsInit) {
      engine.init({eval=evalRec});
      engineIsInit := true
    };
    let exp_ = alloc(exp);
    evalRec(exp_)
  };

  func evalRec(exp : Exp) : R.Result<Val, Error> {
    switch exp {
    case (#num(n)) { #ok(n) };
    case (#alloc(n, e)) { loop { assert false }  };
    case (#thunk(n)) {
      switch (engine.get(n)) {
        case (#ok(res)) { res }; // temp
        case (#err(_)) { #err(#getError(n)) };
      }
    };
    case _ {
      switch (evalBinopArgs(exp)) {
        case (#err(e)) #err(e);
        case (#ok((n1, n2))) {
          switch (binOpOfExp(exp)) {
            case null { loop { assert false } };
            case (?#add) #ok(n1 + n2) ;
            case (?#mul) #ok(n1 * n2);
            case (?#sub) #ok(n1 - n2);
            case (?#div) if (n2 == 0) { #err(#divByZero) } else #ok(n1 / n2);
          }
        }
      }
     };
    }
  };

  func evalBinopArgs(e:Exp) : R.Result<(Val, Val), Error> {
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
      case (#add(e1, e2)) { doit(e1, e2) };
      case (#sub(e1, e2)) { doit(e1, e2) };
      case (#div(e1, e2)) { doit(e1, e2) };
      case (#mul(e1, e2)) { doit(e1, e2) };
      case _ { loop { assert false } };
    }
  };

  public func takeLog() : Engine.Log<Name, Val, Error, Exp> {
    let log = engine.takeLog();
    debug { Debug.print (debug_show log) };
    log
  };


};

}
