import H "mo:base/HashMap";
import Hash "mo:base/Hash";
import Buf "mo:base/Buf";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";

import E "EvalType";
import Log "LogType";

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
  public type EdgeBuf<Name, Val, Error, Closure> = Buf.Buf<Edge<Name, Val, Error, Closure>>;

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

  public type LogEvent<Name, Val, Error, Closure> =
    Log.LogEvent<Name, Val, Error, Closure>;

  public type LogEventTag<Name, Val, Error, Closure> =
    Log.LogEventTag<Name, Val, Error, Closure>;

  public type LogEventBuf<Name, Val, Error, Closure> =
    Buf.Buf<LogEvent<Name, Val, Error, Closure>>;

  public type LogBufStack<Name, Val, Error, Closure> =
    L.List<LogEventBuf<Name, Val, Error, Closure>>;

  public type Context<Name, Val, Error, Closure> = {
    var agent: {#editor; #archivist};
    var edges: EdgeBuf<Name, Val, Error, Closure>;
    var stack: Stack<Name>;
    var store: Store<Name, Val, Error, Closure>;
    // logging for debugging; not essential for other state:
    var logFlag: Bool;
    var logBuf: LogEventBuf<Name, Val, Error, Closure>;
    var logStack: LogBufStack<Name, Val, Error, Closure>;
    // defined and supplied by the client:
    evalOps: E.EvalOps<Name, Val, Error, Closure>;
    var evalClosure: ?E.EvalClosure<Val, Error, Closure>;
  };
}
