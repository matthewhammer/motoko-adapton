/** Adapton engine. */

import H "mo:base/HashMap";
import Hash "mo:base/Hash";
import Buffer "mo:base/Buffer";
import L "mo:base/List";
import R "mo:base/Result";
import P "mo:base/Prelude";

import E "types/Eval";
import G "types/Graph";
import Lg "types/Log";
import Log "Log";

module {
  public type Log<Name, Val, Error, Closure> = Lg.Log<Name, Val, Error, Closure>;

  // class accepts the associated operations over the 4 user-defined type params; See usage instructions in `types/Eval` module
  public class Engine<Name, Val, Error, Closure>
  (
    evalOps : E.EvalOps<Name, Val, Error, Closure>,
    _logFlag : Bool
  ) = ThisEngine
  {
    // Private initialization step, during construction.
    // See also, public init().
    func init0(_logFlag:Bool) : G.Context<Name, Val, Error, Closure> {
      {
        var edges : G.EdgeBuf<Name, Val, Error, Closure> =
          Buffer.Buffer<G.Edge<Name, Val, Error, Closure>>(0);

        var stack : G.Stack<Name> = null;

        var store : G.Store<Name, Val, Error, Closure> =
          H.HashMap<Name, G.Node<Name, Val, Error, Closure>>(03, evalOps.nameEq, evalOps.nameHash);

        evalOps;
        var evalClosure : ?E.EvalClosure<Val, Error, Closure> = null;
        var logOps : Lg.LogOps<Name, Val, Error, Closure>
          = Log.Logger<Name, Val, Error, Closure>(evalOps, _logFlag);
      };
    };

    // Call exactly once, before any uses of engine.
    // See further information in `types/Eval.mo`.
    public func init(evalClosure:E.EvalClosure<Val, Error, Closure>) {
      switch (context.evalClosure) {
        case null { context.evalClosure := ?evalClosure };
        case (?_) { assert false };
      }
    };

    /// take the log events (always empty when log is off)
    public func takeLog() : Log<Name, Val, Error, Closure> {
      context.logOps.take()
    };

    var context : G.Context<Name, Val, Error, Closure> = init0(_logFlag);

    func logBegin() { context.logOps.begin() };
    func logEnd(tag : Lg.LogEventTag<Name, Val, Error, Closure>) {
      context.logOps.end(tag)
    };

    public func put(name:Name, val:Val) : R.Result<Name, G.PutError> {
      logBegin();
      let newRefNode : G.Ref<Name, Val, Error, Closure> = {
        incoming=newEdgeBuf();
        content=val;
      };
      switch (context.store.replace(name, #ref(newRefNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) { dirtyThunk(name, oldThunk) };
      case (?#ref(oldRef)) {
             if (context.evalOps.valEq(oldRef.content, val)) {
               // matching values ==> no dirtying.
             } else {
               dirtyRef(name, oldRef)
             }
           };
      };
      addEdge(name, #put(val));
      logEnd(#put(name, val));
      #ok(name)
    };

    public func putThunk(name:Name, cl:Closure) : R.Result<Name, G.PutError> {
      logBegin();
      let newThunkNode : G.Thunk<Name, Val, Error, Closure> = {
        incoming=newEdgeBuf();
        outgoing=[];
        result=null;
        closure=cl;
      };
      switch (context.store.replace(name, #thunk(newThunkNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) {
             if (evalOps.closureEq(oldThunk.closure, cl)) {
               // matching closures ==> no dirtying.
             } else {
               newThunkNode.incoming.append(oldThunk.incoming);
               dirtyThunk(name, oldThunk)
             }
           };
      case (?#ref(oldRef)) { dirtyRef(name, oldRef) };
      };
      addEdge(name, #putThunk(cl));
      logEnd(#putThunk(name, cl));
      #ok(name)
    };

    public func get(name:Name) : R.Result<{#ok:Val;#err:Error}, G.GetError> {
      logBegin();
      switch (context.store.get(name)) {
      case null { #err(()) /* error: dangling/forged name posing as live node id. */ };
      case (?#ref(refNode)) {
             let val = refNode.content;
             let res = #ok(val);
             logEnd(#get(name, res));
             addEdge(name, #get(res));
             #ok(res)
           };
      case (?#thunk(thunkNode)) {
             let getRes = switch (thunkNode.result) {
               case null { evalThunk(name, thunkNode) };
               case (?_) { cleanThunk(name, thunkNode) };
             };
             addEdge(name, #get(getRes));
             logEnd( #get(name, getRes));
             #ok(getRes)
           };
      }
    };

    func newEdge(source:Name, target:Name, action:G.Action<Val, Error, Closure>)
      : G.Edge<Name, Val, Error, Closure> {
      { dependent=source;
        dependency=target;
        checkpoint=action;
        var dirtyFlag=false;
      }
    };

    func incomingEdgeBuf(n:G.Node<Name, Val, Error, Closure>) : G.EdgeBuf<Name, Val, Error, Closure> {
      switch n {
      case (#ref(n)) { n.incoming };
      case (#thunk(t)) { t.incoming };
      }
    };

    func addBackEdge(edge:G.Edge<Name, Val, Error, Closure>) {
      switch (context.store.get(edge.dependency)) {
      case null { P.unreachable() };
      case (?targetNode) {
             let edgeBuf = incomingEdgeBuf(targetNode);
             for (existing in edgeBuf.vals()) {
               // same edge means same source and action tag; return early.
               if (evalOps.nameEq(edge.dependent,
                                  existing.dependent)) {
                 switch (edge.checkpoint, existing.checkpoint) {
                 case (#get(_), #get(_)) { return () };
                 case (#put(_), #put(_)) { return () };
                 case (#putThunk(_), #putThunk(_)) { return () };
                 case (_, _) { };
                 };
               }
             };
             // not found, so add it:
             edgeBuf.add(edge);
           }
      }
    };

    func remBackEdge(edge:G.Edge<Name, Val, Error, Closure>) {
      switch (context.store.get(edge.dependency)) {
      case (?node) {
             let nodeIncoming = incomingEdgeBuf(node);
             let newIncoming : G.EdgeBuf<Name, Val, Error, Closure> =
               Buffer.Buffer<G.Edge<Name, Val, Error, Closure>>(0);
             for (incomingEdge in nodeIncoming.vals()) {
               if (evalOps.nameEq(edge.dependent,
                                 incomingEdge.dependent)) {
                 // same source, so filter otherEdge out.
                 // (we do not bother comparing actions; it's not required.)
               } else {
                 newIncoming.add(incomingEdge)
               }
             };
             nodeIncoming.clear();
             nodeIncoming.append(newIncoming);
           };
      case _ { assert false };
      }
    };

    func addBackEdges(edges : [G.Edge<Name, Val, Error, Closure>]) {
      for (i in edges.keys()) {
        addBackEdge(edges[i])
      }
    };

    func remBackEdges(edges : [G.Edge<Name, Val, Error, Closure>]) {
      for (i in edges.keys()) {
        remBackEdge(edges[i])
      }
    };

    func addEdge(target : Name, action : G.Action<Val, Error, Closure>) {
      switch (context.stack) {
      case null {  };
      case (?(source, _)) {
             let edge = newEdge(source, target, action);
             context.edges.add(edge)
           };
      }
    };

    func newEdgeBuf() : G.EdgeBuf<Name, Val, Error, Closure> { Buffer.Buffer<G.Edge<Name, Val, Error, Closure>>(03) };

    func thunkIsDirty(t:G.Thunk<Name, Val, Error, Closure>) : Bool {
      assert switch(t.result) { case null false; case _ true };
      for (i in t.outgoing.keys()) {
        if (t.outgoing[i].dirtyFlag) {
          return true
        };
      };
      false
    };

    func dirtyThunk(n : Name, thunkNode : G.Thunk<Name, Val, Error, Closure>) {
      // to do: if the node is on the stack,
      //   then the DCG is overwriting names
      //   too often for change propagation to follow soundly; signal an error.
      //
      // to do: if we carry the "original put name" with our dirty
      //   traversals, we can report about the overused name that causes this error,
      //   and its detection here (usually non-locally within the DCG, at another name, always of a thunk).
      logBegin();
      if (stackContainsNodeName(context.stack, n)) {
        // to do: the node to dirty is currently running; the program is overusing a name
        // #err(#archivistNameOveruse(context.stack, n))
        assert false
      };
      for (edge in thunkNode.incoming.vals()) {
        dirtyEdge(edge)
      };
      logEnd(#dirtyIncomingTo(n));
    };

    func dirtyRef(n : Name, refNode : G.Ref<Name, Val, Error, Closure>) {
      logBegin();
      for (edge in refNode.incoming.vals()) {
        dirtyEdge(edge)
      };
      logEnd(#dirtyIncomingTo(n));
    };

    func dirtyEdge(edge : G.Edge<Name, Val, Error, Closure>) {
      if (edge.dirtyFlag) {
        // graph invariants ==> dirtying is already done.
      } else {
        logBegin();
        edge.dirtyFlag := true;
        switch (context.store.get(edge.dependent)) {
        case null { P.unreachable() };
        case (?#ref(_)) { P.unreachable() };
        case (?#thunk(thunkNode)) {
               dirtyThunk(edge.dependent, thunkNode)
             };
        };
        logEnd(#dirtyEdgeFrom(edge.dependent));
      }
    };

    func resultEq (r1:{#ok:Val; #err:Error}, r2:{#ok:Val; #err:Error}) : Bool {
      switch (r1, r2) {
        case (#ok(v1), #ok(v2)) { evalOps.valEq(v1, v2) };
        case (#err(e1), #err(e2)) { evalOps.errorEq(e1, e2) };
        case _ false;
      };
    };

    func cleanEdge(e:G.Edge<Name, Val, Error, Closure>) : Bool {
      logBegin();
      let successFlag = if (e.dirtyFlag) {
        switch (e.checkpoint, context.store.get(e.dependency)) {
        case (#get(oldRes), ?#ref(refNode)) {
               if (resultEq(oldRes, #ok(refNode.content))) {
                 e.dirtyFlag := false;
                 true
               } else { false }
             };
        case (#put(oldVal), ?#ref(refNode)) {
               if (evalOps.valEq(oldVal, refNode.content)) {
                 e.dirtyFlag := false;
                 true
               } else { false }
             };
        case (#putThunk(oldClosure), ?#thunk(thunkNode)) {
               if (evalOps.closureEq(oldClosure, thunkNode.closure)) {
                 e.dirtyFlag := false;
                 true
               } else { false }
             };
        case (#get(oldRes), ?#thunk(thunkNode)) {
               let cleanRes = cleanThunk(e.dependency, thunkNode);
               if (resultEq(oldRes, cleanRes)) {
                 e.dirtyFlag := false;
                 true // equal results ==> clean edge; reuse it edge.
               } else {
                 false // changed result ==> could not clean edge; must replace.
               }
             };
        case (_, _) {
               loop { assert false }
             };
        }
      } else {
        true // already clean
      };
      logEnd(#cleanEdgeTo(e.dependency, successFlag));
      successFlag;
    };

    func cleanThunk(n : Name, t : G.Thunk<Name, Val, Error, Closure>)
      : R.Result<Val, Error>
    {
      logBegin();
      switch(t.result) {
        case null {
          // no cache result and in demand ==> we must evaluate thunk (from scratch):
          // now the thunk is "clean" (always an invariant post evaluation).
          let res = evalThunk(n, t);
          logEnd(#cleanThunk(n, false)); // false because no dep graph to clean
          res
        };
        case (?oldRes) {
          for (i in t.outgoing.keys()) {
            if (cleanEdge(t.outgoing[i])) {
              /* continue */
            } else {
              let res = evalThunk(n, t);
              logEnd(#cleanThunk(n, false)); // false because we could not clean edge
              return res
            }
          };
          // cleaning success: old result and its dep graph is consistent.
          logEnd(#cleanThunk(n, true));
          oldRes
       };
      }
    };

    func stackContainsNodeName(s:G.Stack<Name>, nodeName:Name) : Bool {
      L.some<Name>(s, func (n:Name) : Bool { evalOps.nameEq(n, nodeName) })
    };

    func evalThunk
      (nodeName:Name,
       thunkNode:G.Thunk<Name, Val, Error, Closure>)
      : R.Result<Val, Error>
    {
      logBegin();
      let oldEdges = context.edges;
      let oldStack = context.stack;
      // if nodeName exists on oldStack, then we have detected a cycle.
      if (stackContainsNodeName(oldStack, nodeName)) {
        return #err(evalOps.cyclicDependency(oldStack, nodeName))
      };
      context.edges := Buffer.Buffer(0);
      context.stack := ?(nodeName, oldStack);
      remBackEdges(thunkNode.outgoing);
      let res = switch (context.evalClosure) {
        case null { assert false; loop { } };
        case (?closureEval) { closureEval.eval(thunkNode.closure) };
      };
      let edges = context.edges.toArray();
      context.edges := oldEdges;
      context.stack := oldStack;
      let newNode = {
        closure=thunkNode.closure;
        result=?res;
        outgoing=edges;
        incoming=newEdgeBuf();
      };
      context.store.put(nodeName, #thunk(newNode));
      addBackEdges(newNode.outgoing);
      logEnd(#evalThunk(nodeName, res));
      res
    };

  } // class Engine

}
