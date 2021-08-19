/**
 Representation of engine state.
*/
import H "mo:base/HashMap";
import Hash "mo:base/Hash";
import Buffer "mo:base/Buffer";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";

import E "Eval";
import Log "Log";

module {

  // morally, there are 4 user-defined types over which this module is
  // parameterized: Name, Val, Error and Closure.
  // Some types defined below require all four of these abstract parameters.  Some require fewer.

  public type Store<Name, Val, Error, Closure> =
    H.HashMap<Name, Node<Name, Val, Error, Closure>>;

  public type Node<Name, Val, Error, Closure> = {
    #ref:Ref<Name, Val, Error, Closure>;
    #thunk:Thunk<Name, Val, Error, Closure>;
  };

  public type Stack<Name> = L.List<Name>;
  public type EdgeBuf<Name, Val, Error, Closure> = Buffer.Buffer<Edge<Name, Val, Error, Closure>>;

  public type Ref<Name, Val, Error, Closure> = {
    content: Val;
    incoming: EdgeBuf<Name, Val, Error, Closure>;
  };

  public type Thunk<Name, Val, Error, Closure> = {
    closure: Closure;
    result: ?R.Result<Val, Error>;
    outgoing: [Edge<Name, Val, Error, Closure>];
    incoming: EdgeBuf<Name, Val, Error, Closure>;
  };

  public type Edge<Name, Val, Error, Closure> = {
    dependent: Name;
    dependency: Name;
    checkpoint: Action<Val, Error, Closure>;
    var dirtyFlag: Bool
  };

  public type Action<Val, Error, Closure> = {
    #put:Val;
    #putThunk:Closure;
    #get:R.Result<Val, Error>;
  };

  public type PutError = (); // to do
  public type GetError = (); // to do

  public type Context<Name, Val, Error, Closure> = {
    var edges: EdgeBuf<Name, Val, Error, Closure>;
    var stack: Stack<Name>;
    var store: Store<Name, Val, Error, Closure>;
    var logOps : Log.LogOps<Name, Val, Error, Closure>;
    // defined and supplied by the client as Engine class param:
    evalOps: E.EvalOps<Name, Val, Error, Closure>;
    // write-once back-patching for closure evaluation
    var evalClosure: ?E.EvalClosure<Val, Error, Closure>;
  };
}
