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
    // ... by following original cleanSheets implementation (mostly copying it).
  };

}
