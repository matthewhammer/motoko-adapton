import P "mo:stdlib/prelude";
import Buf "mo:stdlib/buf";
import Hash "mo:stdlib/hash";
import List "mo:stdlib/list";
import H "mo:stdlib/hashMap";
import L "mo:stdlib/list";

module {

// A generic Adapton engine is parameterized by these choices:
public type EvalSig = module {
  type Name;
  nameEq : (n1:Name, n2:Name) -> Bool;
    
  type HashVal;
  nameHash : (n:Name) -> HashVal;

  type Val;
  valEq : (v1:Val, v2:Val) -> Bool;

  type Error;
  errorEq : (err1:Error, err2:Error) -> Bool;

  type Env;  
  envEq : (env1:Env, env2:Env) -> Bool;

  type Exp;
  expEq : (e1:Exp, e2:Exp) -> Bool;
};

// Types that represent Adapton state, and the demanded computation graph (DCG).
public class AdaptonTypes(Eval:EvalSig) {

  public type Closure = {
    env: Eval.Env;
    exp: Eval.Exp;
  };

  public func closureEq(c1:Closure, c2:Closure) : Bool {
    Eval.envEq(c1.env, c2.env)
    and Eval.expEq(c1.exp, c2.exp)
  };

  public type Name = Eval.Name;
  public type Closure = Closure.Closure;
  public type Val = Eval.Val;
  public type Result = Eval.Result;

  public type Store = H.HashMap<Name, Node>;
  public type Stack = L.List<Name>;
  public type EdgeBuf = Buf.Buf<Edge>;

  public type NodeId = {
    name: Name
  };

  public type Ref = {
    content: Val;
    incoming: EdgeBuf;
  };

  public type Thunk = {
    closure: Closure;
    result: ?Result;
    outgoing: [Edge];
    incoming: EdgeBuf;
  };

  public type Edge = {
    dependent: NodeId;
    dependency: NodeId;
    checkpoint: Action;
    var dirtyFlag: Bool
  };

  public type Action = {
    #put:Val;
    #putThunk:Closure;
    #get:Result;
  };

  public type PutError = (); // to do
  public type GetError = (); // to do

  // Logs are tree-structured.
  public type LogEvent = {
    #put:      (Name, Val, [LogEvent]);
    #putThunk: (Name, MissingClosure, [LogEvent]);
    #get:      (Name, Result, [LogEvent]);
    #dirtyIncomingTo:(Name, [LogEvent]);
    #dirtyEdgeFrom:(Name, [LogEvent]);
    #cleanEdgeTo:(Name, Bool, [LogEvent]);
    #cleanThunk:(Name, Bool, [LogEvent]);
    #evalThunk:(Name, Result, [LogEvent]);
  };
  public type MissingClosure = (); // to get the compiler to accept things
  public type LogEventTag = {
    #put:      (Name, Val);
    #putThunk: (Name, MissingClosure);
    #get:      (Name, Result);
    #dirtyIncomingTo:Name;
    #dirtyEdgeFrom: Name;
    #cleanEdgeTo:(Name, Bool);
    #cleanThunk:(Name, Bool);
    #evalThunk:(Name, Result);
  };
  public type LogEventBuf = Buf.Buf<LogEvent>;
  public type LogBufStack = List.List<LogEventBuf>;

  public type Node = {
    #ref:Ref;
    #thunk:Thunk;
  };

  public type Context = {
    var agent: {#editor; #archivist};
    var edges: EdgeBuf;
    var stack: Stack;
    var store: Store;
    // logging for debugging; not essential for other state:
    var logFlag: Bool;
    var logBuf: LogEventBuf;
    var logStack: LogBufStack;
    // initially gives errors; real `eval` is installed by `Eval` module:
    var eval: (Context, Eval.Env, Eval.Exp) -> Eval.Result;
  };

  public func logEventsEq (e1:[LogEvent], e2:[LogEvent]) : Bool {
    if (e1.len() == e2.len()) {
      for (i in e1.keys()) {
        if (logEventEq(e1[i], e2[i])) {
          /* continue */
        } else {
          return false
        }
      };
      true
    } else { false }
  };

  public func logEventEq (e1:LogEvent, e2:LogEvent) : Bool {
    switch (e1, e2) {
    case (#put(n1, v1, es1), #put(n2, v2, es2)) {
           Eval.nameEq(n1, n2) and Eval.valEq(v1, v2) and logEventsEq(es1, es2)
         };
    case (#putThunk(n1, c1, es1), #putThunk(n2, c2, es2)) {
           P.nyi()
         };
    case (#get(n1, r1, es1), #get(n2, r2, es2)) {
           Eval.nameEq(n1, n2) and Eval.resultEq(r1, r2) and logEventsEq(es1, es2)
         };
    case (#dirtyIncomingTo(n1, es1), #dirtyIncomingTo(n2, es2)) {
           Eval.nameEq(n1, n2) and logEventsEq(es1, es2)
         };
    case (#dirtyEdgeFrom(n1, es1), #dirtyEdgeFrom(n2, es2)) {
           Eval.nameEq(n1, n2) and logEventsEq(es1, es2)
         };
    case (#cleanEdgeTo(n1, f1, es1), #cleanEdgeTo(n2, f2, es2)) {
           Eval.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
         };
    case (#cleanThunk(n1, f1, es1), #cleanThunk(n2, f2, es2)) {
           Eval.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
         };
    case (#evalThunk(n1, r1, es1), #evalThunk(n2, r2, es2)) {
           Eval.nameEq(n1, n2) and Eval.resultEq(r1, r2) and logEventsEq(es1, es2)
         };
    case (_, _) {
           false
         }
    }

  };

};

}
