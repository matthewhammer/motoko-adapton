import Engine "../Engine";
import Meta "Meta";

import H "mo:base/Hash";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Text "mo:base/Text";


module {

public type Name = Meta.Name;

public type ListMeta = Meta.Meta;

public type TreeMeta = {
  name : Name;
  level : Meta.Level;
  size : Nat
};

// Expresssions serve as "spreadsheet formula" for sequences.
public type Exp<Val_, Error_> = {
  // alloc reduces to #thunk case *before* evaluation
  #alloc: (Name, Exp<Val_, Error_>);
  // thunk case permits fine-grained re-use / re-evaluation
  #thunk: Name;
  // Sequence literal definition/construction
  #cons: (Exp<Val_, Error_>, ListMeta, Exp<Val_, Error_>);
  #nil;
  #val: Val_;
  // Sequence operations
  #toTree: Exp<Val_, Error_>;
  #toList: Exp<Val_, Error_>;
  #max: Exp<Val_, Error_>;
  //#sort: Exp;
  //#median: Exp;
  #err: Error_;
};

public type Val<Val_> = {
  // empty list; empty tree.
  #nil;
  // cons list: left value is list element; right is sub-list.
  #cons: (Val<Val_>, ListMeta, Val<Val_>);
  // binary tree: left/right values are sub-trees.
  #bin: (Val<Val_>, TreeMeta, Val<Val_>);
  #thunk: Name;
  #val: Val_;
};

public type Error = {
  #typeError;
  #engineError; // to do -- improve with separate PR
  #emptySequence // no max/min/median defined when sequence is empty
};

public type Ops<Exp_, Val_, Error_> = {
  valMax : (Val_, Val_) -> R.Result<Val_, Error_>;
  getVal : Val_ -> ?Val<Val_>;
  putExp : Exp<Val_, Error_> -> Exp_;
  getExp : Exp_ -> ?Exp<Val_, Error_>;
  putError : Error -> Error_;
  getError : Error_ -> ?Error;
};

public class Sequence<Exp_, Val_, Error_>(
  engine: Engine.Engine<Name, Val_, Error_, Exp_>,
  ops: Ops<Exp_, Val_, Error_>
) {

  public func eval(e : Exp<Val_, Error_>) : R.Result<Val<Val_>, Error> {
    evalRec(alloc(e))
  };

  func alloc(e : Exp<Val_, Error_>) : Exp<Val_, Error_> {
    switch e {
      case (#thunk(n)) #thunk((n));
      case (#alloc(n, e))
        switch (engine.putThunk(n, ops.putExp(alloc(e)))) {
        case (#err(err)) { loop { assert false } };
        case (#ok(n)) { #thunk(n) };
      };
      case _ { // to do -- recursive cases
             loop { assert false }
           };
    }
  };

  func evalRec(exp : Exp<Val_, Error_>) : R.Result<Val<Val_>, Error> {
    switch exp {
    case (#alloc(n, e)) loop { assert false };
    case (#thunk(n))
      switch (engine.get(n)) {
        case (#err(_) or #ok(#err _)) #err(#engineError); 
        case (#ok(#ok(res))) switch (ops.getVal(res)) {
          case null { #err(#typeError) };
          case (?v) { #ok(v) };
        };
      };
    case _ loop { assert false };
  // #cons: (Exp<Val_, Error_>, ListMeta, Exp<Val_, Error_>);
  // #nil;
  // #val: Val_;
  // // Sequence operations
  // #toTree: Exp<Val_, Error_>;
  // #toList: Exp<Val_, Error_>;
  // #max: Exp<Val_, Error_>;
  // //#sort: Exp;
  // //#median: Exp;
  // #err: Error_;
    }
  };

};

}
