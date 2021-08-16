# Adapton in Motoko, as a class-based generic "functor"

The `Engine` module defines a general-purpose cache and dependence graph
system by closely following ideas from the research project [`Adapton`](http://adapton.org).

See [`types/Eval`](http://matthewhammer.org/motoko-adapton/types/Eval.html) module for details about DSL evaluation within the [`Engine`](http://matthewhammer.org/motoko-adapton/Engine.html).

In brief, the client of this API chooses [4 representations](http://matthewhammer.org/motoko-adapton/types/Eval.html#type.EvalOps)
for a customized incremental interpter that they define:

 - `Name` -- the identity of cached information; must be unique.
 - `Val` -- the type of data stored in Named Refs, and produced by successfully-evaluated Closures.
 - `Error` -- the type of data produced when evaluation errors occur. Misusing the cache can also produce Errors.
 - `Closure` -- the representation of suspended computations stored in Named Thunks.

## Cache operations

Using the types chosen above, the [Engine](http://matthewhammer.org/motoko-adapton/Engine.html#type.Engine) exposes three important cache operations:

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

### [Graph definitions:](http://matthewhammer.org/motoko-adapton/types/Graph.html)

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

#### Clean/dirty invariant

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

#### Further discussion

- All node identities used here are determined by explicit, user-provided names.

- Nominal Adapton (here) supports "classic Adapton" by choosing names
  structurally, as "full hashes"; we do not yet directly support that
  usage here, but it could be easily added later as another feature.

- This code is based on these two Adapton papers:

  1. [Incremental Computation with Names](https://arxiv.org/abs/1503.07792)

  2. [Adapton: composable, demand-driven incremental computation](https://dl.acm.org/doi/abs/10.1145/2666356.2594324)

