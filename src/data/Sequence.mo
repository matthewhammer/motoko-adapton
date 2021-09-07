import Engine "../Engine";
import Meta "Meta";

import H "mo:base/Hash";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";

module {

public type Name = Meta.Name;

public type Meta = Meta.Meta;

public type TreeMeta = {
  name : Name;
  level : Meta.Level;
  size : Nat
};

// Expresssions serve as "spreadsheet formula" for sequences.
public type Exp<Val_> = {
  // arrays for small test inputs, and little else.
  #array: [ (Exp<Val_>, Meta.Meta) ];
  // each `#put` case transforms into an #at case *before any evaluation*.
  #put: (Name, Exp<Val_>);
  // `#at` case permits fine-grained re-use / re-evaluation via Adapton names.
  #at: Name;
  // Stream-literal definition/construction
  #cons: (Exp<Val_>, Meta, Exp<Val_>);
  #nil;
  #val: Val_;
  // Sequence operations
  #streamOfArray: Exp<Val_>;
  #treeOfStream: Exp<Val_>;
  #maxOfTree: Exp<Val_>;
  //#sort: Exp;
  //#median: Exp;
};

public type Val<Val_> = {
  // arrays for small test inputs, and little else.
  #array: [ (Val<Val_>, Meta.Meta) ];
  // empty list; empty tree.
  #nil;
  // lazy list / stream cell: left value is stream "now"; right is stream "later".
  #cons: (Val<Val_>, Meta, Val<Val_>);
  // binary tree: left/right values are sub-trees.
  #bin: (Val<Val_>, TreeMeta, Val<Val_>);
  #at: Name;
  #val: Val_;
};

/// Each sequence representation has a different run-time type,
/// with associated checks for its operations.
public type SeqType = {
  #array;
  #stream;
  #tree;
};

/// Result type for all "meta level" operations returning an `X`.
public type Result<X, Val_> = R.Result<X, Error<Val_>>;

/// Evaluation results in a `Val` on success.
public type EvalResult<Val_> = Result<Val<Val_>, Val_>;

public type Error<Val_> = {
  /// Wrong value form: Not from this language module.
  #notOurVal : Val_;
  /// Wrong value form: Type mismatch.
  #doNotHave : (SeqType, Val<Val_>);
  // no max/min/median defined when sequence is empty
  #emptySequence;
  // to do -- improve with separate PR
  #engineError;
};

public type Ops<Exp_, Val_, Error_> = {
  valMax : (Val_, Val_) -> R.Result<Val_, Error_>;
  getVal : Val_ -> ?Val<Val_>;
  putExp : Exp<Val_> -> Exp_;
  getExp : Exp_ -> ?Exp<Val_>;
  putVal : Val<Val_> -> Val_;
  putError : Error<Val_> -> Error_;
};

public class Sequence<Val_, Error_, Exp_>(
  engine: Engine.Engine<Name, Val_, Error_, Exp_>,
  ops: Ops<Exp_, Val_, Error_>
) {

  public func eval(e : Exp<Val_>) : R.Result<Val_, Error_> {
    switch (evalRec(alloc(e))) {
      case (#ok(v)) #ok(ops.putVal(v));
      case (#err(e)) #err(ops.putError(e));
    }
  };

  func alloc(e : Exp<Val_>) : Exp<Val_> {
    switch e {
      case (#at(n)) #at((n));
      case (#put(n, e))
        switch (engine.putThunk(n, ops.putExp(alloc(e)))) {
        case (#err(err)) { loop { assert false } };
        case (#ok(n)) { #at(n) };
      };
      case _ { // to do -- recursive cases
             loop { assert false }
           };
    }
  };

  public func haveArray(arr : Val<Val_>) : Result<[(Val<Val_>, Meta)], Val_> {
    switch arr {
      case (#array(a)) { #ok(a) };
      case _ { #err(#doNotHave(#array, arr)) };
    };
  };

  public func streamOfArray(input : Val<Val_>) : EvalResult<Val_> {
    let array = haveArray(input);
    loop { assert false };
  };

  public func treeOfStream(iter : Val<Val_>) : EvalResult<Val_> {
    loop { assert false }
  };

  func evalRec(exp : Exp<Val_>) : EvalResult<Val_> {
    switch exp {
    case (#put(n, e)) loop { assert false };
    case (#array(arr)) {
           let vals = Buffer.Buffer<(Val<Val_>, Meta)>(arr.size());
           for ((e, meta) in arr.vals()) {
             switch (evalRec(e)) {
               case (#ok(v)) { vals.add((v, meta)) };
               case (#err(e)) { return #err(e) };
             };
           };
           #ok(#array(vals.toArray()))
         };
    case (#at(n))
      switch (engine.get(n)) {
        case (#err(_) or #ok(#err _)) #err(#engineError);
        case (#ok(#ok(res))) switch (ops.getVal(res)) {
          case null { #err(#notOurVal(res)) };
          case (?v) { #ok(v) };
        };
      };
    case (#streamOfArray(a)) {
           switch (evalRec(a)) {
             case (#err(err)) { #err(err) };
             case (#ok(array)) { streamOfArray(array) };
           }
         };
    case (#treeOfStream(e)) {
           switch (evalRec(e)) {
             case (#err(err)) { #err(err) };
             case (#ok(list)) { treeOfStream(list) };
           }
         };
    case _ { loop { assert false } };
  // #cons: (Exp<Val_, Error_>, ListMeta, Exp<Val_, Error_>);
  // #nil;
  // #val: Val_;
  // // Sequence operations
  // #toList: Exp<Val_, Error_>;
  // #max: Exp<Val_, Error_>;
  // //#sort: Exp;
  // //#median: Exp;
  // #err: Error_;
    }
  };

};

}
