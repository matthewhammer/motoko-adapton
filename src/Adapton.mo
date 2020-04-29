/** Adapton in Motoko, as a class-based generic "functor".

This module defines a general-purpose cache and dependence graph
system.  See `EvalType` module for details about its parameters.

In brief, the client of this API chooses 4 representations
for a customized incremental interpter that they define:

 - `Name` -- the identity of cached information; must be unique.
 - `Val` -- the type of data stored in Named Refs, and produced by successfully-evaluated Closures.
 - `Error` -- the type of data produced when evaluation errors occur. Misusing the cache can also produce Errors.
 - `Closure` -- the representation of suspended computations stored in Named Thunks.

## Cache operations

Using the types chosen above, the Engine exposes three important cache operations:

 - `put` a Value into a Ref, located at a Name.

 - `putThunk` a suspended Closure into a Thunk, located at a Name.

 - `get` the Value of a Ref, or the result of evaluating a Thunk, by its Name.

## Incremental caching and re-computation is automatic

Behind the scenes, Adapton caches the results and dependencies of
user-defined thunks as they evaluate.

Sometimes, a single thunk is demanded repeatedly amidst a series of
changes (via `put` or `putThunk`).  When a previously-evaluated thunk
is not "stale", Adapton reuses its past cached results and avoids
recomputing it.  However, when these cached results are stale, Adapton
will automatically recompute them and update its cache information, in
place.  An overview of more details are below, and they consist of
"dirtying" and "cleaning" operations over the graph that preserve its
invariants.  See adapton.org for papers and the underlying theory.


## Details: Cleaning and dirtying algorithms

The algorithms in this module are only used by Adapton, not
externally.  They permit the main API (put, putThunk, get) to dirty
and clean edges while enforcing certain invariants, given below.

### Graph definitions:

- Each node is either a ref node or a thunk node.

- Each edge is directed and arises from a thunk node;
  its target can either be a thunk node or a ref node.

- An edge is either dirty or clean.

- A thunk node is dirty if and only if it has at least one outgoing dirty edge.

- Ref nodes are never themselves dirty, but their dependent (incoming)
  edges can _each_ be dirty or clean.  When at least one such edge is
  dirty for a ref node, we have encoded a situation where the ref node
  changes to a "new" value, distinct from at least _some_ past recorded
  action on this dirty edge.

### Clean/dirty invariant

The clean/dirty invariant for each edge is a global one, over the
status of the entire graph:

 - If an edge `E` is dirty, then all its dependent
   ("up-demand-dep"/incoming) edges are also dirty:

   `for all E2 in upFrom(E), isDirty(E2)`

 - If an edge `E` is clean, then all of its dependencies
   ("down-demand-dep"/outgoing) edges are also clean:

   `for all E2 in downFrom(E), not(isDirty(E2))`

The sets of edges `upFrom(E)` and `downFrom(E)` used above denote the
transitive closure of edges that forms by following the dependent
direction of each edge, or dependency direction of each edge,
respectively.

### Further discussion

- All node identities used here are determined by explicit, user-provided names.

- Nominal Adapton (here) supports "classic Adapton" by choosing names
  structurally, as "full hashes"; we do not yet directly support that
  usage here, but it could be easily added later as another feature.

- This code is based on these two Adapton papers:

  1. [Incremental Computation with Names](https://arxiv.org/abs/1503.07792)

  2. [Adapton: composable, demand-driven incremental computation](https://dl.acm.org/doi/abs/10.1145/2666356.2594324)

*/

import H "mo:base/hashMap";
import Hash "mo:base/hash";
import Buf "mo:base/buf";
import L "mo:base/list";
import R "mo:base/result";
import P "mo:base/prelude";

import E "EvalType";
import G "GraphType";

import Draw "Draw";

module {
  // class accepts the associated operations over the 4 user-defined type params; See usage instructions in `EvalType` module
  public class Engine<Name, Val, Error, Closure>(evalOps:E.EvalOps<Name, Val, Error, Closure>, _logFlag:Bool) = Self {

    /* Initialize */

    func init(_logFlag:Bool) : G.Context<Name, Val, Error, Closure> {
      let _evalOps = evalOps;
      {
        var agent = (#editor : {#editor; #archivist});

        var edges : G.EdgeBuf<Name, Val, Error, Closure> =
          Buf.Buf<G.Edge<Name, Val, Error, Closure>>(0);

        var stack : G.Stack<Name> = null;

        var store : G.Store<Name, Val, Error, Closure> =
          H.HashMap<Name, G.Node<Name, Val, Error, Closure>>(03, _evalOps.nameEq, _evalOps.nameHash);

        var logFlag = _logFlag;

        var logBuf : G.LogEventBuf<Name, Val, Error, Closure> =
          Buf.Buf<G.LogEvent<Name, Val, Error, Closure>>(0);

        var logStack : G.LogBufStack<Name, Val, Error, Closure> = null;
        evalOps = _evalOps;
        var evalClosure = (null : ?E.EvalClosure<Val, Error, Closure>);
      }
    };

    // Call exactly once, before any accesses; See usage instructions in `EvalType` module.
    public func setEvalClosure(evalClosure:E.EvalClosure<Val, Error, Closure>) {
      switch (context.evalClosure) {
        case null { context.evalClosure := ?evalClosure };
        case (?_) { assert false };
      }
    };

    /* A distinguished context for the Main API */

    public var context : G.Context<Name, Val, Error, Closure> = init(_logFlag);

    /* Main API: put, putThunk, and get */

    public func put(n:Name, val:Val)
      : R.Result<Name, G.PutError>
      = contextPut(context, n, val);

    public func putThunk(n:Name, clos:Closure)
      : R.Result<Name, G.PutError>
      = contextPutThunk(context, n, clos);

    public func get(n:Name)
      : R.Result<{#ok:Val; #err:Error}, G.GetError>
      = contextGet(context, n);

    /* Public utilities */

    public var draw : Draw.Draw<Name, Val, Error, Closure> =
      Draw.Draw<Name, Val, Error, Closure>(Self);

    public func resultEq (r1:{#ok:Val; #err:Error}, r2:{#ok:Val; #err:Error}) : Bool {
      switch (r1, r2) {
        case (#ok(v1), #ok(v2)) { evalOps.valEq(v1, v2) };
        case (#err(e1), #err(e2)) { evalOps.errorEq(e1, e2) };
        case _ false;
      };
    };

    public func logEventsEq (e1:[G.LogEvent<Name, Val, Error, Closure>],
                             e2:[G.LogEvent<Name, Val, Error, Closure>]) : Bool {
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

    public func logEventEq (e1:G.LogEvent<Name, Val, Error, Closure>,
                            e2:G.LogEvent<Name, Val, Error, Closure>) : Bool {
      switch (e1, e2) {
      case (#put(n1, v1, es1), #put(n2, v2, es2)) {
             evalOps.nameEq(n1, n2) and evalOps.valEq(v1, v2) and logEventsEq(es1, es2)
           };
      case (#putThunk(n1, c1, es1), #putThunk(n2, c2, es2)) {
             P.nyi()
           };
      case (#get(n1, r1, es1), #get(n2, r2, es2)) {
             evalOps.nameEq(n1, n2) and resultEq(r1, r2) and logEventsEq(es1, es2)
           };
      case (#dirtyIncomingTo(n1, es1), #dirtyIncomingTo(n2, es2)) {
             evalOps.nameEq(n1, n2) and logEventsEq(es1, es2)
           };
      case (#dirtyEdgeFrom(n1, es1), #dirtyEdgeFrom(n2, es2)) {
             evalOps.nameEq(n1, n2) and logEventsEq(es1, es2)
           };
      case (#cleanEdgeTo(n1, f1, es1), #cleanEdgeTo(n2, f2, es2)) {
             evalOps.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
           };
      case (#cleanThunk(n1, f1, es1), #cleanThunk(n2, f2, es2)) {
            evalOps.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
           };
      case (#evalThunk(n1, r1, es1), #evalThunk(n2, r2, es2)) {
             evalOps.nameEq(n1, n2) and resultEq(r1, r2) and logEventsEq(es1, es2)
           };
      case (_, _) {
             false
           }
      }

    };

    // note: the log is just for output, for human-based debugging;
    // it is not to used by evaluation logic, nor by our algorithms here.
    public func getLogEvents() : [G.LogEvent<Name, Val, Error, Closure>] {
      switch (context.agent) {
      case (#editor) { context.logBuf.toArray() };
      case (#archivist) { assert false ; loop { } };
      }
    };

    public func getLogEventLast() : ?G.LogEvent<Name, Val, Error, Closure> {
      if (context.logBuf.len() > 0) {
        ?context.logBuf.get(context.logBuf.len() - 1)
      } else {
        null
      }
    };

    // assert last log event
    public func assertLogEventLast(expected:G.LogEvent<Name, Val, Error, Closure>) {
      let logLen = context.logBuf.len();
      if (logLen > 0) {
        let actual = context.logBuf.get(logLen - 1);
        assert logEventEq(actual, expected)
      } else { // no log event
        assert false
      }
    };

    /* Context-parametric versions of the core API --- they only use `evalOps` (not the `context` var).

     We do not /need/ these, but they demonstrate another design.
     */

    public func contextPut(c:G.Context<Name, Val, Error, Closure>, name:Name, val:Val)
      : R.Result<Name, G.PutError>
    {
      beginLogEvent(c);
      let newRefNode : G.Ref<Name, Val, Error, Closure> = {
        incoming=newEdgeBuf();
        content=val;
      };
      switch (c.store.swap(name, #ref(newRefNode))) {
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
      endLogEvent(c, #put(name, val));
      #ok(name)
    };

    public func contextPutThunk(c:G.Context<Name, Val, Error, Closure>, name:Name, cl:Closure)
      : R.Result<Name, G.PutError>
    {
      beginLogEvent(c);
      let newThunkNode : G.Thunk<Name, Val, Error, Closure> = {
        incoming=newEdgeBuf();
        outgoing=[];
        result=null;
        closure=cl;
      };
      switch (c.store.swap(name, #thunk(newThunkNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) {
             if (evalOps.closureEq(oldThunk.closure, cl)) {
               // matching closures ==> no dirtying.
             } else {
               dirtyThunk(c, name, oldThunk)
             }
           };
      case (?#ref(oldRef)) { dirtyRef(c, name, oldRef) };
      };
      addEdge(c, name, #putThunk(cl));
      endLogEvent(c, #putThunk(name, cl));
      #ok(name)
    };

    public func contextGet(c:G.Context<Name, Val, Error, Closure>, name:Name)
      : R.Result<{#ok:Val;#err:Error}, G.GetError>
    {
      beginLogEvent(c);
      switch (c.store.get(name)) {
      case null { #err(()) /* error: dangling/forged name posing as live node id. */ };
      case (?#ref(refNode)) {
             let val = refNode.content;
             let res = #ok(val);
             endLogEvent(c, #get(name, res));
             addEdge(c, name, #get(res));
             #ok(res)
           };
      case (?#thunk(thunkNode)) {
             switch (thunkNode.result) {
             case null {
                    assert (thunkNode.incoming.len() == 0);
                    let res = evalThunk(c, name, thunkNode);
                    endLogEvent(c, #get(name, res));
                    addEdge(c, name, #get(res));
                    #ok(res)
                  };
             case (?oldResult) {
                    if (thunkIsDirty(thunkNode)) {
                      if(cleanThunk(c, name, thunkNode)) {
                        endLogEvent(c, #get(name, oldResult));
                        addEdge(c, name, #get(oldResult));
                        #ok(oldResult)
                      } else {
                        let res = evalThunk(c, name, thunkNode);
                        endLogEvent(c, #get(name, res));
                        addEdge(c, name, #get(res));
                        #ok(res)
                      }
                    } else {
                      endLogEvent(c, #get(name, oldResult));
                      addEdge(c, name, #get(oldResult));
                      #ok(oldResult)
                    }
                  };
             }
           };
      }
    };

    /* Private implementation details --- Change propagation (aka, "dirtying and cleaning") algorithms below.  */

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
             for (existing in edgeBuf.iter()) {
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
               Buf.Buf<G.Edge<Name, Val, Error, Closure>>(0);
             for (incomingEdge in nodeIncoming.iter()) {
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

    func newEdgeBuf() : G.EdgeBuf<Name, Val, Error, Closure> { Buf.Buf<G.Edge<Name, Val, Error, Closure>>(03) };

    func thunkIsDirty(t:G.Thunk<Name, Val, Error, Closure>) : Bool {
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
      beginLogEvent(c);
      if (stackContainsNodeName(c.stack, n)) {
        // to do: the node to dirty is currently running; the program is overusing a name
        // #err(#archivistNameOveruse(c.stack, n))
        assert false
      };
      for (edge in thunkNode.incoming.iter()) {
        dirtyEdge(c, edge)
      };
      endLogEvent(c, #dirtyIncomingTo(n));
    };

    func dirtyRef(c:G.Context<Name, Val, Error, Closure>, n:Name, refNode:G.Ref<Name, Val, Error, Closure>) {
      beginLogEvent(c);
      for (edge in refNode.incoming.iter()) {
        dirtyEdge(c, edge)
      };
      endLogEvent(c, #dirtyIncomingTo(n));
    };

    func dirtyEdge(c:G.Context<Name, Val, Error, Closure>, edge:G.Edge<Name, Val, Error, Closure>) {
      if (edge.dirtyFlag) {
        // graph invariants ==> dirtying is already done.
      } else {
        beginLogEvent(c);
        edge.dirtyFlag := true;
        switch (c.store.get(edge.dependent)) {
        case null { P.unreachable() };
        case (?#ref(_)) { P.unreachable() };
        case (?#thunk(thunkNode)) {
               dirtyThunk(c, edge.dependent, thunkNode)
             };
        };
        endLogEvent(c, #dirtyEdgeFrom(edge.dependent));
      }
    };

    func cleanEdge(c:G.Context<Name, Val, Error, Closure>, e:G.Edge<Name, Val, Error, Closure>) : Bool {
      beginLogEvent(c);
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
               let oldRes = switch (thunkNode.result) {
               case (?res) { res };
               case null { P.unreachable() };
               };
               // dirty flag true ==> we must re-evaluate thunk:
               let newRes = evalThunk(c, e.dependency, thunkNode);
               if (resultEq(oldRes, newRes)) {
                 e.dirtyFlag := false;
                 true // equal results ==> clean.
               } else {
                 false // changed result ==> thunk could not be cleaned.
               }
             };
        case (_, _) {
               P.unreachable()
             };
        }
      } else {
        true // already clean
      };
      endLogEvent(c, #cleanEdgeTo(e.dependency, successFlag));
      successFlag;
    };

    func cleanThunk(c:G.Context<Name, Val, Error, Closure>, n:Name, t:G.Thunk<Name, Val, Error, Closure>) : Bool {
      beginLogEvent(c);
      for (i in t.outgoing.keys()) {
        if (cleanEdge(c, t.outgoing[i])) {
          /* continue */
        } else {
          endLogEvent(c, #cleanThunk(n, false));
          return false // outgoing[i] could not be cleaned.
        }
      };
      endLogEvent(c, #cleanThunk(n, true));
      true
    };

    func stackContainsNodeName(s:G.Stack<Name>, nodeName:Name) : Bool {
      L.exists<Name>(s, func (n:Name) : Bool { evalOps.nameEq(n, nodeName) })
    };

    func evalThunk
      (c:G.Context<Name, Val, Error, Closure>,
       nodeName:Name,
       thunkNode:G.Thunk<Name, Val, Error, Closure>)
      : R.Result<Val, Error>
    {
      beginLogEvent(c);
      let oldEdges = c.edges;
      let oldStack = c.stack;
      let oldAgent = c.agent;
      // if nodeName exists on oldStack, then we have detected a cycle.
      if (stackContainsNodeName(oldStack, nodeName)) {
        return #err(evalOps.cyclicDependency(oldStack, nodeName))
      };
      c.agent := #archivist;
      c.edges := Buf.Buf(0);
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
      ignore c.store.set(nodeName, #thunk(newNode));
      addBackEdges(c, newNode.outgoing);
      endLogEvent(c, #evalThunk(nodeName, res));
      res
    };

    func beginLogEvent
      (c:G.Context<Name, Val, Error, Closure>)
    {
      if (c.logFlag) {
        c.logStack := ?(c.logBuf, c.logStack);
        c.logBuf := Buf.Buf<G.LogEvent<Name, Val, Error, Closure>>(03);
      }
    };

    func logEvent
      (tag:G.LogEventTag<Name, Val, Error, Closure>,
       events:[G.LogEvent<Name, Val, Error, Closure>])
      : G.LogEvent<Name, Val, Error, Closure>
    {
      switch tag {
      case (#put(v, n))      { #put(v, n,      events) };
      case (#putThunk(c, n)) { #putThunk(c, n, events) };
      case (#get(r, n))      { #get(r, n,      events) };
      case (#dirtyIncomingTo(n)){ #dirtyIncomingTo(n,events) };
      case (#dirtyEdgeFrom(n)){ #dirtyEdgeFrom(n,events) };
      case (#cleanEdgeTo(n,f)) { #cleanEdgeTo(n,f,events) };
      case (#cleanThunk(n,f)) { #cleanThunk(n,f,events) };
      case (#evalThunk(n,r)) { #evalThunk(n,r,events) };
      }
    };

    func endLogEvent
      (c:G.Context<Name, Val, Error, Closure>,
       tag:G.LogEventTag<Name, Val, Error, Closure>)
    {
      if (c.logFlag) {
        switch (c.logStack) {
        case null { assert false };
        case (?(prevLogBuf, logStack)) {
               let events = c.logBuf.toArray();
               let ev = logEvent(tag, events);
               c.logStack := logStack;
               c.logBuf := prevLogBuf;
               c.logBuf.add(ev);
             }
        }
      }
    };

  } // class Engine

}
