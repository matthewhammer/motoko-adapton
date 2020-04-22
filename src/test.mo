import T "types";
import A "adapton2";
import E "eval";
import Draw "draw";

// the `E` part of a Cloud-backed `REPL` for the CleanSheets lang.

actor {
  public type Env = T.Eval.Env;
  public type Name = T.Eval.Name;
  public type Exp = T.Eval.Exp;
  public type Result = T.Eval.Result;

  var env : Env = null;
  var adaptonCtx : T.Adapton.Context = A.init(true);

  public func eval(n:?Name, e:Exp) : async Result {
    let res = E.evalExp(adaptonCtx, env, e);
    env := { switch (n, res) {
             case (?n, #ok(val)) { ?((n, val), env) };
             case (_, _) { env };
             }};
    res
  };

  public func put(n:Name, e:Exp) : async Result {
    let res = E.evalExp(adaptonCtx, env, #put(#name(n), e));
    // re-use the name n, updating the environment on success:
    env := { switch (res) {
             case (#ok(val)) { ?((n, val), env) };
             case (_) { env };
             }};
    res
  };

  public func putThunk(n:Name, e:Exp) : async Result {
    let res = E.evalExp(adaptonCtx, env, #putThunk(#name(n), e));
    // re-use the name n, updating the environment on success:
    env := { switch (res) {
             case (#ok(val)) { ?((n, val), env) };
             case (_) { env };
             }};
    res
  };

  public func get(e:Exp) : async Result {
    E.evalExp(adaptonCtx, env, #get(e))
  };

  public func getLastLogEvent() : async ?T.Adapton.LogEvent {
    A.getLogEventLast(adaptonCtx)
  };


  public func drawEnv() : async Draw.Result {
    let r = Draw.begin();
    Draw.env(r, env);
    #ok(#redraw([("env", r.getElm())]))
  };

  public func drawGraph() : async Draw.Result {
    let r = Draw.begin();
    Draw.graph(r, adaptonCtx);
    #ok(#redraw([("dcg", r.getElm())]))
  };

  public func drawLast() : async Draw.Result {
    let r = Draw.begin();
    switch (A.getLogEventLast(adaptonCtx)) {
      case null { };
      case (?ev) { Draw.logEvent(r, ev) };
    };
    #ok(#redraw([("last", r.getElm())]))
  };

}

/* To do in the future:

 - Nice UI that looks like a Cloud-based data science notebook
   (e.g., https://jupyter.org/), or the basic outlines of one.

 - `eval` function uses caller ID to save
   per-caller resources (environments and adapton contexts).

 - more complete formula features, and more end-to-end tests...

 - inter-canister dependencies and inter-canister updates.

*/
