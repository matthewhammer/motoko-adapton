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
// Read "Val_" as "Any", but for our DSL system, not for Motoko.
public type Exp<Val_> = {
  // arrays for small test inputs, and little else.
  #array: [ (Exp<Val_>, Meta.Meta) ];
  // each `#put` case transforms into an #at case *before any evaluation*.
  #put: (Name, Exp<Val_>);
  // `#at` case permits fine-grained re-use / re-evaluation via Adapton names.
  #at: Name;
  // Stream-literal definition/construction
  #cons: { head: Exp<Val_>; meta: Exp<Val_>; tail: Exp<Val_> };
  #nil;
  #val: Val_;
  // Sequence operations
  #streamOfArray: Exp<Val_>;
  #treeOfStream: Exp<Val_>;
  #treeOfStreamRec: TreeOfStreamRec<Val_>;
  #maxOfTree: Exp<Val_>;
  //#sort: Exp;
  //#median: Exp;
};

public type TreeOfStreamRec<Val_> = {
  parentLevel : ?Nat;
  stream : Stream<Val_>;
  subTree : Tree<Val_>
};

public type Array<Val_> = [ (Val<Val_>, Meta.Meta) ];

public type ArrayStream<Val_> = {
  array : Array<Val_>;
  offset : Nat;
};

public type Cons<Val_> = (Val<Val_>, Meta, Val<Val_>);

public type Bin<Val_> = {
  left : Val<Val_>;
  meta : TreeMeta;
  right : Val<Val_>;
};

public type Val<Val_> = {
  // value allocated at a name, stored by an adapton thunk or ref.
  #at: Name;
  // arrays for small test inputs, and little else.
  #array: Array<Val_>;
  // array streams: Special stream where source is a fixed array.
  #arrayStream: ArrayStream<Val_>;
  // empty list; empty tree.
  #nil;
  // lazy list / stream cell: left value is stream "now"; right is stream "later".
  #cons: Cons<Val_>;
  // binary tree: binary case.
  #bin: Bin<Val_>;
  // binary tree: leaf case. *Any* value, from any language module.
  #leaf: Val_;
  // pair of our values.
  #pair: (Val<Val_>, Val<Val_>);
};

/// Cartesian trees as balanced representations for sequences.
public type Tree<Val_> = {
  #nil;
  #bin: Bin<Val_>;
  #leaf: Val_;
  // value allocated at a name, stored by an adapton thunk or ref.
  #at: Name;
};

public type Stream<Val_> = {
  // empty list; empty tree.
  #nil;
  // lazy list / stream cell: left value is stream "now"; right is stream "later".
  #cons: Cons<Val_>;
  // array streams: Special stream where source is a fixed array.
  #arrayStream: ArrayStream<Val_>;
};

/// Each sequence representation has a different run-time type,
/// with associated checks for its operations.
public type SeqType = {
  #array;
  #stream;
  #tree;
  #pair;
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
  getError : Error_ -> ?Error<Val_>;
};

public class Sequence<Val_, Error_, Exp_>(
  engine: Engine.Engine<Name, Val_, Error_, Exp_>,
  ops: Ops<Exp_, Val_, Error_>
) {

  /// Evaluate expression into a result.
  public func eval(e : Exp<Val_>) : R.Result<Val_, Error_> {
    switch (evalRec(alloc(e))) {
      case (#ok(v)) #ok(ops.putVal(v));
      case (#err(e)) #err(ops.putError(e));
    }
  };

  func alloc(e : Exp<Val_>) : Exp<Val_> {
    switch e {
      case (#array(a)) {
        let elms = Buffer.Buffer<(Exp<Val_>, Meta)>(a.size());
        for ((e, meta) in a.vals()) {
          elms.add((alloc e, meta))
        };
        #array(elms.toArray())
      };
      case (#at(n)) #at((n));
      case (#put(n, e)) {
        switch (engine.putThunk(n, ops.putExp(alloc(e)))) {
        case (#err(err)) { loop { assert false } };
        case (#ok(n)) { #at(n) };
        }};
      case (#val(v)) #val(v);
      case (#streamOfArray(e)) #streamOfArray(alloc e);
      case (#treeOfStream(e)) #treeOfStream(alloc e);
      case (#maxOfTree(e)) #maxOfTree(alloc e);
      case (#nil) #nil;
      case (#cons(c)) {
             #cons({head=alloc(c.head); meta=alloc(c.meta); tail=alloc(c.tail)})
           };
      case (#treeOfStreamRec(args)) { #treeOfStreamRec(args) };
    }
  };

  /// Check canonical array forms.
  public func haveArray(v : Val<Val_>) : Result<[(Val<Val_>, Meta)], Val_> {
    switch v {
      case (#array(a)) { #ok(a) };
      case _ { #err(#doNotHave(#array, v)) };
    };
  };

  /// Check canonical stream head form.
  public func haveStream(v : Val<Val_>) : Result<Stream<Val_>, Val_> {
    switch v {
      case (#arrayStream(s)) { #ok(#arrayStream(s)) };
      case (#cons(c)) { #ok(#cons(c)) };
      case (#nil) { #ok(#nil) };
      case _ { #err(#doNotHave(#stream, v)) };
    }
  };

  /// Check canonical tree head form.
  public func haveTree(v : Val<Val_>) : Result<Tree<Val_>, Val_> {
    switch v {
      case (#at n) { #ok(#at(n)) };
      case (#nil) { #ok(#nil) };
      case (#bin(b)) { #ok(#bin(b)) };
      case (#leaf v) { #ok(#leaf(v)) };
      case _ { #err(#doNotHave(#tree, v)) };
    }
  };

  /// Transforms an array into a stream.
  public func streamOfArray(v : Val<Val_>) : EvalResult<Val_> {
    switch(haveArray(v)) {
      case (#ok(array)) { #ok(#arrayStream({array; offset = 0})) };
      case (#err(err)) { #err(err) };
    }
  };

  // Returns the thunk, and its (eagerly-computed) value, as a pair.
  func getPutThunk(name : Name, exp : Exp<Val_>) : EvalResult<Val_> {
    let thunk =
      engine.putThunk(
        name, ops.putExp(exp)
      );
    switch thunk {
      case (#ok(putName)) {
        switch(engine.get(putName)) {
          case (#err(err)) { #err(#engineError) };
          case (#ok(v)) {
            switch(v) {
              case (#ok(v)) {
                switch (ops.getVal(v)) {
                  case null { #err(#engineError) };
                  case (?gotValue) { resultPair(#at(putName), gotValue) };
                }
              };
              case (#err(err)) {
                switch (ops.getError(err)) {
                  case null { #err(#engineError) };
                  case (?e) { #err(e) };
                }
              };
            }
          };
        }
      };
      case (#err(err)) { #err(#engineError) };
    }
  };

  // Does getPutThunk, but only returns the result of the thunk.
  func memo(name : Name, exp : Exp<Val_>) : EvalResult<Val_> {
    switch (getPutThunk(name, exp)) {
      case (#err(e)) #err(e);
      case (#ok(#pair((_, v)))) #ok(v);
      case (#ok(_)) { assert false; loop {}};
    }
  };

  // Does getPutThunk, but returns the thunk and value as a Motoko pair.
  func memo_(name : Name, exp : Exp<Val_>) : Result<(Name, Val<Val_>), Val_> {
    switch (getPutThunk(name, exp)) {
      case (#err(e)) #err(e);
      case (#ok(#pair(#at(n), v))) #ok((n, v));
      case (#ok(_)) { assert false; loop {}};
    }
  };

  /// number of elms; ignore internal nodes
  public func treeSize (t : Tree<Val_>) : Nat {
    switch t {
      case (#at(n)) { assert false; loop {}}; // query engine here?
      case (#nil) 0;
      case (#bin(b)) b.meta.size;
      case (#leaf _) 1;
    }
  };

  public func treeLevel (t : Tree<Val_>) : Nat {
    switch t {
      case (#at(n)) { assert false; loop {}}; // to do -- query engine here?
      case (#nil) 0;
      case (#bin(b)) b.meta.level;
      case (#leaf _) 0;
    }
  };

  public func streamNext (s : Stream<Val_>) : ?Cons<Val_> {
    switch s {
      case (#nil) null;
      case (#arrayStream(a)) {
        if(a.offset < a.array.size()) {
          let (elm, meta) = a.array[a.offset];
          ?(elm, meta, #arrayStream{ offset = a.offset + 1;
                                     array = a.array })
        } else null;
      };
      case (#cons(c)) { ?c }
    }
  };

  public func resultPairSplit(r : EvalResult<Val_>) : Result<(Val<Val_>, Val<Val_>), Val_> {
    switch r {
      case (#ok(#pair(v1, v2))) { #ok((v1, v2)) };
      case (#ok(v)) { #err(#doNotHave(#pair, v)) };
      case (#err(e)) { #err(e) };
    }
  };

  public func resultPair(v1 : Val<Val_>, v2 : Val<Val_>) : EvalResult<Val_> {
    #ok(#pair(v1, v2))
  };

  /// Transforms a stream into a tree.
  public func treeOfStreamRec(parentLevel : ?Nat, s : Stream<Val_>, tree : Tree<Val_>)
    : EvalResult<Val_> // (Tree, Stream), for the result and remaining stream.
  {
    switch (streamNext(s)) {
      case null (resultPair(tree, #nil));
      case (?cons) {
        let (head, meta, tail) = cons;
        switch parentLevel {
          case (?pl) {
            if (meta.level > pl) {
              return resultPair(tree, s)
            } };
          case _ { };
        };
        if (meta.level < treeLevel(tree)) {
          return resultPair(tree, s)
        };
        let tailAsStream = switch (haveStream(s)) {
          case (#ok(s)) s;
          case (#err(e)) { return #err(e) }
        };
        let (tree2, s2) =
          switch (resultPairSplit(memo(
                      #bin(meta.name, #text("right")),
                      #treeOfStreamRec({
                                         parentLevel = ?meta.level;
                                         stream = tailAsStream;
                                         subTree = #leaf(ops.putVal(head));
                                       })))) {
          case (#err(e)) { return #err(e) };
          case (#ok(v1, v2)) (v1, v2);
        };
        let (tree2_, s2_) = switch (haveTree(tree2), haveStream(s2)) {
        case (#ok(t), #ok(s)) (t, s);
        case (#err(e1), _) { return #err(e1) };
        case (_, #err(e2)) { return #err(e2) };
        };
        let size = treeSize(tree) + treeSize(tree2_);
        let tree3 = #bin({ left = tree;
                           meta = { level = meta.level; name = meta.name; size};
                           right = tree2_ });
        memo(
          #bin(meta.name, #text("root")),
          #treeOfStreamRec({
                             parentLevel;
                             stream = s2_;
                             subTree = tree3;
                           }));
           }
    }
  };

  /// Transforms a stream into a tree.
  public func treeOfStream(s : Val<Val_>) : EvalResult<Val_> {
    engine.nest(#text("treeOfStream"), func () : EvalResult<Val_> {
    switch(haveStream(s)) {
      case (#ok(s)) { treeOfStreamRec(null, s, #nil)  };
      case (#err(err)) { #err(err) };
    }});
  };

  func evalRec(exp : Exp<Val_>) : EvalResult<Val_> {
    switch exp {
    case (#val(v)) { #ok(#leaf(v)) };
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
    case (#treeOfStreamRec(args)) {
      treeOfStreamRec(args.parentLevel, args.stream, args.subTree)
    };
    case (#treeOfStream(e)) {
      switch (evalRec(e)) {
        case (#err(err)) { #err(err) };
        case (#ok(list)) { treeOfStream(list) };
      }
    };
    }
  };

};

}
