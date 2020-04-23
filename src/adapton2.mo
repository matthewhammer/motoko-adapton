/** Adapton in Motoko, specialized for CleanSheets lang.

This module defines a general-purpose cache and dependence graph
system.  We use it here for CleanSheets.  This Motoko code does not
depend heavily on CleanSheets, however, and can be adapted for other
purposes; it follows an established (published) algorithm.

## Cleaning and dirtying algorithms

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

import E "evalType";

module {

  // morally, there are 5 user-defined types over which this module is
  // parameterized: Env, Exp, Val, Error and Name.
  // Some types defined below require all five of these abstract parameters.  Some require fewer.

  type Closure<Env, Exp> = {
    env: Env;
    exp: Exp;
  };

  public type Store<Name, Val, Error, Env, Exp> =
    H.HashMap<Name, Node<Name, Val, Error, Env, Exp>>;

  public type Node<Name, Val, Error, Env, Exp> = {
    #ref:Ref<Name, Val, Error, Env, Exp>;
    #thunk:Thunk<Name, Val, Error, Env, Exp>;
  };

  public type Stack<Name> = L.List<Name>;
  public type EdgeBuf<Name, Val, Error, Env, Exp> = Buf.Buf<Edge<Name, Val, Error, Env, Exp>>;

  public type Ref<Name, Val, Error, Env, Exp> = {
    content: Val;
    incoming: EdgeBuf<Name, Val, Error, Env, Exp>;
  };

  public type Thunk<Name, Val, Error, Env, Exp> = {
    closure: Closure<Env, Exp>;
    result: R.Result<Val, Error>;
    outgoing: [Edge<Name, Val, Error, Env, Exp>];
    incoming: EdgeBuf<Name, Val, Error, Env, Exp>;
  };

  public type Edge<Name, Val, Error, Env, Exp> = {
    dependent: Name;
    dependency: Name;
    checkpoint: Action<Val, Error, Env, Exp>;
    var dirtyFlag: Bool
  };

  public type Action<Val, Error, Env, Exp> = {
    #put:Val;
    #putThunk:Closure<Env, Exp>;
    #get:R.Result<Val, Error>;
  };

  public type PutError = (); // to do
  public type GetError = (); // to do

  // Logs are tree-structured.
  public type LogEvent<Name, Val, Error, Env, Exp> = {
    #put:      (Name, Val, [LogEvent<Name, Val, Error, Env, Exp>]);
    #putThunk: (Name, Closure<Env, Exp>, [LogEvent<Name, Val, Error, Env, Exp>]);
    #get:      (Name, R.Result<Val, Error>, [LogEvent<Name, Val, Error, Env, Exp>]);
    #dirtyIncomingTo:(Name, [LogEvent<Name, Val, Error, Env, Exp>]);
    #dirtyEdgeFrom:(Name, [LogEvent<Name, Val, Error, Env, Exp>]);
    #cleanEdgeTo:(Name, Bool, [LogEvent<Name, Val, Error, Env, Exp>]);
    #cleanThunk:(Name, Bool, [LogEvent<Name, Val, Error, Env, Exp>]);
    #evalThunk:(Name, R.Result<Val, Error>, [LogEvent<Name, Val, Error, Env, Exp>])
  };
  public type LogEventTag<Name, Val, Error, Env, Exp> = {
    #put:      (Name, Val);
    #putThunk: (Name, Closure<Env, Exp>);
    #get:      (Name, R.Result<Val, Error>);
    #dirtyIncomingTo:Name;
    #dirtyEdgeFrom: Name;
    #cleanEdgeTo:(Name, Bool);
    #cleanThunk:(Name, Bool);
    #evalThunk:(Name, R.Result<Val, Error>);
  };
  public type LogEventBuf<Name, Val, Error, Env, Exp> = Buf.Buf<LogEvent<Name, Val, Error, Env, Exp>>;
  public type LogBufStack<Name, Val, Error, Env, Exp> = L.List<LogEventBuf<Name, Val, Error, Env, Exp>>;


  public type Context<Name, Val, Error, Env, Exp> = {
    var agent: {#editor; #archivist};
    var edges: EdgeBuf<Name, Val, Error, Env, Exp>;
    var stack: Stack<Name>;
    var store: Store<Name, Val, Error, Env, Exp>;
    // logging for debugging; not essential for other state:
    var logFlag: Bool;
    var logBuf: LogEventBuf<Name, Val, Error, Env, Exp>;
    var logStack: LogBufStack<Name, Val, Error, Env, Exp>;
    var eval: E.Eval<Name, Val, Error, Env, Exp>;
  };

  // class accepts the associated operations over the 5 user-defined type params
  public class Engine<_Name, _Val, _Error, _Env, _Exp>(Eval:E.Eval<_Name, _Val, _Error, _Env, _Exp>) {
    // to do: define the public interface of Adapton using Eval to implement expression evaluation ...
    // ... by following original cleanSheets implementation (mostly copying it, now commented out below).

/*
    public func closureEq(c1:Closure, c2:Closure) : Bool {
      Eval.envEq(c1.env, c2.env)
      and Eval.expEq(c1.exp, c2.exp)
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


    public func init(_logFlag:Bool) : Context {
      // to do -- compiler bug? -- IR typing issue when this line is inlined to its use below:
      let a : {#editor;#archivist} = (#editor : {#editor;#archivist});
      { var store : Store = H.HashMap<Name, Node>(03, T.Eval.nameEq, T.Eval.nameHash);
        var stack : Stack = null;
        var edges : EdgeBuf = Buf.Buf<Edge>(03);
        var agent = a;
        var logBuf : LogEventBuf = Buf.Buf<T.Adapton.LogEvent>(03);
        var logStack : LogBufStack = null;
        var logFlag = _logFlag;
        var eval = func (c:Context, env:Env, exp:Exp) : Result {
          // hack: this field should be initialized by the Eval module,
          // which depends on this (Adapton) module.
          #err(#uninitializedEvaluatorField)
        };
      }
    };

    // note: the log is just for output, for human-based debugging;
    // it is not to used by evaluation logic, nor by our algorithms here.
    public func getLogEvents(c:Context) : [LogEvent] {
      switch (c.agent) {
      case (#editor) { c.logBuf.toArray() };
      case (#archivist) { assert false ; loop { } };
      }
    };

    public func getLogEventLast(c:Context) : ?LogEvent {
      if (c.logBuf.len() > 0) {
        ?c.logBuf.get(c.logBuf.len())
      } else {
        null
      }
    };

    // assert last log event
    public func assertLogEventLast(c:Context, expected:LogEvent) {
      let logLen = c.logBuf.len();
      if (logLen > 0) {
        let actual = c.logBuf.get(logLen - 1);
        assert T.Adapton.logEventEq(actual, expected)
      } else { // no log event
        assert false
      }
    };

    public func put(c:Context, n:Name, val:Val)
      : R.Result<NodeId, PutError>
    {
      beginLogEvent(c);
      let newRefNode : Ref = {
        incoming=newEdgeBuf();
        content=val;
      };
      switch (c.store.set(n, #ref(newRefNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) { dirtyThunk(c, n, oldThunk) };
      case (?#ref(oldRef)) {
             if (T.Eval.valEq(oldRef.content, val)) {
               // matching values ==> no dirtying.
             } else {
               dirtyRef(c, n, oldRef)
             }
           };
      };
      addEdge(c, {name=n}, #put(val));
      endLogEvent(c, #put(n, val));
      #ok({ name=n })
    };

    public func putThunk(c:Context, n:Name, cl:Closure)
      : R.Result<NodeId, T.Adapton.PutError>
    {
      beginLogEvent(c);
      let newThunkNode : Thunk = {
        incoming=newEdgeBuf();
        outgoing=[];
        result=null;
        closure=cl;
      };
      switch (c.store.set(n, #thunk(newThunkNode))) {
      case null { /* no prior node of this name */ };
      case (?#thunk(oldThunk)) {
             if (T.Closure.closureEq(oldThunk.closure, cl)) {
               // matching closures ==> no dirtying.
             } else {
               dirtyThunk(c, n, oldThunk)
             }
           };
      case (?#ref(oldRef)) { dirtyRef(c, n, oldRef) };
      };
      addEdge(c, {name=n}, #putThunk(cl));
      endLogEvent(c, #putThunk(n, ignore cl));
      #ok({ name=n })
    };

    public func get(c:Context, n:NodeId) : R.Result<Result, GetError> {
      beginLogEvent(c);
      switch (c.store.get(n.name)) {
      case null { #err(()) /* error: dangling/forged name posing as live node id. */ };
      case (?#ref(refNode)) {
             let val = refNode.content;
             let res = #ok(val);
             endLogEvent(c, #get(n.name, res));
             addEdge(c, n, #get(res));
             #ok(res)
           };
      case (?#thunk(thunkNode)) {
             switch (thunkNode.result) {
             case null {
                    assert (thunkNode.incoming.len() == 0);
                    let res = evalThunk(c, n.name, thunkNode);
                    endLogEvent(c, #get(n.name, res));
                    addEdge(c, n, #get(res));
                    #ok(res)
                  };
             case (?oldResult) {
                    if (thunkIsDirty(thunkNode)) {
                      if(cleanThunk(c, n.name, thunkNode)) {
                        endLogEvent(c, #get(n.name, oldResult));
                        addEdge(c, n, #get(oldResult));
                        #ok(oldResult)
                      } else {
                        let res = evalThunk(c, n.name, thunkNode);
                        endLogEvent(c, #get(n.name, res));
                        addEdge(c, n, #get(res));
                        #ok(res)
                      }
                    } else {
                      endLogEvent(c, #get(n.name, oldResult));
                      addEdge(c, n, #get(oldResult));
                      #ok(oldResult)
                    }
                  };
             }
           };
      }
    };

    func newEdge(source:NodeId, target:NodeId, action:Action) : Edge {
      { dependent=source;
        dependency=target;
        checkpoint=action;
        var dirtyFlag=false;
      }
    };

    func incomingEdgeBuf(n:Node) : T.Adapton.EdgeBuf {
      switch n {
      case (#ref(n)) { n.incoming };
      case (#thunk(t)) { t.incoming };
      }
    };

    func addBackEdge(c:Context, edge:Edge) {
      switch (c.store.get(edge.dependency.name)) {
      case null { P.unreachable() };
      case (?targetNode) {
             let edgeBuf = incomingEdgeBuf(targetNode);
             for (existing in edgeBuf.iter()) {
               // same edge means same source and action tag; return early.
               if (T.Eval.nameEq(edge.dependent.name,
                                 existing.dependent.name)) {
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

    func remBackEdge(c:Context, edge:Edge) {
      switch (c.store.get(edge.dependency.name)) {
      case (?node) {
             let nodeIncoming = incomingEdgeBuf(node);
             let newIncoming : EdgeBuf = Buf.Buf<Edge>(03);
             for (incomingEdge in nodeIncoming.iter()) {
               if (T.Eval.nameEq(edge.dependent.name,
                                 incomingEdge.dependent.name)) {
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

    func addBackEdges(c:Context, edges:[Edge]) {
      for (i in edges.keys()) {
        addBackEdge(c, edges[i])
      }
    };

    func remBackEdges(c:Context, edges:[Edge]) {
      for (i in edges.keys()) {
        remBackEdge(c, edges[i])
      }
    };

    func addEdge(c:Context, target:NodeId, action:Action) {
      let edge = switch (c.agent) {
      case (#editor) { /* the editor role is not recorded or memoized */ };
      case (#archivist) {
             switch (c.stack) {
             case null { P.unreachable() };
             case (?(source, _)) {
                    let edge = newEdge({name=source}, target, action);
                    c.edges.add(edge)
                  };
             }
           };
      };
    };

    func newEdgeBuf() : T.Adapton.EdgeBuf { Buf.Buf<Edge>(03) };

    func thunkIsDirty(t:Thunk) : Bool {
      for (i in t.outgoing.keys()) {
        if (t.outgoing[i].dirtyFlag) {
          return true
        };
      };
      false
    };

    func dirtyThunk(c:Context, n:Name, thunkNode:Thunk) {
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

    func dirtyRef(c:Context, n:Name, refNode:Ref) {
      beginLogEvent(c);
      for (edge in refNode.incoming.iter()) {
        dirtyEdge(c, edge)
      };
      endLogEvent(c, #dirtyIncomingTo(n));
    };

    func dirtyEdge(c:Context, edge:Edge) {
      if (edge.dirtyFlag) {
        // graph invariants ==> dirtying is already done.
      } else {
        beginLogEvent(c);
        edge.dirtyFlag := true;
        switch (c.store.get(edge.dependent.name)) {
        case null { P.unreachable() };
        case (?#ref(_)) { P.unreachable() };
        case (?#thunk(thunkNode)) {
               dirtyThunk(c, edge.dependent.name, thunkNode)
             };
        };
        endLogEvent(c, #dirtyEdgeFrom(edge.dependent.name));
      }
    };

    func cleanEdge(c:Context, e:Edge) : Bool {
      beginLogEvent(c);
      let successFlag = if (e.dirtyFlag) {
        switch (e.checkpoint, c.store.get(e.dependency.name)) {
        case (#get(oldRes), ?#ref(refNode)) {
               if (T.Eval.resultEq(oldRes, #ok(refNode.content))) {
                 e.dirtyFlag := false;
                 true
               } else { false }
             };
        case (#put(oldVal), ?#ref(refNode)) {
               if (T.Eval.valEq(oldVal, refNode.content)) {
                 e.dirtyFlag := false;
                 true
               } else { false }
             };
        case (#putThunk(oldClos), ?#thunk(thunkNode)) {
               if (T.Closure.closureEq(oldClos, thunkNode.closure)) {
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
               let newRes = evalThunk(c, e.dependency.name, thunkNode);
               if (T.Eval.resultEq(oldRes, newRes)) {
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
      endLogEvent(c, #cleanEdgeTo(e.dependency.name, successFlag));
      successFlag;
    };

    func cleanThunk(c:Context, n:Name, t:Thunk) : Bool {
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

    func stackContainsNodeName(s:Stack, nodeName:Name) : Bool {
      L.exists<Name>(s, func (n:Name) : Bool { T.Eval.nameEq(n, nodeName) })
    };

    func evalThunk(c:Context, nodeName:Name, thunkNode:Thunk) : Result {
      beginLogEvent(c);
      let oldEdges = c.edges;
      let oldStack = c.stack;
      let oldAgent = c.agent;
      // if nodeName exists on oldStack, then we have detected a cycle.
      if (stackContainsNodeName(oldStack, nodeName)) {
        return #err(#cyclicDependency(oldStack, nodeName))
      };
      c.agent := #archivist;
      c.edges := Buf.Buf<Edge>(03);
      c.stack := ?(nodeName, oldStack);
      remBackEdges(c, thunkNode.outgoing);
      let res = c.eval(c,
                       thunkNode.closure.env,
                       thunkNode.closure.exp);
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

    func beginLogEvent(c:Context) {
      if (c.logFlag) {
        c.logStack := ?(c.logBuf, c.logStack);
        c.logBuf := Buf.Buf<LogEvent>(03);
      }
    };

    func logEvent(tag:LogEventTag, events:[LogEvent]) : LogEvent {
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

    func endLogEvent(c:Context,
                     tag:LogEventTag)
    {
      if (c.logFlag) {
        switch (c.logStack) {
        case null { assert false };
        case (?(prevLogBuf, logStack)) {
               let events = c.logBuf.toArray();
               let ev : LogEvent = logEvent(tag, events);
               c.logStack := logStack;
               c.logBuf := prevLogBuf;
               c.logBuf.add(ev);
             }
        }
      }
    };
*/

  };
}
