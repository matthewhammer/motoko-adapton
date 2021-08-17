/**
Adapton engine.
*/

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
  // class accepts the associated operations over the 4 user-defined type params; See usage instructions in `types/Eval` module
  public class Engine<Name, Val, Error, Closure>
  (
    evalOps : E.EvalOps<Name, Val, Error, Closure>,
    _logFlag : Bool
  ) = Self
  {
    func init(_logFlag:Bool) : G.Context<Name, Val, Error, Closure> {
      let _evalOps = evalOps;
      {
        var agent = (#editor : {#editor; #archivist}); // determined by by isEmpty(stack)

        var edges : G.EdgeBuf<Name, Val, Error, Closure> =
          Buffer.Buffer<G.Edge<Name, Val, Error, Closure>>(0);

        var stack : G.Stack<Name> = null;

        var store : G.Store<Name, Val, Error, Closure> =
          H.HashMap<Name, G.Node<Name, Val, Error, Closure>>(03, _evalOps.nameEq, _evalOps.nameHash);

        evalOps = _evalOps;
        var evalClosure = (null : ?E.EvalClosure<Val, Error, Closure>);

        var logOps : Lg.LogOps<Name, Val, Error, Closure>
          = Log.Logger<Name, Val, Error, Closure>(evalOps, _logFlag);
      }
    };

    // Call exactly once, before any accesses; See usage instructions in `types/Eval` module.
    public func setEvalClosure(evalClosure:E.EvalClosure<Val, Error, Closure>) {
      switch (context.evalClosure) {
        case null { context.evalClosure := ?evalClosure };
        case (?_) { assert false };
      }
    };

    /// put a value with name
    public func put(n:Name, val:Val)
      : R.Result<Name, G.PutError>
      = put_(context, n, val);

    /// put a thunk with name
    public func putThunk(n:Name, clos:Closure)
      : R.Result<Name, G.PutError>
      = putThunk_(context, n, clos);

    /// get a named value, possibly by evaluating thunks, if needed.
    public func get(n:Name)
      : R.Result<{#ok:Val; #err:Error}, G.GetError>
      = get_(context, n);

    /// take the log events (always empty when log is off)
    public func takeLog() : [ Lg.LogEvent<Name, Val, Error, Closure> ] {
      context.logOps.take()
    };

    var context : G.Context<Name, Val, Error, Closure> = init(_logFlag);


    func logBegin
      (c : G.Context<Name, Val, Error, Closure>)
    {
      c.logOps.begin()
    };

    func logEnd
      (c : G.Context<Name, Val, Error, Closure>,
       tag : Lg.LogEventTag<Name, Val, Error, Closure>)
    {
      c.logOps.end(tag)
    };

    func put_(c:G.Context<Name, Val, Error, Closure>, name:Name, val:Val)
      : R.Result<Name, G.PutError>
    {
      logBegin(c);
      let newRefNode : G.Ref<Name, Val, Error, Closure> = {
        incoming=newEdgeBuf();
        content=val;
      };
      switch (c.store.replace(name, #ref(newRefNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) { dirtyThunk(c, name, oldThunk) };
      case (?#ref(oldRef)) {
             if (c.evalOps.valEq(oldRef.content, val)) {
               // matching values ==> no dirtying.
             } else {
               dirtyRef(c, name, oldRef)
             }
           };
      };
      addEdge(c, name, #put(val));
      logEnd(c, #put(name, val));
      #ok(name)
    };

    func putThunk_(c:G.Context<Name, Val, Error, Closure>, name:Name, cl:Closure)
      : R.Result<Name, G.PutError>
    {
      logBegin(c);
      let newThunkNode : G.Thunk<Name, Val, Error, Closure> = {
        incoming=newEdgeBuf();
        outgoing=[];
        result=null;
        closure=cl;
      };
      switch (c.store.replace(name, #thunk(newThunkNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) {
             if (evalOps.closureEq(oldThunk.closure, cl)) {
               // matching closures ==> no dirtying.
             } else {
               newThunkNode.incoming.append(oldThunk.incoming);
               dirtyThunk(c, name, oldThunk)
             }
           };
      case (?#ref(oldRef)) { dirtyRef(c, name, oldRef) };
      };
      addEdge(c, name, #putThunk(cl));
      logEnd(c, #putThunk(name, cl));
      #ok(name)
    };

    func get_(c:G.Context<Name, Val, Error, Closure>, name:Name)
      : R.Result<{#ok:Val;#err:Error}, G.GetError>
    {
      logBegin(c);
      switch (c.store.get(name)) {
      case null { #err(()) /* error: dangling/forged name posing as live node id. */ };
      case (?#ref(refNode)) {
             let val = refNode.content;
             let res = #ok(val);
             logEnd(c, #get(name, res));
             addEdge(c, name, #get(res));
             #ok(res)
           };
      case (?#thunk(thunkNode)) {
             switch (thunkNode.result) {
             case null {
                    let res = evalThunk(c, name, thunkNode);
                    logEnd(c, #get(name, res));
                    addEdge(c, name, #get(res));
                    #ok(res)
                  };
             case (?oldResult) {
                    if (thunkIsDirty(thunkNode)) {
                      if(cleanThunk(c, name, thunkNode)) {
                        logEnd(c, #get(name, oldResult));
                        addEdge(c, name, #get(oldResult));
                        #ok(oldResult)
                      } else {
                        let res = evalThunk(c, name, thunkNode);
                        logEnd(c, #get(name, res));
                        addEdge(c, name, #get(res));
                        #ok(res)
                      }
                    } else {
                      logEnd(c, #get(name, oldResult));
                      addEdge(c, name, #get(oldResult));
                      #ok(oldResult)
                    }
                  };
             }
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

    func addBackEdge(c:G.Context<Name, Val, Error, Closure>, edge:G.Edge<Name, Val, Error, Closure>) {
      switch (c.store.get(edge.dependency)) {
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

    func remBackEdge(c:G.Context<Name, Val, Error, Closure>, edge:G.Edge<Name, Val, Error, Closure>) {
      switch (c.store.get(edge.dependency)) {
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

    func addBackEdges(c:G.Context<Name, Val, Error, Closure>, edges:[G.Edge<Name, Val, Error, Closure>]) {
      for (i in edges.keys()) {
        addBackEdge(c, edges[i])
      }
    };

    func remBackEdges(c:G.Context<Name, Val, Error, Closure>, edges:[G.Edge<Name, Val, Error, Closure>]) {
      for (i in edges.keys()) {
        remBackEdge(c, edges[i])
      }
    };

    func addEdge(c:G.Context<Name, Val, Error, Closure>, target:Name, action:G.Action<Val, Error, Closure>) {
      let edge = switch (c.agent) {
      case (#editor) { /* the editor role is not recorded or memoized */ };
      case (#archivist) {
             switch (c.stack) {
             case null { P.unreachable() };
             case (?(source, _)) {
                    let edge = newEdge(source, target, action);
                    c.edges.add(edge)
                  };
             }
           };
      };
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

    func dirtyThunk(c:G.Context<Name, Val, Error, Closure>, n:Name, thunkNode:G.Thunk<Name, Val, Error, Closure>) {
      // to do: if the node is on the stack,
      //   then the DCG is overwriting names
      //   too often for change propagation to follow soundly; signal an error.
      //
      // to do: if we carry the "original put name" with our dirty
      //   traversals, we can report about the overused name that causes this error,
      //   and its detection here (usually non-locally within the DCG, at another name, always of a thunk).
      logBegin(c);
      if (stackContainsNodeName(c.stack, n)) {
        // to do: the node to dirty is currently running; the program is overusing a name
        // #err(#archivistNameOveruse(c.stack, n))
        assert false
      };
      for (edge in thunkNode.incoming.vals()) {
        dirtyEdge(c, edge)
      };
      logEnd(c, #dirtyIncomingTo(n));
    };

    func dirtyRef(c:G.Context<Name, Val, Error, Closure>, n:Name, refNode:G.Ref<Name, Val, Error, Closure>) {
      logBegin(c);
      for (edge in refNode.incoming.vals()) {
        dirtyEdge(c, edge)
      };
      logEnd(c, #dirtyIncomingTo(n));
    };

    func dirtyEdge(c:G.Context<Name, Val, Error, Closure>, edge:G.Edge<Name, Val, Error, Closure>) {
      if (edge.dirtyFlag) {
        // graph invariants ==> dirtying is already done.
      } else {
        logBegin(c);
        edge.dirtyFlag := true;
        switch (c.store.get(edge.dependent)) {
        case null { P.unreachable() };
        case (?#ref(_)) { P.unreachable() };
        case (?#thunk(thunkNode)) {
               dirtyThunk(c, edge.dependent, thunkNode)
             };
        };
        logEnd(c, #dirtyEdgeFrom(edge.dependent));
      }
    };

    func optionResultEq (r1:?{#ok:Val; #err:Error}, r2:?{#ok:Val; #err:Error}) : Bool {
      switch (r1, r2) {
        case (null, null) { true };
        case (?r1, ?r2) { resultEq(r1, r2) };
        case _ { false };
      }
    };

    func resultEq (r1:{#ok:Val; #err:Error}, r2:{#ok:Val; #err:Error}) : Bool {
      switch (r1, r2) {
        case (#ok(v1), #ok(v2)) { evalOps.valEq(v1, v2) };
        case (#err(e1), #err(e2)) { evalOps.errorEq(e1, e2) };
        case _ false;
      };
    };

    func cleanEdge(c:G.Context<Name, Val, Error, Closure>, e:G.Edge<Name, Val, Error, Closure>) : Bool {
      logBegin(c);
      let successFlag = if (e.dirtyFlag) {
        switch (e.checkpoint, c.store.get(e.dependency)) {
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
               if (not cleanThunk(c, e.dependency, thunkNode)) {
                 ignore evalThunk(c, e.dependency, thunkNode);
               };
               // now, we care about
               // equality test of old observation vs latest observation on edge,
               // post-cleaning, regardless of cases above.
               let thunkNode2 = switch(c.store.get(e.dependency)) {
                 case (?#thunk(tn)) { tn };
                 case _ { loop { assert false } };
               };
               if (optionResultEq(?oldRes, thunkNode2.result)) {
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
      logEnd(c, #cleanEdgeTo(e.dependency, successFlag));
      successFlag;
    };

    func cleanThunk(c:G.Context<Name, Val, Error, Closure>, n:Name, t:G.Thunk<Name, Val, Error, Closure>) : Bool {
      logBegin(c);
      if (switch(t.result) { case null true; case _ false }) {
        // no cache result and in demand ==> we must evaluate thunk (from scratch):
        // now the thunk is "clean" (always an invariant post evaluation).
        ignore evalThunk(c, n, t);
        logEnd(c, #cleanThunk(n, true));
        return true
      } else {
        for (i in t.outgoing.keys()) {
          if (cleanEdge(c, t.outgoing[i])) {
            /* continue */
          } else {
            logEnd(c, #cleanThunk(n, false));
            return false // outgoing[i] could not be cleaned.
          }
        }
      };
      logEnd(c, #cleanThunk(n, true));
      true
    };

    func stackContainsNodeName(s:G.Stack<Name>, nodeName:Name) : Bool {
      L.some<Name>(s, func (n:Name) : Bool { evalOps.nameEq(n, nodeName) })
    };

    func evalThunk
      (c:G.Context<Name, Val, Error, Closure>,
       nodeName:Name,
       thunkNode:G.Thunk<Name, Val, Error, Closure>)
      : R.Result<Val, Error>
    {
      logBegin(c);
      let oldEdges = c.edges;
      let oldStack = c.stack;
      let oldAgent = c.agent;
      // if nodeName exists on oldStack, then we have detected a cycle.
      if (stackContainsNodeName(oldStack, nodeName)) {
        return #err(evalOps.cyclicDependency(oldStack, nodeName))
      };
      c.agent := #archivist;
      c.edges := Buffer.Buffer(0);
      c.stack := ?(nodeName, oldStack);
      remBackEdges(c, thunkNode.outgoing);
      let res = switch (c.evalClosure) {
        case null { assert false; loop { } };
        case (?closureEval) { closureEval.eval(thunkNode.closure) };
      };
      let edges = c.edges.toArray();
      c.agent := oldAgent;
      c.edges := oldEdges;
      c.stack := oldStack;
      let newNode = {
        closure=thunkNode.closure;
        result=?res;
        outgoing=edges;
        incoming=newEdgeBuf();
      };
      c.store.put(nodeName, #thunk(newNode));
      addBackEdges(c, newNode.outgoing);
      logEnd(c, #evalThunk(nodeName, res));
      res
    };

  } // class Engine

}
